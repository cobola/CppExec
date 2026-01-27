# Requirements Document: Dockerized C++ Program API Service

## 1. Document Overview

### 1.1 Purpose

This document defines the development requirements, technical specifications, deployment requirements, and API standards for the Dockerized C++ Program API Service. It serves as the basis for the entire development, testing, and deployment process, ensuring the final product meets the core goals of "minimal deployment, easy replacement, and cross-platform support".

### 1.2 Scope

Applicable to developers, testers, and operations personnel, covering all aspects including C++ business program encapsulation, FastAPI interface layer development, Docker packaging configuration, deployment, and API invocation.

### 1.3 Core Positioning

For lightweight C++ programs (computation/logic judgment types), this provides an integrated "interface layer + containerization" solution, supporting local/server/Docker multi-environment deployment, lowering the barrier for new developers, and enabling rapid business logic iteration through single-file replacement.

## 2. Project Background and Goals

### 2.1 Project Background

C++ programs have advantages in computational performance and logic processing, but directly providing HTTP interfaces has high development costs, poor cross-platform compatibility, and complex deployment configurations. Through lightweight interface layer encapsulation + containerization technology, this project addresses the needs for C++ program API invocation and convenient deployment while balancing ease of use and compatibility.

### 2.2 Core Goals

- **Minimal Deployment**: Only 3 core files needed, supports one-click Docker build and startup, easy for beginners to get started
- **API Invocation**: Provides standard HTTP interface, supports GET/POST methods, no need to directly operate C++ programs
- **High Compatibility**: Supports Windows/macOS/Linux multi-system deployment, relies on Docker for environment consistency
- **Extensibility**: Supports rapid C++ business logic replacement, flexible adjustment of interface parameters and dependencies
- **Lightweight and Efficient**: Image size controlled to hundreds of MB, stable operation on low-spec servers (1 core, 2GB)

## 3. Functional Requirements

### 3.1 C++ Business Program Module

- **Interaction Method**: Supports command-line parameter input, returns results through standard console output, no extra print information (for easy interface layer capture)
- **Parameter Validation**: Has basic parameter validity checking capability, outputs clear error messages and returns non-zero status code on parameter errors
- **Replaceability**: Core business logic is independent, supports user replacement with custom computation/logic judgment code without modifying the interaction mechanism
- **Example Function**: Default implementation of double floating-point addition logic as a basic demonstration template

### 3.2 FastAPI Interface Layer Module

- **Interface Capability**: Provides Judge0-compatible core interface (/execute), supports POST request method, interface standards aligned with Judge0 basic execution specifications for easy integration with existing Judge0 adaptation systems

- **Parameter Processing**: Follows Judge0 interface parameter format, receives input parameters matching the C++ program (original a, b parameters adapted to Judge0 standard fields while preserving core parameter passing logic), forwards to C++ executable, captures output results, error messages, and exit codes, synchronously adapts to Judge0 return field mapping

- **Return Format**: Unified JSON return, balancing original functional logic and Judge0 compatibility, fields include status (status information), stdout (program output), stderr (error information), exit_code (exit code), while preserving original status codes for troubleshooting:
  - Success: `{"code":200,"msg":"Success","status":{"id":1,"description":"Completed"},"stdout":"result","stderr":"","exit_code":0}`
  - C++ program error: `{"code":500,"msg":"C++ program execution failed","status":{"id":2,"description":"Runtime Error"},"stdout":"","stderr":"error details","exit_code":1}`
  - Interface layer error: `{"code":400,"msg":"API call failed","status":{"id":3,"description":"Bad Request"},"stdout":"","stderr":"error details","exit_code":-1}`

- **Local Testing**: Supports running Python file directly to start service without Docker dependency, test port defaults to 4002

- **Security Restrictions**: Interface calls must satisfy dual security verification: first, request header must carry API Key authentication (X-API-Key), requests without valid Key are rejected; second, single IP request frequency limited to ≤60 per minute, exceeding frequency returns rate limit notice to prevent malicious calls

### 3.3 Docker Packaging Module

- **Base Image**: Uses Alpine 3.19 to ensure lightweight and compatibility
- **Auto Build**: Integrates C++ compilation environment (g++) and Python dependencies (fastapi, uvicorn), automatically compiles C++ code to generate executable during build
- **Port Exposure**: Default exposes port 4002 (uncommon port to avoid conflicts with common ports, reducing port occupation risk), consistent with interface service port, supports custom mapping but recommends keeping 4002 as container internal port
- **Startup Command**: Container automatically starts uvicorn service after startup, listens on all IP addresses, port fixed at 4002, command: `["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "4002"]`

### 3.4 Deployment and Invocation Module

- **Deployment Commands**: Provides 3 core Docker commands (build image, start container, verify status), supports cross-platform execution

- **Invocation Methods**: Supports 3 interface invocation methods to meet different scenario needs:
  - Postman: POST request for quick testing
  - curl command: POST request, suitable for server/terminal scenarios
  - Python code: POST request, convenient for business system integration

- **Status Verification**: Supports viewing container running status through Docker commands to ensure service starts normally

## 4. Non-Functional Requirements

### 4.1 Compatibility

Supports Windows 10+/macOS 12+/Linux (CentOS 7+/Ubuntu 20.04+) systems, Docker version requires ≥20.10.0

### 4.2 Performance

Single container on 1-core 2GB server supports ≥50 interface calls per second, interface response time ≤100ms (excluding C++ business logic time)

### 4.3 Usability

Core files can run without modification, replacing C++ business logic only requires adjusting 3 key points with clear modification guidance; deployment and invocation steps are concise with no complex configuration

### 4.4 Extensibility

- Supports C++ program parameter quantity and type adjustment, interface layer can adapt synchronously
- Supports C++ third-party dependency library integration, can be extended through Dockerfile compilation commands
- Supports interface authentication, multi-process startup, directory mounting, and other advanced feature extensions

### 4.5 Stability

Container runs in background without abnormal exits; interface call errors return clear error messages for easy troubleshooting

## 5. Technical Specifications

### 5.1 File Structure Specification

Core files are uniformly placed in the same directory (CppExec/), structure as follows, directory hierarchy cannot be changed arbitrarily:

```
CppExec/
├── main.cpp       # C++ business program (core file for custom business logic)
├── main.py        # FastAPI interface layer file (fixed template, parameters can be fine-tuned)
└── Dockerfile     # Docker packaging configuration file (fixed template, dependencies can be extended)
```

### 5.2 Technology Stack Requirements

- **C++**: Supports C++11 and above standards, compiled to generate executable file (named cpp_app)
- **Python**: 3.8+, dependency versions: fastapi≥0.100.0, uvicorn≥0.23.2
- **Docker**: Base image Alpine 3.19, dependency tools: g++, python3, py3-pip, gcc, make

### 5.3 Coding Standards

- **C++**: Code is concise and maintainable, parameter validation logic comes first, output results contain only business data, no redundant logs
- **Python**: Complete interface comments, comprehensive exception catching, standardized variable naming (lowercase English + underscore), maintain code readability
- **Dockerfile**: Commands written in order of "install dependencies → set directory → copy files → compile → install dependencies → start", minimize image layers

## 6. Core Modification Points (Business Replacement Guide)

When replacing with custom C++ business logic, only the following 3 points need adjustment, no other code modifications required:

1. **main.cpp**: Replace core business logic, preserve "command-line parameters + console output results" interaction method, synchronously adjust parameter validation logic (argc count), ensure output format can adapt to Judge0's stdout/stderr fields

2. **main.py**: First, change interface path to /execute, parameters and return format adapted to Judge0 standard; second, add API Key authentication and IP rate limiting logic; third, synchronously modify port to 4002, subprocess parameter list corresponds to C++ program argc/argv

3. **Dockerfile (optional)**: If C++ program depends on third-party libraries, add link parameters after g++ compilation command (e.g., -lxxx, where xxx is library name); no need to adjust port configuration (already fixed at 4002)

## 7. Advanced Optimization Requirements (Optional)

Based on actual business scenarios, the following optimization features can be selectively implemented:

1. **Concurrency Optimization**: Enable uvicorn multi-process in Docker startup command (--workers 4), adapt to multi-core CPU while maintaining port 4002

2. **File Mounting**: Add directory mounting when starting container (-v /local/path:/app/data), supports C++ program reading and writing external files

3. **Performance Optimization**: Compile C++ program as dynamic library (.so/.dll), call directly through Python ctypes, eliminate subprocess startup overhead while not affecting Judge0 interface compatibility

4. **Security Optimization**: Strengthen interface security restrictions, beyond basic API Key authentication and rate limiting, can extend IP whitelist mechanism to only allow specified IPs to access interface; also prohibit container from running as root user to reduce security risks

5. **Operations Optimization**: Integrate docker-compose for container auto-start and log persistence management, synchronously specify port 4002 mapping in configuration file

## 8. Deployment and Invocation Instructions

### 8.1 Deployment Steps

1. **Build Image**: `docker build -t cpp-api:v1 .` (image name and version can be customized)

2. **Start Container**: `docker run -d -p 4002:4002 --name cpp-api-server cpp-api:v1` (port mapping keeps internal and external consistent at 4002 to avoid conflicts, container name can be customized)

3. **Verify Status**: `docker ps`, confirm container status is "Up" for successful deployment, can view port 4002 listening logs through docker logs

### 8.2 API Invocation Specification

- **Endpoint**: `http://[IP]:4002/execute` (local IP is 127.0.0.1, default port 4002, server uses public IP, must carry API Key in request)
- **Method**: POST, request header must carry X-API-Key field with preset key value
- **Parameter Format**: Follows Judge0 interface standard key-value format, core parameters consistent with C++ program receiving types while compatible with original business parameter logic

## 9. Server Deployment Notes

1. **Port Opening**: Server firewall/security group only opens port 4002, recommend restricting source IP access to further reduce port exposure risk

2. **Dependency Check**: Server must have Docker pre-installed, version ≥20.10.0, to avoid build failures

3. **Resource Adaptation**: Low-spec servers recommend closing unnecessary processes to ensure sufficient container running resources, also monitor port 4002 occupation to prevent malicious port occupation

4. **Long-term Operation**: Use docker-compose for container auto-start, fix port 4002 mapping and secure startup parameters in configuration file; regularly update API Key to strengthen authentication security

## 10. Appendix

1. This document's requirements focus on "minimal deployment" as core; if business needs to extend complex features, requirements can be supplemented and revised

2. Development process must strictly follow technical specifications to ensure product compatibility and extensibility

3. When interface call exceptions occur, prioritize checking container running status, C++ program parameter format, and business logic
