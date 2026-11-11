# SmartBand

nRF52840 activity-band firmware on Zephyr 4.4.2. The application lives in `app/`. Zephyr and the Nordic modules it needs are in `zephyr/` and `modules/`.

## Layout

```
app/            SmartBand application
app/ble/        BLE advertising and GATT services
zephyr/         Zephyr 4.4.2
modules/        cmsis_6, hal_nordic, segger
hardware/schematic/   KiCad rev A schematic
doc/            nRF52840 product specification and Nordic DK hardware files
app/west.yml    pins the Zephyr revision and module list
```

## New PC: host tools

These steps match Ubuntu 22.04/24.04. Other OS: follow the [Zephyr 4.4.2 getting started guide](https://docs.zephyrproject.org/4.4.2/develop/getting_started/index.html), then continue from **New PC: clone and workspace** below.

Zephyr 4.4.2 needs **Python 3.12+**, CMake 3.20+, west, Ninja, Device Tree compiler, and the **Zephyr SDK 1.0.1** `arm-zephyr-eabi` toolchain.

```
sudo apt update
sudo apt install --no-install-recommends git cmake ninja-build gperf \
  ccache dfu-util device-tree-compiler wget python3 python3-pip \
  python3-venv python3-dev python3-setuptools python3-wheel \
  xz-utils file make gcc gcc-multilib libsdl2-dev libmagic1

# Ubuntu 22.04 ships Python 3.10. Install 3.12 if `python3 --version` is below 3.12:
sudo apt install python3.12 python3.12-venv python3.12-dev
```

Create a venv and install west (do not use the system Python 3.10):

```
python3.12 -m venv $HOME/zephyr-venv
source $HOME/zephyr-venv/bin/activate
pip install -U pip
pip install west
```

Add yourself to `dialout` so UART adapters and the DK VCOM port work without sudo, then log out and back in:

```
sudo usermod -aG dialout $USER
```

### Zephyr SDK 1.0.1

Download the GNU toolchain bundle from the [sdk-ng 1.0.1 release](https://github.com/zephyrproject-rtos/sdk-ng/releases/tag/v1.0.1). Example (Linux x86_64):

```
cd $HOME
wget https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v1.0.1/zephyr-sdk-1.0.1_linux-x86_64_gnu.tar.xz
tar xf zephyr-sdk-1.0.1_linux-x86_64_gnu.tar.xz
cd zephyr-sdk-1.0.1
./setup.sh -t arm-zephyr-eabi -h -c
```

`-t arm-zephyr-eabi` is enough for nRF52840. `-h` installs host tools (dtc). `-c` registers the CMake package.

```
export ZEPHYR_SDK_INSTALL_DIR=$HOME/zephyr-sdk-1.0.1
```

Put that export in `~/.bashrc` (or pass it on every `west build`).

## New PC: clone and workspace

```
source $HOME/zephyr-venv/bin/activate
export ZEPHYR_SDK_INSTALL_DIR=$HOME/zephyr-sdk-1.0.1

git clone https://github.com/prashant23kumthekar/SmartBand.git
cd SmartBand
pip install -r zephyr/scripts/requirements-base.txt
```

This repository is already a west workspace (`.west/config` points at `app/west.yml`). The kernel and modules are vendored under `zephyr/` and `modules/`. You do **not** run `west init`.

`west build` still expects `zephyr/` to be a git checkout tagged `v4.4.2`. A GitHub clone often has no `zephyr/.git`. One-time fix:

```
cd zephyr
git init
git add west.yml
git commit -m "Zephyr v4.4.2 snapshot"
git tag v4.4.2
cd ..
```

If `west build` then fails on missing `zephyr/drivers/i2c/target` or `Kconfig.swo`, those paths were ignored by Zephyr's `.gitignore`. Restore them from the v4.4.2 tree or keep the copies already in this repo.

To refresh Zephyr from GitHub instead of the snapshot: remove `zephyr/` and `modules/`, then `west update`.

## Build

From the repository root, with the venv active and `ZEPHYR_SDK_INSTALL_DIR` set.

nRF52840 Development Kit:

```
west build -p -b nrf52840dk/nrf52840 app
```

Pro Micro / Nice!Nano-style nRF52840 (Adafruit UF2 bootloader — typical):

```
west build -p -b promicro_nrf52840/nrf52840/uf2 app
```

Same board over SWD (no UF2, rear debug pads):

```
west build -p -b promicro_nrf52840/nrf52840 app
```

First-time CMake picks up `app/boards/<board>.overlay`. Rebuild after overlay or `prj.conf` edits with `-p`, or `west build -t clean` then build again.

## Flash / reflash

### nRF52840 DK

USB cable to the **debug** USB port. J-Link on the kit enumerates as a debugger.

```
west flash
```

To force a full chip erase and reflash:

```
west flash --erase
```

### Promicro (UF2)

1. Build the `/uf2` target above.
2. Short **GND** and **RST** twice quickly (or double-tap the reset button). The LED should breathe; a USB mass-storage drive appears.
3. Flash:

```
west flash
```

or copy the image onto the drive:

```
cp build/zephyr/zephyr.uf2 /media/$USER/<UF2-VOLUME>/
```

If the bootloader is gone, recover over SWD on the rear pads (SWDIO, SWCLK, GND, 3.3 V) with a J-Link or Raspberry Pi Debug Probe, using the non-UF2 board target and `west flash`.

### Promicro (SWD)

```
west build -p -b promicro_nrf52840/nrf52840 app
west flash
```

Reconnect USB or power-cycle after a failed flash. Do not flash a UF2 image with an SWD-only layout (or the reverse) unless you intend to replace the bootloader.

## UART debug

`printk` and the Zephyr console are 115200 8N1. `CONFIG_UART_CONSOLE` is already on in `app/prj.conf`.

### nRF52840 DK

The onboard J-Link provides a USB serial port (often `/dev/ttyACM0`). No extra wiring.

```
west build -p -b nrf52840dk/nrf52840 app
west flash
picocom -b 115200 /dev/ttyACM0
```

(`minicom -D /dev/ttyACM0 -b 115200` also works.) You should see `SmartBand sensors and BLE`, IMU/PPG lines, and `Advertising as SmartBand`.

### Promicro UART pins

Default Promicro firmware logs on **USB CDC**, not UART. For a USB–UART adapter (3.3 V logic only):

| Adapter | Promicro |
|---|---|
| RX | **P0.09** (UART TX) |
| TX | **P0.10** (UART RX) |
| GND | GND |
| VCC | do not feed 5 V into a pin |

Rebuild so the console is UART0:

```
west build -p -b promicro_nrf52840/nrf52840/uf2 app -- \
  -DEXTRA_DTC_OVERLAY_FILE=debug_uart.overlay
west flash
picocom -b 115200 /dev/ttyUSB0
```

`app/debug_uart.overlay` sets `zephyr,console` to `&uart0`. Use `/dev/ttyACM0` if your adapter enumerates as ACM. USB CDC may still appear; UART is the log port after this overlay.

### SWD stepping plus UART

Leave the UART adapter connected. Attach a debug probe to SWDIO / SWCLK / GND / 3V3 (Promicro rear pads, or the DK onboard J-Link).

```
west debug
```

Or, with a CMSIS-DAP probe such as the Raspberry Pi Debug Probe:

```
west debug --runner pyocd
```

GDB stops at `main` when the runner supports it; UART keeps streaming `printk` in the other terminal. `west attach` connects without a reset if the image is already running.

RTT is optional (`CONFIG_USE_SEGGER_RTT`); this tree vendors Segger for the DK. UART is the path documented here.

## Sensors

All four parts stay on **I2C**. Do not solder them to the Promicro SPI pins; MAX30102 and MAX17048 have no SPI, and this firmware does not talk SPI.

LSM6DSO is `0x6A` (SDO/SA0 low, **CS tied to VDD**) at 26 Hz with the gyro off. A peak on the dynamic acceleration counts a step. MAX30102 (`0x57`) runs a 20 s red-LED burst, the first one a few seconds after boot and then every 5 minutes. MAX17048 (`0x36`) supplies the battery percent; its CELL pin must see the cell, not 3.3 V. The SSD1306 (`0x3C`) stays blank until the button; that press also pulses the haptic gate, and the panel sleeps again after 8 seconds.

### nRF52840 DK

Arduino I2C header P0.26 SDA, P0.27 SCL. Button P1.10, OLED reset P1.11, haptic P0.04. Overlay: `app/boards/nrf52840dk_nrf52840.overlay`.

The rev A sheet labels P0.26 as SCL and P0.27 as SDA. The DK overlay follows the kit header.

### Pro Micro nRF52840

Solder to the board I2C0 pins and add **4.7 kΩ pull-ups** to 3.3 V (the DK header had pull-ups; this board usually does not). Overlay: `app/boards/promicro_nrf52840_nrf52840.overlay` (UF2: `..._uf2.overlay`).

| Signal | Promicro pin | Notes |
|---|---|---|
| SDA | P1.00 | shared by all four chips |
| SCL | P0.11 | |
| OLED reset | P1.11 | active low |
| Button | P1.13 | to GND, internal pull-up |
| Haptic | P0.24 | MOSFET gate, active high |
| 3V3, GND | VCC / GND | |

DK P1.10 and P0.04 are not on this header, so the overlay does not keep them.

## BLE

The same image advertises as `SmartBand`. nRF Connect can read Heart Rate, Battery, Device Information, and a custom activity service (`fb5a0001-6c4b-4a5a-9f10-b1c2d3e4f500`) with a step count and a moving flag. Enabling notifications on those characteristics streams live values. Pairing is not required.
