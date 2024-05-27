# image-builder

This repo contains script to build a `.iso` file to install customized Ubuntu for ICPC contests.

# Usage

## Prerequisites

> Note: The builder will require root access and may bind, use, and alternate two folders `/dev/` and `/run/`. If an error occurs during the run and the builder is not able to unmount the folders, it will be necessary to perform a physical hard reboot. Therefore, **it is recommended to run the builder in a virtual machine**.

The builder requires a Linux system with at least 80GB of free storage and 4GB of RAM. The builder is tested on Ubuntu 20.04 LTS and 22.04 LTS.

In case you want to build on a virtual machine, it is recommended to use VirtualBox, with **FIXED SIZE STORAGE** of at least 80GB and **4GB of RAM**.

First, pull the repository and enter the directory:

```bash
git clone https://github.com/VNOI-Admin/image-builder.git
cd image-builder
```

## Configuration

After cloning the repository, you need to configure the builder. There are several files that need to be configured before building the image:

- `config.local.sh`: A local copy of `config.sh` with personal configuration. This contains two important configuration variables:
  - `ICPC_URL`: The URL to the ICPC ISO file. The ICPC Global may release new version of the ISO file that may overwrite the old one. Therefore, if errors related to failed download occur, please update this variable.
  - `SUPER_PASSWD`: The password for the `root` user and bootloader.
- `image-toolkit/config.sh`: This a local copy of `image-toolkit/config.sh` with machine-wide configuration. This contains several important configuration variables:
  - `WEBSERVER_PUBLIC_ADDRESS`: The public address of the webserver, commonly for the backup server. This is accessible by the contestants without the need of VPN, therefore should only be used in case of VPN failure.
  - `VPN_CORE_ADDRESS`: The public address of the authentication and VPN central server.
  - `ADMIN_SUBNET`: The subnet of the admin network. This is used to configure the firewall to allow access to the admin network.
  - `COACH_SUBNET`: The subnet of the coach network. This is used to configure the firewall to allow access to the coach network.
- `image-toolkit/config.local.sh`: This is an optional configuration file of `image-toolkit/config.local.sh`. By setting the `VERSION` variable, it will store the version of the build to the image. Useful for debugging and tracking the version of the image.
- `image-toolkit/misc/logo.png` (optional): Replace the Ubuntu logo on boot screen and login screen with a custom one (the dimension should be 400x400 or smaller).

## Building

To build the image for ICPC contests, run the following command:

```bash
sudo ./build.sh icpc_build
```

In case you want to use a specific version of the original ICPC ISO file, you can put the file inside the folder and rename it to `icpc-image.iso`. The builder will automatically use the file instead of downloading from the ICPC Global website.

In case you want to forcefully download the original ICPC ISO file, you can run the following command:

```bash
sudo ./build.sh icpc_build --force
```

In case you want to optimize the build process, you can run the following command:

```bash
sudo ./build.sh icpc_build --github-action
```

This will automatically remove files that are not needed in the final stage of the build process. Should only be used in CI/CD environment or building on systems with limited storage, not for development.
