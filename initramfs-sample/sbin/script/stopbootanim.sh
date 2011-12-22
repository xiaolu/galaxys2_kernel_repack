#!/sbin/busybox8 sh

if [ ! -f /.bootlock ]; then
  stop samsungani
fi;
