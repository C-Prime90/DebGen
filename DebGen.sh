#!/bin/sh
################################################################################
#
# Copyright (C) 2019-2020 Corey Moyer <cronmod.dev@gmail.com>
# This file is part of DebGen - <https://gitlab.com/cronmod-dev/DebGen/>.
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
VER="v0.0.1"

# Parse Arguments
for i in $@; do
	case $i in
		-a|--arch) ARCH="$2"; shift; shift;;
		-d|--dist) DIST="$2"; shift; shift;;
		-r|--rel) REL="$2"; shift; shift;;
		-o|--out) ROOTFS="$2"; shift; shift;;
		-p|--pkgs) PKGS="$2"; shift; shift;;
		-h|--help) HELP="true"; shift;;
	esac
done

# Set Defaults
[ -z "$ARCH" ] && ARCH="amd64"
[ -z "$DIST" ] && DIST="debian"
[ -z "$REL" ] && REL="stable" && [ "$DIST" = "ubuntu" ] && REL="bionic"
[ -z "$ROOTFS" ] && ROOTFS="$PWD/OUTPUT/$DIST-$REL-$ARCH-$(date +%Y%m%d)"
[ -z "$PKGS" ] && PKGS="$PWD/pkgs.list"

# Set Support Variables
SUPPORTED_ARCHS="amd64 arm64 armel armhf i386 mips mipsel powerpc powerpcspe ppc64el s390x"
SUPPORTED_DISTS="debian ubuntu"
DEBIAN_RELS="stretch buster bullseye sid oldstable stable testing unstable"
UBUNTU_RELS="xenial bionic"
[ "$DIST" = "ubuntu" ] && SUPPORTED_RELS="$UBUNTU_RELS" || SUPPORTED_RELS="$DEBIAN_RELS"

help_txt()
{
	# Help Text
	echo "DebGen $VER <https://gitlab.com/cronmod-dev/DebGen/>\n"
	echo "Copyright (C) 2019-2020 Corey Moyer <cronmod.dev@gmail.com>"
	echo "Licensed under the GNU General Public License v3.0 <https://www.gnu.org/licenses/gpl-3.0.txt>\n"
	echo "DebGen is used to generate Debian/Ubuntu root filesystems.\n"
	echo "DebGen by default generates a \"Debian Stable x86_64\" root filesystem.\n"
	echo "Optional Arguments:"
	echo "    -a,--arch        Sets architecture."
	echo "                         ($SUPPORTED_ARCHS)"
	echo "    -d,--dist        Sets distribution."
	echo "                         ($SUPPORTED_DISTS)"
	echo "    -r,--rel         Sets release."
	echo "                         Debian: ($DEBIAN_RELS)"
	echo "                         Ubuntu: ($UBUNTU_RELS)"
	echo "    -o,--out         Sets output directory."
	echo "    -p,--pkgs        Includes list of extra packages to install"
	echo "    -h,--help        Shows this help text.\n"
	echo "Usage Examples:"
	echo "    $(basename $0)"
	echo "    $(basename $0) -h"
	echo "    $(basename $0) -a amd64 -d debian -r stable -o OUTPUT"
	echo "    $(basename $0) --help"
	echo "    $(basename $0) --arch amd64 --dist debian --rel stable --out OUTPUT"
}

run_script()
{
	# Check For Root Permissions
	[ "$(id -u)" != "0" ] && echo "!!! DebGen Must Be Run As Root !!!" && exit 1

	# Check Architecture
	HOST_ARCH="$(dpkg --print-architecture)"
	for i in $SUPPORTED_ARCHS; do
		[ "$ARCH" = "$i" ] && supported="1"
	done
	[ -z "$supported" ] && echo "Unsupported Architecture: $ARCH\nSupported Architectures: $SUPPORTED_ARCHS" && exit 1 || unset -v supported
	[ "$HOST_ARCH" != "$ARCH" ] && FOREIGN="true" || FOREIGN="false"

	# Check Distribution
	for i in $SUPPORTED_DISTS; do
		[ "$DIST" = "$i" ] && supported="1"
	done
	[ -z "$supported" ] && echo "Unsupported Distribution: $DIST\nSupported Distributions: $SUPPORTED_DISTS" && exit 1 || unset -v supported

	# Check Release
	for i in $SUPPORTED_RELS; do
		[ "$REL" = "$i" ] && supported="1"
	done
	[ -z "$supported" ] && echo "Unsupported Release: $REL\nSupported Releases: $SUPPORTED_RELS" && exit 1 || unset -v supported

	# Check/Create Output Directory
	if [ -d "$ROOTFS" ]; then
		while true; do
			read -p "Output Directory \"$ROOTFS\" Already Exists, Do You Want To Overwrite It? (y/N): " yn
			case $yn in
				[Yy]) rm -rf $ROOTFS; break;;
				*) exit 1;;
			esac
		done
	fi
	mkdir -p $ROOTFS

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
		debootstrap --foreign --arch $ARCH $REL $ROOTFS
		cp $QEMU_BIN $ROOTFS/usr/bin/
		chroot $ROOTFS /debootstrap/debootstrap --second-stage
	else # Native Target
		# Generate Root Filesystem
		debootstrap --arch $ARCH $REL $ROOTFS
	fi

	# Install Extra Packages
	[ -f $PKGS ] && chroot $ROOTFS /usr/bin/apt update && chroot $ROOTFS /usr/bin/apt install -y $(cat $PKGS | xargs)
}

# Run DebGen
[ -z "$HELP" ] && run_script || help_txt
