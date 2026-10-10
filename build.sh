#!/bin/bash
#
# Сборка ядра Lenovo A1000 (Linux 3.10.64, Spreadtrum SC7731G).
# Собирает то, что нужно для Android ТОЙ ВЕТКИ, на которой вы стоите
# (android-4.4 / android-9 / android-10): конфиг у каждой ветки свой.
#
#   ./build.sh                    — Image + модули (mali, sprdwl, trout_fm)
#   ./build.sh clean              — то же, но с нуля
#   CROSS_COMPILE=... ./build.sh  — свой тулчейн
#   KEEP_CONFIG=1 ./build.sh      — не трогать готовый .config (свои правки)
#
# Результат: out/Image, out/mali.ko, out/sprdwl.ko, out/trout_fm.ko
#
# Тулчейн: AOSP arm-eabi-4.8 (GCC 4.8). Более новый GCC ядро 3.10 не собирает.
#   git clone --depth 1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8
#
set -e

JOBS=${JOBS:-$(nproc)}
DEFCONFIG=${DEFCONFIG:-a1000_baton4iks_defconfig}

if [ -z "$CROSS_COMPILE" ]; then
    for p in ./toolchain/bin/arm-eabi- \
             ../arm-eabi-4.8/bin/arm-eabi- \
             ../arm-eabi-4.8-toolchain/bin/arm-eabi- \
             /opt/arm-eabi-4.8/bin/arm-eabi-; do
        [ -x "${p}gcc" ] && CROSS_COMPILE="$p" && break
    done
fi
if [ -z "$CROSS_COMPILE" ] || [ ! -x "${CROSS_COMPILE}gcc" ]; then
    echo "ОШИБКА: не найден тулчейн arm-eabi-4.8."
    echo "Задайте путь явно, например:"
    echo "  CROSS_COMPILE=\$HOME/arm-eabi-4.8/bin/arm-eabi- ./build.sh"
    exit 1
fi

# kbuild запускает компилятор из подкаталогов — путь обязан быть абсолютным
CROSS_COMPILE="$(cd "$(dirname "$CROSS_COMPILE")" && pwd)/$(basename "$CROSS_COMPILE")"

export ARCH=arm
export CROSS_COMPILE
# Пустой LOCALVERSION: иначе в git-клоне к версии дописывается "+" (3.10.64+),
# и модули прошивки с vermagic "3.10.64" ядро не примет.
export LOCALVERSION=
echo "=== ветка: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?') ==="
echo "=== тулчейн: $(${CROSS_COMPILE}gcc --version | head -1) ==="

[ "$1" = "clean" ] && make ARCH=arm clean

# Конфиг пересоздаётся из defconfig ВЕТКИ при каждой сборке: иначе после
# переключения ветки остался бы .config от прошлой (у 4.4, 9 и 10 они разные).
[ "$KEEP_CONFIG" = 1 ] && [ -f .config ] || make ARCH=arm "$DEFCONFIG"

make -j"$JOBS" ARCH=arm Image
# Модули надо собирать вместе с ядром: у них общий vermagic/module_layout,
# модули от другой сборки insmod отвергнет (не будет GPU, Wi-Fi, FM).
for m in drivers/gpu/mali400/r4p1 drivers/net/wireless/sprdwl drivers/misc/fm_2351; do
    make -j"$JOBS" ARCH=arm M=$m modules
done

mkdir -p out
cp -f arch/arm/boot/Image drivers/gpu/mali400/r4p1/mali.ko \
      drivers/net/wireless/sprdwl/sprdwl.ko drivers/misc/fm_2351/trout_fm.ko out/

echo
echo "=== готово ==="
ls -la out/
strings -a out/Image | grep -m1 "Linux version" || true
echo
echo "Дальше — упаковать в boot.img (нужен образ, снятый с вашего аппарата):"
echo "  python3 tools/repack_boot.py boot_orig.img out/Image boot_new.img"
echo "Модули (.ko) — в /system/lib/modules/ (или куда их грузит ваша прошивка), вместе с этим ядром."
