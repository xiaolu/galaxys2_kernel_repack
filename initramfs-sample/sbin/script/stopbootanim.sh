#!/sbin/busybox sh

if [ ! -f /.bootlock ]; then
  stop samsungani
fi;
