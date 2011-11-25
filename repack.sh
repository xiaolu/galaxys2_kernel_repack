#!/bin/bash
##############################################################################
# you should point where your cross-compiler is         
COMPILER=/home/xiaolu/bin/android-toolchain-eabi/bin/arm-eabi
COMPILER_LIB=/home/xiaolu/bin/android-toolchain-eabi/lib/gcc/arm-eabi/4.5.4
#COMPILER=/home/xiaolu/CodeSourcery/Sourcery_G++_Lite/bin/arm-none-eabi
#COMPILER_LIB=/home/xiaolu/CodeSourcery/Sourcery_G++_Lite/lib/gcc/arm-none-eabi/4.5.2
##############################################################################
#set -x

srcdir=`dirname $0`
srcdir=`realpath $srcdir`
RESOURCES=$srcdir/resources
GEN_INITRAMFS=$srcdir/gen_initramfs.sh

zImage="$1"
new_ramdisk="$2"
kernel="./out/kernel.image"
test_unzipped_cpio="./out/cpio.image"
head_image="./out/head.image"
tail_image="./out/tail.image"
ramdisk_image="./out/ramdisk.image"
workdir=`pwd`

C_H1="\033[1;32m" # highlight text 1
C_ERR="\033[1;31m"
C_CLEAR="\033[1;0m"

printhl() {
	printf "${C_H1}[I] ${1}${C_CLEAR} \n"
}

printerr() {
	printf "${C_ERR}[E] ${1}${C_CLEAR} \n"
}

exit_usage() {
cat << EOF
Usage:$0 <zImage> <initramfs>
	zImage          = the zImage file (kernel) you wish to repack
	initramfs  = the cpio (initramfs) you wish to pack into the zImage
		     file or directory

Not enough parameters or file not found!

EOF
	exit 1
}

# find start/end of initramfs in the zImage file
find_start_end() 
{
	pos1=`grep -P -a -b -m 1 --only-matching '\x1F\x8B\x08' $zImage | cut -f 1 -d :`
	pos2=`grep -P -a -b -m 1 --only-matching '\x{5D}\x{00}\x..\x{FF}\x{FF}\x{FF}\x{FF}\x{FF}\x{FF}' $zImage | cut -f 1 -d :`
	pos3=`grep -P -a -b -m 1 --only-matching '\xFD\x37\x7A\x58\x5A' $zImage | cut -f 1 -d : | tail -1`
	zImagesize=$(stat -c "%s" $zImage)
	[ -z $pos1 ] && pos1=$zImagesize
	[ -z $pos2 ] && pos2=$zImagesize
	[ -z $pos3 ] && pos3=$zImagesize
	minpos=`echo -e "$pos1\n$pos2\n$pos3" | sort -n | head -1`
	mkdir out 2>/dev/null
	if [ $minpos -eq $zImagesize ]; then
		printerr "not found kernel from $zImage!"
		exit 1
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
	fi	
	#========================================================
	# Determine cpio compression type:
	#========================================================
	for x in none gzip bzip lzma; do
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

            		none)
                		csig='070701'
                		ucmd=
                		fext=
                		;;
        	esac

        	#========================================================================
        	# Search for compressed cpio archive
        	#========================================================================
        	search=`grep -P -a -b -m 1 --only-matching $csig $kernel | cut -f 1 -d : | head -1`
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
		#[ ! -z $end ] && end=$((end + 16))		
		[ ! -z $end ] && end=$((end + 2))
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
		[ ! -z $end2 ] && end2=$((end2 + 4))
		end=$((end1 + end2))
		end=$((end - end%16))
		cpio_compress_type=$compress_type
	fi
}

function size_append()
{
	fsize=$(stat -c "%s" $1);
	printf "%08x\n" $fsize |					\
	sed 's/\(..\)/\1 /g' | {					\
		read ch0 ch1 ch2 ch3;					\
		for ch in $ch3 $ch2 $ch1 $ch0; do			\
			printf '%s%03o' '\' $((0x$ch)); 		\
		done;							\
	}
}

###############################################################################
#
# code begins
#
###############################################################################

printhl "---------------------------kernel repacker for i9100---------------------------"

if [ "$1" == "" ] || [ "$2" == "" ] || [ ! -f $1 ] || [ ! -e $2 ]; then
	exit_usage
fi

find_start_end
count=$end
printhl "CPIO image MAX size:$count"
headcount=$((end + start))
printhl "Head count:$headcount"

#exit

if [ $count -lt 0 ]; then
	printerr "Could not correctly determine the start/end positions of the CPIO!"
	exit
fi

# Check the Image's size
filesize=$(stat -c "%s" $kernel)
# Split the Image #1 ->  head.img
printhl "Making head.img ( from 0 ~ $start )"
dd if=$kernel bs=$start count=1 of=$head_image 2>/dev/null >/dev/null

# Split the Image #2 ->  tail.img
printhl "Making a tail.img ( from $headcount ~ $filesize )"
dd if=$kernel bs=$headcount skip=1 of=$tail_image 2>/dev/null >/dev/null

# Create new ramdisk Image

#if [ -d $new_ramdisk ]; then
#	printhl "$new_ramdisk is a directory,Generate initramfs.cpio"
#	$GEN_INITRAMFS -o ./out/initramfs.cpio -u 1001 -g 2000 $new_ramdisk
#	new_ramdisk="./out/initramfs.cpio"
#fi

toobig="TRUE"
for method in "cat" "$cpio_compress_type -f9"; do
	cat $new_ramdisk | $method - > $ramdisk_image
	ramdsize=$(stat -c "%s" $ramdisk_image)
	printhl "Current ramdsize using $method : $ramdsize with required size : $count bytes"
	if [ $ramdsize -le $count ]; then
		printhl "$method accepted!"
		toobig="FALSE"
		break;
	fi
done

if [ "$toobig" == "TRUE" ]; then
	printerr "New ramdisk is still too big. Repack failed. $ramdsize > $count"
	exit
fi

#Merge head.img + ramdisk
cat $head_image $ramdisk_image > out/franken.img
franksize=$(stat -c "%s" out/franken.img)

#Merge head.img + ramdisk + padding + tail
if [ $franksize -lt $headcount ]; then
	printhl "Merging [head+ramdisk] + padding + tail"
	tempnum=$((headcount - franksize))
	dd status=noxfer if=/dev/zero bs=$tempnum count=1 of=out/padding 2>/dev/null >/dev/null
	cat out/padding $tail_image > out/newtail.img
	cat out/franken.img out/newtail.img > out/new_Image
elif [ $franksize -eq $headcount ]; then
	printhl "Merging [head+ramdisk] + tail"
	cat out/franken.img $tail_image > out/new_Image
else
	printerr "Combined zImage is too large - original end is $end and new end is $franksize"
	exit
fi

#============================================
# rebuild zImage
#============================================
printhl "Now we are rebuilding the zImage"
mkdir resources_tmp
cp -rn $RESOURCES/* ./resources_tmp/
cd resources_tmp
cp ../out/new_Image arch/arm/boot/Image
cp -f include/generated/autoconf.$compress_type.h include/generated/autoconf.h 2>/dev/null >/dev/null

NOSTDINC_FLAGS="-nostdinc -isystem $COMPILER_LIB/include -Iarch/arm/include \
		-Iinclude  -include include/generated/autoconf.h -D__KERNEL__ \
		-mlittle-endian -Iarch/arm/mach-s5pv310/include \
		-Iarch/arm/plat-s5p/include -Iarch/arm/plat-samsung/include"
KBUILD_CFLAGS="-Wall -Wundef -Wstrict-prototypes -Wno-trigraphs \
		   -fno-strict-aliasing -fno-common \
		   -Werror-implicit-function-declaration \
		   -Wno-format-security \
		   -fno-delete-null-pointer-checks"
CFLAGS_ABI="-mabi=aapcs-linux -mno-thumb-interwork -funwind-tables -D__LINUX_ARM_ARCH__=7 -march=armv7-a"

if [[ "${1/sy/}" != "$1" ]]; then
	#for Siyah
	CFLAGS_KERNEL="-fsched-spec-load -funswitch-loops -fpredictive-commoning \
			-fgcse-after-reload -ftree-vectorize -fipa-cp-clone \
			-ffast-math -fsingle-precision-constant -pipe \
			-mtune=cortex-a9 -mfpu=neon -march=armv7-a"
	printhl "Prepare source code for 【Siyah】"
	cp -f include/linux/kernel.siyah.h include/linux/kernel.h
	cp -f include/asm-generic/bug.siyah.h include/asm-generic/bug.h
	cp -f include/generated/autoconf.siyah.h include/generated/autoconf.h
elif [[ "${1/vd/}" != "$1" ]]; then
	#for Void
	KBUILD_CFLAGS="$KBUILD_CFLAGS -marm -march=armv7-a -mtune=cortex-a9 \
			-mfpu=neon -mfloat-abi=softfp \
			-fno-tree-vectorize \
			-floop-interchange -floop-strip-mine -floop-block \
			-pipe"
	printhl "Prepare source code for 【Void】"
	cp -f include/linux/kernel.void.h include/linux/kernel.h
	cp -f arch/arm/include/asm/ptrace.void.h arch/arm/include/asm/ptrace.h
	cp -f include/generated/autoconf.void.h include/generated/autoconf.h
elif [[ "${1/md/}" != "$1" ]]; then
	#for Androidmeda
	CFLAGS_KERNEL="-finline-functions -funswitch-loops -fpredictive-commoning \
			-fgcse-after-reload -ftree-vectorize -fipa-cp-clone \
			-ffast-math -fsingle-precision-constant -pipe -mtune=cortex-a9 \
			-mfpu=neon -march=armv7-a"
	KBUILD_CFLAGS="$KBUILD_CFLAGS -mfloat-abi=softfp -funroll-loops \
                	-floop-interchange -floop-strip-mine -floop-block \
                	-fpredictive-commoning -ftree-vectorize \
                	-funswitch-loops -fgcse-after-reload -fipa-cp-clone \
                	-pipe \
                	-marm -march=armv7-a -mtune=cortex-a9 \
                	-mfpu=neon"

	printhl "Prepare source code for 【Androidmeda】"
	cp -f include/asm-generic/bug.siyah.h include/asm-generic/bug.h
	cp -f arch/arm/include/asm/assembler.meda.h arch/arm/include/asm/assembler.h
	cp -f include/generated/autoconf.meda.h include/generated/autoconf.h
fi

#1. Image -> piggy.*
printhl "Image ---> piggy.$compress_type"
llsl=""
if [ $compress_type = "gzip" ]; then
	cat arch/arm/boot/Image | gzip -f -9 > arch/arm/boot/compressed/piggy.gzip
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

fi

#2. piggy.* -> piggy.*.o
printhl "piggy.$compress_type ---> piggy.$compress_type.o"
$COMPILER-gcc -Wp,-MD,arch/arm/boot/compressed/.piggy.$compress_type.o.d  $NOSTDINC_FLAGS -D__ASSEMBLY__ $CFLAGS_ABI  -include asm/unified.h -msoft-float -gdwarf-2     -Wa,-march=all   -c -o arch/arm/boot/compressed/piggy.$compress_type.o arch/arm/boot/compressed/piggy.$compress_type.S

#3. head.o
printhl "Compiling head.o"
$COMPILER-gcc -Wp,-MD,arch/arm/boot/compressed/.head.o.d  $NOSTDINC_FLAGS -D__ASSEMBLY__ $CFLAGS_ABI  -include asm/unified.h -msoft-float -gdwarf-2     -Wa,-march=all   -c -o arch/arm/boot/compressed/head.o arch/arm/boot/compressed/head.S

#4. misc.o
printhl "Compiling misc.o"
$COMPILER-gcc -Wp,-MD,arch/arm/boot/compressed/.misc.o.d  $NOSTDINC_FLAGS $KBUILD_CFLAGS -Os -marm -fno-omit-frame-pointer -mapcs -mno-sched-prolog $CFLAGS_ABI -msoft-float -Uarm -Wframe-larger-than=1024 -fno-stack-protector -fno-omit-frame-pointer -fno-optimize-sibling-calls -g -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow -fconserve-stack -fpic -fno-builtin  $CFLAGS_KERNEL -D"KBUILD_STR(s)=\#s" -D"KBUILD_BASENAME=KBUILD_STR(misc)"  -D"KBUILD_MODNAME=KBUILD_STR(misc)"  -c -o arch/arm/boot/compressed/misc.o arch/arm/boot/compressed/misc.c 2>/dev/null >/dev/null

#5. decompress.o
printhl "Compiling decompress.o"
$COMPILER-gcc -Wp,-MD,arch/arm/boot/compressed/.decompress.o.d  $NOSTDINC_FLAGS $KBUILD_CFLAGS -Os -marm -fno-omit-frame-pointer -mapcs -mno-sched-prolog $CFLAGS_ABI -msoft-float -Uarm -Wframe-larger-than=1024 -fno-stack-protector -fno-omit-frame-pointer -fno-optimize-sibling-calls -g -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow -fconserve-stack -fpic -fno-builtin  $CFLAGS_KERNEL -D"KBUILD_STR(s)=\#s" -D"KBUILD_BASENAME=KBUILD_STR(decompress)"  -D"KBUILD_MODNAME=KBUILD_STR(decompress)"  -c -o arch/arm/boot/compressed/decompress.o arch/arm/boot/compressed/decompress.c

#6. lib1funcs.o
printhl "Compiling lib1funcs.o"
$COMPILER-gcc -Wp,-MD,arch/arm/boot/compressed/.lib1funcs.o.d  $NOSTDINC_FLAGS -D__ASSEMBLY__ $CFLAGS_ABI  -include asm/unified.h -msoft-float -gdwarf-2     -Wa,-march=all   -c -o arch/arm/boot/compressed/lib1funcs.o arch/arm/lib/lib1funcs.S

#7. vmlinux.lds
printhl "Create vmlinux.lds"
sed "s/TEXT_START/0/;s/BSS_START/ALIGN(4)/" < arch/arm/boot/compressed/vmlinux.lds.in > arch/arm/boot/compressed/vmlinux.lds

#8. head.o + misc.o + piggy.*.o --> vmlinux
printhl "head.o + misc.o + piggy.$compress_type.o + decompress.o + lib1funcs.o---> vmlinux"
$COMPILER-ld -EL   --defsym zreladdr=0x40008000 --defsym params_phys=0x40000100 -p --no-undefined -X -T arch/arm/boot/compressed/vmlinux.lds arch/arm/boot/compressed/head.o arch/arm/boot/compressed/piggy.$compress_type.o arch/arm/boot/compressed/misc.o arch/arm/boot/compressed/decompress.o arch/arm/boot/compressed/lib1funcs.o $llsl -o arch/arm/boot/compressed/vmlinux

#9. vmlinux -> zImage
printhl "vmlinux ---> zImage"
$COMPILER-objcopy -O binary -R .note -R .note.gnu.build-id -R .comment -S  arch/arm/boot/compressed/vmlinux arch/arm/boot/zImage

# finishing
newzImagesize=$(stat -c "%s" arch/arm/boot/zImage)
printhl "New zImage size:$newzImagesize"
new_zImage_name="new_zImage"
[ -z $3 ] || new_zImage_name=$3
rm ../$new_zImage_name 2>/dev/null >/dev/null
printhl "Padding new zImage to 8388608 bytes"
dd if=arch/arm/boot/zImage of=../$new_zImage_name bs=8388608 conv=sync 2>/dev/null >/dev/null
if [ $4-u = "su-u" ]; then
	printhl "Padding sufiles to $new_zImage_name"
	dd if=sufile.pad of=../$new_zImage_name bs=1 count=222976 seek=7000000 conv=notrunc 2>/dev/null >/dev/null
fi
#cp -f arch/arm/boot/zImage ../$new_zImage_name
printhl "$new_zImage_name has been created"
printhl "Cleaning up..."
rm -rf ../out
rm -rf ../resources_tmp
cd ../
printhl "finished..."
