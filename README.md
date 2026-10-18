# SmartBand

nRF52840 activity-band firmware on Zephyr 4.4.2. The application lives in `app/`. Zephyr and the Nordic modules it needs are checked out beside it (`zephyr/`, `modules/`) by west. Those trees are not stored in git.

## Layout

```
app/            SmartBand application
zephyr/         Zephyr 4.4.2
modules/        cmsis_6, hal_nordic, segger
doc/            nRF52840 product specification and Nordic DK hardware files
app/west.yml    pins the Zephyr revision and module list
```

## Get the code

From a fresh clone, with [west](https://docs.zephyrproject.org/latest/develop/west/index.html) installed:

```
west update
```

That checks out Zephyr v4.4.2 and the modules listed in `app/west.yml` (cmsis_6, hal_nordic, segger). `.west/config` already points this repository at that manifest. The manifest lives in `app/` so the Zephyr tree can sit next to the application without being detected as a Zephyr module.

Host tools and the Zephyr SDK are still required to compile. See the [Zephyr getting started guide](https://docs.zephyrproject.org/4.4.2/develop/getting_started/index.html).

## Build

The first board target is the nRF52840 Development Kit (`nrf52840dk/nrf52840`).

```
west build -b nrf52840dk/nrf52840 app
```

Flash a connected kit with `west flash`. Console output uses the kit's UART.

To refresh Zephyr from `app/west.yml`:

```
west update
```
