#!/sbin/busybox sh

b="/sbin/busybox"

# Logging
$b cp /data/user.log /data/user.log.bak
$b rm /data/user.log
exec >>/data/user.log
exec 2>&1

boot_extract()
{
	eval $(/sbin/read_boot_headers /dev/block/mmcblk0p5)
	load_offset=$boot_offset
	load_len=$boot_len
	dd bs=512 if=/dev/block/mmcblk0p5 skip=$load_offset count=$load_len | xzcat | tar x
	payload=1
}

installs()
{
	$b mount -o remount,rw /system
	echo "Checking Superuser installed"
	if [ ! -f /system/bin/su ]; then
		[ -z $payload ] && boot_extract
		rm /system/bin/su
		rm /system/xbin/su
		cp /cache/misc/su /system/bin/su
		chown 0.0 /system/bin/su
		chmod 6755 /system/bin/su
		ln -s /system/bin/su /system/xbin/su
		rm /system/app/*uper?ser.apk
		rm /data/app/*uper?ser.apk
		rm /data/dalvik-cache/*uper?ser.apk*
		zcat /cache/misc/Superuser.apk.gz > /system/app/Superuser.apk
		chown 0.0 /system/app/Superuser.apk
		chmod 644 /system/app/Superuser.apk
	fi

	
	##### Modify build.prop #####
	if [ "`$b grep -i persist.adb.notify /system/build.prop`" ];
	then
		echo already there...
	else
		echo persist.adb.notify=0 >> /system/build.prop
	fi;
	$b mount -o remount,ro /system
}

tweaks()
{
	echo "tweak..."
	# Tweak cfq io scheduler
	for i in $($b find /sys/block/mmc*)
	do 
		echo "0" > $i/queue/rotational
		echo "0" > $i/queue/iostats
		echo "1" > $i/queue/iosched/group_isolation
		echo "4" > $i/queue/iosched/quantum
		echo "1" > $i/queue/iosched/low_latency
		echo "5" > $i/queue/iosched/slice_idle
		echo "2" > $i/queue/iosched/back_seek_penalty
		echo "1000000000" > $i/queue/iosched/back_seek_max
	done
	# Remount all partitions with noatime
	for k in $($b mount | $b grep relatime | $b cut -d " " -f3)
	do
		sync
		$b mount -o remount,noatime $k
	done
	# Remount ext4 partitions with optimizations
	for k in $($b mount | $b grep ext4 | $b cut -d " " -f3)
	do
		sync
		$b mount -o remount,commit=15 $k
	done
	# SD cards (mmcblk) read ahead tweaks
	echo "256" > /sys/devices/virtual/bdi/179:0/read_ahead_kb
	echo "256" > /sys/devices/virtual/bdi/179:16/read_ahead_kb
}

initscripts()
{
	(
	echo $(date) USER INIT SCRIPTS START
	[ -d /system/etc/init.d ] && $b run-parts /system/etc/init.d
	[ -d /data/init.d ] && $b run-parts /data/init.d
	[ -f /system/bin/customboot.sh ] && $b sh /system/bin/customboot.sh
	[ -f /system/xbin/customboot.sh ] && $b sh /system/xbin/customboot.sh
	[ -f /data/local/customboot.sh ] && $b sh /data/local/customboot.sh
	echo $(date) USER INIT SCRIPTS DONE
	) &
}

efsbackup()
{
	(
	sleep 100
	echo "backup efs to /sdcard/.bak/"
	if [ ! -f /sdcard/.bak/efsbackup.tar.gz ];
	then
		[ -d "/sdcard/.bak" ] || mkdir /sdcard/.bak
		$b tar zcvf /sdcard/.bak/efsbackup.tar.gz /efs
		$b cat /dev/block/mmcblk0p1 > /sdcard/.bak/efsdev-mmcblk0p1.img
		$b gzip /sdcard/.bak/efsdev-mmcblk0p1.img
	fi
	echo "backup efs Done."
	) &
}

echo $(date) START of post-init.sh
installs

#tweaks

initscripts

efsbackup

echo $(date) END of post-init.sh
