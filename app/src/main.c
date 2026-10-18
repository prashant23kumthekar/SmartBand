/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * SmartBand phase 3: IMU steps, a heart-rate burst, and a sleeping OLED.
 * Target: nrf52840dk/nrf52840 with the Arduino-header overlay.
 */

#include "band.h"

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

	printk("SmartBand sensors\n");
	band_init();

	if (gpio_is_ready_dt(&led) && gpio_pin_configure_dt(&led, GPIO_OUTPUT_INACTIVE) == 0) {
		led_ready = true;
	}

	imu_start();
	ppg_start();
	ui_start();

	while (1) {
		if (led_ready) {
			(void)gpio_pin_toggle_dt(&led);
		}
		k_msleep(1000);
	}

	return 0;
}
