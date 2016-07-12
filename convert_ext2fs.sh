#!/bin/bash

set -e

PREBUILT_UINITRD=`pwd`/prebuilt/uInitrd
OUTPUT_DIR=`pwd`/output
SCRIPT_DIR=`pwd`/scripts

[ -d $OUTPUT_DIR/sys_root ] || mkdir $OUTPUT_DIR/sys_root

pushd $OUTPUT_DIR

dd if=/dev/zero of=ramdisk bs=1M count=16
mkfs.ext2 -F ramdisk

dd if=$PREBUILT_UINITRD of=initrd.gz bs=64 skip=1

sudo mount -o loop ramdisk $OUTPUT_DIR/sys_root

pushd $OUTPUT_DIR/sys_root
gunzip -c $OUTPUT_DIR/initrd.gz | sudo cpio -ivd

cp -rf $SCRIPT_DIR/* .

popd

sudo umount $OUTPUT_DIR/sys_root

rm -rf $OUTPUT_DIR/sys_root

gzip -f $OUTPUT_DIR/ramdisk

ls -al $OUTPUT_DIR/ramdisk.gz
