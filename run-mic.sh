#!/bin/bash
sudo mic create fs --arch=armv7hl \
                   --tokenmap=ARCH:armv7hl,RELEASE:$RELEASE,EXTRA_NAME:"$EXTRA_NAME" \
                   --record-pkgs=name,url \
                   --outdir=sfe-$DEVICE-$RELEASE"$EXTRA_NAME" \
                   --pack-to=sfe-$DEVICE-$RELEASE"$EXTRA_NAME".tar.bz2 \
                   Jolla-@RELEASE@-$DEVICE-@ARCH@.ks
