#!/bin/bash

#set -x

# 获取当前路径
CURRENT_DIR=$(pwd)

## Copy this script inside the kernel directory
KERNEL_DEFCONFIG=raphael_defconfig

# 目标文件
TARGET_OBJS="Image.gz-dtb"
FINAL_KERNEL_ZIP_PRE=rikkakernel-v2-raphael
FINAL_KERNEL_ZIP=$FINAL_KERNEL_ZIP_PRE-$(date '+%Y%m%d-%H%M').zip

#set compile
CC_TYPE="neutron=main"

# 设置编译参数
CC_DIR=$PWD/toolchains/clang
CC=clang
CROSS_COMPILE=aarch64-linux-gnu-
CROSS_COMPILE_ARM32=arm-linux-gnueabi-
CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
CLANG_TRIPLE=aarch64-linux-gnu-
CC_ADD_FLAGS="LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip"
ANYKERNEL3_DIR=$CURRENT_DIR/toolchains/AnyKernel3
KSU_DIR=$CURRENT_DIR/drivers/staging/kernelsu
KSU_BRANCH=main
BUILD_CMD=all
THREADNUM=$(($(nproc --all) / 2))
GCCVERSION=13

export PATH="$CC_DIR/bin:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER=GITHUB
export KBUILD_BUILD_HOST=YAMLEAF

# Kernel Details
REV="R6.1"
EDITION="STANDALONE-DSP"
VER="$REV"-"$EDITION"
UPDATEBUILDENV=false

# 编译参数
args="-j$THREADNUM \
      O=out \
      ARCH=$ARCH \
      CC=$CC \
      CLANG_TRIPLE=$CLANG_TRIPLE \
      CROSS_COMPILE=$CROSS_COMPILE \
      CROSS_COMPILE_COMPAT=$CROSS_COMPILE_COMPAT \
      $CC_ADD_FLAGS \
      "

# 编译输出参数
BUILD_START=$(date +"%s")
blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'

# 解析命令
function build_cmd() {
    if [ "$1" == "all" ]; then
        BUILD_CMD=build_main
    elif [ "$1" == "config"  -o "$1" == "cfg" ]; then
        BUILD_CMD=build_defconfig
    elif [ "$1" == "prep"  -o "$1" == "prepare" ]; then
        BUILD_CMD=build_prepare
    elif [ "$1" == "kernel" ]; then
        BUILD_CMD=build_kernel
    elif [ "$1" == "clean" ]; then
        BUILD_CMD=objs_clean
    elif [ "${1:0:3}" == "any" ]; then
        BUILD_CMD=build_Anykernel
    elif [ "${1:0:3}" == "gcc" ]; then
        BUILD_CMD=update_gcc_version
        GCCVERSION=${1#*=}
    else
        build_help
        exit 2
    fi
}

# 编译帮助
function build_help() {
    echo -e "$blue"
    echo "Usage: ./build.sh [all] [prepare|prep] [clean] [anykernel|any][config|cfg][kernel]$nocol"
    echo -e "$blue"
    echo "Simple: ./build.sh gcc=13                #update gcc version to 13.1.0$nocol"
    exit 0
}

#更新编译环境gcc
function update_gcc_version() {
    echo -e "$blue***********************************************"
    echo "  Update compile server gcc version "
    echo -e "***********************************************$nocol"
    # 下载安装gcc版本
    if [ "${GCCVERSION:0:2}" == "13" ]; then
        gccVer=gcc-13.1.0
    else
        gccVer=gcc-13.1.0
    fi
    wget http://ftp.gnu.org/gnu/gcc/$gccVer/$gccVer.tar.gz
    tar xf $gccVer.tar.gz
    cd $gccVer/
    ./contrib/download_prerequisites
    mkdir build && cd build
    ../configure -enable-checking=release -enable-languages=c,c++ -disable-multilib
    sudo make -j$(nproc --all) 
    sudo make install
}

# 编译准备
function build_prepare() {
    echo -e "$blue***********************************************"
    echo "  Prepare the Kernel Environment  "
    echo -e "***********************************************$nocol"
    if [ ! -d $CURRENT_DIR/out ]; then
        mkdir -p out
    fi
    git submodule init && git submodule update
    cd $KSU_DIR
    git pull origin $KSU_BRANCH
    cd $CURRENT_DIR
}

# 构建设备配置
function build_defconfig() {
    echo -e "$blue***********************************************"
    echo "  Building Device Kernel $KERNEL_DEFCONFIG  "
    echo -e "***********************************************$nocol"
    echo "CONFIG_OVERLAY_FS=y" >> arch/arm64/configs/$KERNEL_DEFCONFIG
    echo "CONFIG_CC_WERROR=n" >> arch/arm64/configs/$KERNEL_DEFCONFIG
    make ${args} $KERNEL_DEFCONFIG
}

# 构建内核
function build_kernel() {
    echo -e "$blue***********************************************"
    echo "  Building Kernel drivers  "
    echo -e "***********************************************$nocol"
    make ${args} $TARGET_OBJS
    if [ $? == 1 ]; then
        echo "$red *** kernel build error!!! ****$nocol"
        exit 1
    fi
}

# download neutron clang
function down_neutron_clang() {
    sudo apt-get update
    sudo apt install -y libelf-dev libarchive-tools lld llvm gcc binutils-arm-linux-gnueabi binutils-aarch64-linux-gnu curl wget vim git ccache automake flex lzop bison gperf build-essential zip zlib1g-dev g++-multilib libxml2-utils bzip2 libbz2-dev libbz2-1.0 libghc-bzlib-dev squashfs-tools pngcrush schedtool dpkg-dev liblz4-tool make optipng maven libssl-dev pwgen libswitch-perl policycoreutils minicom libxml-sax-base-perl libxml-simple-perl bc libc6-dev-i386 lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z-dev libgl1-mesa-dev xsltproc unzip device-tree-compiler kmod python2 python3 python3-pip
 
    mkdir -p $CC_DIR && cd $CC_DIR
    curl -LO  https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman
    chmod +x antman
    if [ "${CC_TYPE#*=}" == "main" ]; then
        ./antman --sync=latest
    elif ["${CC_TYPE#*=}" == "18" ]; then
        ./antman -S=29072023
    elif [ "${CC_TYPE#*=}" == "17" ]; then
        ./antman -S=11032023
    elif [ "${CC_TYPE#*=}" == "16" ]; then
        ./antman -S=16012023
    else
        ./antman --sync=latest
    fi
    ./antman --patch=glibc
}

# download proton clang
function down_proton_clang() {
    sudo apt-get update
    sudo apt install -y curl python2 libelf-dev llvm lld wget vim git ccache automake flex lzop bison gperf build-essential zip zlib1g-dev g++-multilib libxml2-utils bzip2 libbz2-dev libbz2-1.0 libghc-bzlib-dev squashfs-tools pngcrush schedtool dpkg-dev liblz4-tool make optipng maven libssl-dev pwgen libswitch-perl policycoreutils minicom libxml-sax-base-perl libxml-simple-perl bc libc6-dev-i386 lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z-dev libgl1-mesa-dev xsltproc unzip device-tree-compiler kmod python3 python3-pip

    if ! git clone -q https://github.com/kdrag0n/proton-clang.git --depth=1  $CC_DIR; then
        echo "Cloning failed! Aborting..."
        exit 1
    fi
}

# download mandisa clang
function down_mandisa_clang() {
    sudo apt-get update
    sudo apt install -y libelf-dev p7zip-full lld llvm gcc binutils-arm-linux-gnueabi binutils-aarch64-linux-gnu curl wget vim git ccache automake flex lzop bison gperf build-essential zip zlib1g-dev g++-multilib libxml2-utils bzip2 libbz2-dev libbz2-1.0 libghc-bzlib-dev squashfs-tools pngcrush schedtool dpkg-dev liblz4-tool make optipng maven libssl-dev pwgen libswitch-perl policycoreutils minicom libxml-sax-base-perl libxml-simple-perl bc libc6-dev-i386 lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z-dev libgl1-mesa-dev xsltproc unzip device-tree-compiler kmod python3 python3-pip

    if [ "${CC_TYPE#*=}" == "19" ]; then
        wget -O clang.7z https://github.com/Mandi-Sa/clang/releases/download/amd64-kernel-arm-19/llvm19.0.0-binutils2.42.50_amd64-kernel-arm_20240218.7z
    fi
    
    if [ "${CC_TYPE#*=}" == "18" ]; then
        wget -O clang.7z https://github.com/Mandi-Sa/clang/releases/download/amd64-kernel-arm-18/llvm18.0.0-binutils2.41.50_amd64-kernel-arm_20230726.7z
    fi
    
    if [ "${CC_TYPE#*=}" == "17" ]; then
        wget -O clang.7z https://github.com/Mandi-Sa/clang/releases/download/amd64-kernel-arm-17/llvm17.0.0-binutils2.40.50_amd64-kernel-arm_20230127.7z
    fi

    if [ "${CC_TYPE#*=}" == "16" ]; then
        wget -O clang.7z https://github.com/Mandi-Sa/clang/releases/download/amd64-kernel-arm-16/llvm16.0.0-binutils2.39.50_amd64-kernel-arm_20220826.7z
    fi

    if [ "${CC_TYPE#*=}" == "15" ]; then
        wget -O clang.7z https://github.com/Mandi-Sa/clang/releases/download/amd64-kernel-arm-15/llvm15.0.0-binutils2.38_amd64-kernel-arm_20220502.7z
    fi
	7z x clang.7z -r -o $CC_DIR
	rm -rf clang.7z
}

# 构建内核
function build_kernel() {
    echo -e "$blue***********************************************"
    echo "  Building Kernel drivers  "
    echo -e "***********************************************$nocol"
    make ${args} $TARGET_OBJS
    if [ $? == 1 ]; then
        echo "$red *** kernel build error!!! ****$nocol"
        exit 1
    fi
}

# 检查工具链
function build_toolchain() {
    echo -e "$blue***********************************************"
    echo "  Build toolchains check  "
    echo -e "***********************************************$nocol"
    if ! [ -d "$CC_DIR/bin" ]; then
        echo "Clang not found! Cloning $CC_TYPE"
        if [ "neutron" == "${CC_TYPE%%=*}" ]; then
            down_neutron_clang
        elif [ "mandisa" == "${CC_TYPE%%=*}" ]; then
            down_mandisa_clang
        else
            down_proton_clang
        fi
    else
        echo "Clang find, start building..."
    fi
    
    cd $CURRENT_DIR
    export KBUILD_COMPILER_STRING="$($CC_DIR/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
}

# 临时文件清理
function objs_clean() {
    echo -e "$blue***********************************************"
    echo "  Clean last objs  "
    echo -e "***********************************************$nocol"

    if [ ! -d out/arch/$ARCH/boot/dts ]; then
        mkdir -p out/arch/$ARCH/boot/dts
    fi
    
    if [ ! -f out/.config ]; then
        cp -rf out/arch/$ARCH/configs/$KERNEL_DEFCONFIG out/.config
    fi
    make O=out clean && make O=out mrproper
    rm -rf out
    cd $ANYKERNEL3_DIR
    for tar in $TARGET_OBJS; do
        if [ -f $tar ]; then
            rm -rf $tar
        fi
    done
    
    for file in $FINAL_KERNEL_ZIP_PRE*; do
        if [ -f "$file" ]; then
            rm -rf "$file"
        fi
    done
    cd $CURRENT_DIR
}

# 打包AnyKernel3
function build_Anykernel() {
    echo -e "$blue***********************************************"
    echo "  Pack $FINAL_KERNEL_ZIP  "
    echo -e "***********************************************$nocol"
    cd $ANYKERNEL3_DIR/
    for tar in $TARGET_OBJS; do
        if [ -f $tar ]; then
            echo -e "$yellow**** Copying $tar to AnyKernel ****$nocol"
            cp $CURRENT_DIR/out/arch/arm64/boot/$tar ./
        fi
    done

    zip -r9 "./$FINAL_KERNEL_ZIP" * -x README $FINAL_KERNEL_ZIP
    sha1sum $FINAL_KERNEL_ZIP
    BUILD_END=$(date +"%s")
    DIFF=$(($BUILD_END - $BUILD_START))
    echo -e "$cyan Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$nocol"
}

# 内核构建全流程
function build_main() {
    objs_clean && \
    build_prepare && \
    build_defconfig && \
    build_kernel && \
    build_Anykernel
}

if [ -n "$1" ]; then
    build_cmd $1
else
    build_cmd all
fi

if [ "$BUILD_CMD" == "build_defconfig" -o "$BUILD_CMD" == "build_kernel" -o "$BUILD_CMD" == "build_main" ]; then
    build_toolchain
fi

#执行脚本
$BUILD_CMD 2>&1 | tee "$CURRENT_DIR/out/buildKernel.log"