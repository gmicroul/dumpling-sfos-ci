# dumpling-sfos-ci
Sailfish OS on OnePlus 5T

# 1. if your IP route is 192.168.2.0/24, Please use route delete net command to enable connection of ssh internal.
    sudo route del -net 192.168.2.0 netmask 255.255.255.0 dev usb0
# 2. install chum repo and storeman repo via below rpm from https://openrepos.net
     sudo zypper in https://openrepos.net/sites/default/files/packages/5928/sailfishos-chum-gui-installer-0.6.9-1.noarch.rpm
     sudo zypper in https://openrepos.net/sites/default/files/packages/5928/harbour-storeman-installer-2.3.0-release10.noarch.rpm
     
