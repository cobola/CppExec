#!/bin/bash

# CppExec 全新服务器安装脚本
# 从本地执行，通过 SSH 远程操作服务器

set -e

echo "=========================================="
echo "  CppExec 全新安装脚本"
echo "  警告: 将删除服务器上现有的 CppExec 部署!"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 获取脚本所在目录的父目录（项目根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 加载 .env 配置文件
ENV_FILE="$SCRIPT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    echo -e "${GREEN}加载配置文件: $ENV_FILE${NC}"
    set -a
    source "$ENV_FILE"
    set +a
else
    echo -e "${YELLOW}未找到 .env 文件，使用环境变量或默认值${NC}"
fi

# 配置
SERVER="${CPPEXEC_SERVER:-root@your-server.com}"
REMOTE_DIR="${CPPEXEC_REMOTE_DIR:-/opt/cppexec}"
CONTAINER_NAME="cpp-api-server"
IMAGE_NAME="cpp-api:v1"
PORT="${CPPEXEC_PORT:-4002}"

# API Key 配置
if [ -z "$API_KEY" ]; then
    echo -e "${RED}错误: 请设置 API_KEY（在 .env 文件或环境变量中）${NC}"
    echo "示例: echo \"API_KEY='your-secret-key'\" >> $ENV_FILE"
    exit 1
fi

echo "本地项目目录: $PROJECT_DIR"
echo "目标服务器: $SERVER:$REMOTE_DIR"
echo "服务端口: $PORT"
echo ""

# 检查本地文件
if [ ! -f "$PROJECT_DIR/Dockerfile" ]; then
    echo -e "${RED}错误: 未找到 Dockerfile${NC}"
    exit 1
fi

if [ ! -f "$PROJECT_DIR/main.cpp" ]; then
    echo -e "${RED}错误: 未找到 main.cpp${NC}"
    exit 1
fi

if [ ! -f "$PROJECT_DIR/main.py" ]; then
    echo -e "${RED}错误: 未找到 main.py${NC}"
    exit 1
fi

# 确认操作
echo -e "${RED}警告: 此操作将删除服务器上的以下内容:${NC}"
echo "  - 现有的 $CONTAINER_NAME 容器"
echo "  - 现有的 $IMAGE_NAME 镜像"
echo "  - 项目目录 $REMOTE_DIR"
echo ""
read -p "确定要继续吗? (输入 'yes' 确认): " confirm
if [ "$confirm" != "yes" ]; then
    echo "操作已取消"
    exit 0
fi

echo ""
echo -e "${YELLOW}[1/5] 检查服务器连接...${NC}"
ssh $SERVER "echo '服务器连接成功'"

echo ""
echo -e "${YELLOW}[2/5] 清理服务器...${NC}"
ssh $SERVER "
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
    docker rmi $IMAGE_NAME 2>/dev/null || true
    rm -rf $REMOTE_DIR
    mkdir -p $REMOTE_DIR
    echo '清理完成'
"

echo ""
echo -e "${YELLOW}[3/5] 安装 Docker（如果需要）...${NC}"
ssh $SERVER "
    if ! command -v docker &> /dev/null; then
        echo '安装 Docker...'
        apt-get update
        apt-get install -y curl apt-transport-https ca-certificates gnupg lsb-release
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        systemctl enable docker
        systemctl start docker
    else
        echo 'Docker 已安装'
    fi
"

echo ""
echo -e "${YELLOW}[4/5] 上传代码并构建镜像...${NC}"
rsync -avz --progress \
    --exclude '.git' \
    --exclude 'docs' \
    --exclude 'deploy' \
    --exclude '*.log' \
    --exclude 'cpp_app' \
    --exclude '__pycache__' \
    --exclude '.venv' \
    "$PROJECT_DIR/" "$SERVER:$REMOTE_DIR/"

ssh $SERVER "cd $REMOTE_DIR && docker build -t $IMAGE_NAME ."

echo ""
echo -e "${YELLOW}[5/5] 启动服务...${NC}"
ssh $SERVER "docker run -d \
    -p $PORT:4002 \
    -e API_KEY='$API_KEY' \
    --name $CONTAINER_NAME \
    --restart unless-stopped \
    $IMAGE_NAME"

# 等待服务启动
sleep 5

echo ""
echo "检查服务状态..."
ssh $SERVER "docker ps | grep $CONTAINER_NAME"

echo ""
echo "容器日志:"
ssh $SERVER "docker logs --tail=20 $CONTAINER_NAME"

echo ""
echo -e "${GREEN}=========================================="
echo "  安装完成!"
echo "==========================================${NC}"
echo ""
echo "服务地址: http://\$(服务器IP):$PORT"
echo ""
echo "测试命令:"
echo "  健康检查:"
echo "    curl http://服务器IP:$PORT/health"
echo ""
echo "  执行计算:"
echo "    curl -X POST http://服务器IP:$PORT/execute \\"
echo "      -H 'X-API-Key: \$API_KEY' \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"stdin\": \"1.5 2.5\"}'"
echo ""
echo "常用命令:"
echo "  查看日志: ssh $SERVER 'docker logs -f $CONTAINER_NAME'"
echo "  重启服务: ssh $SERVER 'docker restart $CONTAINER_NAME'"
echo "  停止服务: ssh $SERVER 'docker stop $CONTAINER_NAME'"
echo ""
