/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * SmartBand sensors plus a BLE GATT peripheral.
 * Board overlay selects the I2C map: nRF52840 DK Arduino header, or
 * Pro Micro nRF52840 i2c0 (P1.00 SDA, P0.11 SCL).
 */

#include "band.h"
#include "ble.h"

#include <zephyr/drivers/gpio.h>
#include <zephyr/kernel.h>

#define LED0_NODE DT_ALIAS(led0)

static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED0_NODE, gpios);

struct band_metrics band = {
	.battery_pct = -1,
};

void band_init(void)
{
	k_mutex_init(&band.lock);
}

int main(void)
{
	bool led_ready = false;

	printk("SmartBand sensors and BLE\n");
	band_init();

	if (gpio_is_ready_dt(&led) && gpio_pin_configure_dt(&led, GPIO_OUTPUT_INACTIVE) == 0) {
		led_ready = true;
	}

	imu_start();
	ppg_start();
	ui_start();
	(void)ble_start();

	while (1) {
		if (led_ready) {
			(void)gpio_pin_toggle_dt(&led);
		}
		k_msleep(1000);
	}

	return 0;
}
