#!/sbin/busybox8 sh
#
# 89system_tweak V66
# by zacharias.maladroit
# modifications and ideas taken from: ckMod SSSwitch by voku1987 and "battery tweak" (collin_ph@xda)
# OOM/LMK settings by Juwe11
# network security settings inspired by various security, server guides on the web
# One-time tweaks to apply on every boot
a_echo()
{
	[ -e $2 ] && echo $1 > $2
}

STL=`ls -d /sys/block/stl*`;
BML=`ls -d /sys/block/bml*`;
MMC=`ls -d /sys/block/mmc*`;
ZRM=`ls -d /sys/block/zram*`;

# set the cfq scheduler as default i/o scheduler (Samsung ROMs)
for i in $STL $BML $MMC;
do
	echo "cfq" > $i/queue/scheduler; 
done;

# Optimize non-rotating storage; 
for i in $STL $BML $MMC $ZRM;
do
	#IMPORTANT!
	a_echo 0 $i/queue/rotational; 
	a_echo 8192 $i/queue/nr_requests;
	#CFQ specific
	a_echo 1 $i/queue/iosched/back_seek_penalty;
	a_echo 1 $i/queue/iosched/low_latency;
	a_echo 0 $i/queue/iosched/slice_idle;
	# deadline/VR/SIO scheduler specific
	a_echo 1 $i/queue/iosched/fifo_batch;
	a_echo 1 $i/queue/iosched/writes_starved;
	#CFQ specific
	a_echo 8 $i/queue/iosched/quantum;
	#VR Specific
	a_echo 1 $i/queue/iosched/rev_penalty;
	a_echo 1 $i/queue/rq_affinity;
	#disable iostats to reduce overhead 
	a_echo 0 $i/queue/iostats;
	# yes - I know - this is evil ^^
	a_echo 256 $i/queue/read_ahead_kb;
done;
# TWEAKS: raising read_ahead_kb cache-value for sd card to 2048 [not needed with above tweak but just in case it doesn't get applied]
# improved approach of the readahead-tweak:
a_echo "1024" /sys/devices/virtual/bdi/179:0/read_ahead_kb;
a_echo "1024" /sys/devices/virtual/bdi/179:8/read_ahead_kb;
a_echo "1024" /sys/devices/virtual/bdi/179:28/read_ahead_kb;
a_echo "1024" /sys/devices/virtual/bdi/179:33/read_ahead_kb;
a_echo "256" /sys/devices/virtual/bdi/default/read_ahead_kb;

# =========
# TWEAKS: overall
# =========
setprop ro.telephony.call_ring.delay 1000;
#setprop ro.ril.disable.power.collapse 0;
#setprop dalvik.vm.startheapsize 8m;
[ "`getprop dalvik.vm.heapsize | sed 's/m//g'`" -gt 80 ] && \
	setprop dalvik.vm.heapsize 80m;
[ "`getprop dalvik.vm.heapsize | sed 's/m//g'`" -lt 64 ] && \
	setprop dalvik.vm.heapsize 64m;
setprop wifi.supplicant_scan_interval 60;
#[ "`getprop windowsmgr.max_events_per_sec`" -lt 60 ] && \
	setprop windowsmgr.max_events_per_sec 60; # smoother GUI
