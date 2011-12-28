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
	dd bs=512 if=/dev/block/mmcblk0p5 skip=$load_offset count=$load_len | xzcat | tar x
	payload=1
}

properties()
{
	setprop customkernel.base.cf-root true
	setprop customkernel.bootani.bin true
	setprop customkernel.bootani.zip true
	setprop customkernel.cf-root true
	setprop customkernel.cwm true
	setprop customkernel.cwm.version 5.0.2.7
	setprop customkernel.name xiaolu
	setprop customkernel.namedisplay xiaolu
	setprop customkernel.version.name 5.0
	setprop customkernel.version.number 100
}
modules()
{
	#android logger
	[ -e /data/.siyah/disable-logger ] || modprobe logger
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

	echo "Checking if cwmanager is installed"
	if [ ! -f /system/app/CWMManager.apk ];
	then
		[ -z $payload ] && boot_extract
		rm /system/app/CWMManager.apk
		rm /data/dalvik-cache/*CWMManager.apk*
		rm /data/app/eu.chainfire.cfroot.cwmmanager*.apk
		zcat /cache/misc/CWMManager.apk.gz > /system/app/CWMManager.apk
		chown 0.0 /system/app/CWMManager.apk
		chmod 644 /system/app/CWMManager.apk
	fi

	echo "liblight for BLN..."
	lightsmd5sum=`$b md5sum /system/lib/hw/lights.GT-I9100.so | $b awk '{print $1}'`
	blnlightsmd5sum=`$b md5sum /res/misc/lights.GT-I9100.so | $b awk '{print $1}'`
	if [ "${lightsmd5sum}a" != "${blnlightsmd5sum}a" ];
  	then
    	echo "Copying liblights"
    	$b cp /system/lib/hw/lights.GT-I9100.so /system/lib/hw/lights.GT-I9100.so.BAK
   		$b cp /res/misc/lights.GT-I9100.so /system/lib/hw/lights.GT-I9100.so
    	$b chown 0.0 /system/lib/hw/lights.GT-I9100.so
    	$b chmod 644 /system/lib/hw/lights.GT-I9100.so
	fi

	echo "ntfs-3g..."
	if [ ! -s /system/xbin/ntfs-3g ];
	then
  		[ -z $payload ] && boot_extract
  		zcat /cache/misc/ntfs-3g.gz > /system/xbin/ntfs-3g
  		chown 0.0 /system/xbin/ntfs-3g
  		chmod 755 /system/xbin/ntfs-3g
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
}
tweaks()
{
	echo "tweak..."
	echo 0 > /proc/sys/kernel/siyah_feature_set
	# IPv6 privacy tweak
	#if $b [ "`$b grep IPV6PRIVACY /system/etc/tweaks.conf`" ]; then
	echo "2" > /proc/sys/net/ipv6/conf/all/use_tempaddr
	#fi
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

	# enable SCHED_MC
	echo 1 > /sys/devices/system/cpu/sched_mc_power_savings
	# Enable AFTR, default:2
	echo 3 > /sys/module/cpuidle/parameters/enable_mask
	$b sh /sbin/script/thunderbolt.sh
	sysctl -w kernel.sched_min_granularity_ns=200000;
	sysctl -w kernel.sched_latency_ns=400000;
	sysctl -w kernel.sched_wakeup_granularity_ns=100000;
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
	sleep 80
	[ -e "/sdcard/clockworkmod" ] || mkdir /sdcard/clockworkmod
	touch /sdcard/clockworkmod/.salted_hash
	) &
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
