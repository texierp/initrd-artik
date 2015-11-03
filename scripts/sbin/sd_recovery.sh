#!/bin/sh

EMMC_ROOT_DEV=/dev/mmcblk0p3
SD_ROOT_DEV=/dev/mmcblk1p3

SD_MNT=/root/sd_root

mkdir -p $SD_MNT
mkdir /mnt

fuse_rootfs_partition()
{
	mkfs.ext4 -F $EMMC_ROOT_DEV -L rootfs > /dev/null 2>&1

	mount -t ext4 $EMMC_ROOT_DEV /mnt > /dev/null 2>&1
	pv $SD_MNT/rootfs.tar.gz | tar zxf - -C /mnt > /dev/null 2>&1
	cp $SD_MNT/artik_release /mnt/etc > /dev/null 2>&1
	sync; sync; sync
}

sync
mdev -s

mount -t ext4 $SD_ROOT_DEV $SD_MNT

echo "Please wait until the fusing has been finished"

fuse_rootfs_partition

echo "Fusing is done."
echo "Please turn off the board and convert to eMMC boot mode"
