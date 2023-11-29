# Makefile

IMAGE_NAME = chromium-win-cross
BASE_IMAGE_NAME = $(IMAGE_NAME)-base
CONTAINER_NAME = $(IMAGE_NAME)-con

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
	rc.cc \
	requirements.txt \
	rootfs-sums.sh

build-image-base: Dockerfile.base rust.stamp $(image_base_deps)
	$(GH_ECHO) '::group::Build base container image'
	rm -rf $(CONTEXT)
	mkdir $(CONTEXT)
	cp -p $(image_base_deps) $(CONTEXT)
	cp -al rust/ $(CONTEXT)
	docker build \
		--file $< \
		--tag $(BASE_IMAGE_NAME) \
		--progress plain \
		$(if $(IMAGE_SOURCE),--label org.opencontainers.image.source=$(IMAGE_SOURCE)) \
		$(if $(APT_MIRROR),--build-arg APT_MIRROR=$(APT_MIRROR)) \
		$(if $(BUILD_UID),--build-arg BUILD_UID=$(BUILD_UID)) \
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

# Portable resource compiler re-implementation, see
# build/toolchain/win/rc/README.md
# (llvm-rc does not yet appear to be usable for the Chromium build)
#
# View source in context:
# https://github.com/nico/hack/blob/main/res/rc.cc
#
rc.cc:
	wget -nv https://raw.githubusercontent.com/nico/hack/main/res/rc.cc
	test -f $@

#### Rust toolchain/libraries setup

# Debian/Ubuntu don't package the Rust standard libraries needed for
# cross-compilation to Windows/MSVC, and the packaged Rust compiler will
# reject any libraries we download with error E0514, so install the whole
# Rust toolchain and set of libraries using the "rustup" utility.

RUST_VERSION = 1.75.0
#RUST_VERSION = nightly-2024-02-14

.SECONDARY: rustup-init
rustup-init:
	wget -nv https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init
	chmod +x $@

rust.stamp: rustup-init
	$(GH_ECHO) '::group::Prepare Rust installation'
	rm -rf rust rust-cargo.tmp
	CARGO_HOME=rust/cargo \
	RUSTUP_HOME=rust/rustup \
	TERM=dumb \
	./rustup-init -y --quiet \
		--profile minimal \
		--default-toolchain $(RUST_VERSION) \
		$(if $(MSVC_X64_ONLY),,--target i686-pc-windows-msvc) \
		--target x86_64-pc-windows-msvc \
		--no-modify-path
	cd rust && ln -s rustup/toolchains/* sysroot
	CARGO_HOME=rust-cargo.tmp \
	RUSTC=rust/sysroot/bin/rustc \
	TERM=dumb \
	rust/sysroot/bin/cargo install --root rust/bindgen bindgen-cli
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

MSVC_MANIFEST_FILE := $(wildcard msvc-cache/*.*.*.manifest)

# Unset to retain support for ARM and (32-bit) x86
MSVC_X64_ONLY = 1

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
	$(if $(MSVC_MANIFEST_FILE),true,cp -pnv *.*.*.manifest msvc-cache/)

	$(GH_ECHO) '::endgroup::'
	$(GH_ECHO) '::group::Prepare MSVC installation'

# Delete unpopulated MSVC tool dirs, as they will cause trouble if they
# are higher-versioned than the real one (see clang-cl's /vctoolsversion
# option, which we don't want to use)
	for dir in winsysroot/VC/Tools/MSVC/*; do \
		test -d $$dir/include || rm -rv $$dir; \
	done

ifdef MSVC_X64_ONLY
# Delete directories specific to non-x64 architectures
	find winsysroot -depth -type d \
		\( -name x86 -o -name Hostx86 -o \
		   -name arm -o -name arm64 -o -name HostArm64 \) \
		-printf "removing '%p'\\n" -exec rm -r {} +
endif # MSVC_X64_ONLY

# Zap all the executables (except for CL+MIDL), since we won't need them
	find winsysroot -type f -name \*.exe \
		\! -name cl.exe \! -name midl.exe \! -name midlc.exe \
		-printf "zapping '%p'\\n" -exec truncate -s 0 {} +

# Generate environment files
	./gen-setenv.py winsysroot

# Add symlinks for letter-case variations
	./case-fold.sh winsysroot

ifdef MSVC_X64_ONLY
# The Chromium build still checks for a handful of "x86" directories
	for dir in \
		winsysroot/VC/Tools/MSVC/*/lib \
		winsysroot/VC/Tools/MSVC/*/atlmfc/lib \
		winsysroot/'Windows Kits'/*/Lib/*/um \
		winsysroot/'Windows Kits'/*/Lib/*/ucrt; \
	do \
		mkdir -v "$$dir/x86" || exit; \
	done
endif # MSVC_X64_ONLY

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
	rm -f MD5SUMS.*
	rm -f rc.cc
	rm -f rustup-init
	rm -rf $(CONTEXT)
	rm -rf rust.stamp rust rust-cargo.tmp
	rm -rf winsysroot.stamp winsysroot
	-docker image rm $(IMAGE_NAME)

clean-more:
	rm -f *.manifest
	rm -rf msvc-cache

.PHONY: run run-extra build-image verify-image clean clean-more

# end Makefile
