# base-setup.sh
#
# Setup script for container image build, run from Dockerfile.base
#

set -e
export DEBIAN_FRONTEND=noninteractive

test -n "$APT_MIRROR"
test -n "$BUILD_UID"
test -f /usr/local/src/rc.cc

run() {
	echo "+ $*"
	env "$@" 2>&1
	echo
}

run tee /etc/apt/apt.conf.d/95custom << END
# Don't install recommended packages
APT::Install-Recommends "0";

# Don't use "Reading database ... X%" progress indicator
Dpkg::Use-Pty "false";
END

# Set up APT package repositories
if [ "_$APT_MIRROR" != _NONE ]
then
	run perl -pi \
		-e 's!deb.debian.org!<APT>!;' \
		-e 's!archive.ubuntu.com/ubuntu!<APT>/ubuntu!;' \
		-e 's!security.ubuntu.com/ubuntu!<APT>/ubuntu-security! if 0;' \
		-e "s!<APT>!$APT_MIRROR!;" \
		-e '/ \w+-(backports|security) / and s/^/#!#/' \
		/etc/apt/sources.list.d/*.sources \
		/etc/apt/sources.list
fi
run apt-get --error-on=any update

echo 'APT release info:'
grep -H '^Date:' /var/lib/apt/lists/*Release | cut -d_ -f2-
echo

# General build environment tooling
run apt-get -y install \
	7zip \
	bubblewrap \
	ccache \
	file \
	git \
	less \
	nano \
	netcat-openbsd \
	procps \
	python3 \
	python3-httplib2 \
	quilt \
	rsync \
	time \
	unzip \
	wget \
	wine wine64 \
	xz-utils \
	zip \
	zstd

# NOTE: LLVM and Node.js are installed from upstream binary tarballs, Rust
# is installed via rustup, and generate-ninja is built from source, so
# don't install packages for those

# Needed by Linux-side tooling
run apt-get -y install \
	libexpat1-dev \
	libglib2.0-dev \
	libkrb5-dev \
	libnss3-dev

# XXX EXPERIMENTAL:
# Additional dependencies for use_v8_context_snapshot=true
run apt-get -y install \
	libgl-dev \
	libpci-dev \
	libx11-xcb-dev \
	libxext-dev \
	libxi-dev

# Build tools
run apt-get -y install \
	gperf \
	ninja-build

# Runtime dependencies of the upstream LLVM binaries
run apt-get -y install \
	libncurses6 \
	libxml2

run apt-get -y install libgcc-14-dev

if [ -n "$MULTI_ARCH" ]
then
	# ARM64 cross libraries are not needed, only x86
	run apt-get -y install \
		lib32gcc-s1 \
		libc6-dev-i386-cross \
		libgcc-14-dev-i386-cross

	# Help Clang find the x86 headers
	run ln -s ../i686-linux-gnu/include /usr/include/i386-linux-gnu
fi

# Set up sudo(8) to allow running gh-unburden as root
run apt-get -y install sudo
#
# Note: The "!fqdn" bit is to avoid "sudo: unable to resolve host _____:
# Name or service not known" errors in the container
#
run tee /etc/sudoers.d/build << END
Defaults !fqdn
build ALL = NOPASSWD: /usr/local/sbin/gh-unburden ""
END

# Clean up
run apt-get clean
rm -f /var/lib/apt/lists/*ubuntu*

# Set up duplicate LLVM tree with ccache(1) support
(cd /opt/llvm/bin
 for x in clang clang++ clang-cl clang-cpp; do test -L $x || exit; done
 test ! -L clang-[1-9]*
)
mkdir /opt/llvm-ccache
(cd /opt/llvm-ccache && ln -s ../llvm/* .)
rm /opt/llvm-ccache/bin
mkdir /opt/llvm-ccache/bin
(cd /opt/llvm-ccache/bin
 find ../../llvm/bin/* -type l -exec cp -d {} . \; -o -exec ln -s {} . \;
 ln -sf ../../../usr/bin/ccache clang-[1-9]*
)

# Compile the rc program
run /opt/llvm/bin/clang++ \
	-stdlib=libc++ \
	-std=c++14 \
	-fuse-ld=lld \
	-Wall \
	-Wno-c++11-narrowing \
	/usr/local/src/rc.cc \
	-o /usr/local/bin/rc

# Create regular user for running the build
run useradd \
	--uid $BUILD_UID \
	--gid users \
	--no-user-group \
	--comment 'Build User' \
	--create-home \
	--key HOME_MODE=0755 \
	--shell /bin/bash \
	build

# Zap unreproducible files
rm -f /var/cache/ldconfig/aux-cache
for file in \
	alternatives.log \
	apt/history.log \
	apt/term.log \
	dpkg.log
do
	echo UNREPRODUCIBLE_FILE > /var/log/$file
done

echo 'base-setup done.'

# end base-setup.sh
