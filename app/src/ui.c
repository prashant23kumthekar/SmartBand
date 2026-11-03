/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * OLED, the user button, and a short haptic tap.
 * The panel stays blank until the button wakes it, then sleeps again.
 */

#include "band.h"

#include <stdio.h>

#include <zephyr/device.h>
#include <zephyr/devicetree.h>
#include <zephyr/display/cfb.h>
#include <zephyr/drivers/display.h>
#include <zephyr/drivers/fuel_gauge.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/kernel.h>
#include <zephyr/sys/printk.h>

#define UI_AWAKE_MS    8000
#define UI_POLL_MS     20
#define UI_DRAW_MS     250
#define UI_BATTERY_MS  30000
#define HAPTIC_MS      80

#if DT_NODE_EXISTS(DT_PATH(zephyr_user)) && DT_NODE_HAS_PROP(DT_PATH(zephyr_user), button_gpios)
static const struct gpio_dt_spec button =
	GPIO_DT_SPEC_GET(DT_PATH(zephyr_user), button_gpios);
#endif

#if DT_NODE_EXISTS(DT_PATH(zephyr_user)) && DT_NODE_HAS_PROP(DT_PATH(zephyr_user), haptic_gpios)
static const struct gpio_dt_spec haptic =
	GPIO_DT_SPEC_GET(DT_PATH(zephyr_user), haptic_gpios);
#endif

#if DT_HAS_CHOSEN(zephyr_display)
static const struct device *const display = DEVICE_DT_GET(DT_CHOSEN(zephyr_display));
#endif

#if DT_HAS_ALIAS(fuel_gauge0)
static const struct device *const gauge = DEVICE_DT_GET(DT_ALIAS(fuel_gauge0));
#endif

static void haptic_pulse(void)
{
#if DT_NODE_EXISTS(DT_PATH(zephyr_user)) && DT_NODE_HAS_PROP(DT_PATH(zephyr_user), haptic_gpios)
	if (!gpio_is_ready_dt(&haptic)) {
		return;
	}
	gpio_pin_set_dt(&haptic, 1);
	k_msleep(HAPTIC_MS);
	gpio_pin_set_dt(&haptic, 0);
	printk("haptic tap\n");
#else
	printk("haptic pin is not configured\n");
#endif
}

static void battery_read(void)
{
#if DT_HAS_ALIAS(fuel_gauge0)
	union fuel_gauge_prop_val val;
	int ret;
	int pct;

	if (!device_is_ready(gauge)) {
		return;
	}

	ret = fuel_gauge_get_prop(gauge, FUEL_GAUGE_RELATIVE_STATE_OF_CHARGE, &val);
	if (ret < 0) {
		printk("battery read failed: %d\n", ret);
		return;
	}

	pct = val.relative_state_of_charge;
	k_mutex_lock(&band.lock, K_FOREVER);
	band.battery_pct = pct;
	k_mutex_unlock(&band.lock);
#else
	return;
#endif
}

static void format_lines(char lines[][20], int *hr_bpm, bool *hr_present, bool *hr_motion)
{
	uint32_t steps;
	int battery;
	int64_t uptime;
	uint32_t secs, mins, hours;

	k_mutex_lock(&band.lock, K_FOREVER);
	steps = band.steps;
	*hr_bpm = band.hr_bpm;
	*hr_present = band.hr_present;
	*hr_motion = band.hr_motion;
	battery = band.battery_pct;
	k_mutex_unlock(&band.lock);

	uptime = k_uptime_get() / 1000;
	secs = (uint32_t)(uptime % 60);
	mins = (uint32_t)((uptime / 60) % 60);
	hours = (uint32_t)((uptime / 3600) % 100);

	snprintf(lines[0], sizeof(lines[0]), "%02u:%02u:%02u", hours, mins, secs);
	snprintf(lines[1], sizeof(lines[1]), "steps %u", steps);
	if (!*hr_present) {
		snprintf(lines[2], sizeof(lines[2]), "HR --");
	} else if (*hr_motion) {
		snprintf(lines[2], sizeof(lines[2]), "HR %d mov", *hr_bpm);
	} else {
		snprintf(lines[2], sizeof(lines[2]), "HR %d", *hr_bpm);
	}
	if (battery < 0) {
		snprintf(lines[3], sizeof(lines[3]), "bat --");
	} else {
		snprintf(lines[3], sizeof(lines[3]), "bat %d%%", battery);
	}
}

static void ui_thread(void *p1, void *p2, void *p3)
{
	bool awake = false;
	bool button_ready = false;
	bool display_ready = false;
	int last_level = 1;
	int64_t awake_until = 0;
	int64_t next_draw = 0;
	int64_t next_battery = 0;
	uint8_t font_h = 16;
	int debounce = 0;

	ARG_UNUSED(p1);
	ARG_UNUSED(p2);
	ARG_UNUSED(p3);

#if DT_NODE_EXISTS(DT_PATH(zephyr_user)) && DT_NODE_HAS_PROP(DT_PATH(zephyr_user), button_gpios)
	if (gpio_is_ready_dt(&button) &&
	    gpio_pin_configure_dt(&button, GPIO_INPUT) == 0) {
		button_ready = true;
	} else {
		printk("button is not ready\n");
	}
#endif

#if DT_NODE_EXISTS(DT_PATH(zephyr_user)) && DT_NODE_HAS_PROP(DT_PATH(zephyr_user), haptic_gpios)
	if (!gpio_is_ready_dt(&haptic) ||
	    gpio_pin_configure_dt(&haptic, GPIO_OUTPUT_INACTIVE) < 0) {
		printk("haptic pin is not ready\n");
	}
#endif

#if DT_HAS_CHOSEN(zephyr_display)
	if (device_is_ready(display) && cfb_framebuffer_init(display) == 0) {
		uint8_t width = 0;

		display_ready = true;
		(void)cfb_get_font_size(display, 0, &width, &font_h);
		(void)cfb_framebuffer_set_font(display, 0);
		(void)display_blanking_on(display);
		printk("OLED asleep until the button\n");
	} else {
		printk("OLED absent, metrics stay on the console\n");
	}
#else
	printk("OLED node is not in this board\n");
#endif

	while (1) {
		int64_t now = k_uptime_get();
		char lines[4][20];
		int hr_bpm = 0;
		bool hr_present = false;
		bool hr_motion = false;

		if (button_ready) {
			int level = gpio_pin_get_dt(&button);

			if (level < 0) {
				level = 1;
			}
			if (level == 0 && last_level == 1) {
				debounce++;
				if (debounce >= 2) {
					awake = true;
					awake_until = now + UI_AWAKE_MS;
					last_level = 0;
					debounce = 0;
#if DT_HAS_CHOSEN(zephyr_display)
					if (display_ready) {
						(void)display_blanking_off(display);
					}
#endif
					haptic_pulse();
					next_draw = now;
				}
			} else if (level != 0) {
				debounce = 0;
				last_level = 1;
			}
		}

		if (awake && now >= awake_until) {
			awake = false;
#if DT_HAS_CHOSEN(zephyr_display)
			if (display_ready) {
				(void)display_blanking_on(display);
				printk("OLED asleep\n");
			}
#endif
		}

		if (now >= next_battery) {
			battery_read();
			next_battery = now + UI_BATTERY_MS;
		}

		if (now >= next_draw) {
			format_lines(lines, &hr_bpm, &hr_present, &hr_motion);
			if (!display_ready) {
				printk("%s  %s  %s  %s\n", lines[0], lines[1], lines[2], lines[3]);
			}
#if DT_HAS_CHOSEN(zephyr_display)
			else if (awake) {
				(void)cfb_framebuffer_clear(display, false);
				for (int i = 0; i < 4; i++) {
					(void)cfb_print(display, lines[i], 0, i * font_h);
				}
				(void)cfb_framebuffer_finalize(display);
			}
#endif
			next_draw = now + (display_ready ? UI_DRAW_MS : 1000);
		}

		k_msleep(UI_POLL_MS);
	}
}

static K_THREAD_STACK_DEFINE(ui_stack, 2048);
static struct k_thread ui_thread_data;

void ui_start(void)
{
	k_thread_create(&ui_thread_data, ui_stack, K_THREAD_STACK_SIZEOF(ui_stack),
			ui_thread, NULL, NULL, NULL, K_PRIO_PREEMPT(9), 0, K_NO_WAIT);
	k_thread_name_set(&ui_thread_data, "ui");
}
