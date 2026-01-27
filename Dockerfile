# 使用DaoCloud加速的Alpine镜像
FROM docker.m.daocloud.io/library/alpine:3.19

# 设置国内阿里云镜像源
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 安装依赖（g++编译器和Python3环境）
RUN apk add --no-cache g++ python3 py3-pip

# 设置工作目录
WORKDIR /app

# 复制源代码文件
COPY main.cpp main.py ./

# 编译C++程序
RUN g++ -std=c++11 -O2 -o cpp_app main.cpp

# 创建Python虚拟环境并安装依赖
RUN python3 -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

# 使用国内阿里云PyPI镜像源安装Python依赖
RUN pip install --no-cache-dir -i https://mirrors.aliyun.com/pypi/simple/ fastapi uvicorn pydantic

# 暴露服务端口
EXPOSE 4002

# 启动FastAPI服务
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "4002"]
