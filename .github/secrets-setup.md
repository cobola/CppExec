# GitHub Secrets 配置说明

## 必需配置

在 GitHub 仓库设置中配置以下 Secrets：

### Aliyun ACR 镜像仓库

| Secret Name | 说明 | 获取方式 |
|------------|------|---------|
| `ALIYUN_USERNAME` | 阿里云容器镜像服务用户名 | 阿里云控制台 → 容器镜像服务 → 访问凭证 |
| `ALIYUN_PASSWORD` | 阿里云容器镜像服务密码 | 同上 |

### 服务器配置

| Secret Name | 说明 | 示例 |
|------------|------|------|
| `APP_SERVER` | 应用服务器 IP 地址或域名 | `jdyun` 或 `192.168.1.100` |
| `NGINX_SERVER` | Nginx 代理服务器 IP 地址或域名 | `hkyun` 或 `192.168.1.101` |
| `SSH_PRIVATE_KEY` | SSH 私钥 | `cat ~/.ssh/id_rsa` |

### 环境变量配置

| Secret Name | 说明 | 格式 |
|------------|------|------|
| `ENV_FILE` | 应用服务器环境变量文件内容 | 多行文本，包含 API_KEY 等 |

示例 `ENV_FILE` 内容：
```
API_KEY=your-secret-api-key
RATE_LIMIT=60
RATE_WINDOW=60
CLEANUP_INTERVAL=300
```

### 飞书通知（可选）

| Secret Name | 说明 | 获取方式 |
|------------|------|---------|
| `FEISHU_WEBHOOK_URL` | 飞书机器人 Webhook 地址 | 飞书群 → 设置 → 群机器人 |

## 配置步骤

1. 进入 GitHub 仓库 → Settings → Secrets and variables → Actions
2. 点击 "New repository secret"
3. 逐个添加上述 Secrets

## 服务器架构

```
┌─────────────────┐         ┌─────────────────┐
│  Nginx Server   │         │  App Server     │
│  (NGINX_SERVER) │────────▶│  (APP_SERVER)   │
│                 │         │                 │
│  - Nginx (80)   │         │  - Docker       │
│  - 域名解析      │         │  - Blue: 4002   │
│                 │         │  - Green: 4003  │
└─────────────────┘         └─────────────────┘
```

## 部署流程

1. **构建镜像**：GitHub Actions 构建并推送到阿里云 ACR
2. **部署应用**：SSH 到 APP_SERVER 执行蓝绿部署
3. **更新 Nginx**：SSH 到 NGINX_SERVER 更新配置并重启
4. **健康检查**：自动检测活跃端口并更新 Nginx upstream

## 验证配置

配置完成后，可以手动触发工作流验证：

1. 进入 Actions 页面
2. 选择 "Build and Deploy CppExec"
3. 点击 "Run workflow"
4. 查看执行日志

## 故障排查

### 镜像推送失败
- 检查 `ALIYUN_USERNAME` 和 `ALIYUN_PASSWORD` 是否正确
- 确认阿里云容器镜像服务已创建命名空间 `cobola`

### SSH 连接失败
- 检查 `APP_SERVER` 和 `NGINX_SERVER` 是否正确
- 确认服务器已添加 GitHub Actions 的公钥到 `~/.ssh/authorized_keys`
- 确认服务器防火墙允许 SSH 连接
- 确认 APP_SERVER 和 NGINX_SERVER 之间可以 SSH 互通

### 部署失败
- 检查 APP_SERVER 上 `/opt/cppexec` 目录是否存在且有写入权限
- 检查 `ENV_FILE` 格式是否正确
- 查看应用服务器上的部署日志：`docker logs cppexec-blue` 或 `docker logs cppexec-green`

### Nginx 更新失败
- 检查 NGINX_SERVER 上是否安装了 Nginx
- 检查 Nginx 配置目录权限：`/etc/nginx/conf.d/`
- 确认 APP_SERVER 允许 NGINX_SERVER 通过 SSH 访问

## 服务器间 SSH 互信配置

由于部署过程需要 NGINX_SERVER 从 APP_SERVER 复制配置文件，需要配置服务器间 SSH 互信：

```bash
# 在 NGINX_SERVER 上生成 SSH 密钥（如果没有）
ssh-keygen -t rsa -b 4096

# 将 NGINX_SERVER 的公钥添加到 APP_SERVER
ssh-copy-id root@APP_SERVER

# 测试连接
ssh root@APP_SERVER "echo 'SSH 互信配置成功'"
```

## 域名配置

确保域名 `c.noiquest.com` 的 DNS 解析指向 NGINX_SERVER 的 IP 地址。
