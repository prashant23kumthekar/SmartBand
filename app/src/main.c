/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * SmartBand application entry point.
 * Target: nrf52840dk/nrf52840 until a custom board exists.
 */

#include <zephyr/kernel.h>
#include <zephyr/drivers/gpio.h>

#define SLEEP_TIME_MS 1000

#define LED0_NODE DT_ALIAS(led0)

static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED0_NODE, gpios);

int main(void)
{
	int ret;

	printk("SmartBand booted\n");

	if (!gpio_is_ready_dt(&led)) {
		printk("LED device is not ready\n");
		return 0;
	}

	ret = gpio_pin_configure_dt(&led, GPIO_OUTPUT_ACTIVE);
	if (ret < 0) {
		printk("LED configure failed: %d\n", ret);
		return 0;
	}

	while (1) {
		ret = gpio_pin_toggle_dt(&led);
		if (ret < 0) {
			printk("LED toggle failed: %d\n", ret);
			return 0;
		}

		k_msleep(SLEEP_TIME_MS);
	}

	return 0;
}
