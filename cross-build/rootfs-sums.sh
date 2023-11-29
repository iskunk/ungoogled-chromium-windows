#!/bin/sh
# rootfs-sums.sh
#
# A script to facilitate generating/verifying MD5 hash sums for all files
# in a [container's] root filesystem
#

set -e

mnt=/tmp/rootfs

do_bind_mount()
{
	mkdir $mnt
	mount --bind --make-private / $mnt
	cd $mnt
}

if [ $(id -u) -ne 0 ]
then
	echo "$0: error: must run as root"
	exit 1
fi

case "$1" in
	generate)
	do_bind_mount
	find . -type f -printf '%P\n' \
	| LC_COLLATE=C sort \
	| xargs -d '\n' md5sum
	cd; umount $mnt
	;;

	verify)
	do_bind_mount
	md5sum --quiet --check && echo OK	# read input from stdin
	cd; umount $mnt
	;;

	*)
	echo 'usage:'
	echo "  $0 generate > MD5SUMS"
	echo "  $0 verify < MD5SUMS"
	;;
esac

# end rootfs-sums.sh
