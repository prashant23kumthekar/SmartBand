# SmartBand

nRF52840 activity-band firmware on Zephyr 4.4.2. The application lives in `app/`. Zephyr and the Nordic modules it needs are in `zephyr/` and `modules/`.

## Layout

```
app/            SmartBand application
zephyr/         Zephyr 4.4.2
modules/        cmsis_6, hal_nordic, segger
doc/            nRF52840 product specification and Nordic DK hardware files
app/west.yml    pins the Zephyr revision and module list
```

## Tree

`zephyr/` is Zephyr v4.4.2. `modules/` holds cmsis_6, hal_nordic, and segger, at the revisions in `app/west.yml`. `.west/config` makes this repository the west workspace, with the manifest in `app/` so the kernel tree is not detected as a Zephyr module.

Host tools and the Zephyr SDK are still required to compile. See the [Zephyr getting started guide](https://docs.zephyrproject.org/4.4.2/develop/getting_started/index.html).

`west update` expects those directories to be west git clones. This snapshot does not include their `.git` metadata. To move to another revision, remove `zephyr/` and `modules/` first, then run `west update`.

## Build

The first board target is the nRF52840 Development Kit (`nrf52840dk/nrf52840`).

```
west build -b nrf52840dk/nrf52840 app
```

Flash a connected kit with `west flash`. Console output uses the kit's UART.
