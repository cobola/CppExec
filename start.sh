#!/bin/bash

# CppExec 本地启动脚本
# 支持 Docker 和本地两种启动方式

echo "=========================================="
echo "  CppExec 本地启动脚本"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查 Docker 是否运行
check_docker() {
    if docker info > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 启动 Docker（macOS）
start_docker() {
    echo -e "${YELLOW}正在启动 Docker...${NC}"
    open -a Docker
    
    # 等待 Docker 启动
    echo -e "${YELLOW}等待 Docker 启动完成（最多60秒）...${NC}"
    for i in {1..60}; do
        if check_docker; then
            echo -e "${GREEN}Docker 已启动${NC}"
            return 0
        fi
        sleep 1
    done
    
    echo -e "${RED}Docker 启动超时，请手动启动 Docker Desktop${NC}"
    return 1
}

# 编译 C++ 程序
compile_cpp() {
    echo -e "${YELLOW}正在编译 C++ 程序...${NC}"
    if g++ -std=c++11 -O2 -o cpp_app main.cpp; then
        echo -e "${GREEN}C++ 程序编译成功${NC}"
        return 0
    else
        echo -e "${RED}C++ 程序编译失败${NC}"
        return 1
    fi
}

# 构建 Docker 镜像
build_docker() {
    echo -e "${YELLOW}正在构建 Docker 镜像...${NC}"
    if docker build -t cpp-exec:dev .; then
        echo -e "${GREEN}Docker 镜像构建成功${NC}"
        return 0
    else
        echo -e "${RED}Docker 镜像构建失败${NC}"
        return 1
    fi
}

# 启动 Docker 容器
run_docker() {
    echo -e "${YELLOW}正在启动 Docker 容器...${NC}"
    
    # 停止现有容器
    docker stop cpp-exec-dev 2>/dev/null || true
    docker rm cpp-exec-dev 2>/dev/null || true
    
    if docker run -d -p 4002:4002 --name cpp-exec-dev cpp-exec:dev; then
        echo -e "${GREEN}Docker 容器启动成功${NC}"
        
        # 等待服务启动
        sleep 3
        
        # 测试服务
        echo -e "${YELLOW}正在测试服务...${NC}"
        if curl -s http://localhost:4002/health > /dev/null; then
            echo -e "${GREEN}服务健康检查通过${NC}"
            echo ""
            echo -e "${GREEN}==========================================${NC}"
            echo -e "${GREEN}  CppExec 服务已启动成功！${NC}"
            echo -e "${GREEN}==========================================${NC}"
            echo ""
            echo -e "${YELLOW}服务信息：${NC}"
            echo "  接口地址: http://localhost:4002/execute"
            echo "  健康检查: http://localhost:4002/health"
            echo "  容器名称: cpp-exec-dev"
            echo ""
            echo -e "${YELLOW}测试命令：${NC}"
            echo "  curl -X POST http://localhost:4002/execute \\"
            echo "    -H 'Content-Type: application/json' \\"
            echo "    -d '{\"stdin\": \"1.5 2.5\"}'"
            echo ""
            echo -e "${YELLOW}管理命令：${NC}"
            echo "  查看日志: docker logs -f cpp-exec-dev"
            echo "  停止服务: docker stop cpp-exec-dev"
            echo "  重启服务: docker restart cpp-exec-dev"
            echo "  删除容器: docker rm cpp-exec-dev"
            echo ""
            return 0
        else
            echo -e "${RED}服务启动失败，请查看日志：docker logs cpp-exec-dev${NC}"
            return 1
        fi
    else
        echo -e "${RED}Docker 容器启动失败${NC}"
        return 1
    fi
}

# 本地启动（不使用 Docker）
start_local() {
    echo -e "${YELLOW}使用本地模式启动...${NC}"
    
    # 编译 C++ 程序
    if ! compile_cpp; then
        return 1
    fi
    
    # 检查 Python 环境
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}未找到 Python3，请先安装 Python${NC}"
        return 1
    fi
    
    # 检查依赖
    echo -e "${YELLOW}检查 Python 依赖...${NC}"
    if ! python3 -c "import fastapi, uvicorn, pydantic" &> /dev/null; then
        echo -e "${YELLOW}正在安装 Python 依赖...${NC}"
        if ! pip3 install fastapi uvicorn pydantic; then
            echo -e "${RED}Python 依赖安装失败${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}Python 依赖检查通过${NC}"
    
    # 启动服务
    echo -e "${YELLOW}正在启动服务...${NC}"
    echo -e "${GREEN}服务将在 http://localhost:4002 启动${NC}"
    echo ""
    echo -e "${YELLOW}按 Ctrl+C 停止服务${NC}"
    echo ""
    
    uvicorn main:app --host 0.0.0.0 --port 4002
}

# 主菜单
main_menu() {
    echo ""
    echo "请选择启动方式："
    echo "  1. Docker 模式（推荐）"
    echo "  2. 本地模式（直接运行）"
    echo "  3. 退出"
    echo ""
    read -p "请输入选择 (1-3): " choice
    
    case $choice in
        1)
            echo ""
            echo -e "${YELLOW}选择 Docker 模式启动${NC}"
            
            # 检查 Docker
            if ! check_docker; then
                echo -e "${RED}Docker 未运行${NC}"
                
                read -p "是否自动启动 Docker？(y/n): " answer
                if [[ $answer =~ ^[Yy]$ ]]; then
                    if ! start_docker; then
                        echo -e "${RED}无法启动 Docker，请手动启动 Docker Desktop${NC}"
                        exit 1
                    fi
                else
                    echo -e "${YELLOW}请手动启动 Docker 后再运行本脚本${NC}"
                    exit 1
                fi
            fi
            
            # 构建镜像
            if ! build_docker; then
                exit 1
            fi
            
            # 启动容器
            if ! run_docker; then
                exit 1
            fi
            ;;
            
        2)
            echo ""
            echo -e "${YELLOW}选择本地模式启动${NC}"
            start_local
            ;;
            
        3)
            echo -e "${YELLOW}退出${NC}"
            exit 0
            ;;
            
        *)
            echo -e "${RED}无效选择，请输入 1-3${NC}"
            main_menu
            ;;
    esac
}

# 主程序
main_menu
