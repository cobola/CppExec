import os
import re
import shutil
import subprocess
import time
import threading
import uuid
import resource
import signal
from collections import defaultdict
from typing import Optional
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel

app = FastAPI(
    title="CppExec - Docker化C++程序接口服务",
    description="一个轻量级、可扩展的C++程序接口化解决方案",
    version="1.0.0",
    contact={
        "name": "Author",
        "email": "cobola@gmail.com",
    },
    license_info={
        "name": "MIT License",
        "url": "https://opensource.org/licenses/MIT",
    },
)

# Configuration
API_KEY = os.environ.get("API_KEY", "")
RATE_LIMIT = int(os.environ.get("RATE_LIMIT", "60"))  # requests per minute
RATE_WINDOW = int(os.environ.get("RATE_WINDOW", "60"))  # seconds
CLEANUP_INTERVAL = int(os.environ.get("CLEANUP_INTERVAL", "300"))  # cleanup every 5 minutes
PORT = int(os.environ.get("PORT", "4002"))  # service port

# Workspace directory for user code file operations
WORKSPACE_DIR = "/app/workspace"

# Dangerous code patterns that should be blocked
DANGEROUS_PATTERNS = [
    (r'\bsystem\s*\(', 'system() call'),
    (r'\bexec[lv]?[pe]?\s*\(', 'exec*() call'),
    (r'\bfork\s*\(', 'fork() call'),
    (r'\bpopen\s*\(', 'popen() call'),
    (r'\bpthread_create\s*\(', 'pthread_create() call'),
    (r'#include\s*<sys/socket\.h>', 'socket programming'),
    (r'#include\s*<netinet/', 'network programming'),
    (r'#include\s*<arpa/', 'network programming'),
    (r'\bsocket\s*\(', 'socket() call'),
    (r'\bconnect\s*\(', 'connect() call'),
    (r'\bbind\s*\(', 'bind() call'),
    (r'\blisten\s*\(', 'listen() call'),
    (r'\baccept\s*\(', 'accept() call'),
    (r'\bsendto\s*\(', 'sendto() call'),
    (r'\brecvfrom\s*\(', 'recvfrom() call'),
    (r'\bchmod\s*\(', 'chmod() call'),
    (r'\bchown\s*\(', 'chown() call'),
    (r'\bunlink\s*\(', 'unlink() call'),
    (r'\brmdir\s*\(', 'rmdir() call'),
    (r'\bmkdir\s*\(', 'mkdir() call'),
    (r'\brename\s*\(', 'rename() call'),
    (r'\bkill\s*\(', 'kill() call'),
    (r'\basm\s*\(', 'inline assembly'),
    (r'\b__asm__\s*\(', 'inline assembly'),
    (r'\bsetuid\s*\(', 'setuid() call'),
    (r'\bsetgid\s*\(', 'setgid() call'),
    (r'\bchroot\s*\(', 'chroot() call'),
    (r'\bmount\s*\(', 'mount() call'),
    (r'\bumount\s*\(', 'umount() call'),
    (r'\bptrace\s*\(', 'ptrace() call'),
    (r'\bmmap\s*\([^)]*PROT_EXEC', 'executable mmap'),
    (r'\bdlopen\s*\(', 'dlopen() call'),
    (r'\bdlsym\s*\(', 'dlsym() call'),
]


def check_dangerous_code(source_code: str) -> tuple[bool, str]:
    """
    Check if source code contains dangerous patterns.
    Returns (is_safe, reason).
    """
    for pattern, description in DANGEROUS_PATTERNS:
        if re.search(pattern, source_code):
            return False, f"Forbidden: {description} is not allowed"
    return True, ""


def set_resource_limits():
    """Set resource limits for subprocess execution."""
    # Memory limit: 256MB
    mem_limit = 256 * 1024 * 1024
    resource.setrlimit(resource.RLIMIT_AS, (mem_limit, mem_limit))

    # CPU time limit: 10 seconds
    resource.setrlimit(resource.RLIMIT_CPU, (10, 10))

    # Max file size: 10MB
    file_limit = 10 * 1024 * 1024
    resource.setrlimit(resource.RLIMIT_FSIZE, (file_limit, file_limit))

    # Max number of processes: 1 (no fork)
    resource.setrlimit(resource.RLIMIT_NPROC, (1, 1))

    # Max open files: 20
    resource.setrlimit(resource.RLIMIT_NOFILE, (20, 20))


def clean_workspace():
    """Clean up workspace directory before each execution."""
    if os.path.exists(WORKSPACE_DIR):
        for item in os.listdir(WORKSPACE_DIR):
            path = os.path.join(WORKSPACE_DIR, item)
            try:
                if os.path.isfile(path):
                    os.remove(path)
                else:
                    shutil.rmtree(path)
            except:
                pass


# Rate limiting storage
ip_requests: dict[str, list[float]] = defaultdict(list)
ip_lock = threading.Lock()


def cleanup_expired_records():
    """Periodically clean up expired IP records."""
    while True:
        time.sleep(CLEANUP_INTERVAL)
        current_time = time.time()
        with ip_lock:
            expired_ips = []
            for ip, timestamps in ip_requests.items():
                ip_requests[ip] = [t for t in timestamps if current_time - t < RATE_WINDOW]
                if not ip_requests[ip]:
                    expired_ips.append(ip)
            for ip in expired_ips:
                del ip_requests[ip]


# Start cleanup thread
cleanup_thread = threading.Thread(target=cleanup_expired_records, daemon=True)
cleanup_thread.start()


@app.middleware("http")
async def security_middleware(request: Request, call_next):
    # Skip auth for health check
    if request.url.path == "/health":
        return await call_next(request)

    # API Key authentication
    if API_KEY:
        request_key = request.headers.get("X-API-Key", "")
        if request_key != API_KEY:
            return JSONResponse(
                status_code=401,
                content={"error": "Invalid or missing API key"}
            )

    # Rate limiting
    client_ip = request.client.host if request.client else "unknown"
    current_time = time.time()

    with ip_lock:
        ip_requests[client_ip] = [
            t for t in ip_requests[client_ip] if current_time - t < RATE_WINDOW
        ]
        if len(ip_requests[client_ip]) >= RATE_LIMIT:
            return JSONResponse(
                status_code=429,
                content={"error": "Rate limit exceeded"}
            )
        ip_requests[client_ip].append(current_time)

    return await call_next(request)


class ExecuteRequest(BaseModel):
    stdin: str = ""


class ExecuteResponse(BaseModel):
    stdout: str
    stderr: str
    exit_code: int
    time: float


# Judge0-compatible status codes
class StatusCode:
    ACCEPTED = 3
    WRONG_ANSWER = 4
    TIME_LIMIT_EXCEEDED = 5
    COMPILATION_ERROR = 6
    RUNTIME_ERROR_SIGSEGV = 7
    RUNTIME_ERROR_OTHER = 11


class SubmissionRequest(BaseModel):
    source_code: str
    stdin: str = ""
    time_limit: float = 5.0
    memory_limit: int = 256000  # KB


class SubmissionResponse(BaseModel):
    stdout: str
    stderr: str
    status: dict
    time: float
    memory: int  # KB
    compile_output: str = ""


@app.get("/health")
async def health_check():
    return {"status": "healthy"}


@app.post("/execute", response_model=ExecuteResponse)
async def execute(request: ExecuteRequest):
    args = request.stdin.strip().split()

    start_time = time.time()
    try:
        result = subprocess.run(
            ["./cpp_app"] + args,
            capture_output=True,
            text=True,
            timeout=10
        )
        elapsed_time = time.time() - start_time

        return ExecuteResponse(
            stdout=result.stdout,
            stderr=result.stderr,
            exit_code=result.returncode,
            time=elapsed_time
        )
    except subprocess.TimeoutExpired:
        elapsed_time = time.time() - start_time
        return ExecuteResponse(
            stdout="",
            stderr="Execution timed out",
            exit_code=-1,
            time=elapsed_time
        )
    except Exception as e:
        elapsed_time = time.time() - start_time
        return ExecuteResponse(
            stdout="",
            stderr=str(e),
            exit_code=-1,
            time=elapsed_time
        )


@app.post("/submissions", response_model=SubmissionResponse)
async def submit_code(request: SubmissionRequest):
    """
    Compile and execute C++ source code.
    Returns Judge0-compatible status codes.
    """
    # Check for dangerous code patterns
    is_safe, reason = check_dangerous_code(request.source_code)
    if not is_safe:
        return SubmissionResponse(
            stdout="",
            stderr=reason,
            status={"id": StatusCode.RUNTIME_ERROR_OTHER, "description": reason},
            time=0.0,
            memory=0,
            compile_output=""
        )

    submission_id = str(uuid.uuid4())[:8]
    source_file = f"/tmp/submission_{submission_id}.cpp"
    binary_file = f"/tmp/submission_{submission_id}"

    compile_output = ""
    stdout = ""
    stderr = ""
    status_id = StatusCode.ACCEPTED
    status_desc = "Accepted"
    exec_time = 0.0
    memory_used = 0

    try:
        # Write source code to temp file
        with open(source_file, 'w') as f:
            f.write(request.source_code)

        # Compile with security flags
        compile_start = time.time()
        compile_result = subprocess.run(
            ["g++", "-std=c++17", "-O2", "-fno-stack-protector", "-o", binary_file, source_file],
            capture_output=True,
            text=True,
            timeout=30
        )

        if compile_result.returncode != 0:
            compile_output = compile_result.stderr
            status_id = StatusCode.COMPILATION_ERROR
            status_desc = "Compilation Error"
            return SubmissionResponse(
                stdout="",
                stderr="",
                status={"id": status_id, "description": status_desc},
                time=0.0,
                memory=0,
                compile_output=compile_output
            )

        # Clean workspace before execution
        clean_workspace()

        # Execute with timeout and resource limits
        exec_start = time.time()
        try:
            result = subprocess.run(
                [binary_file],
                input=request.stdin,
                capture_output=True,
                text=True,
                timeout=request.time_limit,
                cwd=WORKSPACE_DIR,
                preexec_fn=set_resource_limits
            )
            exec_time = time.time() - exec_start

            stdout = result.stdout
            stderr = result.stderr

            # Check exit code for runtime errors
            if result.returncode != 0:
                if result.returncode == -signal.SIGSEGV or result.returncode == 139:
                    status_id = StatusCode.RUNTIME_ERROR_SIGSEGV
                    status_desc = "Runtime Error (SIGSEGV)"
                elif result.returncode == -signal.SIGXCPU or result.returncode == 137:
                    status_id = StatusCode.TIME_LIMIT_EXCEEDED
                    status_desc = "Time Limit Exceeded (CPU)"
                else:
                    status_id = StatusCode.RUNTIME_ERROR_OTHER
                    status_desc = f"Runtime Error (exit code: {result.returncode})"
            else:
                status_id = StatusCode.ACCEPTED
                status_desc = "Accepted"

        except subprocess.TimeoutExpired:
            exec_time = request.time_limit
            status_id = StatusCode.TIME_LIMIT_EXCEEDED
            status_desc = "Time Limit Exceeded"

    except Exception as e:
        stderr = str(e)
        status_id = StatusCode.RUNTIME_ERROR_OTHER
        status_desc = f"Runtime Error: {str(e)}"

    finally:
        # Cleanup temp files
        for f in [source_file, binary_file]:
            try:
                os.remove(f)
            except:
                pass
        # Clean workspace after execution
        clean_workspace()

    return SubmissionResponse(
        stdout=stdout,
        stderr=stderr,
        status={"id": status_id, "description": status_desc},
        time=round(exec_time, 3),
        memory=memory_used,
        compile_output=compile_output
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=4002)
