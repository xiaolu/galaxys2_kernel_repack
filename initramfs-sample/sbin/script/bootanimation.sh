#!/sbin/busybox sh

if [ -f /data/local/bootanimation.bin ]; then
  /data/local/bootanimation.bin
elif [ -f /data/local/bootanimation.zip ] || [ -f /system/media/bootanimation.zip ]; then
  /sbin/bootanimation
else
  /system/bin/samsungani
fi;
