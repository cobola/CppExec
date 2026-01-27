import os
import subprocess
import time
import threading
from collections import defaultdict
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


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=4002)
