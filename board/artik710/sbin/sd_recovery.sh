#!/bin/sh

EMMC_ROOT_DEV=/dev/mmcblk0p3
SD_ROOT_DEV=/dev/mmcblk1p3
SD_MNT=/root/sd_root

LED_RED=28
LED_BLUE=38
GPIO_PATH=/sys/class/gpio

mkdir -p $SD_MNT
mkdir /mnt

led_ctl()
{
	local led=$1
	local ctl=$2

	if ! [ -d $GPIO_PATH/gpio$led ]; then
		echo $led > $GPIO_PATH/export
	fi

	echo "out" > $GPIO_PATH/gpio$led/direction
	echo $ctl > $GPIO_PATH/gpio$led/value
}

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

led_ctl $LED_RED 1

echo "Please wait until the fusing has been finished"

fuse_rootfs_partition

echo "Fusing is done."
echo "Please turn off the board and convert to eMMC boot mode"

led_ctl $LED_RED 0
led_ctl $LED_BLUE 1
