#!/bin/sh
# m52xq classic: kf6-kpeople 6.24.0-0ubuntu1 + 0001-m52xq-serialize-persondb-access.patch -> 6.24.0-0ubuntu1+m52xq1
# run inside the mesa-build-root2 chroot (arm64): sh /build-kp/build.sh   (dependencies: apt-get build-dep kf6-kpeople)
set -e
cd /build-kp
[ ! -e kpeople-6.24.0 ] || { echo "/build-kp/kpeople-6.24.0 exists (earlier build): move it away first"; exit 1; }
tar -xf kf6-kpeople_6.24.0.orig.tar.xz
cd kpeople-6.24.0
tar -xf ../kf6-kpeople_6.24.0-0ubuntu1.debian.tar.xz
mkdir -p debian/patches
cp ../0001-m52xq-serialize-persondb-access.patch debian/patches/
echo 0001-m52xq-serialize-persondb-access.patch >> debian/patches/series
# no dch in the chroot: the changelog entry by hand
{ printf 'kf6-kpeople (6.24.0-0ubuntu1+m52xq1) resolute; urgency=medium\n\n  * m52xq: serialize the PersonManager database connection (dialer crash with\n    contact name + avatar, SIGSEGV in sqlite3DbMallocRawNN).\n\n -- Asdlerto Korry <korryasdlerto@gmail.com>  %s\n\n' "$(date -R)"; cat debian/changelog; } > debian/changelog.new
mv debian/changelog.new debian/changelog
dpkg-checkbuilddeps || true	# doxygen / dbus-x11 are for the docs / tests only (nodoc nocheck): -d below
DEB_BUILD_OPTIONS="nocheck nodoc parallel=${J:-8}" dpkg-buildpackage -b -uc -us -d
