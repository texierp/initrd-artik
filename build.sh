#!/bin/bash

BOARD_DIR=`pwd`/board
TARGET=

usage()
{
	echo "usage: build.sh [options]"
	echo "-h		Print this help message"
	echo "-b [board]	Target board(artik520, artik1020, artik530, artik710)"
}

parse_options()
{
	TEMP=`getopt -o "h:b:" -- "$@"`
	eval set -- "$TEMP"
	case "$1" in
		-b ) TARGET=$2;;
		-h | * ) usage; exit 1 ;;
	esac
}

parse_options $@

set -x
set -e

let NCPUS=(`grep -c ^processor /proc/cpuinfo` + 1)

SRCS=`pwd`/srcs
BUILD_ROOT=`pwd`/build
OUTPUT=`pwd`/output
PREBUILT=`pwd`/prebuilt
TOOLCHAIN_ROOT=$OUTPUT/toolchain
SYS_ROOT=$OUTPUT/sys_root
SCRIPT_DIR=`pwd`/scripts

if [ $TARGET == "artik710" ]; then
	TARGET_ARCH=arm64
else
	TARGET_ARCH=arm
fi

[ -d output ] || mkdir output
[ -d output/sys_root ] || mkdir output/sys_root
[ -d output/toolchain ] || mkdir output/toolchain

BUSYBOX=busybox-1_24_0
BUSYBOX_CONFIG=`pwd`/configs/busybox_config
E2FSPROGS=e2fsprogs-1.42.13
PV=pv-1.6.0
LIBC=`pwd`/prebuilt/libc-2.19-2014.08-1_sysroot.tar.gz
TOOLCHAIN=gcc-linaro-4.9-2015.02-3-x86_64_arm-linux-gnueabihf.tar.xz
TOOLCHAIN_NAME=`echo $TOOLCHAIN | sed 's/^/./' | rev | cut -d. -f3- | rev | cut -c2-`

if [ ! -f $PREBUILT/$TOOLCHAIN ]; then
	pushd $PREBUILT
	wget http://releases.linaro.org/archive/15.02/components/toolchain/binaries/arm-linux-gnueabihf/gcc-linaro-4.9-2015.02-3-x86_64_arm-linux-gnueabihf.tar.xz
	popd
fi

if [ ! -d $TOOLCHAIN_ROOT ]; then
	mkdir $TOOLCHAIN_ROOT
	pushd $TOOLCHAIN_ROOT
	tar xf $PREBUILT/$TOOLCHAIN
	popd
fi

PATH=$TOOLCHAIN_ROOT/$TOOLCHAIN_NAME/bin:$PATH

[ -d build ] || mkdir build
rm -rf build/*
pushd build

tar xf $SRCS/${BUSYBOX}.tar.gz
pushd ${BUSYBOX}

cp ${BUSYBOX_CONFIG} .config
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j${NCPUS}
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- install

popd

mkdir ${E2FSPROGS}_install
tar xf $SRCS/${E2FSPROGS}.tar.gz
pushd ${E2FSPROGS}

./configure --host=arm-linux-gnueabihf --prefix=$BUILD_ROOT/${E2FSPROGS}_install --disable-backtrace --disable-debugfs --disable-imager --disable-defrag --disable-tls --disable-uuidd --disable-nls
make -j${NCPUS}
make install

popd

mkdir ${PV}_install
tar xf $SRCS/${PV}.tar.gz
pushd ${PV}

./configure --host=arm-linux-gnueabihf --prefix=${BUILD_ROOT}/${PV}_install
LD=arm-linux-gnueabihf-ld make -j${NCPUS}
LD=arm-linux-gnueabihf-ld make install

popd

arm-linux-gnueabihf-gcc -o run-init $SRCS/run-init.c

cp ${E2FSPROGS}_install/sbin/e2fsck $SYS_ROOT/sbin
arm-linux-gnueabihf-strip $SYS_ROOT/sbin/e2fsck
cp ${E2FSPROGS}_install/sbin/mkfs.ext4 $SYS_ROOT/sbin
arm-linux-gnueabihf-strip $SYS_ROOT/sbin/mkfs.ext4
cp ${E2FSPROGS}_install/sbin/resize2fs $SYS_ROOT/sbin
arm-linux-gnueabihf-strip $SYS_ROOT/sbin/resize2fs

cp ${PV}_install/bin/pv $SYS_ROOT/bin
arm-linux-gnueabihf-strip $SYS_ROOT/bin/pv

cp run-init $SYS_ROOT/sbin
arm-linux-gnueabihf-strip $SYS_ROOT/sbin/run-init

[ -d $SYS_ROOT/lib ] || mkdir $SYS_ROOT/lib
tar xf ${LIBC} -C $SYS_ROOT/lib

rm -rf build/*

pushd $SYS_ROOT
cp -rf $SCRIPT_DIR/* .

if [ -d $BOARD_DIR/$TARGET ]; then
	cp -Lrf $BOARD_DIR/$TARGET/* .
fi

find . | cpio -o -H newc | gzip > $OUTPUT/initrd.gz
popd

rm -rf $OUTPUT/sys_root

pushd $OUTPUT
mkimage -A $TARGET_ARCH -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d initrd.gz uInitrd
popd

ls -al $OUTPUT/uInitrd
