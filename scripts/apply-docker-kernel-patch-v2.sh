#!/bin/bash

# Docker 内核补丁脚本 v2
# 基于一加6T实际检查结果，添加缺失的Docker内核配置

set -e

KERNEL_DIR="kernel/oneplus/sdm845"
CONFIG_FILE="arch/arm64/configs/fajita_defconfig"
BACKUP_FILE="arch/arm64/configs/fajita_defconfig.bak"

echo "=========================================="
echo "Docker 内核补丁脚本 v2"
echo "=========================================="
echo ""

# 检查是否在 Android 源码目录中
if [ ! -d "$KERNEL_DIR" ]; then
    echo "错误：未找到内核目录 $KERNEL_DIR"
    echo "请确保在 Android 源码根目录中运行此脚本"
    exit 1
fi

cd "$KERNEL_DIR"

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误：未找到配置文件 $CONFIG_FILE"
    exit 1
fi

# 备份原配置
echo "1. 备份原配置文件..."
if [ -f "$BACKUP_FILE" ]; then
    echo "  备份文件已存在，跳过"
else
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo "  已备份到 $BACKUP_FILE"
fi

# 检查是否已经应用过补丁
if grep -q "Docker support v2" "$CONFIG_FILE"; then
    echo "  检测到已应用过 Docker 补丁 v2"
    read -p "  是否要重新应用？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "  取消操作"
        exit 0
    fi
    # 恢复备份
    cp "$BACKUP_FILE" "$CONFIG_FILE"
fi

# 添加 Docker 内核选项
echo ""
echo "2. 添加 Docker 内核选项..."

cat >> "$CONFIG_FILE" << 'EOF'

# Docker support v2 - 基于一加6T实际检查结果

# Generally Necessary - 网络过滤
CONFIG_BRIDGE_NETFILTER=y
CONFIG_IP6_NF_TARGET_MASQUERADE=y
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y
CONFIG_NETFILTER_XT_MATCH_IPVS=y

# Generally Necessary - 其他
CONFIG_POSIX_MQUEUE=y
CONFIG_IP6_NF_NAT=y

# Optional Features - 存储和IO
CONFIG_CFQ_GROUP_IOSCHED=y
CONFIG_BLK_CGROUP=y
CONFIG_BLK_DEV_THROTTLING=y

# Optional Features - Cgroups
CONFIG_CGROUP_PERF=y
CONFIG_CGROUP_HUGETLB=y
CONFIG_CGROUP_NET_PRIO=y
CONFIG_CFS_BANDWIDTH=y

# Optional Features - 安全
CONFIG_SECURITY_APPARMOR=y

# Optional Features - 文件系统
CONFIG_EXT4_FS_POSIX_ACL=y

# Optional Features - 网络驱动
CONFIG_VXLAN=y
CONFIG_BRIDGE_VLAN_FILTERING=y
CONFIG_IPVLAN=y
CONFIG_DUMMY=y

# Optional Features - 存储驱动
CONFIG_BTRFS_FS=y
CONFIG_BTRFS_FS_POSIX_ACL=y

# 禁用 EFI stub 避免链接错误
CONFIG_EFI=n
CONFIG_EFI_STUB=n
EOF

echo "  已添加 Docker 内核选项"

# 验证配置
echo ""
echo "3. 验证配置..."

# 检查关键选项
REQUIRED_OPTIONS=(
    "CONFIG_NAMESPACES"
    "CONFIG_CGROUPS"
    "CONFIG_OVERLAY_FS"
    "CONFIG_VETH"
    "CONFIG_BRIDGE"
    "CONFIG_NETFILTER"
    "CONFIG_BRIDGE_NETFILTER"
    "CONFIG_IP6_NF_TARGET_MASQUERADE"
    "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE"
    "CONFIG_POSIX_MQUEUE"
    "CONFIG_BLK_CGROUP"
    "CONFIG_IPVLAN"
    "CONFIG_DUMMY"
)

MISSING_COUNT=0
for option in "${REQUIRED_OPTIONS[@]}"; do
    if grep -q "^${option}=y" "$CONFIG_FILE"; then
        echo "  ✓ $option"
    else
        echo "  ✗ $option (缺失)"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
done

echo ""
if [ $MISSING_COUNT -eq 0 ]; then
    echo "✓ 所有必需的内核选项都已添加"
else
    echo "✗ 有 $MISSING_COUNT 个必需选项缺失"
    exit 1
fi

# 显示新增的配置
echo ""
echo "4. 新增的配置内容："
echo "----------------------------------------"
tail -50 "$CONFIG_FILE"
echo "----------------------------------------"

# 提示下一步
echo ""
echo "=========================================="
echo "补丁应用成功！"
echo "=========================================="
echo ""
echo "新增配置："
echo "  - 网络过滤：BRIDGE_NETFILTER, IP6_NF_TARGET_MASQUERADE"
echo "  - 地址匹配：NETFILTER_XT_MATCH_ADDRTYPE, NETFILTER_XT_MATCH_IPVS"
echo "  - 消息队列：POSIX_MQUEUE"
echo "  - 存储控制：BLK_CGROUP, BLK_DEV_THROTTLING"
echo "  - Cgroups：CGROUP_PERF, CGROUP_HUGETLB, CGROUP_NET_PRIO"
echo "  - 调度器：CFQ_GROUP_IOSCHED, CFS_BANDWIDTH"
echo "  - 安全：SECURITY_APPARMOR"
echo "  - 文件系统：EXT4_FS_POSIX_ACL"
echo "  - 网络驱动：VXLAN, BRIDGE_VLAN_FILTERING, IPVLAN, DUMMY"
echo "  - 存储驱动：BTRFS_FS"
echo ""
echo "下一步："
echo "  1. 编译内核："
echo "     cd \$ANDROID_ROOT"
echo "     source build/envsetup.sh"
echo "     lunch fajita-userdebug"
echo "     make bootimage -j\$(nproc)"
echo ""
echo "  2. 提取 boot.img："
echo "     cp out/target/product/fajita/boot.img hybris-boot.img"
echo ""
echo "  3. 刷入设备："
echo "     adb reboot bootloader"
echo "     fastboot flash boot hybris-boot.img"
echo "     fastboot reboot"
echo ""
echo "  4. 启用网络转发（在设备上）："
echo "     sudo sysctl -w net.ipv4.ip_forward=1"
echo "     sudo sysctl -w net.ipv6.conf.all.forwarding=1"
echo "     sudo sysctl -w net.ipv6.conf.default.forwarding=1"
echo ""
echo "  5. 验证 Docker："
echo "     sh check-config.sh"
echo "     docker run --rm hello-world"
echo ""
echo "备份文件：$BACKUP_FILE"
echo "如需恢复原配置：cp $BACKUP_FILE $CONFIG_FILE"
echo ""
