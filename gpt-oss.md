下面按 文件顺序 逐行解释所有 非注释 的命令。
（注释行 # … 已按要求省略，只给出真正执行的代码的说明。）

1. 头部设置

timezone --utc UTC
timezone：Kickstart 关键字，用来设置系统时区。
--utc UTC 表示把系统时间设为 UTC，并把 TZ 环境变量设为 UTC。
作用：让生成的镜像始终使用 UTC 时区，避免因时区差异导致的时间错乱。
2. 分区

part / --size 500 --ondisk sda --fstype=ext4
part：Kickstart 的分区命令。
--size 500：根分区大小为 500 MiB。
--ondisk sda：放在磁盘 sda 上。
--fstype=ext4：文件系统为 ext4。
作用：在目标设备上创建根分区。
3. 软件仓库

repo --name=adaptation-common-fajita-@RELEASE@ --baseurl=https://releases.jolla.com/releases/@RELEASE@/jolla-hw/adaptation-common/@ARCH@/
repo --name=adaptation-community-fajita-@RELEASE@ --baseurl=https://repo.sailfishos.org/obs/nemo:/testing:/hw:/oneplus:/fajita/sailfishos_5.0/
repo --name=adaptation-community-common-fajita-@RELEASE@ --baseurl=https://repo.sailfishos.org/obs/nemo:/testing:/hw:/common/sailfishos_5.0_@ARCH@/
repo --name=apps-@RELEASE@ --baseurl=https://releases.jolla.com/jolla-apps/@RELEASE@/@ARCH@/
repo --name=chum-@RELEASE@ --baseurl=https://repo.sailfishos.org/obs/sailfishos:/chum/5.0_@ARCH@/
repo --name=hotfixes-@RELEASE@ --baseurl=https://releases.jolla.com/releases/@RELEASE@/hotfixes/@ARCH@/
repo --name=jolla-@RELEASE@ --baseurl=https://releases.jolla.com/releases/@RELEASE@/jolla/@ARCH@/
repo --name=mister-@RELEASE@ --baseurl=https://sailfish.openrepos.net/Mister_Magister/personal/main
repo --name=storeman-@RELEASE@ --baseurl=https://repo.sailfishos.org/obs/home:/olf:/harbour-storeman/5.1_@ARCH@/
repo：Kickstart 的仓库声明。
--name= 为仓库起别名，便于后续在 yum/zypper 中引用。
--baseurl= 指向仓库的 HTTP(S) 位置。
@RELEASE@, @ARCH@ 是占位符，在实际构建时会被替换成相应的版本号和架构。
作用：为系统软件安装提供来源，包含设备驱动、系统组件、应用、补丁等。
4. 安装包

%packages
patterns-sailfish-device-configuration-fajita
%end
%packages 块：Kickstart 用来声明需要安装的包。
patterns-sailfish-device-configuration-fajita 是一个 Pattern（软件集合），包含了该设备特定的配置包。
patterns 允许一次性安装一组相关软件，而不必列举每个包。
5. 附件（%attachment）

%attachment
/boot/hybris-boot.img
/boot/hybris-updater-script
/boot/hybris-updater-unpack.sh
/boot/update-binary
%end
%attachment：Kickstart 语法，用来把文件附加到镜像中。
列出的四个文件会被直接放到 /boot 目录下，常用于 OTA/升级包。
6. 预安装阶段（%pre）

%pre --erroronfail
export SSU_RELEASE_TYPE=release
touch $INSTALL_ROOT/.bootstrap
%end
%pre：在系统安装前执行。
--erroronfail：如果脚本返回非 0，Kickstart 会停止构建。
SSU_RELEASE_TYPE=release：设置环境变量，后续脚本会根据它来判断镜像类型。
touch $INSTALL_ROOT/.bootstrap：在根文件系统里创建一个标记文件 .bootstrap，后面会用来判断是否已进入“引导模式”。
7. 后安装阶段（%post）

%post --erroronfail
export SSU_RELEASE_TYPE=release
%post：系统安装完成后、/ 已挂载时执行。
同样把 SSU_RELEASE_TYPE 设为 release，方便后续逻辑判断。
7.1 架构相关处理

if [ "@ARCH@" == armv7hl ] || [ "@ARCH@" == armv7tnhl ] || [ "@ARCH@" == aarch64 ]; then
    echo -n "@ARCH@-meego-linux" > /etc/rpm/platform
    echo "arch = @ARCH@" >> /etc/zypp/zypp.conf
fi
检查目标架构是否是 armv7hl、armv7tnhl 或 aarch64。
RPM 平台：/etc/rpm/platform 文件会被 RPM 用来判定发行版平台，写入 @ARCH@-meego-linux 可以让 RPM 正确识别架构。
Zypper 配置：/etc/zypp/zypp.conf 中加入 arch = @ARCH@，解决 libzypp 自动检测架构失误的问题（参见 Meego Bug 11484）。
7.2 重建 RPM 数据库

echo -n "Rebuilding db using target rpm.."
rm -f /var/lib/rpm/__db*
rpm --rebuilddb
echo "done"
在目标镜像上重建 RPM 数据库，保证数据库状态与实际文件一致。
删除旧的数据库文件后执行 rpm --rebuilddb。
7.3 oneshot 触发器

rm -f /.bootstrap
export LANG=en_US.UTF-8
export LC_COLLATE=en_US.UTF-8

UID_MIN=$(grep "^UID_MIN" /etc/login.defs |  tr -s " " | cut -d " " -f2)
DEVICEUSER=`getent passwd $UID_MIN | sed 's/:.*//'`

if [ -x /usr/bin/oneshot ]; then
   /usr/bin/oneshot --mic
   su -c "/usr/bin/oneshot --mic" $DEVICEUSER
fi
删除 .bootstrap：表示已完成引导模式。
设置本地化变量 LANG、LC_COLLATE 为 en_US.UTF-8，保证后续工具正常处理字符串。
UID_MIN：从 /etc/login.defs 获取最小普通用户 UID。
DEVICEUSER：利用 getent passwd 找到第一个普通用户的用户名。
-x /usr/bin/oneshot：检查 oneshot 是否可执行。
/usr/bin/oneshot --mic：对 root 账户执行一次触发器。
su -c "/usr/bin/oneshot --mic" $DEVICEUSER：在第一个普通用户的身份下再次执行。
su -c 把命令字符串交给目标用户的默认 shell 运行。
7.4 SSU（Sailfish Software Update）配置

if [ "$SSU_RELEASE_TYPE" = "rnd" ]; then
    [ -n "@RELEASE@" ] && ssu release -r @RELEASE@
    [ -n "@FLAVOUR@" ] && ssu flavour @FLAVOUR@
    ssu mode 2
else
    [ -n "@RELEASE@" ] && ssu release @RELEASE@
    ssu mode 4
fi
判断镜像类型是 “rnd”（随机）还是正式 release。
ssu release：设置镜像的发布版本。
-r 仅在 rnd 情况下使用。
ssu flavour：设置镜像的“口味”或子版本。
ssu mode 2/4：设定 SSU 模式，分别对应随机镜像与正式镜像。
8. 后安装（无 chroot）阶段（%post --nochroot）

%post --nochroot --erroronfail
export SSU_RELEASE_TYPE=release
该块在系统根目录 未 挂载的状态下执行，适合对根文件系统之外的路径做处理。
再次设定 SSU_RELEASE_TYPE。
8.1 生成 os-release

(
CUSTOMERS=$(find $INSTALL_ROOT/usr/share/ssu/features.d -name 'customer-*.ini' \
    |xargs --no-run-if-empty sed -n 's/^name[[:space:]]*=[[:space:]]*//p')

cat $INSTALL_ROOT/etc/os-release
echo "SAILFISH_CUSTOMER=\"${CUSTOMERS//$'\n'/ }\""
) > $IMG_OUT_DIR/os-release
find … | xargs … sed …：搜集所有 customer-*.ini 文件里的 name= 值。
cat $INSTALL_ROOT/etc/os-release：读取系统默认的 os-release 内容。
追加一行 SAILFISH_CUSTOMER=，把所有客户名拼接成一个空格分隔的字符串。
最终输出到 $IMG_OUT_DIR/os-release，生成的镜像会携带此文件。
8.2 检查 shadow（用户密码）

IS_BAD=0

echo "Checking that no user has password set in /etc/shadow."
if grep -vE '^[^:]+:[*!]{1,2}:' $INSTALL_ROOT/etc/shadow
then
    echo "A USER HAS PASSWORD SET! THE IMAGE IS NOT SAFE!"
    IS_BAD=1
fi

if grep -vE '^[^:]+:x:' $INSTALL_ROOT/etc/passwd
then
    echo "BAD PASSWORD IN /etc/passwd! THE IMAGE IS NOT SAFE!"
    IS_BAD=1
fi

[ $IS_BAD -eq 0 ] && echo "No passwords set, good." || exit 1
检查 /etc/shadow：所有行应为 user:*、user:! 或 user:!!（无密码）。
检查 /etc/passwd：对应行应为 user:x:（密码占位符 x）。
若发现有实际密码，脚本会退出并标记镜像不安全。
9. 生成镜像包（%pack）

%pack --erroronfail
export SSU_RELEASE_TYPE=release
%pack：Kickstart 的镜像打包阶段，负责把文件写入最终的镜像文件。
再次设定 SSU_RELEASE_TYPE。
9.1 变量准备

pushd $IMG_OUT_DIR
DEVICE=fajita
EXTRA_NAME=@EXTRA_NAME@
DATE=$(date +"%Y%m%d")
source ./os-release
pushd 进入输出目录。
DEVICE=fajita：硬编码设备名。
EXTRA_NAME=@EXTRA_NAME@：可能用于区分不同构建。
DATE：构建日期。
source ./os-release：读取 os-release，把 ID、VERSION_ID 等变量导入。
9.2 识别 rootfs 源文件

for filename in *.tar.bz2; do
    GEN_IMG_BASE=$(basename $filename .tar.bz2)
done
遍历当前目录下所有 *.tar.bz2（假设只有一个），得到根文件系统的基名 sfe-fajita-<ver>。
9.3 验证文件存在

if [ ! -e "$GEN_IMG_BASE.tar.bz2" ]; then
    echo "[hybris-installer] No rootfs archive found, exiting..."
    exit 1
fi
9.4 安装 bc（计算根文件系统大小）

zypper --non-interactive in bc &> /dev/null
9.5 估算最终根文件系统大小

IMAGE_SIZE=`echo "scale=2; 2.25 * $(du -h $GEN_IMG_BASE.tar.bz2 | cut -d'M' -f1)" | bc`
echo "[hybris-installer] Estimated rootfs size when installed: ${IMAGE_SIZE}M"
du -h … | cut -d'M' -f1：获取压缩包大小（MiB）。
2.25 * size：经验系数，估算解压后实际占用空间。
bc 计算保留两位小数。
9.6 定义输出文件名

DST_IMG=sfos-rootfs.tar.bz2
DST_PKG=$ID-$VERSION_ID-$DATE-$DEVICE$EXTRA_NAME-SLOT_a
DST_IMG：最终要放在升级包里的 rootfs 文件名。
DST_PKG：ZIP 包的文件名，包含发行版 ID、版本、日期、设备、可选扩展名和 SLOT。
9.7 复制 hybris‑installer

if [ ! -d ../hybris/hybris-installer/ ]; then
    git clone --depth 1 https://github.com/sailfish-oneplus6/hybris-installer ../hybris/hybris-installer > /dev/null
fi
确保本地有 hybris-installer（如果没有就拉取最新）。
9.8 构建更新包

mkdir updater/
mv $GEN_IMG_BASE.tar.bz2 updater/$DST_IMG
cp -r ../hybris/hybris-installer/hybris-installer/* updater/
把根文件系统和 hybris‑installer 脚本拷贝到 updater/ 目录。
9.9 替换模板变量

LOS_VER="16.0"
sed -e "s/%DEVICE%/$DEVICE/g" \
    -e "s/%VERSION%/$VERSION/g" \
    -e "s/%DATE%/$DATE/g" \
    -e "s/%IMAGE_SIZE%/${IMAGE_SIZE}M/g" \
    -e "s/%DST_PKG%/$DST_PKG/g" \
    -e "s/%LOS_VER%/$LOS_VER/g" \
    -i updater/META-INF/com/google/android/update-binary
update-binary 是 hybris‑installer 的主脚本，使用占位符。
用 sed 把占位符替换为实际值。
9.10 打包 ZIP

pushd updater
echo "[hybris-installer] Creating package '$DST_PKG.zip'..."
zip -r ../$DST_PKG.zip .
mv $DST_IMG ../$GEN_IMG_BASE.tar.bz2
popd
在 updater/ 目录下递归压缩成 DST_PKG.zip。
把根文件系统压缩包恢复到原位置（$GEN_IMG_BASE.tar.bz2），以便后续步骤使用。
9.11 清理工作区

rm -rf updater/
9.12 计算校验和

printf "[hybris-installer] Calculating MD5, SHA1 & SHA256 checksums for '$DST_PKG.zip'..."
md5sum $DST_PKG.zip > $DST_PKG.zip.md5sum
sha1sum $DST_PKG.zip > $DST_PKG.zip.sha1sum
sha256sum $DST_PKG.zip > $DST_PKG.zip.sha256sum
echo " DONE!"
生成 ZIP 的 MD5、SHA1、SHA256 校验和文件，方便 OTA 验证。
9.13 回到原目录

popd
10. 总结

该脚本是 Sailfish OS 的镜像构建 Kickstart 配置，涵盖了：
时区、分区、仓库、软件包、附件、环境变量、架构修正、RPM 数据库重建、oneshot 触发、SSU 配置、用户密码安全检查、os-release 生成、rootfs 与 hybris‑installer 包装、校验和生成等步骤。
每一段都严格按照 Kickstart 的分阶段执行（%pre → %post → %post --nochroot → %pack）。
通过占位符 @ARCH@, @RELEASE@, @EXTRA_NAME@ 等实现了模板化构建，便于在 CI 环境中生成多版本镜像。
如需进一步细化某一段的细节或有特定问题，随时告诉我！
