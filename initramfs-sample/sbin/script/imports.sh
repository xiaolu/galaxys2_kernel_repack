#!/sbin/busybox sh
#### install boot logo ####
# thanks to Hellcat
# import/install custom boot logo if one exists
# sdcard isn't mounted at this point, mount it for now
b="/sbin/busybox"
$b mount -o rw /dev/block/mmcblk0p11 /mnt/sdcard

# import/install custom boot animation if one exists
if [ -f /mnt/sdcard/import/bootanimation.zip ]; then
  $b mount -o rw,remount /dev/block/mmcblk0p9 /system
  $b rm /system/media/sanim.zip
  $b cp /mnt/sdcard/import/bootanimation.zip /system/media/sanim.zip
  $b rm /mnt/sdcard/import/bootanimation.zip
  $b mount -o ro,remount /dev/block/mmcblk0p9 /system
fi;

# import/install custom boot sound if one exists
if [ -f /mnt/sdcard/import/PowerOn.wav ]; then
  $b mount -o rw,remount /dev/block/mmcblk0p9 /system
  $b rm /system/etc/PowerOn.wav
  $b cp /mnt/sdcard/import/PowerOn.wav /system/etc/PowerOn.wav
  $b rm /mnt/sdcard/import/PowerOn.wav
  $b mount -o ro,remount /dev/block/mmcblk0p9 /system
fi;

# import/install custom boot logo if one exists
if [ -f /mnt/sdcard/import/logo.jpg ]; then
  $b mount -o rw,remount /dev/block/mmcblk0p9 /system
  $b mount -o rw,remount /
  $b touch /.bootlock

  if [ ! -f /system/lib/param.img ]; then
    $b dd if=/dev/block/mmcblk0p4 of=/system/lib/param.img bs=4096
    $b sed 's/.jpg/.org/g' /system/lib/param.img > /system/lib/param.tmp
    $b dd if=/system/lib/param.tmp of=/dev/block/mmcblk0p4 bs=4096
  fi;
  $b mkdir /mnt/sdcard/import/old
  $b cp /mnt/.lfs/*.jpg /mnt/sdcard/import/old/
  $b umount /mnt/.lfs
  $b mount /dev/block/mmcblk0p4 /mnt/.lfs
  $b cp /mnt/sdcard/import/logo.jpg /mnt/.lfs/logo.jpg
  $b cp /mnt/sdcard/import/logo.jpg /mnt/.lfs/logo_att.jpg
  $b cp /mnt/sdcard/import/logo.jpg /mnt/.lfs/logo_kor.jpg
  $b cp /mnt/sdcard/import/logo.jpg /mnt/.lfs/logo_ntt.jpg
  $b cp /mnt/sdcard/import/logo.jpg /mnt/.lfs/logo_p6.jpg
  $b rm /mnt/sdcard/import/logo.jpg

  $b rm /.bootlock
  $b mount -o ro,remount /dev/block/mmcblk0p9 /system
  $b mount -o ro,remount /
  $b umount /mnt/.lfs
  $b umount /mnt/sdcard
  reboot
fi;

# remove sdcard mount again
$b umount /mnt/sdcard
