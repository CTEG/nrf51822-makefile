**this is a working document**

# nrf51822-makefile #

+Makefile template for nrf51822 using pure gcc, copied and modified from hlnd:nrf51-pure-gcc-setup+

This script was test under,
```bash
JLinkExe 4.80 (from segger.com)
arm-none-eabi-gcc 4.9.0 (via pacman)
nrf51822 SDK v5.2.0 39364 (official)
s110 6.0.0-5 beta, s120 0.8.0-3 alpha
```
and make sure you have these folders specified in `Makefile.config`, where
```makefile
SDK_PATH = $(HOME)/bin/nrf51_sdk_v5_2_0_39364/Nordic/nrf51822
SOC_PATH = $(HOME)/bin/nrf51_softdevice
PROG_ROOT := $(HOME)/bin/jlink
GNU_INSTALL_ROOT := /usr
```

## How to use ##
just follows
```bash
$ cd blinky_example
$ mkdir gcc
$ cd gcc
$ ln -sf ../../Makefile
$ ln -sf ../../Makefile.config.simple Makefile.config
$ make all
$ make erase-all
$ make flash
```

you can directly use `Makefile.config.ble` in `s110/ble_app_hrs`, and
```bash
$ make clean
$ make all
$ make flash-softdevice
$ make flash
```
`make flash-softdevice` will automatically `make erase-all` before programming.


