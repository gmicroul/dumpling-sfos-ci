#!/bin/bash

# Docker 网络配置脚本
# 用于在一加6T SailfishOS 上启用 Docker 所需的网络转发

set -e

echo "=========================================="
echo "Docker 网络配置脚本"
echo "=========================================="
echo ""

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then
    echo "错误：请使用 root 权限运行此脚本"
    echo "使用方法：sudo $0"
    exit 1
fi

# 启用 IPv4 转发
echo "1. 启用 IPv4 转发..."
sysctl -w net.ipv4.ip_forward=1
echo "  ✓ net.ipv4.ip_forward=1"

# 启用 IPv6 转发
echo ""
echo "2. 启用 IPv6 转发..."
sysctl -w net.ipv6.conf.all.forwarding=1
echo "  ✓ net.ipv6.conf.all.forwarding=1"

sysctl -w net.ipv6.conf.default.forwarding=1
echo "  ✓ net.ipv6.conf.default.forwarding=1"

# 持久化配置
echo ""
echo "3. 持久化配置..."

# 检查 sysctl 配置文件
SYSCTL_CONF="/etc/sysctl.conf"
SYSCTL_D_DIR="/etc/sysctl.d"

if [ -d "$SYSCTL_D_DIR" ]; then
    # 使用 sysctl.d 目录
    DOCKER_SYSCTL="$SYSCTL_D_DIR/99-docker.conf"
    echo "  写入配置到 $DOCKER_SYSCTL"

    cat > "$DOCKER_SYSCTL" << 'EOF'
# Docker 网络配置
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
EOF
else
    # 使用 sysctl.conf
    echo "  写入配置到 $SYSCTL_CONF"

    # 检查是否已存在配置
    if ! grep -q "^net.ipv4.ip_forward" "$SYSCTL_CONF"; then
        echo "" >> "$SYSCTL_CONF"
        echo "# Docker 网络配置" >> "$SYSCTL_CONF"
        echo "net.ipv4.ip_forward=1" >> "$SYSCTL_CONF"
    fi

    if ! grep -q "^net.ipv6.conf.all.forwarding" "$SYSCTL_CONF"; then
        echo "net.ipv6.conf.all.forwarding=1" >> "$SYSCTL_CONF"
    fi

    if ! grep -q "^net.ipv6.conf.default.forwarding" "$SYSCTL_CONF"; then
        echo "net.ipv6.conf.default.forwarding=1" >> "$SYSCTL_CONF"
    fi
fi

echo "  ✓ 配置已持久化"

# 验证配置
echo ""
echo "4. 验证配置..."

echo ""
echo "当前网络转发状态："
echo "----------------------------------------"
sysctl net.ipv4.ip_forward
sysctl net.ipv6.conf.all.forwarding
sysctl net.ipv6.conf.default.forwarding
echo "----------------------------------------"

# 测试 Docker
echo ""
echo "5. 测试 Docker..."

if command -v docker &> /dev/null; then
    echo "  Docker 已安装"
    echo ""
    echo "  运行 Docker 检查："
    docker info 2>&1 | head -20
else
    echo "  ⚠ Docker 未安装或不在 PATH 中"
    echo "  请先安装 Docker："
    echo "    sudo zypper in docker"
fi

echo ""
echo "=========================================="
echo "配置完成！"
echo "=========================================="
echo ""
echo "下一步："
echo "  1. 运行 Docker 配置检查："
echo "     sh check-config.sh"
echo ""
echo "  2. 测试 Docker："
echo "     docker run --rm hello-world"
echo ""
echo "  3. 启动 Docker 服务："
echo "     sudo systemctl enable docker"
echo "     sudo systemctl start docker"
echo ""
