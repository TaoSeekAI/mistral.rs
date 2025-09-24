# Docker 部署指南

## 概述

Mistral.rs 支持通过 Docker 进行部署，包括 CPU 和 GPU 版本。本文档介绍如何使用 Docker 和 Docker Compose 部署 Mistral.rs。

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

#### CPU 版本
```bash
# 启动服务器
docker-compose -f docker-compose.yml --profile cpu up -d

# 查看日志
docker-compose -f docker-compose.yml logs -f mistralrs-cpu

# 停止服务器
docker-compose -f docker-compose.yml down
```

#### GPU 版本
```bash
# 使用脚本启动（推荐）
./start-gpu.sh

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