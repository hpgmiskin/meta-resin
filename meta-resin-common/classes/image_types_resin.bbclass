inherit image_types

# Images inheriting this class MUST define:
# RESIN_IMAGE_BOOTLOADER 	- bootloader
# RESIN_BOOT_PARTITION_FILES 	- this is a list of files relative to DEPLOY_DIR_IMAGE that will be included in the vfat partition
#				- should be a list of elements of the following format "FilenameRelativeToDeployDir:FilenameOnTheTarget"
#				- if FilenameOnTheTarget is omitted the same filename will be used
#
# Optional:
# RESIN_SDIMG_ROOTFS_TYPE 	- rootfs image to be used [default: ext3]
# BOOT_SPACE			- size of boot partition in KiB [default: 20480]
# RESIN_SDIMG_COMPRESSION	- define this to compress the final SD image with gzip, xz or bzip2 [default: empty]

#
# Create an image that can by written onto a SD card using dd.
#
# The disk layout used is:
#
#    0                      -> IMAGE_ROOTFS_ALIGNMENT         - reserved for other data
#    IMAGE_ROOTFS_ALIGNMENT -> BOOT_SPACE                     - boot partition (usually kernel and bootloaders)
#    BOOT_SPACE             -> ROOTFS_SIZE                    - rootfs
#    ROOTFS_SIZE            -> UPDATE_SIZE                    - update partition (this is a duplicate of rootfs so UPDATE_SIZE == ROOTFS_SIZE)
#    UPDATE_SIZE            -> SDIMG_SIZE                     - extended partition
#
# The exended partition layout is:
#    0                      -> IMAGE_ROOTFS_ALIGNMENT         - reserved for other data
#    IMAGE_ROOTFS_ALIGNMENT -> CONFIG_SIZE                    - the config.json gets injected in here
#    CONFIG_SIZE            -> IMAGE_ROOTFS_ALIGNMENT         - reserved for other data
#    IMAGE_ROOTFS_ALIGNMENT -> SDIMG_SIZE                     - btrfs partition

#
#            4MiB              20MiB        ROOTFS_SIZE       ROOTFS_SIZE              4MiB                4MiB                 4MiB                4MiB
# <-----------------------> <----------> <----------------> <--------------->  <----------------------> <------------> <-----------------------> <------------>
#  ------------------------ ------------ ------------------ -----------------  ================================================================================
# | IMAGE_ROOTFS_ALIGNMENT | BOOT_SPACE | ROOTFS_SIZE      |  ROOTFS_SIZE    || IMAGE_ROOTFS_ALIGNMENT || CONFIG_SIZE || IMAGE_ROOTFS_ALIGNMENT || BTRFS_SIZE  ||
#  ------------------------ ------------ ------------------ -----------------  ================================================================================
# ^                        ^            ^                  ^                 ^^                        ^^             ^^                        ^^             ^^ 
# |                        |            |                  |                 ||                        ||             ||                        ||             ||
# 0                      4MiB         4MiB +             4MiB +            4MiB +                      4MiB +         4MiB +                    4MiB +         4MiB +
#                                     20Mib              20MiB +           20MiB +                     20MiB +        20MiB +                   20MiB +        20MiB +
#                                                        ROOTFS_SIZE       ROOTFS_SIZE +               ROOTFS_SIZE +  ROOTFS_SIZE +             ROOTFS_SIZE +  ROOTFS_SIZE +
#                                                                          ROOTFS_SIZE                 ROOTFS_SIZE +  ROOTFS_SIZE +             ROOTFS_SIZE +  ROOTFS_SIZE +
#                                                                                                      4MiB           4MiB +                    4MiB +         4MiB +
#                                                                                                                     4MiB                      4MiB +         4MiB +
#                                                                                                                                               4MiB           4MiB +
#                                                                                                                                                              4MiB

# This image depends on the rootfs image
IMAGE_TYPEDEP_resin-sdcard = "${RESIN_SDIMG_ROOTFS_TYPE}"

# Boot partition volume id
BOOTDD_VOLUME_ID ?= "boot-${MACHINE}"

# Boot partition size [in KiB] (will be rounded up to IMAGE_ROOTFS_ALIGNMENT)
BOOT_SPACE ?= "20480"

# Set alignment to 4MB [in KiB]
IMAGE_ROOTFS_ALIGNMENT = "4096"

# Use an uncompressed ext3 by default as rootfs
RESIN_SDIMG_ROOTFS_TYPE ?= "ext3"
SDIMG_ROOTFS = "${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.${RESIN_SDIMG_ROOTFS_TYPE}"

IMAGE_DEPENDS_resin-sdcard = " \
			e2fsprogs-native \
			parted-native \
			mtools-native \
			dosfstools-native \
			virtual/kernel \
			${RESIN_IMAGE_BOOTLOADER} \
			resin-supervisor-disk \
			"

# SD card image name
SDIMG = "${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.resin-sdcard"

# Compression method to apply to SDIMG after it has been created. Supported
# compression formats are "gzip", "bzip2" or "xz". The original .resin-sdcard file
# is kept and a new compressed file is created if one of these compression
# formats is chosen. If RESIN_SDIMG_COMPRESSION is set to any other value it is
# silently ignored.
RESIN_SDIMG_COMPRESSION ?= ""

IMAGEDATESTAMP = "${@time.strftime('%Y.%m.%d',time.gmtime())}"

# BTRFS image
BTRFS_IMAGE = "${DEPLOY_DIR}/images/${MACHINE}/data_disk.img"

# Config size
CONFIG_SIZE = "4096"

IMAGE_CMD_resin-sdcard () {
	# Align partitions
	BOOT_SPACE_ALIGNED=$(expr ${BOOT_SPACE} \+ ${IMAGE_ROOTFS_ALIGNMENT} - 1)
	BOOT_SPACE_ALIGNED=$(expr ${BOOT_SPACE_ALIGNED} \- ${BOOT_SPACE_ALIGNED} \% ${IMAGE_ROOTFS_ALIGNMENT})
	ROOTFS_SIZE=`du -bks ${SDIMG_ROOTFS} | awk '{print $1}'`
	BTRFS_SPACE=`du -bks ${BTRFS_IMAGE} | awk '{print $1}'`
	# Round up RootFS size to the alignment size as well
	ROOTFS_SIZE_ALIGNED=$(expr ${ROOTFS_SIZE} \+ ${IMAGE_ROOTFS_ALIGNMENT} \- 1)
	ROOTFS_SIZE_ALIGNED=$(expr ${ROOTFS_SIZE_ALIGNED} \- ${ROOTFS_SIZE_ALIGNED} \% ${IMAGE_ROOTFS_ALIGNMENT})
	# UPDATE alignment
	UPDATE_SIZE_ALIGNED=$(expr ${ROOTFS_SIZE} \+ ${IMAGE_ROOTFS_ALIGNMENT} \- 1)
	UPDATE_SIZE_ALIGNED=$(expr ${UPDATE_SIZE_ALIGNED} \- ${UPDATE_SIZE_ALIGNED} \% ${IMAGE_ROOTFS_ALIGNMENT})
	# BTRFS alignment
	BTRFS_SIZE_ALIGNED=$(expr ${BTRFS_SPACE} \+ ${IMAGE_ROOTFS_ALIGNMENT} \- 1)
	BTRFS_SIZE_ALIGNED=$(expr ${BTRFS_SIZE_ALIGNED} \- ${BTRFS_SIZE_ALIGNED} \% ${IMAGE_ROOTFS_ALIGNMENT})
	# Config alignment
	CONFIG_SIZE_ALIGNED=$(expr ${CONFIG_SIZE} \+ ${IMAGE_ROOTFS_ALIGNMENT} \- 1)
	CONFIG_SIZE_ALIGNED=$(expr ${CONFIG_SIZE_ALIGNED} \- ${CONFIG_SIZE_ALIGNED} \% ${IMAGE_ROOTFS_ALIGNMENT})
	SDIMG_SIZE=$(expr 3 \* ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_SPACE_ALIGNED} \+ ${ROOTFS_SIZE_ALIGNED} \+ ${UPDATE_SIZE_ALIGNED} \+ ${BTRFS_SIZE_ALIGNED} \+ ${CONFIG_SIZE_ALIGNED})

	echo "Creating filesystem with Boot partition ${BOOT_SPACE_ALIGNED} KiB, RootFS ${ROOTFS_SIZE_ALIGNED} KiB, UpdateFS ${UPDATE_SIZE_ALIGNED} KiB, Config ${CONFIG_SIZE_ALIGNED} KiB and BTRFS ${BTRFS_SIZE_ALIGNED} KiB"
	echo "Total SD card size ${SDIMG_SIZE} KiB"

	# Initialize sdcard image file
	dd if=/dev/zero of=${SDIMG} bs=1024 count=0 seek=${SDIMG_SIZE}

	# Create partition table
	parted -s ${SDIMG} mklabel msdos

	# Define START and END; so the parted commands don't get too crowded
	START=${IMAGE_ROOTFS_ALIGNMENT}
	END=$(expr ${START} \+ ${BOOT_SPACE_ALIGNED})
	# Create boot partition and mark it as bootable
	parted -s ${SDIMG} unit KiB mkpart primary fat32 ${START} ${END}
	parted -s ${SDIMG} set 1 boot on

	# Create rootfs partition
	START=${END}
	END=$(expr ${START} \+ ${ROOTFS_SIZE_ALIGNED})
	parted -s ${SDIMG} unit KiB mkpart primary ext4 ${START} ${END}

	# Create update partition
	START=${END}
	END=$(expr ${START} \+ ${UPDATE_SIZE_ALIGNED})
	parted -s ${SDIMG} unit KiB mkpart primary ext4 ${START} ${END}

	# Create extended partition 
	START=${END}
	parted -s ${SDIMG} -- unit KiB mkpart extended ${START} -1s

	# After creating the extended partition the next logical parition needs a IMAGE_ROOTFS_ALIGNMENT in front of it
	START=$(expr ${START} \+ ${IMAGE_ROOTFS_ALIGNMENT})
	END=$(expr ${START} \+ ${CONFIG_SIZE_ALIGNED})
	parted -s ${SDIMG} unit KiB mkpart logical ext2 ${START} ${END}

	# Create BTRFS partition
	START=$(expr ${END} \+ ${IMAGE_ROOTFS_ALIGNMENT})
	parted -s ${SDIMG} -- unit KiB mkpart logical ext2 ${START} -1s

	# Create a vfat filesystem with boot files
	BOOT_BLOCKS=$(LC_ALL=C parted -s ${SDIMG} unit b print | awk '/ 1 / { print substr($4, 1, length($4 -1)) / 512 /2 }')
	mkfs.vfat -n "${BOOTDD_VOLUME_ID}" -S 512 -C ${WORKDIR}/boot.img $BOOT_BLOCKS
	for RESIN_BOOT_PARTITION_FILE in ${RESIN_BOOT_PARTITION_FILES}; do
		src=`echo ${RESIN_BOOT_PARTITION_FILE} | awk -F: '{print $1}'`
		dst=`echo ${RESIN_BOOT_PARTITION_FILE} | awk -F: '{print $2}'`
		if [ -z "${dst}" ]; then
			dst=`basename ${src}`
		fi
		mcopy -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${src} ::/${dst}
	done

	# Add stamp file to vfat partition
	echo "${IMAGE_NAME}-${IMAGEDATESTAMP}" > ${WORKDIR}/image-version-info
	mcopy -i ${WORKDIR}/boot.img -v ${WORKDIR}//image-version-info ::

	# Burn Boot Partition
	dd if=${WORKDIR}/boot.img of=${SDIMG} conv=notrunc seek=1 bs=$(expr ${IMAGE_ROOTFS_ALIGNMENT} \* 1024) && sync && sync
	# Burn Rootfs Partition
	dd if=${SDIMG_ROOTFS} of=${SDIMG} conv=notrunc seek=1 bs=$(expr 1024 \* $(expr ${BOOT_SPACE_ALIGNED} \+ ${IMAGE_ROOTFS_ALIGNMENT})) && sync && sync
	# Burn BTRFS Partition
	dd if=${BTRFS_IMAGE} of=${SDIMG} conv=notrunc seek=1 bs=$(expr 1024 \* $(expr ${BOOT_SPACE_ALIGNED} \+ ${IMAGE_ROOTFS_ALIGNMENT} \+ ${ROOTFS_SIZE_ALIGNED} \+ ${UPDATE_SIZE_ALIGNED} \+ ${IMAGE_ROOTFS_ALIGNMENT} \+ ${CONFIG_SIZE_ALIGNED} \+ ${IMAGE_ROOTFS_ALIGNMENT})) && sync && sync
}

resin_sdcard_compress () {
	# Optionally apply compression
	case "${RESIN_SDIMG_COMPRESSION}" in
	"gzip")
		gzip -k9 "${SDIMG}"
		;;
	"bzip2")
		bzip2 -k9 "${SDIMG}"
		;;
	"xz")
		xz -k "${SDIMG}"
		;;
	esac
}

IMAGE_POSTPROCESS_COMMAND += "resin_sdcard_compress;"