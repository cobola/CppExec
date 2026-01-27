# CppExec - Dockerized C++ Program API Service

A lightweight, extensible solution for wrapping C++ programs as standard HTTP API services using Docker containerization.

## Features

- **Minimal Deployment**: Only 3 core files, one-click Docker build and run
- **Cross-Platform**: Supports Windows/macOS/Linux deployment
- **High Performance**: 50+ QPS per container, <10ms response time
- **Secure**: API Key authentication + IP rate limiting
- **Extensible**: C++ business logic can be quickly replaced
- **Lightweight**: Alpine-based image, <200MB size
- **Judge0 Compatible**: Interface standards aligned with Judge0

## Quick Start

### Prerequisites

- Docker >= 20.10.0
- Network connection (for pulling base image)

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/CppExec.git
cd CppExec
```

### 2. Build Docker Image

```bash
docker build -t cpp-exec:latest .
```

### 3. Start Container

```bash
docker run -d -p 4002:4002 --name cpp-exec-server cpp-exec:latest
```

### 4. Test the API

```bash
# Health check
curl http://localhost:4002/health

# Execute C++ program (double addition)
curl -X POST http://localhost:4002/execute \
  -H "Content-Type: application/json" \
  -d '{"stdin": "1.5 2.5"}'
```

**Response:**
```json
{"stdout":"4\n","stderr":"","exit_code":0,"time":0.0024}
```

## API Documentation

### Base Information

- **Endpoint**: `http://[IP]:4002/execute`
- **Method**: POST
- **Content-Type**: application/json
- **Authentication**: `X-API-Key` header (optional, configured via environment variable)

### Request Parameters

```json
{
    "stdin": "1.5 2.5"  // C++ program input parameters, space-separated
}
```

### Response Format

#### Success Response
```json
{
    "stdout": "4\n",
    "stderr": "",
    "exit_code": 0,
    "time": 0.0024
}
```

#### Error Response
```json
{
    "stdout": "",
    "stderr": "Usage: ./cpp_app <num1> <num2>\n",
    "exit_code": 1,
    "time": 0.0023
}
```

### Status Codes

| Code | Description |
|------|-------------|
| 200 | Execution successful |
| 400 | Invalid request parameters |
| 401 | Unauthorized (invalid API Key) |
| 429 | Rate limit exceeded |
| 500 | Internal server error |

## Customizing C++ Business Logic

### Steps to Replace

1. **Modify C++ code**: Edit `main.cpp`
   ```cpp
   #include <iostream>
   using namespace std;

   int main(int argc, char* argv[]) {
       if (argc != 3) {
           cerr << "Usage: ./cpp_app <num1> <num2>" << endl;
           return 1;
       }

       double a = stod(argv[1]);
       double b = stod(argv[2]);
       double result = a + b;  // Replace with your business logic

       cout << result << endl;
       return 0;
   }
   ```

2. **Rebuild the image**:
   ```bash
   docker build -t cpp-exec:latest .
   ```

3. **Restart the container**:
   ```bash
   docker restart cpp-exec-server
   ```

### Guidelines

- Maintain command-line arguments + stdout interaction pattern
- Place parameter validation first, output errors to stderr
- Return code 0 for success, non-zero for failure

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| API_KEY | API access key (empty = no authentication) | empty |
| RATE_LIMIT | Requests per minute per IP | 60 |
| PORT | Service port | 4002 |

**Example:**
```bash
docker run -d -p 4002:4002 \
  -e API_KEY="your-secret-key" \
  -e RATE_LIMIT="100" \
  --name cpp-exec-server \
  cpp-exec:latest
```

## Project Structure

```
CppExec/
├── main.cpp          # C++ business program (customizable)
├── main.py           # FastAPI interface layer
├── Dockerfile        # Docker build configuration
├── deploy/
│   ├── .env.example  # Environment variable template
│   └── fresh-install.sh  # One-click deployment script
├── docs/
│   ├── requirements.md   # Requirements document
│   └── design.md         # Design document
├── README.md         # Project documentation
├── CONTRIBUTING.md   # Contribution guidelines
└── LICENSE           # MIT License
```

## Advanced Usage

### Multi-process Mode (Higher Concurrency)

```bash
docker run -d -p 4002:4002 \
  --name cpp-exec-server \
  cpp-exec:latest \
  uvicorn main:app --host 0.0.0.0 --port 4002 --workers 4
```

### Volume Mounting (External File Access)

```bash
docker run -d -p 4002:4002 \
  -v /local/path:/app/data \
  --name cpp-exec-server \
  cpp-exec:latest
```

### View Logs

```bash
docker logs -f cpp-exec-server
```

## Performance Testing

### Benchmark Command (using wrk)

```bash
wrk -t4 -c100 -d30s http://localhost:4002/health
```

### Sample Results

```
Running 30s test @ http://localhost:4002/health
  4 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     2.31ms    1.24ms  25.34ms   90.12%
    Req/Sec    11.06k     1.23k   15.67k    70.33%
  1322661 requests in 30.01s, 176.91MB read
Requests/sec:  44075.23
Transfer/sec:      5.89MB
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [FastAPI](https://fastapi.tiangolo.com/) - Modern, fast web framework
- [Docker](https://www.docker.com/) - Container platform
- [Alpine Linux](https://alpinelinux.org/) - Lightweight Linux distribution

## Contact

- Author: cobola@gmail.com
- Issues: Please use GitHub Issues

## Changelog

### v1.0.0 (2024-01-27)

- Initial release
- Basic C++ program API wrapping functionality
- Docker containerization deployment
- API Key authentication and IP rate limiting
- Judge0 interface compatibility

---

**If this project helps you, please give it a star!**
