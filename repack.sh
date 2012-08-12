#!/bin/bash
##############################################################################
# you should point where your cross-compiler is         
COMPILER=/home/xiaolu/bin/arm-eabi-4.4.3/bin/arm-eabi
COMPILER_LIB=/home/xiaolu/bin/arm-eabi-4.4.3/lib/gcc/arm-eabi/4.4.3
##############################################################################
#set -x

srcdir=`dirname $0`

# Ensure arm-eabi-gcc is on our PATH
if [ -z `which $COMPILER-gcc` ]; then
    echo "Ensure $COMPILER-* binaries are on your path" && exit 1
fi

# Ensure COMPILER_LIB env var is set
if [ -z $COMPILER_LIB ]; then
    echo "Set environment variable COMPILER_LIB to your toolchain gcc lib directory" && exit 1
fi

# PLATFORM DETECTION
if [[ "$OSTYPE" =~ ^darwin ]]; then
    PLATFORM="darwin"

    # Ensure we have gmktemp.
    if [ -z `which gmktemp` ]; then
        echo "gmktemp is required, install via 'sudo port install coreutils'" && exit 1
    fi
    tempdir=$(gmktemp -d)

    # Ensure we have greadlink.
    if [ -z `which greadlink` ]; then
        echo "greadlink is required, install via 'sudo port install coreutils'" && exit 1
    fi
    srcdir=`greadlink -f $srcdir`

    # cut needs locale set to avoid "illegal byte sequence" error
    export LC_ALL=C

    # os x stat uses -f %z to get size
    STATSIZE='stat -f %z'

    # No arguments to dd.
    DDARG=

else
    # TODO: defaults to Linux. We should detect other platforms.
    PLATFORM="linux"

    tempdir=$(mktemp -d)
    srcdir=`realpath -s $srcdir`

    # standard gnu stat uses -c %s to get size
    STATSIZE='stat -c %s'

    # dd arguments
    DDARG="status=noxfer"
fi

RESOURCES=$srcdir/resources
zImage="$1"
new_ramdisk="$2"
kernel="$tempdir/kernel.image"
test_unzipped_cpio="$tempdir/cpio.image"
head_image="$tempdir/head.image"
tail_image="$tempdir/tail.image"
ramdisk_image="$tempdir/ramdisk.image"
workdir=`pwd`

C_H1="\033[1;32m"
C_ERR="\033[1;31m"
C_CLEAR="\033[0;0m"

printhl() {
	printf "${C_H1}${1}${C_CLEAR} \n"
}

printerr() {
	printf "${C_ERR}[Err] ${1}${C_CLEAR} \n"
}

cleanup()
{
	printhl "Cleaning up...\nfinished..."
	rm -rf $tempdir
}

exit_usage() {
	printf $C_H1
	cat << EOF
Usage:$0 <zImage> <initramfs> [new_zImage_name] [c_type or payload] [c_type]
	zImage		= the zImage file (kernel) you wish to repack
	initramfs	= the initramfs you wish to pack into the zImage(file or directory)
	new_zImage	= new zImage name
	c_type		= compression type(gzip lzo lzma xz)
	payload		= padding payload files to new zImage

Error:Not enough parameters or file not found!

Repack zImage,Example:
	$0 zImagesys267 initramfs.cpio zImage

Padding sufile to zImage offset=7000000,Example:
	$0 zImagesy267 sy267.cpio new_zImage su

	how to use sufile:
	dd if=/dev/block/mmcblk0p5 of=/system/app/Superuser.apk skip=7026336 seek=0 bs=1 count=196640
	dd if=/dev/block/mmcblk0p5 of=/system/bin/su skip=7000000 seek=0 bs=1 count=26336

Use payload "tar.xz" in end of zImage:
	$0 zImagesy267 initramfs.cpio new_zImage payload

	how to use,pls read initramfs-sample/sbin/script/post-init.sh & recovery.sh
	recovery.tar.xz and boot.tar.xz in resources directory，you can customize.

Custom zImage compression type:
	$0 zImagesy267 initramfs.cpio new_zImage gzip
	or
	$0 zImagesy267 initramfs.cpio new_zImage payload gzip

EOF
	printf $C_CLEAR
	rm -rf $tempdir
	exit 1
}

# find start/end of initramfs in the zImage file
find_start_end() 
{
	pos1=`grep -P -a -b -m 1 --only-matching '\x1F\x8B\x08' $zImage | \
		cut -f 1 -d : | awk '(int($0)<50000){print $0;exit}'`
	pos2=`grep -P -a -b -m 1 --only-matching '\x{5D}\x{00}\x..\x{FF}\x{FF}\x{FF}\x{FF}\x{FF}\x{FF}' \
		$zImage | cut -f 1 -d : | awk '(int($0)<50000){print $0;exit}'`
	pos3=`grep -P -a -b -m 1 --only-matching '\xFD\x37\x7A\x58\x5A' $zImage | \
		cut -f 1 -d : | tail -1 | awk '(int($0)<50000){print $0;exit}'`
	pos4=`grep -P -a -b --only-matching '\211\114\132' $zImage | \
		head -2 |tail -1|cut -f 1 -d : | awk '(int($0)<50000){print $0;exit}'`
	zImagesize=$($STATSIZE $zImage)
	[ -z $pos1 ] && pos1=$zImagesize
	[ -z $pos2 ] && pos2=$zImagesize
	[ -z $pos3 ] && pos3=$zImagesize
	[ -z $pos4 ] && pos4=$zImagesize
	minpos=`echo -e "$pos1\n$pos2\n$pos3\n$pos4" | sort -n | head -1`
	if [ $minpos -eq $zImagesize ]; then
		printerr "not found kernel from $zImage!"
		cleanup && exit 1
	elif [ $minpos -eq $pos1 ]; then
		printhl "Extracting gzip'd kernel from $zImage (start = $pos1)"
		dd if=$zImage of="$kernel.gz" bs=$pos1 skip=1 2>/dev/null >/dev/null
		gunzip -qf "$kernel.gz"
		compress_type="gzip"
	elif [ $minpos -eq $pos2 ]; then
		printhl "Extracting lzma'd kernel from $zImage (start = $pos2)"
		dd if=$zImage of="$kernel.lzma" bs=$pos2 skip=1 2>/dev/null >/dev/null
		unlzma -qf "$kernel.lzma"
		compress_type="lzma"
	elif [ $minpos -eq $pos3 ]; then
		printhl "Extracting xz'd kernel from $zImage (start = $pos3)"
    		dd status=noxfer if=$zImage bs=$pos3 skip=1 2>/dev/null | unxz -qf > $kernel 2>/dev/null
		compress_type="xz"
	elif [ $minpos -eq $pos4 ]; then
		printhl "Extracting lzo'd kernel from $zImage (start = $pos4)"
		dd if=$zImage of="$kernel.lzo" bs=$pos4 skip=1 2>/dev/null >/dev/null
		lzop -d "$kernel.lzo" 2>/dev/null >/dev/null
		compress_type="lzo"
	fi	
	#========================================================
	# Determine cpio compression type:
	#========================================================
	for x in none gzip bzip lzma lzop; do
		case $x in
			bzip)
                		csig='\x{31}\x{41}\x{59}\x{26}\x{53}\x{59}'
                		ucmd='bunzip2 -q'
                		fext='.bz2'
                		;;

            		gzip)
                		csig='\x1F\x8B\x08'
               			ucmd='gunzip -q'
                		fext='.gz'
                		;;

            		lzma)
                		csig='\x{5D}\x{00}\x..\x{FF}\x{FF}\x{FF}\x{FF}\x{FF}\x{FF}'
                		ucmd='unlzma -q'
                		fext='.lzma'
                		;;

            		lzop)
                		csig='\211\114\132'
				ucmd='lzop -d'
                		fext='.lzo'
                		;;

            		none)
                		csig='070701'
                		ucmd=
                		fext=
                		;;
        	esac

        	#========================================================================
        	# Search for compressed cpio archive
        	#========================================================================
        	search=$(grep -P -a -b -m 1 -o $csig $kernel | cut -f 1 -d : | head -1)
        	pos=${search:-0}
		if [ ${pos} -gt 0 ]; then
			if [ ${pos} -le ${cpio_compressed_start:-0} ] || [ -z $cpio_compressed_start ];then
				cpio_compressed_start=$pos
				compression_name=$x
				compression_signature=$csig
				uncompress_cmd=$ucmd
				file_ext=$fext
			fi
		fi
	done 

	[ $compression_name = "bzip" ] && cpio_compressed_start=$((cpio_compressed_start - 4))
	start=$cpio_compressed_start
	dd if=$kernel of=$test_unzipped_cpio bs=$cpio_compressed_start skip=1 2>/dev/null >/dev/null
	if [ ! $compression_name = "none" ]; then
		printhl "CPIO compression type detected = $compression_name | offset = $cpio_compressed_start"
		end_zero='[\x01-\xff]\x00{8}'
		#end_zero='\x00{16}[\x01-\xff]'
		end=`grep -P -a -b -m 1 -o $end_zero $test_unzipped_cpio | cut -f 1 -d : | head -1`
		#[ $end ] && end=$((end + 16))		
		[ $end ] && end=$((end + 2))
		#end=$((end - end%16))
		cpio_compress_type=$compression_name
	else
        	printhl "Non-compressed CPIO image from kernel image (offset = $cpio_compressed_start)"
		start_zero='0707010{39}10{55}B0{8}TRAILER!!!'
		end1=`grep -P -a -b -m 1 -o $start_zero $test_unzipped_cpio | head -1 | cut -f 1 -d :`
		end1=$((end1 + 120))
		dd if=$test_unzipped_cpio of=$test_unzipped_cpio.tmp bs=$end1 skip=1 2>/dev/null >/dev/null
		end_zero='\x00{4}[\x01-\xff]'
		end2=`grep -P -a -b -m 1 -o $end_zero "$test_unzipped_cpio.tmp" | cut -f 1 -d : | head -1`
		[ $end2 ] && end2=$((end2 + 4))
		end=$((end1 + end2))
		end=$((end - end%16))
		cpio_compress_type="gzip"
		#[ $compress_type = "lzo" ] && cpio_compress_type="lzop"
	fi
}

function size_append()
{
	fsize=$($STATSIZE $1);
	printf "%08x\n" $fsize |					\
	sed 's/\(..\)/\1 /g' | {					\
		read ch0 ch1 ch2 ch3;					\
		for ch in $ch3 $ch2 $ch1 $ch0; do			\
			printf '%s%03o' '\' $((0x$ch)); 		\
		done;							\
	}
}

#Calculation file size, 512 bytes integer times 
function count512()
{
	fsize=$($STATSIZE $1);
	if [ $((fsize%512)) -ne 0 ]; then
		fsize=$((fsize/512+1))
	else
		fsize=$((fsize/512))
	fi
 	printf $fsize
}
#use null string fill to 512 bytes integer times 
function append512()
{
	dd if=$1 of=$2 bs=512 count=$3 conv=sync 2>/dev/null >/dev/null
}
function mkbootoffset()
{
	boot_offset=$(count512 $2)
	append512 $2 $tempdir/zImage512 $boot_offset
	boot_offset=$((boot_offset+1))
	boot_len=$(count512 $3)
	boot512=$3
	if [ $4 ]; then
		recovery_offset=$((boot_offset+boot_len))
		recovery_len=$(count512 $4)
		append512 $4 $tempdir/recovery512 $recovery_len
		recovery_str="recovery_offset=$recovery_offset;recovery_len=$recovery_len;"
		recovery512=$tempdir/recovery512
		append512 $3 $tempdir/boot512 $boot_len
		boot512=$tempdir/boot512
	fi
	printf "\n\nBOOT_IMAGE_OFFSETS\n" > $tempdir/BOOT_IMAGE_OFFSETS
	printf "boot_offset=$boot_offset;boot_len=$boot_len;$recovery_str\n\n" >> $tempdir/BOOT_IMAGE_OFFSETS
	append512 $tempdir/BOOT_IMAGE_OFFSETS $tempdir/BOOT_IMAGE_OFFSETS512 1
	cat $tempdir/zImage512 $tempdir/BOOT_IMAGE_OFFSETS512 $boot512 $recovery512 > $1
	#rm -rf $tempdir
}
MAKE_FIPS_BINARY()
{
	printhl "MAKE_FIPS for zImage."	
	openssl dgst -sha256 -hmac 12345678 -binary -out \
		$1.hmac $1
	cat $1 $1.hmac > $1.digest
	cp -f $1.digest $1
	rm -f $1.digest $1.hmac
}
mkpayload()
{
	printhl "Make payload file(boot.tar.xz|recovery.tar.xz)."	
	cd $tempdir/resources_tmp
	rm boot.tar.xz recovery.tar.xz 2>/dev/null
	if [ -d $1/boot ]; then
		cd $1/boot
		fakeroot tar -Jcf $tempdir/resources_tmp/boot.tar.xz *
		cd $tempdir/resources_tmp
	else
		touch $tempdir/resources_tmp/boot.tar.xz
	fi
	if [ -d $1/recovery ]; then
		cd $1/recovery
		fakeroot tar -Jcf $tempdir/resources_tmp/recovery.tar.xz *
		cd $tempdir/resources_tmp
	else
		touch $tempdir/resources_tmp/recovery.tar.xz
	fi
}
###############################################################################
#
# code begins
#
###############################################################################

printhl "---------------------------kernel repacker for i9100---------------------------"

if [ -z $1 ] || [ -z $2 ] || [ ! -f $1 ] || [ ! -e $2 ]; then
	exit_usage
fi

find_start_end
count=$end
printhl "CPIO image MAX size:$count"
headcount=$((end + start))
printhl "Head count:$headcount"

if [ $count -lt 0 ]; then
	printerr "Could not correctly determine the start/end positions of the CPIO!"
	cleanup && exit 1
fi

if [ -d $new_ramdisk ]; then
	printhl "make initramfs.cpio"
	cd $new_ramdisk
	find . | fakeroot cpio -H newc -o > $tempdir/initramfs.cpio 2>/dev/null
	new_ramdisk=$tempdir/initramfs.cpio
	cd $workdir
fi

# Check the Image's size
filesize=$($STATSIZE $kernel)
# Split the Image #1 ->  head.img
printhl "Making head.img ( from 0 ~ $start )"
dd if=$kernel bs=$start count=1 of=$head_image 2>/dev/null >/dev/null

# Split the Image #2 ->  tail.img
printhl "Making a tail.img ( from $headcount ~ $filesize )"
dd if=$kernel bs=$headcount skip=1 of=$tail_image 2>/dev/null >/dev/null

toobig="TRUE"
for method in "cat" "$cpio_compress_type -f9"; do
	cat $new_ramdisk | $method - > $ramdisk_image
	ramdsize=$($STATSIZE $ramdisk_image)
	printhl "Current ramdsize using $method : $ramdsize with required size : $count bytes"
	if [ $ramdsize -le $count ]; then
		printhl "$method accepted!"
		toobig="FALSE"
		break;
	fi
done

if [ "$toobig" == "TRUE" ]; then
	printerr "New ramdisk is still too big. Repack failed. $ramdsize > $count"
	cleanup && exit 1
fi

#Merge head.img + ramdisk
cat $head_image $ramdisk_image > $tempdir/franken.img
franksize=$($STATSIZE $tempdir/franken.img)

#Merge head.img + ramdisk + padding + tail
if [ $franksize -lt $headcount ]; then
	printhl "Merging [head+ramdisk] + padding + tail"
	tempnum=$((headcount - franksize))
	dd $DDARG if=/dev/zero bs=$tempnum count=1 of=$tempdir/padding 2>/dev/null >/dev/null
	cat $tempdir/padding $tail_image > $tempdir/newtail.img
	cat $tempdir/franken.img $tempdir/newtail.img > $tempdir/new_Image
elif [ $franksize -eq $headcount ]; then
	printhl "Merging [head+ramdisk] + tail"
	cat $tempdir/franken.img $tail_image > $tempdir/new_Image
else
	printerr "Combined zImage is too large - original end is $end and new end is $franksize"
	cleanup && exit 1
fi

#============================================
# rebuild zImage
#============================================
printhl "Now we are rebuilding the zImage"
if [ -z $5 ]; then
	[[ "${4/gzip/}" != "$4" ]] && compress_type="gzip"
	[[ "${4/xz/}" != "$4" ]] && compress_type="xz"
	[[ "${4/lzo/}" != "$4" ]] && compress_type="lzo"
	[[ "${4/lzma/}" != "$4" ]] && compress_type="lzma"
else
	compress_type=$5
fi
cp -rf $RESOURCES $tempdir/resources_tmp
cd $tempdir/resources_tmp
cp $tempdir/new_Image arch/arm/boot/Image
cp -f include/generated/autoconf.$compress_type.h include/generated/autoconf.h

NOSTDINC_FLAGS="-nostdinc -isystem $COMPILER_LIB/include -Iarch/arm/include \
		-Iarch/arm/include/generated -Iinclude  \
		-include include/generated/autoconf.h -D__KERNEL__ -mlittle-endian \
		-Iarch/arm/mach-exynos/include -Iarch/arm/plat-s5p/include -Iarch/arm/plat-samsung/include"

KBUILD_CFLAGS="-Wall -Wundef -Wstrict-prototypes -Wno-trigraphs \
		-fno-strict-aliasing -fno-common \
		-Werror-implicit-function-declaration \
		-Wno-format-security \
		-fno-delete-null-pointer-checks"

CFLAGS_ABI="-mabi=aapcs-linux -mno-thumb-interwork  -D__LINUX_ARM_ARCH__=7 -march=armv7-a"

#for Sourcery_G++_Lite
#[ "${COMPILER_LIB/Sourcery/}" != "$COMPILER_LIB" ] && KBUILD_CFLAGS="$KBUILD_CFLAGS -mno-unaligned-access"
#echo $KBUILD_CFLAGS

#1. Image -> piggy.*
printhl "Image ---> piggy.$compress_type"
llsl=""
if [ $compress_type = "gzip" ]; then
	cat arch/arm/boot/Image | gzip -n -f -9 > arch/arm/boot/compressed/piggy.gzip
elif [ $compress_type = "lzma" ]; then
	(cat arch/arm/boot/Image | lzma -9 && printf $(size_append arch/arm/boot/Image))	\
	 > arch/arm/boot/compressed/piggy.lzma
elif [ $compress_type = "xz" ]; then
	llsl="arch/arm/boot/compressed/ashldi3.o"
	compress_type="xzkern"

	(cat arch/arm/boot/Image | xz --check=crc32 --arm --lzma2=,dict=32MiB &&		\
	printf $(size_append arch/arm/boot/Image)) > arch/arm/boot/compressed/piggy.xzkern

	printhl "Compiling ashldi3.o"
	$COMPILER-gcc -Wp,-MD,arch/arm/boot/compressed/.ashldi3.o.d  $NOSTDINC_FLAGS \
	-D__ASSEMBLY__ $CFLAGS_ABI  -include asm/unified.h -msoft-float -gdwarf-2     \
	-Wa,-march=all   -c -o arch/arm/boot/compressed/ashldi3.o arch/arm/lib/ashldi3.S
elif [ $compress_type = "lzo" ]; then
	(cat arch/arm/boot/Image | lzop -9 && printf $(size_append arch/arm/boot/Image)) \
	> arch/arm/boot/compressed/piggy.lzo
fi

#2. piggy.* -> piggy.*.o
printhl "piggy.$compress_type ---> piggy.$compress_type.o"
$COMPILER-gcc -Wp,-MD,arch/arm/boot/compressed/.piggy.$compress_type.o.d  $NOSTDINC_FLAGS -D__ASSEMBLY__ $CFLAGS_ABI  -include asm/unified.h -msoft-float -gdwarf-2    -Wa,-march=all    -c -o arch/arm/boot/compressed/piggy.$compress_type.o arch/arm/boot/compressed/piggy.$compress_type.S

#3. head.o
printhl "Compiling head.o"
$COMPILER-gcc -Wp,-MD,arch/arm/boot/compressed/.head.o.d  $NOSTDINC_FLAGS -D__ASSEMBLY__ $CFLAGS_ABI  -include asm/unified.h -msoft-float -gdwarf-2    -Wa,-march=all  -DTEXT_OFFSET=0x00008000 -DFIPS_KERNEL_RAM_BASE=0x40008000   -c -o arch/arm/boot/compressed/head.o arch/arm/boot/compressed/head.S

#4. misc.o
printhl "Compiling misc.o"
$COMPILER-gcc -Wp,-MD,arch/arm/boot/compressed/.misc.o.d  $NOSTDINC_FLAGS $KBUILD_CFLAGS -O2 -fdiagnostics-show-option -Werror -Wno-error=unused-function -Wno-error=unused-variable -Wno-error=unused-value -Wno-error=unused-label -marm -fno-dwarf2-cfi-asm -fno-omit-frame-pointer -mapcs -mno-sched-prolog $CFLAGS_ABI -msoft-float -Uarm -Wframe-larger-than=1024 -fno-stack-protector -fno-omit-frame-pointer -fno-optimize-sibling-calls -g -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow -fconserve-stack -fpic -fno-builtin  $CFLAGS_KERNEL -D"KBUILD_STR(s)=\#s" -D"KBUILD_BASENAME=KBUILD_STR(misc)"  -D"KBUILD_MODNAME=KBUILD_STR(misc)" -c -o arch/arm/boot/compressed/misc.o arch/arm/boot/compressed/misc.c

#5. decompress.o
printhl "Compiling decompress.o"
$COMPILER-gcc -Wp,-MD,arch/arm/boot/compressed/.decompress.o.d  $NOSTDINC_FLAGS $KBUILD_CFLAGS -O2 -fdiagnostics-show-option -Werror -Wno-error=unused-function -Wno-error=unused-variable -Wno-unused-but-set-variable -Wno-error=unused-value -Wno-error=unused-label -marm -fno-dwarf2-cfi-asm -fno-omit-frame-pointer -mapcs -mno-sched-prolog $CFLAGS_ABI -msoft-float -Uarm -Wframe-larger-than=1024 -fno-stack-protector -fno-omit-frame-pointer -fno-optimize-sibling-calls -g -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow -fconserve-stack -fpic -fno-builtin  $CFLAGS_KERNEL -D"KBUILD_STR(s)=\#s" -D"KBUILD_BASENAME=KBUILD_STR(decompress)"  -D"KBUILD_MODNAME=KBUILD_STR(decompress)" -c -o arch/arm/boot/compressed/decompress.o arch/arm/boot/compressed/decompress.c

#6. lib1funcs.o
printhl "Compiling lib1funcs.o"
$COMPILER-gcc -Wp,-MD,arch/arm/boot/compressed/.lib1funcs.o.d  $NOSTDINC_FLAGS -D__ASSEMBLY__ $CFLAGS_ABI  -include asm/unified.h -msoft-float -gdwarf-2    -Wa,-march=all     -c -o arch/arm/boot/compressed/lib1funcs.o arch/arm/lib/lib1funcs.S

#7. vmlinux.lds
printhl "Create vmlinux.lds"
sed "s/TEXT_START/0/;s/BSS_START/ALIGN(8)/" < arch/arm/boot/compressed/vmlinux.lds.in > arch/arm/boot/compressed/vmlinux.lds

#8. head.o + misc.o + piggy.*.o --> vmlinux
[ $llsl ] && ashldi3=" + ashldi3.o"
printhl "head.o + misc.o + piggy.$compress_type.o + decompress.o + lib1funcs.o$ashldi3---> vmlinux"
$COMPILER-ld -EL    --defsym zreladdr=0x40008000 -p --no-undefined -X -T arch/arm/boot/compressed/vmlinux.lds arch/arm/boot/compressed/head.o arch/arm/boot/compressed/piggy.$compress_type.o arch/arm/boot/compressed/misc.o arch/arm/boot/compressed/decompress.o arch/arm/boot/compressed/lib1funcs.o $llsl -o arch/arm/boot/compressed/vmlinux

#9. vmlinux -> zImage
printhl "vmlinux ---> zImage"
$COMPILER-objcopy -O binary -R .comment -S  arch/arm/boot/compressed/vmlinux arch/arm/boot/zImage

newzImagesize=$($STATSIZE arch/arm/boot/zImage)
printhl "Compiled new zImage size:$newzImagesize"

#MAKE_FIPS
MAKE_FIPS_BINARY arch/arm/boot/zImage

new_zImage_name="new_zImage"
[ $3 ] && new_zImage_name=$3
if [ ${new_zImage_name:0:1} != "/" ]; then
	new_zImage_name="$workdir/$new_zImage_name"
fi
rm $new_zImage_name 2>/dev/null >/dev/null
if [[ "${4/payload/}" != "$4" ]]; then
	mkpayload ./payload
	printhl "Padding payload files to $(basename $new_zImage_name)."
	if [[ "${4/payloadb/}" != "$4" ]]; then	
		mkbootoffset new_zImage arch/arm/boot/zImage boot.tar.xz
	else
		mkbootoffset new_zImage arch/arm/boot/zImage boot.tar.xz recovery.tar.xz
	fi
	newzImagesize=$($STATSIZE new_zImage)
	printhl "Now zImage size:$newzImagesize bytes"
	[ $newzImagesize -gt 8388608 ] && printerr "zImage too big..." && cleanup && exit 1
	printhl "Padding new zImage to 8388608 bytes."
	dd if=new_zImage of=$new_zImage_name bs=8388608 conv=sync 2>/dev/null >/dev/null
elif [[ "${4/su/}" != "$4" ]]; then
	printhl "Padding sufiles to $new_zImage_name."
	dd if=arch/arm/boot/zImage of=$new_zImage_name bs=8388608 conv=sync 2>/dev/null >/dev/null
	dd if=sufile.pad of=$new_zImage_name bs=1 count=222976 seek=7000000 conv=notrunc 2>/dev/null >/dev/null
elif [[ "${4/pad/}" != "$4" ]]; then
	printhl "Padding new zImage to 8388608 bytes."
	dd if=arch/arm/boot/zImage of=$new_zImage_name bs=8388608 conv=sync 2>/dev/null >/dev/null
else
	cp -f arch/arm/boot/zImage $new_zImage_name
fi

printhl "$(basename $new_zImage_name) has been created."
cd $workdir
cleanup
