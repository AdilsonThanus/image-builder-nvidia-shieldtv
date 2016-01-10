#!/bin/bash -e
set -x

# install parted, if its not there
if [ -z $(which parted) ]; then
  apt-get update
  apt-get install -y parted
fi

# show disk usage before changes
df -h

# get partition number
PART_NUM=$(parted /dev/mmcblk1 -ms unit s p | tail -n 1 | cut -f 1 -d:)
echo $PART_NUM

# get partition start sector
PART_START=$(parted /dev/mmcblk1 -ms unit s p | grep ^$PART_NUM | cut -f 2 -d:)
echo $PART_START

# remove trailing "s"
PART_START=${PART_START::-1}
echo $PART_START

# change partition table for resizing to maximum
set +e
fdisk /dev/mmcblk1 <<EOF
p
d
p
n
p
$PART_NUM
$PART_START

p
w
EOF
set -e

# apply online resizing
partprobe
/sbin/resize2fs /dev/mmcblk1p1

# show disk usage after changes
df -h
