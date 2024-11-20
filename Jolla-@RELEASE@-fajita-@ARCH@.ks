# DisplayName: Jolla fajita/@ARCH@ (release) 1+hybris.16.0.20200211164513.7466c31
# KickstartType: release
# DeviceModel: fajita
# DeviceVariant: fajita
# Brand: Jolla
# SuggestedImageType: fs
# SuggestedArchitecture: armv7hl

timezone --utc UTC

### Commands from /tmp/sandbox/usr/share/ssu/kickstart/part/default
part / --size 500 --ondisk sda --fstype=ext4

## No suitable configuration found in /tmp/sandbox/usr/share/ssu/kickstart/bootloader

repo --name=adaptation-community-fajita-@RELEASE@ --baseurl=http://repo.merproject.org/obs/nemo:/testing:/hw:/oneplus:/fajita/sailfishos_@RELEASE@/
repo --name=adaptation-community-common-fajita-@RELEASE@ARCH@ --baseurl=http://repo.merproject.org/obs/nemo:/testing:/hw:/common/sailfishos_@RELEASE@_@ARCH@/
repo --name=apps-@RELEASE@ --baseurl=https://releases.jolla.com/jolla-apps/@RELEASE@/@ARCH@/
repo --name=hotfixes-@RELEASE@ --baseurl=https://releases.jolla.com/releases/@RELEASE@/hotfixes/@ARCH@/
repo --name=jolla-@RELEASE@ --baseurl=https://releases.jolla.com/releases/@RELEASE@/jolla/@ARCH@/

%packages
#jolla-configuration-@DEVICE@
jolla-configuration-fajita
%end

%attachment
### Commands from /tmp/sandbox/usr/share/ssu/kickstart/attachment/fajita
/boot/hybris-boot.img
/boot/hybris-updater-script
/boot/hybris-updater-unpack.sh
/boot/update-binary

%end

%pre
export SSU_RELEASE_TYPE=release
### begin 01_init
touch $INSTALL_ROOT/.bootstrap
### end 01_init
%end

%post
export SSU_RELEASE_TYPE=release
### begin 01_arch-hack
if [ "@ARCH@" == armv7hl ] || [ "@ARCH@" == armv7tnhl ]; then
    # Without this line the rpm does not get the architecture right.
    echo -n "@ARCH@-meego-linux" > /etc/rpm/platform

    # Also libzypp has problems in autodetecting the architecture so we force tha as well.
    # https://bugs.meego.com/show_bug.cgi?id=11484
    echo "arch = @ARCH@" >> /etc/zypp/zypp.conf
fi
### end 01_arch-hack
### begin 01_rpm-rebuilddb
# Rebuild db using target's rpm
echo -n "Rebuilding db using target rpm.."
rm -f /var/lib/rpm/__db*
rpm --rebuilddb
echo "done"
### end 01_rpm-rebuilddb
### begin 50_oneshot
# exit boostrap mode
rm -f /.bootstrap

# export some important variables until there's a better solution
export LANG=en_US.UTF-8
export LC_COLLATE=en_US.UTF-8
export GSETTINGS_BACKEND=gconf

# run the oneshot triggers for root and first user uid
UID_MIN=$(grep "^UID_MIN" /etc/login.defs |  tr -s " " | cut -d " " -f2)
DEVICEUSER=`getent passwd $UID_MIN | sed 's/:.*//'`

if [ -x /usr/bin/oneshot ]; then
   /usr/bin/oneshot --mic
   su -c "/usr/bin/oneshot --mic" $DEVICEUSER
fi
### end 50_oneshot
### begin 60_ssu
if [ "$SSU_RELEASE_TYPE" = "rnd" ]; then
    [ -n "@RNDRELEASE@" ] && ssu release -r @RNDRELEASE@
    [ -n "@RNDFLAVOUR@" ] && ssu flavour @RNDFLAVOUR@
    # RELEASE is reused in RND setups with parallel release structures
    # this makes sure that an image created from such a structure updates from there
    [ -n "@RELEASE@" ] && ssu set update-version @RELEASE@
    ssu mode 2
else
    [ -n "@RELEASE@" ] && ssu release @RELEASE@
    ssu mode 4
fi
### end 60_ssu
%end

%post --nochroot
export SSU_RELEASE_TYPE=release
### begin 50_os-release
(
CUSTOMERS=$(find $INSTALL_ROOT/usr/share/ssu/features.d -name 'customer-*.ini' \
    |xargs --no-run-if-empty sed -n 's/^name[[:space:]]*=[[:space:]]*//p')

cat $INSTALL_ROOT/etc/os-release
echo "SAILFISH_CUSTOMER=\"${CUSTOMERS//$'\n'/ }\""
) > $IMG_OUT_DIR/os-release
### end 50_os-release
%end

%pack
export SSU_RELEASE_TYPE=release
### begin hybris
pushd $IMG_OUT_DIR # ./sfe-$DEVICE-$RELEASE_ID

DEVICE=@DEVICE@
EXTRA_NAME=@EXTRA_NAME@
DATE=$(date +"%Y%m%d") # 20191101

# Source release info e.g. VERSION
source ./os-release

# Locate rootfs .tar.bz2 archive
for filename in *.tar.bz2; do
	GEN_IMG_BASE=$(basename $filename .tar.bz2) # sfe-$DEVICE-3.2.0.12
done
if [ ! -e "$GEN_IMG_BASE.tar.bz2" ]; then
	echo "[hybris-installer] No rootfs archive found, exiting..."
	exit 1
fi

# Make sure we have 'bc' to estimate rootfs size
zypper --non-interactive in bc &> /dev/null

# Roughly estimate the final rootfs size when installed
IMAGE_SIZE=`echo "scale=2; 2.25 * $(du -h $GEN_IMG_BASE.tar.bz2 | cut -d'M' -f1)" | bc`
echo "[hybris-installer] Estimated rootfs size when installed: ${IMAGE_SIZE}M"

# Output filenames
DST_IMG=sfos-rootfs.tar.bz2
DST_PKG=$ID-$VERSION_ID-$DATE-$DEVICE$EXTRA_NAME-SLOT_a # sailfishos-3.2.0.12-20191101-$DEVICE

# Clone hybris-installer if not preset (e.g. porters-ci build env)
if [ ! -d ../hybris/hybris-installer/ ]; then
	git clone --recurse-submodules --depth 1 https://github.com/sailfish-oneplus6/hybris-installer ../hybris/hybris-installer > /dev/null
fi

# Copy rootfs & hybris-installer scripts into updater .zip tree
mkdir updater/
mv $GEN_IMG_BASE.tar.bz2 updater/$DST_IMG
cp -r ../hybris/hybris-installer/hybris-installer/* updater/

# Update install script with image details
LOS_VER="16.0"
sed -e "s/%DEVICE%/$DEVICE/g" -e "s/%VERSION%/$VERSION/g" -e "s/%DATE%/$DATE/g" -e "s/%IMAGE_SIZE%/${IMAGE_SIZE}M/g" -e "s/%DST_PKG%/$DST_PKG/g" -e "s/%LOS_VER%/$LOS_VER/g" -i updater/META-INF/com/google/android/update-binary

# Pack updater .zip
pushd updater # sfe-$DEVICE-$RELEASE_ID/updater
echo "[hybris-installer] Creating package '$DST_PKG.zip'..."
zip -r ../$DST_PKG.zip .
mv $DST_IMG ../$GEN_IMG_BASE.tar.bz2
popd # sfe-$DEVICE-$RELEASE_ID

# Clean up working directory
rm -rf updater/

# Calculate some checksums for the generated zip
printf "[hybris-installer] Calculating MD5, SHA1 & SHA256 checksums for '$DST_PKG.zip'..."
md5sum $DST_PKG.zip > $DST_PKG.zip.md5sum
sha1sum $DST_PKG.zip > $DST_PKG.zip.sha1sum
sha256sum $DST_PKG.zip > $DST_PKG.zip.sha256sum
echo " DONE!"

popd # hadk source tree
### end hybris
%end
