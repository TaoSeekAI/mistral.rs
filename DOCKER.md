# Docker 部署指南

## 概述

Mistral.rs 支持通过 Docker 进行部署，包括 CPU 和 GPU 版本。本文档介绍如何使用 Docker 和 Docker Compose 部署 Mistral.rs。

## 最新更新 (2025-09-24)

### 新增功能
- ✅ **完整的 Docker Compose 支持**: 包括 CPU、GPU 和开发模式配置
- ✅ **GitHub Actions CI/CD**: 自动构建并推送 Docker 镜像到 GitHub Packages
- ✅ **多架构支持**: 支持 linux/amd64 和 linux/arm64 (CPU 版本)
- ✅ **健康检查**: 所有容器配置了健康检查机制
- ✅ **开发模式**: 支持热重载的开发容器配置
- ✅ **构建缓存优化**: 使用 GitHub Actions 缓存和 Registry 缓存加速构建
- ✅ **环境变量配置**: 通过 `.env` 文件灵活配置

### CI/CD 管道
- **docker.yml**: 主要的 Docker 镜像构建和发布工作流
- **docker-compose.yml**: Docker Compose 配置验证和测试
- **docker-release.yml**: 发布版本的多架构镜像构建和部署

## 前置条件

### CPU 版本
- Docker >= 20.10
- Docker Compose >= 2.0

### GPU 版本
- Docker >= 20.10
- Docker Compose >= 2.0
- NVIDIA Container Toolkit
- NVIDIA GPU 驱动 >= 450.80.02

### 安装 NVIDIA Container Toolkit
```bash
# Ubuntu/Debian
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
   && curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add - \
   && curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update
sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker
```

## 快速开始

### 使用 Docker Compose（推荐）

#### 1. 配置环境变量
```bash
# 复制示例配置文件
cp .env.example .env

# 编辑 .env 文件，设置你的配置
vim .env
```

#### 2. CPU 版本
```bash
# 启动服务器
docker compose --profile cpu up -d

# 查看日志
docker compose --profile cpu logs -f

# 健康检查状态
docker compose --profile cpu ps

# 停止服务器
docker compose --profile cpu down
```

#### 3. GPU 版本
```bash
# 启动 GPU 版本
docker compose --profile gpu up -d

# 或使用便捷脚本
./start-gpu.sh

# 查看 GPU 使用情况
docker exec mistralrs-gpu nvidia-smi
```

#### 4. 开发模式
```bash
# 启动开发容器（支持热重载）
docker compose --profile dev up

# 容器内执行命令
docker compose --profile dev exec mistralrs-dev cargo test

# 或手动启动
docker-compose -f docker-compose.gpu.yml up -d

# 查看日志
docker-compose -f docker-compose.gpu.yml logs -f mistralrs

# 停止服务器
docker-compose -f docker-compose.gpu.yml down
```

### 使用 Docker 直接运行

#### CPU 版本
```bash
# 构建镜像
docker build -t mistralrs:latest -f Dockerfile .

# 运行容器
docker run -d \
  --name mistralrs-cpu \
  -p 1234:80 \
  -v $(pwd)/test-multi-config.json:/app/config.json \
  mistralrs:latest \
  mistralrs-server --port 80 multi-model --config /app/config.json
```

#### GPU 版本
```bash
# 构建镜像
docker build -t mistralrs:latest-cuda -f Dockerfile.cuda-all \
  --build-arg CUDA_COMPUTE_CAP=89 \
  --build-arg WITH_FEATURES=cuda,cudnn,flash-attn .

# 运行容器
docker run -d \
  --name mistralrs-gpu \
  --gpus all \
  -p 1234:80 \
  -v $(pwd)/test-multi-config.json:/app/config.json \
  mistralrs:latest-cuda \
  mistralrs-server --port 80 multi-model --config /app/config.json
```

## 配置

### 环境变量
- `HUGGINGFACE_HUB_CACHE`: Hugging Face 模型缓存目录（默认：/data）
- `PORT`: 服务器端口（默认：80）

### 挂载卷
- `/data`: 模型缓存目录
- `/app/config.json`: 多模型配置文件

### GPU 配置
- `CUDA_COMPUTE_CAP`: GPU 计算能力（例如：89 for RTX 4090）
- `WITH_FEATURES`: 编译特性（例如：cuda,cudnn,flash-attn）

## 配置文件

### 创建多模型配置文件
```json
{
  "model1": {
    "Plain": {
      "model_id": "TinyLlama/TinyLlama-1.1B-Chat-v1.0"
    }
  },
  "model2": {
    "Plain": {
      "model_id": "Qwen/Qwen2.5-0.5B-Instruct"
    }
  }
}
```

## 测试部署

### 测试 API
```bash
# 获取模型列表
curl http://localhost:1234/v1/models

# 发送聊天请求
curl -X POST http://localhost:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer token" \
  -d '{
    "model": "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ],
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

### 性能测试
```bash
# 测试 GPU 版本性能
curl -X POST http://localhost:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer token" \
  -d '{
    "model": "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
    "messages": [
      {"role": "user", "content": "Tell me a short story about AI"}
    ],
    "max_tokens": 200,
    "temperature": 0.7
  }' --write-out "%{time_total}\n" --silent
```

## 故障排除

### 常见问题

#### 1. NVIDIA Container Toolkit 问题
```bash
# 检查 NVIDIA 运行时
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi

# 如果失败，重新安装 NVIDIA Container Toolkit
sudo apt-get --purge remove nvidia-docker2
sudo apt-get autoremove
sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker
```

#### 2. GPU 内存不足
```bash
# 监控 GPU 使用情况
nvidia-smi --loop=1

# 限制 GPU 内存使用
docker run -d \
  --name mistralrs-gpu \
  --gpus all \
  --env NVIDIA_VISIBLE_DEVICES=0 \
  -p 1234:80 \
  mistralrs:latest-cuda
```

#### 3. 模型下载失败
```bash
# 检查网络连接
docker exec mistralrs-gpu curl -I https://huggingface.co

# 设置代理（如果需要）
docker run -d \
  --name mistralrs-gpu \
  --gpus all \
  -e HTTP_PROXY=http://proxy:port \
  -e HTTPS_PROXY=http://proxy:port \
  -p 1234:80 \
  mistralrs:latest-cuda
```

#### 4. 容器启动失败
```bash
# 查看详细错误日志
docker-compose -f docker-compose.gpu.yml logs mistralrs

# 进入容器调试
docker exec -it mistralrs-gpu bash

# 检查配置文件
docker exec mistralrs-gpu cat /app/config.json
```

## 性能优化

### GPU 优化
1. **使用合适的计算能力**：
   ```bash
   # RTX 4090: 89
   # RTX 3090: 86
   # RTX 2080 Ti: 75
   ```

2. **启用 Flash Attention**：
   ```bash
   --build-arg WITH_FEATURES=cuda,cudnn,flash-attn
   ```

3. **调整内存分配**：
   ```bash
   docker run -d \
     --name mistralrs-gpu \
     --gpus all \
     --env CUDA_VISIBLE_DEVICES=0 \
     --env NVIDIA_DRIVER_CAPABILITIES=compute,utility \
     -p 1234:80 \
     mistralrs:latest-cuda
   ```

### 存储优化
1. **使用持久化卷**：
   ```bash
   docker volume create mistralrs-cache
   docker run -d \
     --name mistralrs-gpu \
     --gpus all \
     -v mistralrs-cache:/data \
     -p 1234:80 \
     mistralrs:latest-cuda
   ```

2. **缓存模型文件**：
   ```bash
   # 预下载模型
   docker run --rm \
     --gpus all \
     -v mistralrs-cache:/data \
     mistralrs:latest-cuda \
     mistralrs-server --port 80 plain -m TinyLlama/TinyLlama-1.1B-Chat-v1.0
   ```

## 安全考虑

1. **网络安全**：
   ```bash
   # 使用特定网络
   docker network create mistralrs-network
   docker run -d \
     --name mistralrs-gpu \
     --gpus all \
     --network mistralrs-network \
     -p 127.0.0.1:1234:80 \
     mistralrs:latest-cuda
   ```

2. **资源限制**：
   ```bash
   # 限制 CPU 和内存使用
   docker run -d \
     --name mistralrs-gpu \
     --gpus all \
     --cpus=4 \
     --memory=8g \
     -p 1234:80 \
     mistralrs:latest-cuda
   ```

3. **API 认证**：
   ```bash
   # 使用环境变量设置认证
   docker run -d \
     --name mistralrs-gpu \
     --gpus all \
     -e API_TOKEN=your-secret-token \
     -p 1234:80 \
     mistralrs:latest-cuda
   ```

## 更新和维护

### 更新镜像
```bash
# 拉取最新镜像
docker-compose -f docker-compose.gpu.yml pull

# 重新构建和启动
docker-compose -f docker-compose.gpu.yml up -d --force-recreate
```

### 清理资源
```bash
# 清理未使用的镜像
docker image prune -f

# 清理所有未使用的资源
docker system prune -a -f
```

### 监控和日志
```bash
# 查看容器状态
docker stats mistralrs-gpu

# 查看实时日志
docker logs -f mistralrs-gpu

# 查看特定时间范围的日志
docker logs --since 1h mistralrs-gpu
```

## GitHub Actions CI/CD

### 自动化构建和发布流程

#### 1. Docker 镜像构建 (`docker.yml`)
- **触发条件**: 推送到 master/main/vk/* 分支、标签推送、PR、手动触发
- **构建内容**: CPU 和 CUDA 版本镜像
- **发布位置**: GitHub Container Registry (ghcr.io)
- **缓存策略**: GitHub Actions 缓存 + Registry 缓存

```yaml
# 镜像标签格式
ghcr.io/mistralrs/mistralrs:latest          # CPU 版本最新
ghcr.io/mistralrs/mistralrs:latest-cuda     # GPU 版本最新
ghcr.io/mistralrs/mistralrs:v1.0.0          # 特定版本
ghcr.io/mistralrs/mistralrs:v1.0.0-cuda     # GPU 特定版本
```

#### 2. Docker Compose 测试 (`docker-compose.yml`)
- **触发条件**: 推送和 PR
- **测试内容**:
  - Docker Compose 配置验证
  - CPU 容器启动和健康检查
  - API 端点测试
  - 配置文件 lint 检查

#### 3. 发布工作流 (`docker-release.yml`)
- **触发条件**: 创建版本标签 (v*)
- **功能特点**:
  - 多架构支持 (amd64/arm64)
  - 自动创建 manifest
  - 发布通知和总结

### 使用 GitHub Packages

#### 拉取镜像
```bash
# 登录 GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# 拉取最新版本
docker pull ghcr.io/mistralrs/mistralrs:latest
docker pull ghcr.io/mistralrs/mistralrs:latest-cuda

# 拉取特定版本
docker pull ghcr.io/mistralrs/mistralrs:v1.0.0
```

#### 在 Docker Compose 中使用
```yaml
# docker-compose.yml
services:
  mistralrs:
    image: ghcr.io/mistralrs/mistralrs:latest
    # ... 其他配置
```

### CI/CD 配置说明

#### 环境变量
```bash
# .env 文件
GITHUB_REPOSITORY=mistralrs/mistralrs
REGISTRY=ghcr.io
IMAGE_NAME=mistralrs/mistralrs
```

#### 秘密配置
在 GitHub 仓库设置中配置：
- `GITHUB_TOKEN`: 自动提供，用于推送到 GitHub Packages
- `HF_TOKEN`: Hugging Face token，用于下载私有模型

### 本地测试 CI 流程

```bash
# 模拟 CI 构建
docker build --build-arg BUILDKIT_INLINE_CACHE=1 -t test:latest .

# 运行配置验证
docker compose config --quiet

# 运行健康检查测试
docker compose --profile cpu up -d
sleep 30
curl -f http://localhost:1234/v1/models
docker compose down
```

## 故障排除

### 常见问题

#### 1. Docker Compose 版本警告
如果看到 `version` 属性过时警告，这是正常的。新版 Docker Compose 不需要版本声明。

#### 2. GPU 容器无法启动
确保安装了 NVIDIA Container Toolkit：
```bash
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

#### 3. 构建缓存问题
清理构建缓存：
```bash
docker builder prune -a
docker compose build --no-cache
```

#### 4. GitHub Packages 认证失败
确保使用正确的 token：
```bash
export GITHUB_TOKEN=your_token_here
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USER --password-stdin
```

## 性能优化建议

### 1. 使用构建缓存
```bash
# 启用 BuildKit
export DOCKER_BUILDKIT=1

# 使用缓存构建
docker compose build --build-arg BUILDKIT_INLINE_CACHE=1
```

### 2. 优化镜像大小
- 使用多阶段构建
- 清理不必要的依赖
- 使用 slim 基础镜像

### 3. 资源限制
```yaml
# docker-compose.yml
services:
  mistralrs:
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
        reservations:
          cpus: '2'
          memory: 4G
```

## 安全建议

1. **不要在镜像中包含敏感信息**
2. **使用 secrets 管理 tokens**
3. **定期更新基础镜像**
4. **使用只读挂载卷**
5. **限制容器权限**

## 总结

本次更新提供了完整的 Docker 和 CI/CD 支持：

✅ **Docker Compose 多配置支持** - CPU、GPU、开发模式
✅ **GitHub Actions 自动化** - 构建、测试、发布全流程
✅ **多架构镜像支持** - linux/amd64、linux/arm64
✅ **健康检查和监控** - 所有容器配置健康检查
✅ **缓存优化** - 多层缓存策略提升构建速度
✅ **环境变量配置** - 灵活的配置管理

这些改进大大简化了 Mistral.rs 的部署和维护流程。