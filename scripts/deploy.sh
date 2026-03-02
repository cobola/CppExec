#!/bin/bash
set -e

cd /opt/cppexec

# 拉取最新镜像
docker compose pull

# 判断当前活跃容器
if docker ps --format '{{.Names}}' | grep -q "cppexec-blue"; then
  NEW="green"
  OLD="blue"
  NEW_PORT=4003
  OLD_PORT=4002
else
  NEW="blue"
  OLD="green"
  NEW_PORT=4002
  OLD_PORT=4003
fi

echo "部署 $NEW (端口 $NEW_PORT), 停止 $OLD (端口 $OLD_PORT)"

# 启动新容器
docker compose up -d "cppexec-$NEW"

# 等待健康检查
echo "等待健康检查..."
for i in $(seq 1 20); do
  sleep 3
  STATUS=$(docker inspect --format='{{.State.Health.Status}}' "cppexec-$NEW" 2>/dev/null || echo "starting")
  echo "  检查 $i/20: $STATUS"
  if [ "$STATUS" = "healthy" ]; then
    break
  fi
done

# 检查新容器是否健康
if docker inspect --format='{{.State.Health.Status}}' "cppexec-$NEW" 2>/dev/null | grep -q "healthy"; then
  echo "新容器健康，部署完成"
  echo "停止旧容器"
  docker compose stop "cppexec-$OLD"
else
  echo "新容器不健康，回滚"
  docker compose stop "cppexec-$NEW"
  exit 1
fi

# 清理旧镜像
docker image prune -f

echo "部署完成！当前活跃: cppexec-$NEW"
