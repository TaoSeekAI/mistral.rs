#!/bin/bash

# 启动GPU版本的Mistral.rs服务器
# 确保已安装Docker和NVIDIA Container Toolkit

set -e

echo "检查NVIDIA Docker支持..."
if ! docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
    echo "错误: NVIDIA Container Toolkit未正确安装或配置"
    echo "请参考: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html"
    exit 1
fi

echo "停止现有容器..."
docker-compose -f docker-compose.gpu.yml down || true

echo "构建GPU镜像..."
docker-compose -f docker-compose.gpu.yml build --no-cache

echo "启动Mistral.rs GPU服务器..."
docker-compose -f docker-compose.gpu.yml up -d

echo "等待服务器启动..."
sleep 10

echo "检查服务器状态..."
docker-compose -f docker-compose.gpu.yml ps

echo "查看日志..."
docker-compose -f docker-compose.gpu.yml logs --tail=20 mistralrs

echo ""
echo "服务器已启动在 http://localhost:1234"
echo "使用以下命令查看日志:"
echo "  docker-compose -f docker-compose.gpu.yml logs -f mistralrs"
echo "使用以下命令停止服务器:"
echo "  docker-compose -f docker-compose.gpu.yml down"