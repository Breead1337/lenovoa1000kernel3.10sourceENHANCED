#!/bin/bash
cd /a1000k || exit 9
export ARCH=arm CROSS_COMPILE=/toolchain48/bin/arm-eabi-
export PATH=/toolchain48/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export KBUILD_BUILD_TIMESTAMP="$(date) by baton4iks"
# olddefconfig: новые зависимости включённых опций доспрашивать некому
yes "" | make ARCH=arm oldconfig >/dev/null 2>&1
make -j4 ARCH=arm Image 2>&1 | tail -6
make -j4 ARCH=arm M=drivers/gpu/mali400/r4p1 modules 2>&1 | tail -3
make -j4 ARCH=arm M=drivers/net/wireless/sprdwl modules 2>&1 | tail -3
make -j4 ARCH=arm M=drivers/misc/fm_2351 modules 2>&1 | tail -3
echo "=== module_layout ==="
grep -w module_layout Module.symvers
echo "=== версия ==="
strings -a arch/arm/boot/Image | grep -m1 "Linux version"
ls -la arch/arm/boot/Image drivers/gpu/mali400/r4p1/mali.ko \
       drivers/net/wireless/sprdwl/sprdwl.ko drivers/misc/fm_2351/trout_fm.ko
