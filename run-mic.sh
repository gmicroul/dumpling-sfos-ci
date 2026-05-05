#!/bin/bash
set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/dumpling.env"

sudo mkdir -p /proc/sys/fs/binfmt_misc/
sudo mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null || true

sudo mic create fs --arch=$PORT_ARCH \
                   --tokenmap=ARCH:$PORT_ARCH,RELEASE:$RELEASE,EXTRA_NAME:"$EXTRA_NAME" \
                   --record-pkgs=name,url \
                   --outdir=sfe-$DEVICE-$RELEASE"$EXTRA_NAME" \
                   --pack-to=sfe-$DEVICE-$RELEASE"$EXTRA_NAME".tar.bz2 \
                   Jolla-@RELEASE@-$DEVICE-@ARCH@.ks