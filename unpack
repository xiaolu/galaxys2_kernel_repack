#!/bin/bash
# This is an update version of the script found at 
# http://forum.xda-developers.com/wiki/index.php?title=Extract_initramfs_from_zImage
#
# The problem with that script is that the gzip magic number occasionally occur 
# naturally, meaning that some non-compressed files get uncompressed.

#GET CURRENT DIR
CURRENT_DIR=`pwd`
TEMP_DIR=$CURRENT_DIR/unpack_kernel_tmp
KERNEL_FILE=kernel
KERNEL_GZIP_FILE=kernel.gz
KERNEL_LZMA_FILE=kernel.lzma
KERNEL_XZ_FILE=kernel.xz
KERNEL_LZO_FILE=kernel.lzo
INITRAMFS_FILE=initramfs.cpio
INITRAMFS_DIR=initramfs_root

# DO NOT MODIFY BELOW THIS LINE
[ -z $1 ] && exit 1 || zImage=$1
[ ! -e $1 ] && exit 1
[ -z $2 ] || INITRAMFS_DIR=$2
[ -d $TEMP_DIR ] || `mkdir $TEMP_DIR`

C_H1="\033[1;36m" # highlight text 1
C_ERR="\033[1;31m"
C_CLEAR="\033[1;0m"

printhl() {
	printf "${C_H1}[I] ${1}${C_CLEAR} \n"
}

printerr() {
	printf "${C_ERR}[E] ${1}${C_CLEAR} \n"
}

function pre_clean()
{
    [ -e $INITRAMFS_FILE ] && rm -f $INITRAMFS_FILE
    [ -e $INITRAMFS_DIR ] && rm -rf $INITRAMFS_DIR
}
function unpack_kernel()
{
    # test Compressed format
    pos1=`grep -P -a -b -m 1 --only-matching '\x1F\x8B\x08' $zImage | \
	cut -f 1 -d : | awk '(int($0)<50000){print $0;exit}'`
    pos2=`grep -P -a -b -m 1 --only-matching '\x{5D}\x{00}\x..\x{FF}\x{FF}\x{FF}\x{FF}\x{FF}\x{FF}' \
	$zImage | cut -f 1 -d : | awk '(int($0)<50000){print $0;exit}'`
    pos3=`grep -P -a -b -m 1 --only-matching '\xFD\x37\x7A\x58\x5A' $zImage | \
	cut -f 1 -d : | tail -1 | awk '(int($0)<50000){print $0;exit}'`
    pos4=`grep -P -a -b --only-matching '\211\114\132' $zImage | head -2 | \
	tail -1 | cut -f 1 -d : | awk '(int($0)<50000){print $0;exit}'`

    zImagesize=$(stat -c "%s" $zImage)
    [ -z $pos1 ] && pos1=$zImagesize
    [ -z $pos2 ] && pos2=$zImagesize
    [ -z $pos3 ] && pos3=$zImagesize
    [ -z $pos4 ] && pos4=$zImagesize
    minpos=`echo -e "$pos1\n$pos2\n$pos3\n$pos4" | sort -n | head -1`
    if [ $minpos -eq $zImagesize ]; then
	printerr "not found kernel from $zImage!"
	exit 1
    elif [ $minpos -eq $pos1 ]; then
        ungzip_kernel
    elif [ $minpos -eq $pos2 ]; then
	unlzma_kernel
    elif [ $minpos -eq $pos3 ]; then
	unxz_kernel
    elif [ $minpos -eq $pos4 ]; then
	unlzo_kernel
    fi
}

function ungzip_kernel()
{
    printhl "Extracting gzip'd kernel image from file: $zImage (start = $pos1)"
    dd if=$zImage of=$TEMP_DIR/$KERNEL_GZIP_FILE bs=$pos1 skip=1 2>/dev/null >/dev/null
    gunzip -qf $TEMP_DIR/$KERNEL_GZIP_FILE
}

function unlzma_kernel()
{
    printhl "Extracting lzma'd kernel image from file: $zImage (start = $pos2)"
    dd if=$zImage of=$TEMP_DIR/$KERNEL_LZMA_FILE bs=$pos2 skip=1 2>/dev/null >/dev/null
    unlzma -qf $TEMP_DIR/$KERNEL_LZMA_FILE
}

function unxz_kernel()
{
    printhl "Extracting xz'd kernel image from file: $zImage (start = $pos3)"
    dd status=noxfer if=$zImage bs=$pos3 skip=1 2>/dev/null | unxz -qf > $TEMP_DIR/$KERNEL_FILE 2>/dev/null  
}

function unlzo_kernel()
{
    printhl "Extracting lzo'd kernel image from file: $zImage (start = $pos4)"
    dd if=$zImage of=$TEMP_DIR/$KERNEL_LZO_FILE bs=$pos4 skip=1 2>/dev/null >/dev/null
    lzop -d $TEMP_DIR/$KERNEL_LZO_FILE 2>/dev/null >/dev/null
}

function search_cpio()
{
    for x in none gzip bzip lzma lzo; do
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
            
            lzo)
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
        search=`grep -P -a -b -m 1 -o $csig $TEMP_DIR/$KERNEL_FILE | cut -f 1 -d : | head -1`
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
    printhl "CPIO compression type detected = $compression_name | offset = $cpio_compressed_start"
}

function extract_cpio()
{
    if [ ! $compression_name = "none" ]; then
        printhl "Extracting $compression_name'd compressed CPIO image from kernel image (offset = $cpio_compressed_start)"
        dd if=$TEMP_DIR/$KERNEL_FILE of=$TEMP_DIR/$INITRAMFS_FILE$file_ext bs=$cpio_compressed_start skip=1 2>/dev/null >/dev/null
        $uncompress_cmd $TEMP_DIR/$INITRAMFS_FILE$file_ext 2>/dev/null >/dev/null

    else
        printhl "Extracting non-compressed CPIO image from kernel image (offset = $cpio_compressed_start)"
        dd if=$TEMP_DIR/$KERNEL_FILE of=$TEMP_DIR/${INITRAMFS_FILE}${file_ext} bs=$cpio_compressed_start skip=1 2>/dev/null >/dev/null
    fi
}

function expand_cpio_archive()
{
    printhl "Expanding CPIO archive: $INITRAMFS_FILE to $INITRAMFS_DIR."

    if [ -e $TEMP_DIR/$INITRAMFS_FILE ]; then
        mkdir $INITRAMFS_DIR
        cd $INITRAMFS_DIR
        cpio --quiet -i --make-directories --preserve-modification-time --no-absolute-filenames -F $TEMP_DIR/$INITRAMFS_FILE 2>/dev/null
    fi
}

function clean_up()
{
    rm -Rf $TEMP_DIR
}

pre_clean
unpack_kernel
search_cpio
extract_cpio
expand_cpio_archive
[ -z $3 ] && clean_up
