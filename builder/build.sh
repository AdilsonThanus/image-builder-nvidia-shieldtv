#!/bin/bash -e
set -x
# This script should be run only inside of a Docker container
if [ ! -f /.dockerinit ]; then
  echo "ERROR: script works only in a Docker container!"
  exit 1
fi

### setting up some important variables to control the build process

# device specific settings
IMAGE_NAME="sd-card-nvidia-shieldtv.img"
IMAGE_ROOTFS_PATH="/image-rootfs.tar.gz"
QEMU_ARCH="aarch64"

# where to store our created sd-image file
BUILD_RESULT_PATH="/workspace"
BUILD_PATH="/build"

# where to store our base file system
ROOTFS_TAR="rootfs-arm64.tar.gz"
ROOTFS_TAR_PATH="$BUILD_RESULT_PATH/$ROOTFS_TAR"
ROOTFS_TAR_VERSION="v0.5"

# size of root and boot partion
ROOT_PARTITION_SIZE="800M"

# create build directory for assembling our image filesystem
rm -rf $BUILD_PATH
mkdir -p $BUILD_PATH

# download our base root file system
if [ ! -f $ROOTFS_TAR_PATH ]; then
  wget -q -O $ROOTFS_TAR_PATH https://github.com/hypriot/os-rootfs/releases/download/$ROOTFS_TAR_VERSION/$ROOTFS_TAR
fi

# extract root file system
tar -xzf $ROOTFS_TAR_PATH -C $BUILD_PATH

# register qemu-arm with binfmt
update-binfmts --enable qemu-$QEMU_ARCH

# set up mount points for pseudo filesystems
mkdir -p $BUILD_PATH/{proc,sys,dev/pts}

mount -o bind /dev $BUILD_PATH/dev
mount -o bind /dev/pts $BUILD_PATH/dev/pts
mount -t proc none $BUILD_PATH/proc
mount -t sysfs none $BUILD_PATH/sys

#---modify image---
# modify/add image files directly
cp /builder/resize-disk-nvidia-shieldtv.sh $BUILD_PATH/root/

# modify image in chroot environment
chroot $BUILD_PATH /bin/bash </builder/chroot-script.sh
#---modify image---

umount -l $BUILD_PATH/sys || true
umount -l $BUILD_PATH/proc || true
umount -l $BUILD_PATH/dev/pts || true
umount -l $BUILD_PATH/dev || true

# package image rootfs
tar -czf $IMAGE_ROOTFS_PATH -C $BUILD_PATH .

# create the image and add a single ext4 filesystem
# --- important settings for NVIDIA ShieldTV SD card
# - initialise the partion with MBR
# - use start sector 2048, this reserves 1MByte of disk space
# - don't set the partition to "bootable"
# - format the disk with ext4
# for debugging use 'set-verbose true'
#set-verbose true
guestfish <<EOF
# create new image disk
sparse /$IMAGE_NAME $ROOT_PARTITION_SIZE
run
part-init /dev/sda mbr
part-add /dev/sda primary 2048 -1
part-set-bootable /dev/sda 1 false
mkfs ext4 /dev/sda1

# import base rootfs
mount /dev/sda1 /
tar-in $IMAGE_ROOTFS_PATH / compress:gzip
EOF

# log image partioning
fdisk -l /$IMAGE_NAME

# ensure that the travis-ci user can access the sd-card image file
umask 0000

# compress image
pigz --zip -c $IMAGE_NAME > $BUILD_RESULT_PATH/$IMAGE_NAME.zip

# test sd-image that we have built
rspec --format documentation --color /builder/test
