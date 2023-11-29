# Cross-compiling ungoogled-chromium for Windows

This directory contains tooling to build ungoogled-chromium for Microsoft Windows using a containerized GNU/Linux build environment. This approach has numerous advantages over the typical Windows build process:

* No Windows installation is needed;

* The necessary Microsoft tools and libraries are freely downloadable (to be clear: no payment-encumbered software components are required);

* The build is hermetic (i.e. isolated from the particulars of the host system on which it runs);

* The build is reproducible (i.e. given the same input sources and libraries, the outputs will likewise be the same, regardless of who runs the build or when it is run);

* Builds can target Windows on x64, x86, or ARM64 with equal ease.


## Requirements

* Linux x86-64 (x64) environment (Ubuntu 24.04/noble is known to work)

* Docker or Docker-compatible container host

(Note: It may be possible to run through this process on Windows using [WSL](https://learn.microsoft.com/windows/wsl) and/or [Rancher Desktop](https://rancherdesktop.io/), but we have no information on this as yet.)


## Preparation

Perform a Git clone of [this repository](https://github.com/ungoogled-chromium/ungoogled-chromium-windows), including submodules. Enter the `cross-build/` subdirectory. Many of the steps involved are covered by targets in `Makefile`.


### Building the container image

The container for building ungoogled-chromium includes the Microsoft Windows SDK, which is proprietary software, and cannot be legally redistributed. You will thereby need to build the container image yourself.

The easiest way is to run `make build-image`, which will prompt you to accept the Microsoft license, download the Windows components needed, and build the `chromium-win-cross` container image.

By default, the image will support 64-bit (x64) builds only. To build a larger image that can support x86 (32-bit) and ARM64 builds as well, run `make build-image MULTI_ARCH=1`.

If you wish to use the exact same version of the Windows SDK as an existing image, then you will need a copy of the `.manifest` file that was used to build said image. Place this file, uncompressed, in the `cross-build/` directory prior to building the image. It should have a name like `17.11.3.manifest`.

The files downloaded from Microsoft will be stored in a `msvc-cache` subdirectory. If you wish to build the image again at a later time, then hanging on to this directory will save you the need to download over a gigabyte's worth of files again.

Once the image build is complete, there will be a `MD5SUMS.rootfs` file that contains MD5 hash sums for every file in the image. You can use this file to compare your build of the image against someone else's. (Also see the `verify-image` target in the makefile.)


#### Base image (optional)

Note that there is also a `chromium-win-cross-base` container image. This has everything that isn't from Microsoft, is freely redistributable, and is normally used as the basis for building `chromium-win-cross`. You can build the base image yourself if you like, with `make build-image-base`.

The container has a regular (non-root) user, named `build`, for running the browser build. By default, its user ID is 1024. If you wish to use a different UID, specify it as e.g. `make build-image-base BUILD_UID=1234`.

The base image is built on an official Ubuntu image, and the image build needs to download numerous Ubuntu packages. To keep the load down on the main Ubuntu package servers, the build uses a third-party mirror server. If there is a different mirror host that you would like to use, you can specify it with e.g. `make build-image-base APT_MIRROR=de.archive.ubuntu.com`. (If you wish to use the official servers, specify `APT_MIRROR=NONE`. Either way, the package indexes will be signature-verified.)

The base image build accepts the same `MULTI_ARCH=1` parameter as described above. You will need to specify it if you wish to peform x86 or ARM64 builds.


### Building ungoogled-chromium

You can start the container with `make run`. Additional shells in the same environment can be started with `make run-extra`. Note that when the first shell exits, the container and all its contents will be deleted! Please don't keep your only copy of any important work inside the container. (Of course, if you already have your own container workflow, then you make the rules.)

You'll need a copy of this repository inside the container, be it a volume-mounted instance of your initial Git clone, or a new/separate one. Ensure that the Git submodule under `ungoogled-chromium/` is checked out as well; you should see e.g. `ungoogled-chromium/chromium_version.txt`.

Enter the `cross-build/` subdirectory, and run `./build.sh --idle --tarball`. This will download the Chromium source tarball, unpack it, prune binary files, apply the ungoogled-chromium patches, and build the browser as a whole. Note that this script has other options; run `./build.sh --help` to see them.

If the build is successful, then you will see two final output files named like the following:
```
ungoogled-chromium_123.0.1234.123-1.1_installer_x64.exe
ungoogled-chromium_123.0.1234.123-1.1_windows_x64.zip
```
Copy these files out of the container (see the `docker cp` command for one way of doing this), and they should work as expected on a compatible Microsoft Windows system.


## Notes

* Google's [re-implementation](https://github.com/nico/hack/blob/main/res/rc.cc) of the `rc` resource compiler is installed under `/usr/local/bin/`. You'll find the source code in `/usr/local/src/`.

* All the Microsoft SDK stuff is under `/opt/microsoft/`, and the Chromium-relevant environment variables pointing to it are set accordingly.

* A non-distro-provided Rust toolchain is installed under `/opt/rust/`. (The distro's packaged Rust compiler does not work, unfortunately, due to Rust's unforgivingly strict ABI compatibility.)

* The build requires Microsoft's `midl.exe` compiler, and this in turn depends on `cl.exe`. I am not aware of any viable alternatives for these. The image includes an installation of Wine to allow running them.

* The scripts are reasonably commented to explain what's going on, so please feel free to read through them beforehand.

* Please report any issues to the project's issue tracker [here](https://github.com/ungoogled-software/ungoogled-chromium-windows/issues).
