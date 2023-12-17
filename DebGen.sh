#!/bin/sh
################################################################################
#
# Copyright (C) 2019-2020 Corey Moyer <cronmod.dev@gmail.com>
# This file is part of DebGen - <https://gitlab.com/CoreMC/DebGen/>.
#
# DebGen is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# DebGen is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with DebGen. If not, see <https://www.gnu.org/licenses/>.
#
################################################################################

# Set DebGen Version
VER="v1.0.1"

# Bash/Dash Shell Compatibility
[ -z "$BASH_VERSION" ] && ECHO="echo" || ECHO="echo -e"

# Parse Arguments
for i in $@; do
	case $i in
		-a|--arch) ARCH="$2"; shift; shift;;
		-d|--dist) DIST="$2"; shift; shift;;
		-r|--rel) REL="$2"; shift; shift;;
		-m|--mirror) MIRROR="$2"; shift; shift;;
		-o|--out) ROOTFS="$2"; shift; shift;;
		-f|--force) FORCE="true"; shift;;
		-p|--pkgs) PKGS="$2"; shift; shift;;
		-h|--help) HELP="true"; shift;;
	esac
done

# Set Defaults
[ -z "$ARCH" ] && ARCH="amd64"
[ -z "$DIST" ] && DIST="debian"
[ -z "$REL" ] && REL="stable" && [ "$DIST" = "ubuntu" ] && REL="bionic"
[ -z "$ROOTFS" ] && ROOTFS="$PWD/OUTPUT/$DIST-$REL-$ARCH-$(date +%Y%m%d)" || ROOTFS="$ROOTFS/$DIST-$REL-$ARCH-$(date +%Y%m%d)"
[ -z "$FORCE" ] && FORCE="false"
[ -z "$PKGS" ] && PKGS="$PWD/pkgs.list"

# Set Support Variables
SUPPORTED_ARCHS="amd64 arm64 armel armhf i386 mips mipsel powerpc powerpcspe ppc64el s390x"
SUPPORTED_DISTS="debian ubuntu"
DEBIAN_RELS="stretch buster bullseye bookworm trixie sid oldstable stable testing unstable"
UBUNTU_RELS="xenial bionic"
[ "$DIST" = "ubuntu" ] && SUPPORTED_RELS="$UBUNTU_RELS" || SUPPORTED_RELS="$DEBIAN_RELS"

help_txt()
{
	# Help Text
	$ECHO "DebGen $VER <https://gitlab.com/CoreMC/DebGen/>\n"
	$ECHO "Copyright (C) 2019-2020 Corey Moyer <cronmod.dev@gmail.com>"
	$ECHO "Licensed under the GNU General Public License v3.0 <https://www.gnu.org/licenses/gpl-3.0.txt>\n"
	$ECHO "DebGen is used to generate Debian/Ubuntu root filesystems.\n"
	$ECHO "DebGen by default generates a \"Debian Stable x86_64\" root filesystem.\n"
	$ECHO "Optional Arguments:"
	$ECHO "\t-a,--arch\tSets architecture."
	$ECHO "\t\t\t\t($SUPPORTED_ARCHS)"
	$ECHO "\t-d,--dist\tSets distribution."
	$ECHO "\t\t\t\t($SUPPORTED_DISTS)"
	$ECHO "\t-r,--rel\tSets release."
	$ECHO "\t\t\t\tDebian: ($DEBIAN_RELS)"
	$ECHO "\t\t\t\tUbuntu: ($UBUNTU_RELS)"
	$ECHO "\t-m,--mirror\tSets download mirror."
	$ECHO "\t-o,--out\tSets output directory."
	$ECHO "\t-f,--force\tAlways overwrite output directory."
	$ECHO "\t-p,--pkgs\tIncludes list of extra packages to install."
	$ECHO "\t-h,--help\tShows this help text.\n"
	$ECHO "Usage Examples:"
	$ECHO "\t$(basename $0)"
	$ECHO "\t$(basename $0) -h"
	$ECHO "\t$(basename $0) -a amd64 -d debian -r stable -m http://deb.debian.org/debian -o OUTPUT -f -p pkgs.list"
	$ECHO "\t$(basename $0) --help"
	$ECHO "\t$(basename $0) --arch amd64 --dist debian --rel stable --mirror http://deb.debian.org/debian --out OUTPUT --force --pkgs pkgs.list"
}

run_script()
{
	# Check For Root Permissions
	[ "$(id -u)" != "0" ] && $ECHO "!!! DebGen Must Be Run As Root !!!" && exit 1

	# Check Architecture
	HOST_ARCH="$(dpkg --print-architecture)"
	for i in $SUPPORTED_ARCHS; do
		[ "$ARCH" = "$i" ] && supported="1"
	done
	[ -z "$supported" ] && $ECHO "Unsupported Architecture: $ARCH\nSupported Architectures: $SUPPORTED_ARCHS" && exit 1 || unset -v supported
	[ "$HOST_ARCH" != "$ARCH" ] && FOREIGN="true" || FOREIGN="false"

	# Check Distribution
	for i in $SUPPORTED_DISTS; do
		[ "$DIST" = "$i" ] && supported="1"
	done
	[ -z "$supported" ] && $ECHO "Unsupported Distribution: $DIST\nSupported Distributions: $SUPPORTED_DISTS" && exit 1 || unset -v supported

	# Check Release
	for i in $SUPPORTED_RELS; do
		[ "$REL" = "$i" ] && supported="1"
	done
	[ -z "$supported" ] && $ECHO "Unsupported Release: $REL\nSupported Releases: $SUPPORTED_RELS" && exit 1 || unset -v supported

	# Check/Create Output Directory
	if [ -d "$ROOTFS" ]; then
		while true; do
			$FORCE && rm -rf $ROOTFS && break
			read -p "Output Directory \"$ROOTFS\" Already Exists, Do You Want To Overwrite It? (y/N): " yn
			case $yn in
				[Yy]) rm -rf $ROOTFS; break;;
				*) exit 1;;
			esac
		done
	fi
	mkdir -p $ROOTFS
	chown $(logname):$(logname) $(dirname $ROOTFS)

	# Foreign Target
	if $FOREIGN; then
		# Set QEMU
		QEMU="qemu-$ARCH-static"
		[ "$ARCH" = "amd64" ] && QEMU="qemu-x86_64-static"
		[ "$ARCH" = "arm64" ] && QEMU="qemu-aarch64-static"
		[ "$ARCH" = "armel" ] || [ "$ARCH" = "armhf" ] && QEMU="qemu-arm-static"
		[ "$ARCH" = "powerpc" ] || [ "$ARCH" = "powerpcspe" ] && QEMU="qemu-ppc-static"
		[ "$ARCH" = "ppc64el" ] && QEMU="qemu-ppc64le-static"
		QEMU_BIN="$(which $QEMU)"

		# Generate Root Filesystem
		debootstrap --foreign --arch $ARCH $REL $ROOTFS $MIRROR
		cp $QEMU_BIN $ROOTFS/usr/bin/
		chroot $ROOTFS /debootstrap/debootstrap --second-stage
	else # Native Target
		# Generate Root Filesystem
		debootstrap --arch $ARCH $REL $ROOTFS $MIRROR
	fi

	# Prepare For Chroot
	LC_ALL="C" LANGUAGE="C" LANG="C"
	mount --bind /dev $ROOTFS/dev
	mount --bind /proc $ROOTFS/proc
	mount --bind /sys $ROOTFS/sys

	# Set Hostname
	[ "$DIST" = "ubuntu" ] && HOSTNAME="Ubuntu" || HOSTNAME="Debian"
	$ECHO "$HOSTNAME" > $ROOTFS/etc/hostname

	# Set DNS Servers
	$ECHO "nameserver 8.8.8.8\nnameserver 8.8.4.4" > $ROOTFS/etc/resolv.conf

	# Set Root Password
	chroot $ROOTFS echo -e "letmein\nletmein" | passwd root

	# Install Extra Packages
	chroot $ROOTFS apt update
	chroot $ROOTFS apt install -y openssh-server
	[ -f $PKGS ] && chroot $ROOTFS apt install -y $(cat $PKGS | xargs)

	# Configure OpenSSH Server
	sed -i -e '/#PermitRootLogin/c\PermitRootLogin yes' $ROOTFS/etc/ssh/sshd_config

	# Clean-up Root Filesystem
	umount $ROOTFS/dev $ROOTFS/proc $ROOTFS/sys
	$FOREIGN && rm $ROOTFS/usr/bin/$QEMU

	# Archive Root Filesystem
	tar -czf $(dirname $ROOTFS)/$(basename $ROOTFS).tar.gz -C $ROOTFS .
	chown $(logname):$(logname) $(dirname $ROOTFS)/$(basename $ROOTFS).tar.gz
	$ECHO "\n\nCreated \"$(dirname $ROOTFS)/$(basename $ROOTFS).tar.gz\""
}

# Run DebGen
[ -z "$HELP" ] && run_script || help_txt
