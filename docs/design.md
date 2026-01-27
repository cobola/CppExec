# Design Document: Dockerized C++ Program API Service

## 1. Feasibility Analysis

### 1.1 Technical Feasibility

**Mature and Reliable Technology Stack**
- C++ compilation and execution: Standard g++ compiler support with good cross-platform compatibility
- FastAPI interface layer: Mature Python ecosystem, excellent performance, comprehensive documentation
- Docker containerization: Lightweight Alpine image, standardized build process

**Key Challenges Solvable**
- Judge0 interface adaptation: Achievable through parameter mapping and field conversion
- Security mechanisms: API Key authentication + IP rate limiting implementable via middleware
- Performance requirements: 50 QPS per container on 1-core 2GB is fully achievable

### 1.2 Implementation Complexity

**Low Complexity, High Controllability**
- Only 3 core files, clear structure
- Business logic decoupled from interface layer, easy to maintain
- Standardized Docker build process, no special dependencies

**Risk Assessment**
- Low risk: All technologies are industry-standard solutions
- High success rate: Similar architectures widely used in production environments

### 1.3 Conclusion

**Requirements are fully feasible**, with mature technical solutions, moderate implementation difficulty, and can be completed in a short time.

---

## 2. System Architecture Design

### 2.1 Overall Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Client Layer                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ Browser  │  │ Postman  │  │ curl     │  │ Python   │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
└───────┼─────────────┼─────────────┼─────────────┼──────────┘
        │             │             │             │
        ▼             ▼             ▼             ▼
┌─────────────────────────────────────────────────────────────┐
│                        Network Layer                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  HTTP/HTTPS Request → Firewall/Security Group → 4002 │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│                     Docker Container Layer                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Alpine 3.19 Image                                    │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │  FastAPI Service (uvicorn)                     │  │   │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐     │  │   │
│  │  │  │   Auth   │  │   Rate   │  │ Execution│     │  │   │
│  │  │  │Middleware│  │ Limiter  │  │  Engine  │     │  │   │
│  │  │  └────┬─────┘  └────┬─────┘  └────┬─────┘     │  │   │
│  │  └───────┼─────────────┼─────────────┼───────────┘  │   │
│  │          │             │             │              │   │
│  │          ▼             ▼             ▼              │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │  C++ Executable (cpp_app)                      │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Module Division

| Module | Responsibility | Technology |
|--------|---------------|------------|
| **C++ Business Program** | Core computation/logic processing | C++11+, stdin/stdout |
| **FastAPI Interface Layer** | HTTP interface exposure and request handling | Python 3.8+, FastAPI |
| **Security Middleware** | API Key authentication and IP rate limiting | FastAPI Middleware |
| **Execution Engine** | C++ program invocation and result capture | subprocess module |
| **Docker Packaging** | Environment encapsulation and deployment | Alpine 3.19, Dockerfile |

---

## 3. Core Module Design

### 3.1 C++ Business Program Design

#### 3.1.1 Interface Specification

```cpp
// Input: Command-line arguments
// Output: stdout for results, stderr for error messages
// Return code: 0=success, non-zero=failure

// Example code structure
int main(int argc, char* argv[]) {
    // 1. Parameter validation
    if (argc != 3) {
        std::cerr << "Error: 2 parameters required" << std::endl;
        return 1;
    }

    // 2. Business logic processing
    double a = std::stod(argv[1]);
    double b = std::stod(argv[2]);
    double result = a + b;

    // 3. Output result
    std::cout << result << std::endl;
    return 0;
}
```

#### 3.1.2 Compilation Specification

```bash
g++ -std=c++11 -o cpp_app main.cpp
```

### 3.2 FastAPI Interface Layer Design

#### 3.2.1 Interface Definition

```python
from fastapi import FastAPI, Request, HTTPException
from pydantic import BaseModel
import subprocess
import time
from typing import Optional

app = FastAPI(title="C++ Program API Service", version="1.0")

# Judge0-compatible request model
class ExecuteRequest(BaseModel):
    source_code: Optional[str] = None  # Compatibility field
    stdin: Optional[str] = None        # Input parameters
    language_id: Optional[int] = None  # Compatibility field

# Judge0-compatible response model
class Status(BaseModel):
    id: int
    description: str

class ExecuteResponse(BaseModel):
    code: int
    msg: str
    status: Status
    stdout: str
    stderr: str
    exit_code: int
```

#### 3.2.2 Security Middleware

```python
# API Key configuration
API_KEYS = {"your-secret-key-here"}

# IP rate limiting configuration
RATE_LIMIT = 60  # Requests per minute
ip_requests = {}

@app.middleware("http")
async def security_middleware(request: Request, call_next):
    # 1. API Key authentication
    api_key = request.headers.get("X-API-Key")
    if not api_key or api_key not in API_KEYS:
        raise HTTPException(status_code=401, detail="Unauthorized")

    # 2. IP rate limiting
    client_ip = request.client.host
    current_time = time.time()

    if client_ip not in ip_requests:
        ip_requests[client_ip] = []

    # Clean up requests older than 60 seconds
    ip_requests[client_ip] = [
        t for t in ip_requests[client_ip]
        if current_time - t < 60
    ]

    if len(ip_requests[client_ip]) >= RATE_LIMIT:
        raise HTTPException(status_code=429, detail="Rate limit exceeded")

    ip_requests[client_ip].append(current_time)

    response = await call_next(request)
    return response
```

#### 3.2.3 Execute Endpoint Implementation

```python
@app.post("/execute", response_model=ExecuteResponse)
async def execute(request: ExecuteRequest):
    try:
        # Parse parameters (Judge0 format compatible)
        input_params = request.stdin or ""
        params = input_params.split()

        # Build C++ program call command
        cmd = ["./cpp_app"] + params

        # Execute C++ program
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=10  # Timeout limit
        )

        # Build response
        if result.returncode == 0:
            return ExecuteResponse(
                code=200,
                msg="Success",
                status=Status(id=1, description="Completed"),
                stdout=result.stdout.strip(),
                stderr="",
                exit_code=0
            )
        else:
            return ExecuteResponse(
                code=500,
                msg="C++ program execution failed",
                status=Status(id=2, description="Runtime Error"),
                stdout="",
                stderr=result.stderr.strip(),
                exit_code=result.returncode
            )

    except subprocess.TimeoutExpired:
        return ExecuteResponse(
            code=500,
            msg="Program execution timeout",
            status=Status(id=4, description="Time Limit Exceeded"),
            stdout="",
            stderr="Program execution exceeded 10 seconds",
            exit_code=-1
        )
    except Exception as e:
        return ExecuteResponse(
            code=400,
            msg="API call failed",
            status=Status(id=3, description="Bad Request"),
            stdout="",
            stderr=str(e),
            exit_code=-1
        )
```

### 3.3 Docker Packaging Design

#### 3.3.1 Dockerfile

```dockerfile
# Base image
FROM alpine:3.19

# Install dependencies
RUN apk add --no-cache \
    g++ \
    python3 \
    py3-pip \
    gcc \
    make

# Set working directory
WORKDIR /app

# Copy C++ source code
COPY main.cpp .

# Compile C++ program
RUN g++ -std=c++11 -o cpp_app main.cpp

# Copy Python code
COPY main.py .

# Install Python dependencies
RUN pip3 install --no-cache-dir fastapi>=0.100.0 uvicorn>=0.23.2

# Expose port
EXPOSE 4002

# Start command
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "4002"]
```

#### 3.3.2 Build Process

```bash
# Build image
docker build -t cpp-api:v1 .

# Start container
docker run -d -p 4002:4002 --name cpp-api-server cpp-api:v1

# View logs
docker logs -f cpp-api-server
```

---

## 4. API Specification

### 4.1 Basic Information

- **Endpoint**: `http://[IP]:4002/execute`
- **Method**: POST
- **Content-Type**: application/json
- **Authentication**: `X-API-Key` header

### 4.2 Request Parameters

```json
{
    "stdin": "1.5 2.5"  // C++ program input parameters, space-separated
}
```

### 4.3 Response Examples

#### Success Response
```json
{
    "code": 200,
    "msg": "Success",
    "status": {
        "id": 1,
        "description": "Completed"
    },
    "stdout": "4",
    "stderr": "",
    "exit_code": 0
}
```

#### Error Response
```json
{
    "code": 500,
    "msg": "C++ program execution failed",
    "status": {
        "id": 2,
        "description": "Runtime Error"
    },
    "stdout": "",
    "stderr": "Error: 2 parameters required",
    "exit_code": 1
}
```

### 4.4 Usage Examples

#### curl Command
```bash
curl -X POST http://localhost:4002/execute \
  -H "X-API-Key: your-secret-key-here" \
  -H "Content-Type: application/json" \
  -d '{"stdin": "1.5 2.5"}'
```

#### Python Code
```python
import requests

url = "http://localhost:4002/execute"
headers = {
    "X-API-Key": "your-secret-key-here",
    "Content-Type": "application/json"
}
data = {"stdin": "1.5 2.5"}

response = requests.post(url, headers=headers, json=data)
print(response.json())
```

---

## 5. Deployment Guide

### 5.1 Local Development Deployment

```bash
# 1. Compile C++ program
g++ -std=c++11 -o cpp_app main.cpp

# 2. Install Python dependencies
pip install fastapi uvicorn

# 3. Start service
uvicorn main:app --host 0.0.0.0 --port 4002
```

### 5.2 Docker Deployment

```bash
# 1. Build image
docker build -t cpp-api:v1 .

# 2. Start container
docker run -d -p 4002:4002 --name cpp-api-server cpp-api:v1

# 3. Verify service
docker ps
# Output should show cpp-api-server container with status "Up"
```

### 5.3 Server Deployment Notes

1. **Port Configuration**: Ensure server security group allows port 4002
2. **Docker Version**: Requires >= 20.10.0
3. **Resource Configuration**: Recommended 1 core, 2GB+ memory
4. **Security Hardening**:
   - Regularly update API Key
   - Restrict source IP access
   - Avoid running container as root user

---

## 6. Performance Optimization

### 6.1 Concurrency Optimization

```bash
# Start multi-process service
docker run -d -p 4002:4002 \
  --name cpp-api-server \
  cpp-api:v1 \
  uvicorn main:app --host 0.0.0.0 --port 4002 --workers 4
```

### 6.2 Performance Monitoring

```bash
# View container resource usage
docker stats cpp-api-server

# Check API response time
curl -w "%{time_total}\n" http://localhost:4002/execute
```

### 6.3 Advanced Optimization (Optional)

1. **Dynamic Library Calls**: Compile C++ program as shared library, call directly via Python ctypes
2. **Connection Pool Optimization**: Use uvicorn's `--loop uvloop` for better performance
3. **Caching Mechanism**: Cache results for repeated requests

---

## 7. Troubleshooting Guide

### 7.1 Common Issues

| Symptom | Possible Cause | Solution |
|---------|---------------|----------|
| Container fails to start | Port occupied | Change port mapping or free port 4002 |
| API returns 401 | Invalid API Key | Check X-API-Key header |
| API returns 429 | Rate limit exceeded | Reduce request frequency or adjust limit |
| C++ program execution fails | Invalid parameters | Check input parameter format |
| Slow response time | C++ program slow | Optimize C++ logic or increase timeout |

### 7.2 Log Viewing

```bash
# View container logs
docker logs -f cpp-api-server

# View last 100 lines
docker logs --tail 100 cpp-api-server
```

---

## 8. Extension Guide

### 8.1 Business Logic Extension

1. **Replace C++ Program**: Modify `main.cpp` and recompile
2. **Adjust Parameter Format**: Update parameter parsing logic in `main.py`
3. **Add Dependencies**: Add compilation dependencies in Dockerfile

### 8.2 Feature Extension

1. **File Upload**: Add file upload endpoint for C++ program file processing
2. **Result Persistence**: Store execution results in database
3. **Async Execution**: Support task submission and result query mode
4. **Multi-language Support**: Extend to support Python, Java, and other languages

### 8.3 Architecture Extension

```
┌─────────────────────────────────────────────────────────────┐
│                    Extended Architecture                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │   Load   │  │  Cache   │  │  Message │  │ Database │    │
│  │ Balancer │  │  Layer   │  │  Queue   │  │          │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## 9. Summary

This design document provides a complete technical implementation plan based on the requirements document, covering system architecture, core module design, API specifications, and deployment guides. The solution features:

- **High Feasibility**: Mature technology stack, controllable risks
- **Easy Maintenance**: Clear module division, concise code structure
- **Extensibility**: Supports business logic and feature extensions
- **High Performance**: Meets 50 QPS performance requirements
- **Security**: Complete authentication and rate limiting mechanisms

This solution enables rapid implementation of Dockerized C++ program API services, meeting the core goals of "minimal deployment, easy replacement, cross-platform support".
