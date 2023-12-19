<pre>
DebGen v1.0.1 [https://gitlab.com/CoreMC/DebGen/]

Copyright (C) 2019-2020 Corey Moyer [cronmod.dev@gmail.com]
Licensed under the GNU General Public License v3.0 [https://www.gnu.org/licenses/gpl-3.0.txt]

DebGen is used to generate Debian/Ubuntu root filesystems.

DebGen by default generates a "Debian Stable x86_64" root filesystem.

Optional Arguments:
	-a,--arch	Sets architecture.
				(amd64 arm64 armel armhf i386 mips mipsel powerpc powerpcspe ppc64el s390x)
	-d,--dist	Sets distribution.
				(debian ubuntu)
	-r,--rel	Sets release.
				Debian: (stretch buster bullseye bookworm trixie sid oldstable stable testing unstable)
				Ubuntu: (trusty xenial bionic focal jammy lunar mantic)
	-m,--mirror	Sets download mirror.
	-o,--out	Sets output directory.
	-f,--force	Always overwrite output directory.
	-p,--pkgs	Includes list of extra packages to install.
	-h,--help	Shows this help text.

Usage Examples:
	DebGen.sh
	DebGen.sh -h
	DebGen.sh -a amd64 -d debian -r stable -m http://deb.debian.org/debian -o OUTPUT -f -p pkgs.list
	DebGen.sh --help
	DebGen.sh --arch amd64 --dist debian --rel stable --mirror http://deb.debian.org/debian --out OUTPUT --force --pkgs pkgs.list
</pre>
