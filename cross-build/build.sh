#!/bin/sh
# build.sh
#
# ungoogled-chromium cross-build script: GNU/Linux to Microsoft Windows
#
# This script should be run inside the build container environment.
#

# Defaults
#
git=no
target_cpu=  # default is x64
ccache=
debug=no
idle=no
ci=no

print_usage()
{
	cat << END
usage: $0 [--git] [--arm64|--x86] [--ccache] [--idle] [--ci]

options:
  --git      build from a Git checkout instead of a source tarball
  --arm64    build for 64-bit ARM instead of Intel
  --x86      build for x86 (32-bit) instead of x64
  --ccache   use ccache for faster rebuilds
  --debug    build with debugging enabled
  --idle     reduce CPU priority for build process
  --ci       running in continuous-integration job (experts only)
  --help     print this help
END
	exit 1
}

#
# Parse command-line options
#

while [ -n "$1" ]
do
	case "$1" in
		--git)     git=yes          ;;
		--arm)     target_cpu=arm64 ;;
		--arm64)   target_cpu=arm64 ;;
		--x64)     target_cpu=      ;;
		--x86)     target_cpu=x86   ;;
		--ccache)  ccache=-ccache   ;;
		--debug)   debug=yes        ;;
		--idle)    idle=yes         ;;
		--ci)      ci=yes           ;;
		-h|--help) print_usage      ;;
		-*) echo "$0: error: unrecognized option \"$1\"";   exit 1 ;;
		*)  echo "$0: error: unrecognized argument \"$1\""; exit 1 ;;
	esac
	shift
done

wrap=

run()
{
	local t= w=

	if [ "_$1" = _--time ]
	then
		t='time --verbose'
		shift
	fi
	if [ "_$1" = _--wrap ]
	then
		w="$wrap"
		shift
	fi

	echo "+ $*"
	$t $w env "$@"
	echo ' '
}

set -e

u_c=$(cd ../ungoogled-chromium && pwd)
u_c_w=$(cd .. && pwd)

#
# Sanity checks
#

if [ ! -f $u_c/chromium_version.txt ]
then
	echo "$0: error: ungoogled-chromium Git tree is not present at $u_c/"
	echo "(Did you clone with --recurse-submodules ?)"
	exit 1

fi

if [ ! -d /opt/rust/sysroot ]
then
	echo "$0: error: Rust installation is not present"
	echo "(Please run this script inside the build container)"
	exit 1
fi

if [ "_$target_cpu" = _arm64 -a \
     ! -d /opt/rust/sysroot/lib/rustlib/aarch64-pc-windows-msvc/lib ]
then
	echo "$0: error: Rust installation lacks ARM64 support"
	echo "(Please build the container with MULTI_ARCH=1)"
	exit 1
fi

if [ "_$target_cpu" = _x86 -a \
     ! -d /opt/rust/sysroot/lib/rustlib/i686-pc-windows-msvc/lib ]
then
	echo "$0: error: Rust installation lacks x86 (32-bit) support"
	echo "(Please build the container with MULTI_ARCH=1)"
	exit 1
fi

if [ ! -d /opt/microsoft/VC ]
then
	echo "$0: error: Windows SDK is not present"
	echo "(Please run this script inside the build container)"
	exit 1
fi

if [ "_$target_cpu" = _arm64 -a \
     ! -f /opt/microsoft/VC/Tools/MSVC/*/bin/HostX64/arm64/cl.exe ]
then
	echo "$0: error: Windows SDK lacks ARM64 support"
	echo "(Please build the container with MULTI_ARCH=1)"
	exit 1
fi

if [ "_$target_cpu" = _x86 -a \
     ! -f /opt/microsoft/VC/Tools/MSVC/*/bin/Hostx86/x86/cl.exe ]
then
	echo "$0: error: Windows SDK lacks x86 (32-bit) support"
	echo "(Please build the container with MULTI_ARCH=1)"
	exit 1
fi

if [ ! -x /usr/local/bin/rc ]
then
	echo "$0: error: Google RC is not present"
	echo "(Please run this script inside the build container)"
	exit 1
fi

#
# Collect some information
#

chromium_version=$(cat $u_c/chromium_version.txt)
u_c_commit=$(cd $u_c && git log -1 --format='%h')
u_c_w_commit=$(git log -1 --format='%h')

cat << END
----------------------------------------------
Chromium upstream version: $chromium_version
ungoogled-chromium Git commit: $u_c_commit
ungoogled-chromium-windows Git commit: $u_c_w_commit
----------------------------------------------
END
echo ' '

#
# Download and unpack sources
#

mkdir -p build/download_cache
cd build

hide_progress=$(test -t 1 || echo --hide-progress-bar)

if [ ! -f stamp-download ]
then
	if [ $git = yes ]
	then
		pgo=$(test $x86 = yes && echo win32 || echo win64)
		run $u_c/utils/clone.py --output src --pgo $pgo
	else
		dl_args="--ini $u_c/downloads.ini --cache download_cache"

		if [ $ci = no ]
		then
			run $u_c/utils/downloads.py retrieve $dl_args $hide_progress
		fi

		run $u_c/utils/downloads.py unpack $dl_args src
	fi
	touch stamp-download
fi

if [ ! -f src/BUILD.gn ]
then
	echo "$0: error: no Chromium source tree is present"
	exit 1
fi

if [ ! -f stamp-download-more ]
then
	dl_args="--ini ../../downloads.ini --cache download_cache"

	run $u_c/utils/downloads.py retrieve --components directx-headers $dl_args $hide_progress

	run $u_c/utils/downloads.py unpack --components directx-headers $dl_args src

	touch stamp-download-more
fi

#
# Prune binaries
#

if [ ! -f stamp-prune ]
then
	run $u_c/utils/prune_binaries.py src $u_c/pruning.list
	touch stamp-prune
fi

#
# Apply patches
#

if [ ! -d patches ]
then
	# Create combined patches directory for quilt(1)
	#
	mkdir patches
	for dir in $u_c/patches/* $u_c_w/patches/*
	do
		test -d "$dir" || continue
		ln -s $dir patches
	done

	(cat $u_c/patches/series
	 echo
	 cat $u_c_w/patches/series
	) > patches/series
fi

if [ ! -f stamp-patch ]
then
	(cd src && run QUILT_PATCHES=../patches quilt push -aq --fuzz=0)
	touch stamp-patch
fi

#
# Substitute domains
#

if [ ! -f stamp-substitute ]
then
	run $u_c/utils/domain_substitution.py \
		apply \
		--regex $u_c/domain_regex.list \
		--files $u_c/domain_substitution.list \
		src
	touch stamp-substitute
fi

#
# Initialize default Wine prefix
#

if [ ! -d ~/.wine ]
then
	run WINEDEBUG=-all wineboot --init

	# Use /tmp for Windows temp files
	(cd ~/.wine/drive_c/users/$(whoami) && rmdir Temp && ln -s /tmp Temp)
fi

#
# Define execution wrappers for the build
#

if bwrap --bind / / true 2>/dev/null
then
	# Use bubblewrap for sandboxing:
	# * Allow write access only to the source/build tree and /tmp
	# * Use separate /dev (allows writing to e.g. /dev/null)
	# * Disallow network access
	wrap="$wrap bwrap --ro-bind / / --dev /dev --bind /tmp /tmp --bind $PWD/src $PWD/src --unshare-net"
fi

if [ $idle = yes ]
then
	wrap="$wrap ionice -c 3 chrt -i 0 nice -n 19"
fi

cd src

out_dir=out/Default${target_cpu:+-$target_cpu}

#
# Build GN
#

mkdir -p $out_dir

if [ ! -x out/gn ]
then
	run --wrap \
	  CXX=/opt/llvm/bin/clang++ \
	  CXXFLAGS='-stdlib=libc++' \
	  AR=/opt/llvm/bin/llvm-ar \
	  LDFLAGS='-fuse-ld=lld -stdlib=libc++ -l:libc++abi.a' \
	  tools/gn/bootstrap/bootstrap.py \
		--build-path=out \
		--skip-generate-buildfiles
fi
if [ ! -x $out_dir/gn ]
then
	ln -s ../gn $out_dir
fi

#
# Prepare build configuration
#

flags=$out_dir/args.gn

(cat $u_c/flags.gn
 echo
 cat $u_c_w/flags.windows.gn
 echo
) > $flags.new

if [ -n "$target_cpu" ]
then
	sed -i "/^target_cpu=/s/x64/$target_cpu/" $flags.new
fi
if [ $debug = yes ]
then
	sed -i \
		-e '/^is_debug=/s/false/true/' \
		-e '/^is_official_build=/s/true/false/' \
		-e '/^\w*symbol_level=/s/0/1/' \
		$flags.new
fi

clang_dir=/opt/llvm$ccache

clang_ver=$(/opt/llvm/bin/clang++ --version \
	| sed -nr 's/.*clang version ([0-9]+)\..+/\1/p')

cat >> $flags.new << END
clang_base_path="$clang_dir"
clang_version="$clang_ver"
rust_sysroot_absolute="/opt/rust/sysroot"
rust_bindgen_root="/opt/rust/bindgen"
rustc_version="$(/opt/rust/sysroot/bin/rustc --version)"

# Build the V8 context snapshot, and disable various Linux-specific
# features to avoid unnecessary host-side dependencies.
use_v8_context_snapshot=true
ozone_platform_wayland=false
ozone_platform_x11=false
rtc_use_x11_extensions=false
use_alsa=false
use_cups=false
use_dbus=false
use_pangocairo=false
use_pulseaudio=false
use_udev=false
use_xkbcommon=false
END

if [ -f ../../extra-flags.gn ]
then
	(echo; cat ../../extra-flags.gn) >> $flags.new
fi

if [ -f $out_dir/build.ninja ] && cmp -s $flags.new $flags
then
	rm $flags.new
	run_gn=no
else
	echo "======== begin GN flags ========"
	sed 's/^$/ /' $flags.new
	echo "========= end GN flags ========="
	echo ' '
	mv -f $flags.new $flags
	run_gn=yes
fi

#
# Generate build files, and perform the build
#

if [ $run_gn = yes ]
then
	run --wrap out/gn gen $out_dir --fail-on-unused-args
fi

targets='chrome chromedriver mini_installer'

if [ $ci = yes ]
then
	echo $targets > $out_dir/build.targets
	exit 0
fi

run --time --wrap ${NINJA:-ninja} -C $out_dir $targets

#
# Package up the build
#

(cd ../..
 run python3 ../package.py --build-outputs build/src/$out_dir
 ls -l build/ungoogled-chromium_*
 echo ' '
 sha256sum build/ungoogled-chromium_*
 echo ' '
)

#
# Hash sums to troubleshoot reproducibility issues
#

echo 'Generating hash sums of source and build trees ...'

(echo '# ungoogled-chromium source and build tree MD5 hash sums'
 echo '# (sorted by last-modified timestamp, oldest to newest)'
 echo "# Chromium upstream version: $chromium_version"
 echo "# ungoogled-chromium Git commit: $u_c_commit"
 echo "# ungoogled-chromium-windows Git commit: $u_c_w_commit"
 test -z "$target_cpu" || echo "# Target CPU: $target_cpu"
 test $debug = no || echo '# Build variant: debug'
 echo '#'
 find . -type f -printf '%T@\t%P\n' \
 | LC_COLLATE=C sort -k 1,1g -k 2b \
 | cut -f2- \
 | xargs -d '\n' md5sum
) > ../MD5SUMS${target_cpu:+-$target_cpu}.repro

echo ' '
echo 'Build complete.'

# end build.sh
