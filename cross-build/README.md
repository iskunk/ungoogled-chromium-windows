# Cross-compiling ungoogled-chromium for Windows

This directory contains tooling to build ungoogled-chromium for Microsoft Windows in a containerized GNU/Linux build environment.

NOTE: This tooling is EXPERIMENTAL and requires further testing and development. Please report any issues with it [here](https://github.com/ungoogled-software/ungoogled-chromium-windows/issues/293). By the same token, this documentation is not yet complete.

## Build process

1. Perform a Git clone of [this repository](https://github.com/ungoogled-chromium/ungoogled-chromium-windows) onto a Linux system with a Docker host, and enter the `cross-build/` subdirectory.

   (TODO: Possible to support folks on Windows running [Rancher Desktop](https://rancherdesktop.io/)?)

2. Build the Docker image with `make build-image`. Note that if you have a faster (and/or local) APT mirror, you may want to edit the `APT_MIRROR` variable at the top of `Dockerfile`.

3. If that is successful, then you can start a container with `make run`. Additional shells can be started with `make run-extra`.

   Note that when the first shell exits, the container and all its contents will be deleted! Please don't save your only copy of any important work inside the container.

4. Perform another Git clone of this repository _inside_ the container. This time, use the `--recurse-submodules` option so that the submodule under `ungoogled-chromium/` is checked out as well. Enter the `cross-build/` directory here.

5. Run `./build.sh --idle --tarball`. This will download the Chromium source tarball, apply the ungoogled-chromium patches, and build the browser as a whole. Note that this script has other options; run `./build.sh --help` to see them.

   (TODO: Better to download the tarball outside of the container so that it is not lost when the container exits)

6. If the build is successful, you will see two final output files named like the following:
   ```
   ungoogled-chromium_123.0.1234.123-1.1_installer.exe
   ungoogled-chromium_123.0.1234.123-1.1_windows.zip
   ```

## Notes

* Google's [re-implementation](https://github.com/nico/hack/blob/main/res/rc.cc) of the `rc` resource compiler is installed under `/opt/google/`. You'll find both the source and binary there.

* All the Microsoft SDK stuff is under `/opt/microsoft/`, and the Chromium-relevant environment variables are set accordingly.

* A non-distro-provided Rust toolchain is installed under `/opt/rust/`. (I tried to make it work with the distro's packaged Rust compiler, but this proved impossible due to Rust's extreme lack of ABI compatibility)

* The build requires Microsoft's `midl.exe` compiler, and this in turn depends on `cl.exe`. I am not aware of any viable alternatives for these. The image includes an installation of Wine to allow running them.

* The scripts are reasonably commented to explain what's going on, so please feel free to read through them beforehand.
