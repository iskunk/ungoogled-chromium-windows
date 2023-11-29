# Makefile

IMAGE_NAME = chromium-win-cross
BASE_IMAGE_NAME = $(IMAGE_NAME)-base
CONTAINER_NAME = $(IMAGE_NAME)-con

# Uncomment to add support for x86 (32-bit) and ARM64 builds
#MULTI_ARCH = 1

ifdef GITHUB_WORKSPACE
GH_ECHO = @echo
else
GH_ECHO = @true
endif

extra_run_args = \
	--network=host \
	--tmpfs /external/tmp:exec

run:
	docker container run -it --rm \
		--name=$(CONTAINER_NAME) \
		--hostname=$(CONTAINER_NAME) \
		$(extra_run_args) \
		$(IMAGE_NAME)

run-extra:
	docker container exec -it $(CONTAINER_NAME) /bin/bash

CONTEXT = tmp.context

build-image: Dockerfile.msvc winsysroot.stamp
	$(GH_ECHO) '::group::Build container image'
	rm -rf $(CONTEXT)
	mkdir $(CONTEXT)
	cp -al winsysroot/ $(CONTEXT)
	docker build \
		--file $< \
		--tag $(IMAGE_NAME) \
		--progress plain \
		$(if $(IMAGE_SOURCE),--label org.opencontainers.image.source=$(IMAGE_SOURCE)) \
		$(CONTEXT)
	rm -rf $(CONTEXT)
	docker container run --rm \
		--user=root \
		--cap-add=SYS_ADMIN \
		--security-opt=apparmor=unconfined \
		$(IMAGE_NAME) \
		rootfs-sums generate \
	> MD5SUMS.rootfs
	$(GH_ECHO) '::endgroup::'

image_base_deps = \
	base-setup.sh \
	ccache.conf \
	gh-unburden.sh \
	rc.cc \
	rootfs-sums.sh

build-image-base: Dockerfile.base llvm.stamp node.stamp rust.stamp $(image_base_deps)
	$(GH_ECHO) '::group::Build base container image'
	rm -rf $(CONTEXT)
	mkdir $(CONTEXT)
	cp -p $(image_base_deps) $(CONTEXT)
	cp -al llvm/ $(CONTEXT)
	cp -al node/ $(CONTEXT)
	cp -al rust/ $(CONTEXT)
	docker build \
		--file $< \
		--tag $(BASE_IMAGE_NAME) \
		--progress plain \
		$(if $(IMAGE_SOURCE),--label org.opencontainers.image.source=$(IMAGE_SOURCE)) \
		$(if $(APT_MIRROR),--build-arg APT_MIRROR=$(APT_MIRROR)) \
		$(if $(BUILD_UID),--build-arg BUILD_UID=$(BUILD_UID)) \
		$(if $(MULTI_ARCH),--build-arg MULTI_ARCH=$(MULTI_ARCH)) \
		$(CONTEXT)
	rm -rf $(CONTEXT)
	$(GH_ECHO) '::endgroup::'

verify-image: MD5SUMS.rootfs
	docker container run -i --rm \
		--user=root \
		--cap-add=SYS_ADMIN \
		--security-opt=apparmor:unconfined \
		$(IMAGE_NAME) \
		rootfs-sums verify \
	< $<

#### Google tools

# Commit from 2024 Oct 14
RC_GIT_REVISION = 4156984e47724ae6a522c9e7af3d5fbb97a876f1
#RC_GIT_REVISION = main

# Portable resource compiler re-implementation, see
# build/toolchain/win/rc/README.md
# (llvm-rc does not yet appear to be usable for the Chromium build)
#
# View source in context:
# https://github.com/nico/hack/blob/main/res/rc.cc
#
rc.cc:
	$(GH_ECHO) '::group::Download Google RC'
	wget -nv https://raw.githubusercontent.com/nico/hack/$(RC_GIT_REVISION)/res/rc.cc
	test -s $@
	$(GH_ECHO) '::endgroup::'

#### LLVM toolchain/libraries setup

LLVM_VERSION = 20.1.1

LLVM_URL = https://github.com/llvm/llvm-project/releases/download/llvmorg-$(LLVM_VERSION)/LLVM-$(LLVM_VERSION)-Linux-X64.tar.xz

LLVM_SHA512 = 'b55fd8827a3ef7617a4b98fda7ee078b23f774e28076f0c67e38092f54659b07847e4151357d05abe17f42b1c130a07f8f846a2f438a52a89f08a604f3b1a06b  LLVM-20.1.1-Linux-X64.tar.xz'

llvm.stamp:
	$(GH_ECHO) '::group::Prepare LLVM installation'
	wget -nv -c $(LLVM_URL)
ifdef LLVM_SHA512
	echo $(LLVM_SHA512) | sha512sum -c -
endif
	rm -rf llvm llvm-tmp
	mkdir llvm-tmp
	tar xJf LLVM-*.tar.xz -C llvm-tmp
	mv -v llvm-tmp/LLVM-* llvm
	rm -r llvm-tmp
# Always link the C++ runtime libraries statically
	for lib in llvm/lib/*/libc++.so; do \
		grep -Iq '^INPUT' $$lib || exit; \
		mv -f $$lib $$lib.orig; \
		echo 'INPUT(libc++.a libc++abi.a libunwind.a)' > $$lib; \
		echo "rewrote '$$lib'"; \
	done
	touch $@
	$(GH_ECHO) '::endgroup::'

#### Node.js toolchain setup

NODE_VERSION = 22.14.0

NODE_URL = https://nodejs.org/dist/v$(NODE_VERSION)/node-v$(NODE_VERSION)-linux-x64.tar.xz

NODE_SHA512 = 'acb8c6df3ad9e5b403449a003726de7733de5bb23162e6db535948589fb15570cd606924ad7ce76f42785117d938deec1e8d5781c20a3558b1ef8f8e4af41735  node-v22.14.0-linux-x64.tar.xz'

node.stamp:
	$(GH_ECHO) '::group::Prepare Node.js installation'
	wget -nv -c $(NODE_URL)
ifdef NODE_SHA512
	echo $(NODE_SHA512) | sha512sum -c -
endif
	rm -rf node node-tmp
	mkdir node-tmp
	tar xJf node-v*.tar.xz -C node-tmp
	mv -v node-tmp/node-v* node
	rm -r node-tmp
	touch $@
	$(GH_ECHO) '::endgroup::'

#### Rust toolchain/libraries setup

# Debian/Ubuntu don't package the Rust standard libraries needed for
# cross-compilation to Windows/MSVC, and the packaged Rust compiler will
# reject any libraries we download with error E0514, so install the whole
# Rust toolchain and set of libraries using the "rustup" utility.

RUST_VERSION = 1.86.0
#RUST_VERSION = nightly-2024-02-14

BINDGEN_VERSION = 0.71.1

RUSTUP_URL = https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init

.SECONDARY: rustup-init
rustup-init:
	$(GH_ECHO) '::group::Download rustup'
	wget -nv -c $(RUSTUP_URL)
	chmod +x $@
	$(GH_ECHO) '::endgroup::'

rust.stamp: rustup-init
	$(GH_ECHO) '::group::Prepare Rust installation'
	rm -rf rust rust-cargo.tmp
	CARGO_HOME=rust/cargo \
	RUSTUP_HOME=rust/rustup \
	TERM=dumb \
	./rustup-init -y --quiet \
		--profile minimal \
		--default-toolchain $(RUST_VERSION) \
		$(if $(MULTI_ARCH),--target i686-pc-windows-msvc) \
		$(if $(MULTI_ARCH),--target aarch64-pc-windows-msvc) \
		--target x86_64-pc-windows-msvc \
		--no-modify-path
	cd rust && ln -s rustup/toolchains/* sysroot
	CARGO_HOME=rust-cargo.tmp \
	RUSTC=rust/sysroot/bin/rustc \
	TERM=dumb \
	rust/sysroot/bin/cargo install --root rust/bindgen bindgen-cli@$(BINDGEN_VERSION)
	rm -rf rust-cargo.tmp
	touch $@
	$(GH_ECHO) '::endgroup::'

#### Microsoft Windows SDK setup

# Uncomment to accept the Microsoft EULA automatically
#MSVC_ACCEPT_LICENSE = --accept-license

MSVC_PACKAGE_LIST = \
	Microsoft.VisualStudio.Component.VC.14.38.17.8.x86.x64 \
	Microsoft.VisualStudio.Component.VC.14.38.17.8.MFC \
	Win11SDK_10.0.22621

ifdef MULTI_ARCH
MSVC_PACKAGE_LIST += \
	Microsoft.VisualStudio.Component.VC.14.38.17.8.ARM64 \
	Microsoft.VisualStudio.Component.VC.14.38.17.8.MFC.ARM64
endif

MSVC_MANIFEST_FILE := $(wildcard msvc-cache/*.*.*.manifest)

.SECONDARY: msvc-wine/vsdownload.py
msvc-wine/vsdownload.py:
	git clone https://github.com/mstorsjo/msvc-wine.git
	test -x $@

winsysroot.stamp: msvc-wine/vsdownload.py
	$(GH_ECHO) '::group::Download and extract MSVC files'
	rm -rf $@ winsysroot
	msiextract --version

	$< \
		$(MSVC_ACCEPT_LICENSE) \
		--cache msvc-cache \
		--dest winsysroot \
		$(if $(MSVC_MANIFEST_FILE),--manifest $(MSVC_MANIFEST_FILE),--save-manifest) \
		$(MSVC_PACKAGE_LIST)

ifeq "$(wildcard msvc-cache/MD5SUMS)" ""
# Generate hash sums for all downloaded files in the cache
	(cd msvc-cache && find . -type f -printf '%P\n' \
	| LC_COLLATE=C sort \
	| xargs -d '\n' md5sum \
	) > MD5SUMS.msvc-cache
	mv MD5SUMS.msvc-cache msvc-cache/MD5SUMS
endif

# Keep a copy of the manifest in the cache (if newly obtained)
	$(if $(MSVC_MANIFEST_FILE),true,cp -pv *.*.*.manifest msvc-cache/)

	$(GH_ECHO) '::endgroup::'
	$(GH_ECHO) '::group::Prepare MSVC installation'

# Delete unpopulated MSVC tool dirs, as they will cause trouble if they
# are higher-versioned than the real one (see clang-cl's /vctoolsversion
# option, which we don't want to use)
	for dir in winsysroot/VC/Tools/MSVC/*; do \
		test -d $$dir/include || rm -rv $$dir; \
	done

ifndef MULTI_ARCH
# Delete directories specific to non-x64 architectures
	find winsysroot -depth -type d \
		\( -iname x86 -o -iname Hostx86 -o \
		   -iname arm -o -iname arm64 -o -iname HostArm64 \) \
		-printf "removing '%p'\\n" -exec rm -r {} +
endif # not MULTI_ARCH

# Zap all the executables (except for CL+MIDL), since we won't need them
	find winsysroot -type f -name \*.exe \
		\! -name cl.exe \! -name midl.exe \! -name midlc.exe \
		-printf "zapping '%p'\\n" -exec truncate -s 0 {} +

# Generate environment files
	./gen-setenv.py winsysroot

# Add symlinks for letter-case variations
	./case-fold.sh winsysroot

ifndef MULTI_ARCH
# The Chromium build still checks for a handful of "x86" directories
	for dir in \
		winsysroot/VC/Tools/MSVC/*/lib \
		winsysroot/VC/Tools/MSVC/*/atlmfc/lib \
		winsysroot/'Windows Kits'/*/Lib/*/um \
		winsysroot/'Windows Kits'/*/Lib/*/ucrt; \
	do \
		mkdir -v "$$dir/x86" || exit; \
	done
endif # not MULTI_ARCH

# Save the manifest file, to allow repeating this download in the future
	mkdir winsysroot/.vsdownload
	cp -pv $(if $(MSVC_MANIFEST_FILE),$(MSVC_MANIFEST_FILE),*.*.*.manifest) \
		winsysroot/.vsdownload/
	xz -9 winsysroot/.vsdownload/*.manifest

# Save the download cache hash sums, to verify future downloads
	cp -p msvc-cache/MD5SUMS \
		winsysroot/.vsdownload/MD5SUMS.cache

	touch $@
	$(GH_ECHO) '::endgroup::'

#### Miscellaneous

clean:
	rm -f LLVM-*.tar.xz
	rm -f MD5SUMS.*
	rm -f rc.cc
	rm -f rustup-init
	rm -rf $(CONTEXT)
	rm -rf llvm llvm-tmp
	rm -rf rust.stamp rust rust-cargo.tmp
	rm -rf winsysroot.stamp winsysroot
	-docker image rm $(IMAGE_NAME)

clean-more:
	rm -f *.manifest
	rm -rf msvc-cache

.PHONY: run run-extra build-image build-image-base verify-image \
	clean clean-more

# end Makefile
