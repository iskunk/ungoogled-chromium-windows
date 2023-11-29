#!/bin/sh
# build.sh
#
# ungoogled-chromium cross-build script: GNU/Linux to Microsoft Windows
#
# This script should be run inside the build container environment.
#

# Defaults
#
ci=no
git=no
x86=no
idle=no

print_usage()
{
	cat << END
usage: $0 [--ci] [--tarball] [--x86]

options:
  --git      build from a Git checkout instead of a source tarball
  --x86      build a 32-bit browser instead of a 64-bit one
  --idle     reduce CPU priority for build process
  --ci       running in continuous-integration job (experts only)
  --help     print this help
END
	exit 1
}

run()
{
	echo "+ $*"
	env "$@"
	echo ' '
}

#
# Parse command-line options
#

while [ -n "$1" ]
do
	case "$1" in
		--git)  git=yes        ;;
		--x86)  x86=yes        ;;
		--idle) idle=yes       ;;
		--ci)   ci=yes         ;;
		-h|--help) print_usage ;;
		-*) echo "$0: error: unrecognized option \"$1\"";   exit 1 ;;
		*)  echo "$0: error: unrecognized argument \"$1\""; exit 1 ;;
	esac
	shift
done

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

if [ $x86 = yes -a ! -d /opt/rust/sysroot/lib/rustlib/i686-pc-windows-msvc/lib ]
then
	echo "$0: error: Rust installation lacks x86 (32-bit) support"
	echo "(Please build the container with MSVC_X64_ONLY undefined)"
	exit 1
fi

if [ ! -d /opt/microsoft/VC ]
then
	echo "$0: error: Windows SDK is not present"
	echo "(Please run this script inside the build container)"
	exit 1
fi

if [ $x86 = yes -a ! -f /opt/microsoft/VC/Tools/MSVC/*/bin/Hostx86/x86/cl.exe ]
then
	echo "$0: error: Windows SDK lacks x86 (32-bit) support"
	echo "(Please build the container with MSVC_X64_ONLY undefined)"
	exit 1
fi

if [ ! -x /opt/google/bin/rc ]
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

#
# Download and unpack sources
#

mkdir -p build/download_cache
cd build

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
			run $u_c/utils/downloads.py retrieve $dl_args
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

	run $u_c/utils/downloads.py retrieve --components directx-headers $dl_args

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
	 echo
	 cat $u_c_w/patches/series.cross-build
	) > patches/series
fi

if [ ! -f stamp-patch ]
then
	(cd src && run QUILT_PATCHES=../patches quilt push -a -q)
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
# Prepare build configuration
#

mkdir -p src/out/Default
flags=src/out/Default/args.gn

(cat $u_c/flags.gn
 echo
 cat $u_c_w/flags.windows.gn
) > $flags.new

if [ $x86 = yes ]
then
	sed -i '/^target_cpu=/s/x64/x86/' $flags.new
fi

clang_base=$(echo /usr/lib/llvm-[1-9]*)
clang_ver=$(echo $clang_base | sed 's/.*-//')
test -d "$clang_base"

cat >> $flags.new << END

clang_base_path="$clang_base"
clang_version="$clang_ver"
rust_sysroot_absolute="/opt/rust/sysroot"
rust_bindgen_root="/opt/rust/bindgen"
rustc_version="$(/opt/rust/sysroot/bin/rustc --version)"
END

if [ -f extra-flags.gn ]
then
	(echo; cat extra-flags.gn) >> $flags.new
fi

if [ -f src/out/Default/build.ninja ] && cmp -s $flags.new $flags
then
	rm $flags.new
	run_gn=no
else
	echo "======== begin GN flags ========"
	cat $flags.new
	echo "========= end GN flags ========="
	echo
	mv -f $flags.new $flags
	run_gn=yes
fi

#
# Generate build files, and perform the build
#

cd src

if [ $run_gn = yes ]
then
	run gn gen out/Default --fail-on-unused-args
fi

if [ $ci = yes ]
then
	exit 0
fi

wrap="time --verbose"

if bwrap --bind / / true 2>/dev/null
then
	# Disallow network access from the build
	wrap="$wrap bwrap --bind / / --unshare-net"
fi

if [ $idle = yes ]
then
	wrap="$wrap ionice -c 3 chrt -i 0 nice -n 19"
fi

run $wrap ninja -C out/Default chrome chromedriver mini_installer

#
# Package up the build
#

(cd ../..
 run python3 ../package.py
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
 find . -type f -printf '%T@\t%P\n' \
 | LC_COLLATE=C sort -k 1,1g -k 2b \
 | cut -f2- \
 | xargs -d '\n' md5sum
) > ../MD5SUMS.repro

echo ' '
echo 'Build complete.'

# end build.sh
