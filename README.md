# image-builder
This repo contains script to build a `.iso` file to install customized Ubuntu.

# Usage
Firstly, make a copy of `config.sh` called `local_config.sh` and change its content. You will want to change the `MIRROR` for faster installation.

Then, run `./build.sh build` as `root`.

Install the `.iso` file on required machines, then head to `src/` for more information.