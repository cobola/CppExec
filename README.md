# CppExec - Dockerized C++ Program API Service

A lightweight, extensible solution for wrapping C++ programs as standard HTTP API services using Docker containerization. 

**简体中文** | [English](#cppexec---dockerized-c-program-api-service)

## ✨ Features

- 🚀 **Minimal Deployment**: Only 3 core files, one-click Docker build and run
- 🌐 **Cross-Platform**: Supports Windows/macOS/Linux deployment
- ⚡ **High Performance**: 50+ QPS per container, <10ms response time
- 🔒 **Secure**: API Key authentication + IP rate limiting
- 🔄 **Extensible**: C++ business logic can be quickly replaced
- 📦 **Lightweight**: Alpine-based image, <200MB size
- 🎯 **Judge0 Compatible**: Interface standards aligned with Judge0

---

# CppExec - Docker化C++程序接口服务

一个轻量级、可扩展的C++程序接口化解决方案，通过Docker容器化技术，将C++程序快速封装为标准HTTP接口服务。

## ✨ 特性

- 🚀 **极简部署**：仅需3个核心文件，一键Docker构建与启动
- 🌐 **跨平台**：支持Windows/macOS/Linux多系统部署
- ⚡ **高性能**：单容器支持50+ QPS，响应时间<10ms
- 🔒 **安全可靠**：API Key鉴权 + IP频率限制双重防护
- 🔄 **易扩展**：C++业务逻辑快速替换，无需修改接口层
- 📦 **轻量高效**：Alpine镜像，体积控制在200MB以内
- 🎯 **Judge0兼容**：接口标准对齐Judge0，便于集成现有体系

## 🚀 快速开始

### 前置要求

- Docker >= 20.10.0
- 网络连接（用于拉取基础镜像）

### 1. 克隆项目

```bash
git clone <repository-url>
cd CppExec
```

### 2. 构建Docker镜像

```bash
docker build -t cpp-exec:latest .
```

### 3. 启动容器服务

```bash
docker run -d -p 4002:4002 --name cpp-exec-server cpp-exec:latest
```

### 4. 测试接口

```bash
# 健康检查
curl http://localhost:4002/health

# 执行C++程序（双数加法）
curl -X POST http://localhost:4002/execute \
  -H "Content-Type: application/json" \
  -d '{"stdin": "1.5 2.5"}'
```

**响应示例：**
```json
{"stdout":"4\n","stderr":"","exit_code":0,"time":0.0024}
```

## 📖 接口文档

### 基础信息

- **接口地址**：`http://[IP]:4002/execute`
- **请求方式**：POST
- **Content-Type**：application/json
- **认证方式**：请求头 `X-API-Key`（可选，通过环境变量配置）

### 请求参数

```json
{
    "stdin": "1.5 2.5"  // C++程序输入参数，空格分隔
}
```

### 响应格式

#### 成功响应
```json
{
    "stdout": "4\n",
    "stderr": "",
    "exit_code": 0,
    "time": 0.0024
}
```

#### 错误响应
```json
{
    "stdout": "",
    "stderr": "Usage: ./cpp_app <num1> <num2>\n",
    "exit_code": 1,
    "time": 0.0023
}
```

### 状态码说明

| 状态码 | 含义 |
|--------|------|
| 200 | 执行成功 |
| 400 | 请求参数错误 |
| 401 | 未授权访问（API Key错误） |
| 429 | 请求频率超限 |
| 500 | 服务器内部错误 |

## 🎨 自定义C++业务逻辑

### 替换步骤

1. **修改C++代码**：编辑 `main.cpp`
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
       double result = a + b;  // 替换为你的业务逻辑
       
       cout << result << endl;
       return 0;
   }
   ```

2. **重新构建镜像**：
   ```bash
   docker build -t cpp-exec:latest .
   ```

3. **重启容器**：
   ```bash
   docker restart cpp-exec-server
   ```

### 注意事项

- 保持命令行传参 + 标准输出的交互方式
- 参数校验逻辑前置，错误信息输出到stderr
- 返回码0表示成功，非0表示失败

## 🔧 环境变量配置

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| API_KEY | 接口访问密钥（为空时不启用鉴权） | 空 |
| RATE_LIMIT | 单IP每分钟请求限制 | 60 |
| PORT | 服务端口 | 4002 |

**示例：**
```bash
docker run -d -p 4002:4002 \
  -e API_KEY="your-secret-key" \
  -e RATE_LIMIT="100" \
  --name cpp-exec-server \
  cpp-exec:latest
```

## 📦 项目结构

```
CppExec/
├── main.cpp          # C++业务程序（可自定义）
├── main.py           # FastAPI接口层
├── Dockerfile        # Docker打包配置
├── deploy/
│   ├── .env          # 环境变量配置
│   └── fresh-install.sh  # 一键部署脚本
├── docs/
│   ├── 需求.md       # 需求文档
│   └── 设计文档.md    # 设计文档
├── README.md         # 项目说明文档
└── LICENSE           # MIT许可证
```

## 🚀 进阶使用

### 多进程启动（提高并发）

```bash
docker run -d -p 4002:4002 \
  --name cpp-exec-server \
  cpp-exec:latest \
  uvicorn main:app --host 0.0.0.0 --port 4002 --workers 4
```

### 文件挂载（支持C++程序读写外部文件）

```bash
docker run -d -p 4002:4002 \
  -v /本地目录:/app/data \
  --name cpp-exec-server \
  cpp-exec:latest
```

### 查看日志

```bash
docker logs -f cpp-exec-server
```

## 📊 性能测试

### 压测命令（使用wrk）

```bash
wrk -t4 -c100 -d30s http://localhost:4002/health
```

### 测试结果示例

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

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

### 开发流程

1. Fork本仓库
2. 创建特性分支：`git checkout -b feature/AmazingFeature`
3. 提交更改：`git commit -m 'Add some AmazingFeature'`
4. 推送到分支：`git push origin feature/AmazingFeature`
5. 打开Pull Request

### 代码规范

- C++：遵循C++11标准，代码简洁可维护
- Python：遵循PEP8规范，变量命名使用蛇形命名法
- Dockerfile：减少镜像层数，使用多阶段构建（如需要）

## 📝 许可证

本项目采用MIT许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 🙏 致谢

- [FastAPI](https://fastapi.tiangolo.com/) - 现代、快速的Web框架
- [Docker](https://www.docker.com/) - 容器化技术领导者
- [Alpine Linux](https://alpinelinux.org/) - 轻量级Linux发行版

## 📧 联系方式

- 作者：cobola@gmail.com
- 项目地址：<repository-url>
- Issue反馈：<issues-url>

## 📄 变更日志

### v1.0.0 (2024-01-27)

- ✨ 初始版本发布
- 🚀 实现基础C++程序接口化功能
- 📦 Docker容器化部署
- 🔒 API Key鉴权与IP限流
- 🎯 Judge0接口兼容

---

**如果这个项目对你有帮助，请给个Star支持一下！** ⭐