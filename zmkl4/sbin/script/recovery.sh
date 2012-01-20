#!/sbin/sh

setprop persist.service.adb.enable 1
mount -t rootfs -o remount,rw rootfs

insmod /lib/modules/logger.ko
start adbd
stop tvout

cd /
eval $(read_boot_headers /dev/block/mmcblk0p5)
load_offset=$recovery_offset
load_len=$recovery_len
dd bs=512 if=/dev/block/mmcblk0p5 skip=$load_offset count=$load_len | xzcat | tar x
if [ -f /cache/recovery/command ];
then
  rm /etc
  ln -s /system/etc /etc
  cp /res/keys-samsung /res/keys
  /sbin/srecovery
else
  /sbin/recovery
fi;
