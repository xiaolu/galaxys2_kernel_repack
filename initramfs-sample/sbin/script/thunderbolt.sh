#!/sbin/busybox8 sh
#
# 89system_tweak V66
# by zacharias.maladroit
# modifications and ideas taken from: ckMod SSSwitch by voku1987 and "battery tweak" (collin_ph@xda)
# OOM/LMK settings by Juwe11
# network security settings inspired by various security, server guides on the web
# One-time tweaks to apply on every boot
STL=`ls -d /sys/block/stl*`;
BML=`ls -d /sys/block/bml*`;
MMC=`ls -d /sys/block/mmc*`;
ZRM=`ls -d /sys/block/zram*`;

# set the cfq scheduler as default i/o scheduler (Samsung ROMs)
#for i in $STL $BML $MMC;
#do
#	echo "noop" > $i/queue/scheduler; 
#done;

# Optimize non-rotating storage; 
for i in $STL $BML $MMC $ZRM;
do
	#IMPORTANT!
	[ -e $i/queue/rotational ] && \
	echo 0 > $i/queue/rotational; 
	[ -e $i/queue/nr_requests ] && \
	echo 8192 > $i/queue/nr_requests;
	#CFQ specific
	[ -e $i/queue/iosched/back_seek_penalty ] && \
	echo 1 > $i/queue/iosched/back_seek_penalty;
	[ -e $i/queue/iosched/low_latency ] && \
	echo 1 > $i/queue/iosched/low_latency;
	[ -e $i/queue/iosched/slice_idle ] && \
	echo 0 > $i/queue/iosched/slice_idle;
	# deadline/VR/SIO scheduler specific
	[ -e $i/queue/iosched/fifo_batch ] && \
	echo 1 > $i/queue/iosched/fifo_batch;
	[ -e $i/queue/iosched/writes_starved ] && \
	echo 1 > $i/queue/iosched/writes_starved;
	#CFQ specific
	[ -e $i/queue/iosched/quantum ] && \
	echo 8 > $i/queue/iosched/quantum;
	#VR Specific
	[ -e $i/queue/iosched/rev_penalty ] && \
	echo 1 > $i/queue/iosched/rev_penalty;
	[ -e $i/queue/rq_affinity ] && \
	echo "1"   >  $i/queue/rq_affinity;
	#disable iostats to reduce overhead 
	[ -e $i/queue/iostats ] && \
	echo "0" > $i/queue/iostats;
	# yes - I know - this is evil ^^
	[ -e $i/queue/read_ahead_kb ] && \
	echo "256" >  $i/queue/read_ahead_kb;
done;
# TWEAKS: raising read_ahead_kb cache-value for sd card to 2048 [not needed with above tweak but just in case it doesn't get applied]
# improved approach of the readahead-tweak:
[ -e /sys/devices/virtual/bdi/179:0/read_ahead_kb ] && \
echo "1024" > /sys/devices/virtual/bdi/179:0/read_ahead_kb;
[ -e /sys/devices/virtual/bdi/179:8/read_ahead_kb ] && \
echo "1024" > /sys/devices/virtual/bdi/179:8/read_ahead_kb;
[ -e /sys/devices/virtual/bdi/179:28/read_ahead_kb ] && \
echo "1024" > /sys/devices/virtual/bdi/179:28/read_ahead_kb;
[ -e /sys/devices/virtual/bdi/179:33/read_ahead_kb ] && \
echo "1024" > /sys/devices/virtual/bdi/179:33/read_ahead_kb;
[ -e /sys/devices/virtual/bdi/default/read_ahead_kb ] && \
echo "256" > /sys/devices/virtual/bdi/default/read_ahead_kb;

sysctl -w vm.page-cluster=3;
sysctl -w vm.laptop_mode=0;
sysctl -w vm.dirty_expire_centisecs=3000;
sysctl -w vm.dirty_expire_centisecs=500;
sysctl -w vm.dirty_background_ratio=65;
sysctl -w vm.dirty_ratio=80;
sysctl -w vm.vfs_cache_pressure=1;
sysctl -w vm.overcommit_memory=1;
sysctl -w vm.oom_kill_allocating_task=0;
sysctl -w vm.panic_on_oom=0;
sysctl -w kernel.panic_on_oops=1;
sysctl -w kernel.panic=0;

# TWEAKS: for TCP read/write
sysctl -w net.ipv4.tcp_timestamps=0;
sysctl -w net.ipv4.tcp_tw_reuse=1;
sysctl -w net.ipv4.tcp_sack=1;
sysctl -w net.ipv4.tcp_dsack=1;
sysctl -w net.ipv4.tcp_tw_recycle=1;
sysctl -w net.ipv4.tcp_window_scaling=1;
sysctl -w net.ipv4.tcp_keepalive_probes=5;
sysctl -w net.ipv4.tcp_keepalive_intvl=30;
sysctl -w net.ipv4.tcp_fin_timeout=30;
sysctl -w net.ipv4.tcp_moderate_rcvbuf=1;
sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1;
[ -e /proc/sys/net/ipv6/icmp_echo_ignore_broadcasts ] && \
echo "1" >  /proc/sys/net/ipv6/icmp_echo_ignore_broadcasts;
sysctl -w net.ipv4.icmp_echo_ignore_all=1;
[ -e /proc/sys/net/ipv6/icmp_echo_ignore_all ] && \
echo "1" >  /proc/sys/net/ipv6/icmp_echo_ignore_all;
sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=1;
[ -e /proc/sys/net/ipv6/icmp_ignore_bogus_error_responses ] && \
echo "1" >  /proc/sys/net/ipv6/icmp_ignore_bogus_error_responses;
sysctl -w net.ipv4.tcp_max_syn_backlog=4096;
sysctl -w net.core.netdev_max_backlog=2500;
#sysctl -w net.ipv4.tcp_syncookies=1;
sysctl -w net.ipv4.ip_dynaddr=0;
setprop ro.telephony.call_ring.delay 1000; # let's minimize the time Android waits until it rings on a call
#setprop ro.ril.disable.power.collapse 0;
#setprop dalvik.vm.startheapsize 8m;
setprop dalvik.vm.heapsize 48m; # leave that setting to cyanogenmod settings or uncomment it if needed
setprop wifi.supplicant_scan_interval 60; # higher is not recommended, scans while not connected anyway so shouldn't affect while connected
setprop windowsmgr.max_events_per_sec 60; # smoother GUI
#echo 64000 > /proc/sys/kernel/msgmni;
sysctl -w kernel.sem=500,512000,100,2048;
sysctl -w kernel.shmmax=268435456;
sysctl -w kernel.msgmni=1024;
#sysctl -w kernel.hung_task_timeout_secs=30;

# TWEAKS: new scheduler performance settings (test)
#echo "NO_GENTLE_FAIR_SLEEPERS" > /sys/kernel/debug/sched_features;
#echo "NO_NEW_FAIR_SLEEPERS" > /sys/kernel/debug/sched_features;
#echo "NO_NORMALIZED_SLEEPER" > /sys/kernel/debug/sched_features;