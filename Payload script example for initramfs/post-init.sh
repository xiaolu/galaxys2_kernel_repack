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
a_echo()
{
	[ -e $2 ] && echo $1 > $2
}

properties()
{
	setprop customkernel.base.cf-root true
	setprop customkernel.bootani.bin true
	setprop customkernel.bootani.zip true
	setprop customkernel.cf-root true
	setprop customkernel.cwm true
	setprop customkernel.cwm.version 5.0.2.8
	setprop customkernel.name xiaolu
	setprop customkernel.namedisplay xiaolu
	setprop customkernel.version.name 5.0
	setprop customkernel.version.number 100
}
modules()
{
	# Enable CIFS tweak
	#[ "`grep CIFS /system/etc/tweaks.conf`" ] && insmod /lib/modules/cifs.ko;
	
	# Android Logger enable tweak
	[ "`grep LOGGER /system/etc/tweaks.conf`" ] && insmod /lib/modules/logger.ko;
	
	#for ntfs-3g
	[ "`grep FUSE /system/etc/tweaks.conf`" ] && insmod /lib/modules/fuse.ko;
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

	echo "fix liblights..."
	ret=`diff /system/lib/hw/lights.GT-I9100.so /res/misc/lights.GT-I9100.so`
	if [ "$ret" ];
  	then
		echo "Copying liblights"
		$b cp /system/lib/hw/lights.GT-I9100.so /system/lib/hw/lights.GT-I9100.so.BAK
		$b cp /res/misc/lights.GT-I9100.so /system/lib/hw/lights.GT-I9100.so
    	$b chown 0.0 /system/lib/hw/lights.GT-I9100.so
    	$b chmod 644 /system/lib/hw/lights.GT-I9100.so
	fi
	
	[ -e /cache/misc ] && rm -rf /cache/misc
	##### Modify build.prop #####
	if [ "`$b grep -i persist.adb.notify /system/build.prop`" ];
	then
		echo already there...
	else
		echo persist.adb.notify=0 >> /system/build.prop
	fi;
	$b mount -o remount,ro /system
	##### to solve kitchen problems with CWM 5.X #####
	(
	sleep 60
	[ -d "/sdcard/clockworkmod" ] || mkdir /sdcard/clockworkmod
	touch /sdcard/clockworkmod/.salted_hash
	) &
}

tweaks()
{
	echo "tweak..."
	# IPv6 privacy tweak
	#if $b [ "`$b grep IPV6PRIVACY /system/etc/tweaks.conf`" ]; then
	a_echo "2" /proc/sys/net/ipv6/conf/all/use_tempaddr
	#fi
	# Tweak cfq io scheduler
	for i in $(find /sys/block/mmc*);
	do 
		a_echo "0" $i/queue/rotational
		a_echo "0" $i/queue/iostats
		a_echo "1" $i/queue/iosched/group_isolation
		a_echo "8" $i/queue/iosched/quantum
		a_echo "1" $i/queue/iosched/low_latency
		a_echo "0" $i/queue/iosched/slice_idle
		a_echo "1" $i/queue/iosched/back_seek_penalty
		a_echo "1000000000" $i/queue/iosched/back_seek_max
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
	# Miscellaneous tweaks
	echo "1500" > /proc/sys/vm/dirty_writeback_centisecs
	echo "200" > /proc/sys/vm/dirty_expire_centisecs
	echo "0" > /proc/sys/vm/swappiness
	
	# Ondemand CPU governor tweaks
	a_echo "100000" /sys/devices/system/cpu/cpufreq/ondemand/sampling_rate
	a_echo "85" /sys/devices/system/cpu/cpufreq/ondemand/up_threshold

	# CFS scheduler tweaks
	a_echo HRTICK /sys/kernel/debug/sched_features

	# SD cards (mmcblk) read ahead tweaks
	echo "256" > /sys/devices/virtual/bdi/179:0/read_ahead_kb
	echo "256" > /sys/devices/virtual/bdi/179:16/read_ahead_kb

	# TCP tweaks (do we need these?)
	echo "2" > /proc/sys/net/ipv4/tcp_syn_retries
	echo "2" > /proc/sys/net/ipv4/tcp_synack_retries
	echo "10" > /proc/sys/net/ipv4/tcp_fin_timeout

	# SCHED_MC power savings level
	echo "1" > /sys/devices/system/cpu/sched_mc_power_savings
	# Turn off debugging for certain modules
	echo "0" > /sys/module/wakelock/parameters/debug_mask
	echo "0" > /sys/module/userwakelock/parameters/debug_mask
	echo "0" > /sys/module/earlysuspend/parameters/debug_mask
	echo "0" > /sys/module/alarm/parameters/debug_mask
	echo "0" > /sys/module/alarm_dev/parameters/debug_mask
	echo "0" > /sys/module/binder/parameters/debug_mask
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
modules
properties
installs
tweaks
initscripts
efsbackup
echo $(date) END of post-init.sh
