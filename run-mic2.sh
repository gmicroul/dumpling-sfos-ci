#!/bin/sh
export PLATFORM_SDK_ROOT="/srv/mer"
export ANDROID_ROOT="/parentroot/srv/hadk"
export VENDOR="xiaomi"
export DEVICE="davinci"
export PORT_ARCH="aarch64"
#export EXTRA_NAME=-devel-`date`
export RELEASE="3.4.0.24"

sudo mic create fs --arch=$PORT_ARCH \
--tokenmap=ARCH:$PORT_ARCH,RELEASE:$RELEASE,EXTRA_NAME:$EXTRA_NAME \
--record-pkgs=name,url \
--outdir=sfe-$DEVICE-$RELEASE$EXTRA_NAME \
--pack-to=sfe-$DEVICE-$RELEASE$EXTRA_NAME.tar.bz2 \
Jolla-@RELEASE@-$DEVICE-@ARCH@.ks
