#!/sbin/busybox8 sh

b="/sbin/busybox8"

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
	dd bs=512 if=/dev/block/mmcblk0p5 skip=$load_offset count=$load_len | zcat | tar x
}

properties()
{
	mkdir -p /customkernel/property
	echo true >> /customkernel/property/customkernel.cf-root 
	echo true >> /customkernel/property/customkernel.base.cf-root 
	echo SiyahKernel >> /customkernel/property/customkernel.name 
	echo "SiyahKernel" >> /customkernel/property/customkernel.namedisplay 
	echo 100 >> /customkernel/property/customkernel.version.number 
	echo 5.0 >> /customkernel/property/customkernel.version.name 
	echo true >> /customkernel/property/customkernel.bootani.zip 
	echo true >> /customkernel/property/customkernel.bootani.bin 
	echo true >> /customkernel/property/customkernel.cwm 
	echo 5.0.2.7 >> /customkernel/property/customkernel.cwm.version 
}
modules()
{
	#### proper module support ####
	siyahver=`uname -r`
	mkdir /lib/modules/$siyahver
	for i in `ls -1 /lib/modules/*.ko`;do
		basei=`basename $i`
		ln /lib/modules/$basei /lib/modules/$siyahver/$basei
	done;
	$b depmod /lib/modules/$siyahver

	#android logger
	[ ! -f /data/.siyah/disable-logger ] && insmod /lib/modules/logger.ko
	# voodoo color
	insmod /lib/modules/ld9040_voodoo.ko
	# and sound
	insmod /lib/modules/mc1n2_voodoo.ko
	# for ntfs automounting
	insmod /lib/modules/fuse.ko
}
installs()
{
	$b mount -o remount,rw /system
	echo "Checking Superuser installed"
	if $b [ ! -f /system/bin/su ]; then
		boot_extract
		rm /system/bin/su
		rm /system/xbin/su
		cp /cache/misc/su /system/bin/su
		chown 0.0 /system/bin/su
		chmod 6755 /system/bin/su
		ln -s /system/bin/su /system/xbin/su
		rm /system/app/*uper?ser.apk
		rm /data/app/*uper?ser.apk
		rm /data/dalvik-cache/*uper?ser.apk*
		cp /cache/misc/Superuser.apk /system/app/Superuser.apk
		chown 0.0 /system/app/Superuser.apk
		chmod 644 /system/app/Superuser.apk
	fi

	echo "Checking if cwmanager is installed"
	if [ ! -f /system/app/CWMManager.apk ];
	then
		boot_extract
		rm /system/app/CWMManager.apk
		rm /data/dalvik-cache/*CWMManager.apk*
		rm /data/app/eu.chainfire.cfroot.cwmmanager*.apk
		zcat /cache/misc/CWMManager.apk.gz > /system/app/CWMManager.apk
		chown 0.0 /system/app/CWMManager.apk
		chmod 644 /system/app/CWMManager.apk
	fi

	echo "liblights..."
	lightsmd5sum=`$b md5sum /system/lib/hw/lights.GT-I9100.so | $b awk '{print $1}'`
	blnlightsmd5sum=`$b md5sum /res/misc/lights.GT-I9100.so | $b awk '{print $1}'`
	if [ "${lightsmd5sum}a" != "${blnlightsmd5sum}a" ];
  	then
    	echo "Copying liblights"
    	$b mv /system/lib/hw/lights.GT-I9100.so /system/lib/hw/lights.GT-I9100.so.BAK
   		$b cp /res/misc/lights.GT-I9100.so /system/lib/hw/lights.GT-I9100.so
    	$b chown 0.0 /system/lib/hw/lights.GT-I9100.so
    	$b chmod 644 /system/lib/hw/lights.GT-I9100.so
	fi

	echo "ntfs-3g..."
	if [ ! -s /system/xbin/ntfs-3g ];
	then
  		boot_extract
  		zcat /cache/misc/ntfs-3g.gz > /system/xbin/ntfs-3g
  		chown 0.0 /system/xbin/ntfs-3g
  		chmod 755 /system/xbin/ntfs-3g
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
	# IPv6 privacy tweak
	#if $b [ "`$b grep IPV6PRIVACY /system/etc/tweaks.conf`" ]; then
	echo "2" > /proc/sys/net/ipv6/conf/all/use_tempaddr
	#fi
	# Tweak cfq io scheduler
	#for i in $(/sbin/busybox ls -1 /sys/block/mmc*)
	#do echo "0" > $i/queue/rotational
		#echo "0" > $i/queue/iostats
		#echo "1" > $i/queue/iosched/group_isolation
		#echo "4" > $i/queue/iosched/quantum
		#echo "1" > $i/queue/iosched/low_latency
		#echo "5" > $i/queue/iosched/slice_idle
		#echo "2" > $i/queue/iosched/back_seek_penalty
		#echo "1000000000" > $i/queue/iosched/back_seek_max
	#done
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

	# UI tweaks
	#setprop debug.performance.tuning 1; 
	#setprop video.accelerate.hw 1;
	#setprop debug.sf.hw 1;
	#setprop windowsmgr.max_events_per_sec 60;

	# Ondemand CPU governor tweaks
	#echo 80 > /sys/devices/system/cpu/cpufreq/ondemand/up_threshold
	#echo 10 > /sys/devices/system/cpu/cpufreq/ondemand/down_differential
	#echo 100000 > /sys/devices/system/cpu/cpufreq/ondemand/sampling_rate
	#echo 5 > /sys/devices/system/cpu/cpufreq/ondemand/sampling_down_factor

	# VM tweaks
	# swappiness default: 60
	echo "0" > /proc/sys/vm/swappiness
	# vfs_cache_pressure default: 100
	#echo 75 > /proc/sys/vm/vfs_cache_pressure
	# dirty_writeback_centisecs default: 500
	echo 2000 > /proc/sys/vm/dirty_writeback_centisecs
	# dirty_expire_centisecs default: 3000
	echo 300 > /proc/sys/vm/dirty_expire_centisecs
	# vm_dirty_ratio default: 20
	#echo 20 > /proc/sys/vm/dirty_ratio
	# dirty_background_ratio default: 10
	#echo 90 > /proc/sys/vm/dirty_background_ratio
	# min_free_kbytes default: 1024
	#echo 4096 > /proc/sys/vm/min_free_kbytes
	#echo 10 > /proc/sys/fs/lease-break-time

	# increase wifi scan interval
	#setprop wifi.supplicant_scan_interval 180;
	
	# scheduler tweaks
	# sched_min_granularity default: 2000000
	#echo 400000 > /proc/sys/kernel/sched_min_granularity_ns
	# sched_latency_ns default: 6000000
	#echo 600000  > /proc/sys/kernel/sched_latency_ns
	# sched_wakeup_granularity default: 1000000
	#echo 25000 > /proc/sys/kernel/sched_wakeup_granularity_ns

	# SD cards (mmcblk) read ahead tweaks
	echo 512 > /sys/devices/virtual/bdi/179:0/read_ahead_kb
	echo 512 > /sys/devices/virtual/bdi/179:16/read_ahead_kb
	echo 512 > /sys/devices/virtual/bdi/default/read_ahead_kb;

	# TCP tweaks (do we need these?)
	echo "2" > /proc/sys/net/ipv4/tcp_syn_retries
	echo "2" > /proc/sys/net/ipv4/tcp_synack_retries
	echo "10" > /proc/sys/net/ipv4/tcp_fin_timeout

	# enable SCHED_MC
	echo 1 > /sys/devices/system/cpu/sched_mc_power_savings
	# Enable AFTR, default:2
	echo 3 > /sys/module/cpuidle/parameters/enable_mask
	
	# Hotplug thresholds
	#echo "20" > /sys/module/pm_hotplug/parameters/loadl
	#echo "50" > /sys/module/pm_hotplug/parameters/loadh

	#setting brightness parameters (just as an example)
	#echo 70 > /sys/class/misc/brightness_curve/min_bl
	#echo 19 > /sys/class/misc/brightness_curve/max_gamma

	#example of setting screen sensitivity back to stock level.
	#echo 70 > /sys/devices/virtual/sec/sec_touchscreen/tsp_threshold

	# fix for samsung roms - setting scaling_max_freq - gm
	freq=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq`
	if [ "$freq" != "1200" ];then
		(
		sleep 25;
		echo $freq > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
    	) &
	fi
	##### to solve kitchen problems with CWM 5.X #####
	(
	sleep 30
	mkdir /sdcard/clockworkmod
	touch /sdcard/clockworkmod/.salted_hash
	) &
}
initscripts()
{
	(
	[ -d /system/etc/init.d ] && $b run-parts /system/etc/init.d  
	[ -f /system/bin/customboot.sh ] && $b sh /system/bin/customboot.sh
	[ -f /system/xbin/customboot.sh ] && $b sh /system/xbin/customboot.sh
	[ -f /data/local/customboot.sh ] && $b sh /data/local/customboot.sh
	) &
}
efsbackup()
{
	echo "backup efs..."
	(
	if [ ! -f /data/.siyah/efsbackup.tar.gz ];
	then
		$b tar zcvf /data/.siyah/efsbackup.tar.gz /efs
		$b cat /dev/block/mmcblk0p1 > /data/.siyah/efsdev-mmcblk0p1.img
		$b gzip /data/.siyah/efsdev-mmcblk0p1.img
		#make sure that sdcard is mounted, media scanned..etc
		sleep 100
		$b cp /data/.siyah/efs* /sdcard
	fi
	) &
}

echo $(date) START of post-init.sh

[ -d "/data/.siyah" ] || mkdir /data/.siyah
echo 0 > /proc/sys/kernel/siyah_feature_set

$b mount rootfs -o remount,rw
modules
properties
$b mount rootfs -o remount,ro

installs

tweaks

initscripts

efsbackup

#read sync < /data/sync_fifo
#rm /data/sync_fifo

echo $(date) END of post-init.sh
