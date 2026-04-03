#!/bin/bash

# 内核清理脚本
# 用于删除有问题的驱动，避免编译错误

set -e

KERNEL_DIR="${1:-kernel/oneplus/sdm845}"

echo "=========================================="
echo "内核清理脚本"
echo "=========================================="
echo ""

cd "$KERNEL_DIR"

echo "1. 删除有问题的驱动..."

# 删除整个目录（这些驱动对于基本启动不是必需的）
echo "  - 删除 kgsl/adreno GPU 驱动"
rm -rf drivers/gpu/msm || true

echo "  - 删除 vidc 视频驱动"
rm -rf drivers/media/platform/msm/vidc || true

echo "  - 删除 esoc 驱动"
rm -rf drivers/esoc || true

echo "  - 删除 ipc_router"
rm -rf net/ipc_router || true

echo "  - 删除 coresight 调试驱动"
rm -rf drivers/hwtracing/coresight || true

echo "  - 删除 sensors 传感器驱动"
rm -rf drivers/sensors || true

echo "  - 删除 qdsp6v2 DSP 驱动"
rm -rf drivers/soc/qcom/qdsp6v2 || true

echo "  - 删除 IPA 网络加速器"
rm -rf drivers/platform/msm/ipa || true

echo "  - 删除 SPS 流处理器"
rm -rf drivers/platform/msm/sps || true

echo "  - 删除 tracer_pkt 追踪驱动"
rm -rf drivers/soc/qcom/tracer_pkt* || true

echo "  - 删除摄像头驱动"
rm -rf drivers/media/platform/msm/camera || true

echo ""
echo "2. 清理 Makefile 引用..."

# 从 Makefile 中移除对已删除目录的引用
echo "  - 清理 drivers/Makefile"
sed -i '/vidc/d' drivers/media/platform/msm/Makefile || true
sed -i '/esoc/d' drivers/Makefile || true
sed -i '/sensors/d' drivers/Makefile || true

echo "  - 清理 drivers/soc/qcom/Makefile"
sed -i '/glink/d' drivers/soc/qcom/Makefile || true
sed -i '/spcom/d' drivers/soc/qcom/Makefile || true
sed -i '/subsystem_restart/d' drivers/soc/qcom/Makefile || true
sed -i '/spss_utils/d' drivers/soc/qcom/Makefile || true
sed -i '/peripheral-loader/d' drivers/soc/qcom/Makefile || true
sed -i '/subsys-pil-tz/d' drivers/soc/qcom/Makefile || true
sed -i '/pil-q6v5-mss/d' drivers/soc/qcom/Makefile || true
sed -i '/qdsp6v2/d' drivers/soc/qcom/Makefile || true

echo "  - 清理 net/Makefile"
sed -i '/ipc_router/d' net/Makefile || true

echo "  - 清理 drivers/bluetooth/Makefile"
sed -i '/btfm_slim/d' drivers/bluetooth/Makefile || true
sed -i '/bluetooth-power/d' drivers/bluetooth/Makefile || true

echo "  - 清理 drivers/clk/qcom/mdss/Makefile"
sed -i '/mdss-dsi-pll-10nm/d' drivers/clk/qcom/mdss/Makefile || true

echo "  - 清理 drivers/crypto/msm/Makefile"
sed -i '/qce50/d' drivers/crypto/msm/Makefile || true
sed -i '/qcedev/d' drivers/crypto/msm/Makefile || true
sed -i '/qcrypto/d' drivers/crypto/msm/Makefile || true

echo "  - 清理 drivers/slimbus/Makefile"
sed -i '/slim-msm/d' drivers/slimbus/Makefile || true

echo "  - 清理 drivers/char/diag/Makefile"
sed -i '/diag_usb/d' drivers/char/diag/Makefile || true
sed -i '/diagchar/d' drivers/char/diag/Makefile || true

echo "  - 清理 drivers/char/Makefile"
sed -i '/adsprpc/d' drivers/char/Makefile || true

echo "  - 清理 drivers/spi/Makefile"
sed -i '/spi_qsd/d' drivers/spi/Makefile || true

echo "  - 清理 drivers/md/Makefile"
sed -i '/dm-req-crypt/d' drivers/md/Makefile || true

echo "  - 清理 drivers/power/supply/qcom/Makefile"
sed -i '/qpnp-fg-gen3/d' drivers/power/supply/qcom/Makefile || true
sed -i '/qpnp-smb2/d' drivers/power/supply/qcom/Makefile || true
sed -i '/smb-lib/d' drivers/power/supply/qcom/Makefile || true

echo "  - 清理 drivers/platform/msm/Makefile"
sed -i '/sps/d' drivers/platform/msm/Makefile || true
sed -i '/usb_bam/d' drivers/platform/msm/Makefile || true

echo "  - 清理 drivers/usb/gadget/function/Makefile"
sed -i '/f_mtp/d' drivers/usb/gadget/function/Makefile || true
sed -i '/f_ptp/d' drivers/usb/gadget/function/Makefile || true
sed -i '/f_ncm/d' drivers/usb/gadget/function/Makefile || true
sed -i '/f_mass_storage/d' drivers/usb/gadget/function/Makefile || true
sed -i '/f_fs/d' drivers/usb/gadget/function/Makefile || true
sed -i '/f_midi/d' drivers/usb/gadget/function/Makefile || true
sed -i '/f_hid/d' drivers/usb/gadget/function/Makefile || true
sed -i '/f_audio_source/d' drivers/usb/gadget/function/Makefile || true
sed -i '/f_accessory/d' drivers/usb/gadget/function/Makefile || true
sed -i '/f_diag/d' drivers/usb/gadget/function/Makefile || true
sed -i '/f_cdev/d' drivers/usb/gadget/function/Makefile || true
sed -i '/f_ccid/d' drivers/usb/gadget/function/Makefile || true
sed -i '/f_gsi/d' drivers/usb/gadget/function/Makefile || true
sed -i '/f_qdss/d' drivers/usb/gadget/function/Makefile || true

echo ""
echo "3. 清理 Kconfig 引用..."

# 从 Kconfig 中移除对已删除目录的引用
echo "  - 清理 drivers/Kconfig"
sed -i '/source "drivers\/sensors\/Kconfig"/d' drivers/Kconfig || true

echo "  - 清理 drivers/video/Kconfig"
sed -i '/source "drivers\/gpu\/msm\/Kconfig"/d' drivers/video/Kconfig || true

echo "  - 清理 drivers/media/platform/msm/Kconfig"
sed -i '/source "drivers\/media\/platform\/msm\/vidc\/Kconfig"/d' drivers/media/platform/msm/Kconfig || true

echo "  - 清理 net/Kconfig"
sed -i '/source "net\/ipc_router\/Kconfig"/d' net/Kconfig || true

echo "  - 清理 arch/arm64/Kconfig.debug"
sed -i '/source "drivers\/hwtracing\/coresight\/Kconfig"/d' arch/arm64/Kconfig.debug || true

echo ""
echo "=========================================="
echo "清理完成！"
echo "=========================================="
echo ""
echo "已删除的驱动："
echo "  - kgsl/adreno (GPU)"
echo "  - vidc (视频)"
echo "  - esoc (子系统)"
echo "  - ipc_router (进程间通信)"
echo "  - coresight (调试)"
echo "  - sensors (传感器)"
echo "  - qdsp6v2 (DSP)"
echo "  - IPA (网络加速)"
echo "  - SPS (流处理器)"
echo "  - tracer_pkt (追踪)"
echo "  - camera (摄像头)"
echo ""
echo "下一步："
echo "  make fajita_defconfig"
echo "  make -j\$(nproc) Image.gz"
echo ""
