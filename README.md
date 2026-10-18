# SmartBand

nRF52840 activity-band firmware on Zephyr 4.4.2. The application lives in `app/`. Zephyr and the Nordic modules it needs are in `zephyr/` and `modules/`.

## Layout

```
app/            SmartBand application
zephyr/         Zephyr 4.4.2
modules/        cmsis_6, hal_nordic, segger
hardware/schematic/   KiCad rev A schematic
doc/            nRF52840 product specification and Nordic DK hardware files
app/west.yml    pins the Zephyr revision and module list
```

## Tree

`zephyr/` is Zephyr v4.4.2. `modules/` holds cmsis_6, hal_nordic, and segger, at the revisions in `app/west.yml`. `.west/config` makes this repository the west workspace, with the manifest in `app/` so the kernel tree is not detected as a Zephyr module.

Host tools and the Zephyr SDK are still required to compile. See the [Zephyr getting started guide](https://docs.zephyrproject.org/4.4.2/develop/getting_started/index.html).

`west build` and `west update` both expect `zephyr/` to be a git checkout whose `v4.4.2` tag contains `west.yml`. This snapshot does not include that `.git` metadata. To build here, initialize a git repository in `zephyr/`, commit `west.yml`, and tag that commit `v4.4.2`. To move to another revision, remove `zephyr/` and `modules/` first, then run `west update`.

## Build

The first board target is the nRF52840 Development Kit (`nrf52840dk/nrf52840`).

```
west build -b nrf52840dk/nrf52840 app
```

Flash a connected kit with `west flash`. Console output uses the kit's UART.

## Sensors

The image on the development kit is the phase-3 sensor slice. Breakouts share the Arduino I2C header (P0.26 SDA, P0.27 SCL). LSM6DSO is `0x6A` (SDO/SA0 low, CS high) and is sampled at 26 Hz with the gyro off. A peak on the dynamic acceleration counts a step. MAX30102 (`0x57`) runs a 20 s red-LED burst, the first one a few seconds after boot and then every 5 minutes, and the console prints the rate with `(motion)` when the wrist was not still. MAX17048 (`0x36`) supplies the battery percent. The SSD1306 (`0x3C`, reset on P1.11) stays blank until the button on P1.10; that press also pulses the haptic gate on P0.04, and the panel sleeps again after 8 seconds.

The rev A sheet labels P0.26 as SCL and P0.27 as SDA. This image follows the development kit header instead, so a breakout on that header matches the pins. P0.11 and P0.12 are the sheet's interrupt pins and the kit's buttons, so the firmware polls.
