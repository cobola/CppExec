# 贡献指南

感谢你有兴趣为 CppExec 项目做出贡献！

## 行为准则

### 我们的承诺

为了营造一个开放和友好的环境，我们作为贡献者和维护者承诺让每个人都能无骚扰地参与我们的项目和社区。

### 我们的标准

有助于创建积极环境的行为包括：

- 使用友好和包容的语言
- 尊重不同的观点和经验
- 优雅地接受建设性批评
- 关注对社区最有利的事情
- 对其他社区成员表现出同理心

## 如何贡献

### 报告问题

1. 在提交新问题之前，请先搜索现有问题
2. 使用清晰的标题和描述
3. 提供重现步骤
4. 包含屏幕截图（如果适用）
5. 说明你的环境（操作系统、Docker版本等）

### 提交代码

#### 准备开发环境

```bash
# 克隆仓库
git clone <repository-url>
cd CppExec

# 构建Docker镜像
docker build -t cpp-exec:dev .

# 启动开发容器
docker run -d -p 4002:4002 -v $(pwd):/app --name cpp-exec-dev cpp-exec:dev
```

#### 提交PR流程

1. Fork 项目
2. 创建特性分支：
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. 提交更改：
   ```bash
   git commit -m "Add some feature"
   ```
   - 提交信息应清晰描述所做的更改
   - 使用英文或中文均可，保持一致
4. 推送到分支：
   ```bash
   git push origin feature/your-feature-name
   ```
5. 打开 Pull Request

#### 代码规范

**C++ 代码规范**

- 遵循 C++11 及以上标准
- 使用 4 空格缩进
- 变量命名使用蛇形命名法（snake_case）
- 函数命名使用驼峰命名法（camelCase）
- 类名使用大驼峰命名法（PascalCase）
- 保持代码简洁，避免不必要的嵌套
- 添加必要的注释说明复杂逻辑

**Python 代码规范**

- 遵循 PEP 8 规范
- 使用 4 空格缩进
- 变量和函数命名使用蛇形命名法（snake_case）
- 类名使用大驼峰命名法（PascalCase）
- 导入按标准库、第三方库、本地库顺序排列
- 使用类型提示

**Dockerfile 规范**

- 使用官方基础镜像
- 减少镜像层数（合并 RUN 命令）
- 使用 --no-cache-dir 避免缓存
- 按顺序排列命令（安装依赖 → 复制文件 → 构建 → 清理）
- 使用 .dockerignore 排除不必要的文件

### 文档贡献

- 改进 README.md
- 添加使用示例
- 完善 API 文档
- 翻译文档

## 许可证

通过贡献代码，你同意你的贡献将在 MIT 许可证下发布。

## 问题？

如有任何问题，请通过以下方式联系我们：

- 提交 Issue
- 发送邮件至 cobola@gmail.com

再次感谢你的贡献！
