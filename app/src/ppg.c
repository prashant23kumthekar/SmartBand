/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Seated heart-rate burst from the MAX30102 red LED.
 * The Zephyr MAX30101 driver owns the chip (same part id, red channel).
 * Samples taken while the IMU reports motion are kept and marked, not dropped.
 */

#include "band.h"

#include <zephyr/device.h>
#include <zephyr/devicetree.h>
#include <zephyr/drivers/i2c.h>
#include <zephyr/drivers/sensor.h>
#include <zephyr/kernel.h>
#include <zephyr/sys/printk.h>

#define PPG_REG_INT_STS1 0x00
#define PPG_REG_FIFO_WR  0x04
#define PPG_REG_FIFO_RD  0x06
#define PPG_REG_MODE_CFG 0x09
#define PPG_INT_PPG_RDY  BIT(6)
#define PPG_MODE_HR      0x02
#define PPG_MODE_SHDN    0x80

#define PPG_FIRST_DELAY_MS  3000
#define PPG_PERIOD_MS       (5 * 60 * 1000)
#define PPG_BURST_MS        20000
#define PPG_SETTLE_MS       1000
#define PPG_MIN_INTERVAL_MS 333
#define PPG_MAX_INTERVAL_MS 1500
#define PPG_MIN_PEAKS       6
#define PPG_MAX_INTERVALS   48

#if DT_HAS_COMPAT_STATUS_OKAY(maxim_max30101)

static const struct i2c_dt_spec ppg_i2c =
	I2C_DT_SPEC_GET(DT_COMPAT_GET_ANY_STATUS_OKAY(maxim_max30101));
static const struct device *const ppg_dev = DEVICE_DT_GET(
	DT_COMPAT_GET_ANY_STATUS_OKAY(maxim_max30101));

static int ppg_mode(uint8_t mode)
{
	return i2c_reg_write_byte_dt(&ppg_i2c, PPG_REG_MODE_CFG, mode);
}

static int ppg_fifo_reset(void)
{
	int ret;

	ret = i2c_reg_write_byte_dt(&ppg_i2c, PPG_REG_FIFO_WR, 0x00);
	if (ret == 0) {
		ret = i2c_reg_write_byte_dt(&ppg_i2c, PPG_REG_FIFO_RD, 0x00);
	}
	return ret;
}

static int interval_median(int *values, int count)
{
	for (int i = 1; i < count; i++) {
		int v = values[i];
		int j = i;

		while (j > 0 && values[j - 1] > v) {
			values[j] = values[j - 1];
			j--;
		}
		values[j] = v;
	}

	return values[count / 2];
}

static int ppg_burst(void)
{
	int intervals[PPG_MAX_INTERVALS];
	int n_intervals = 0;
	int samples = 0;
	int moving_samples = 0;
	int32_t dc = 0;
	int32_t prev_ac = 0;
	int32_t env = 0;
	bool rising = false;
	bool dc_ready = false;
	int64_t last_peak_ms = 0;
	int64_t start;
	int ret;

	ret = ppg_mode(PPG_MODE_HR);
	if (ret < 0) {
		return ret;
	}
	ret = ppg_fifo_reset();
	if (ret < 0) {
		return ret;
	}

	k_msleep(PPG_SETTLE_MS);
	start = k_uptime_get();

	while ((k_uptime_get() - start) < PPG_BURST_MS) {
		uint8_t status = 0;
		struct sensor_value red;
		int32_t sample, ac;
		bool moving;
		int64_t now;

		ret = i2c_reg_read_byte_dt(&ppg_i2c, PPG_REG_INT_STS1, &status);
		if (ret < 0) {
			break;
		}
		if ((status & PPG_INT_PPG_RDY) == 0) {
			k_msleep(2);
			continue;
		}

		ret = sensor_sample_fetch(ppg_dev);
		if (ret < 0) {
			break;
		}
		ret = sensor_channel_get(ppg_dev, SENSOR_CHAN_RED, &red);
		if (ret < 0) {
			break;
		}

		sample = red.val1;
		samples++;
		if (!dc_ready) {
			dc = sample;
			dc_ready = true;
			prev_ac = 0;
			continue;
		}
		dc += (sample - dc) / 32;
		ac = sample - dc;
		if (ac > env) {
			env = ac;
		} else {
			env -= env / 64;
		}

		k_mutex_lock(&band.lock, K_FOREVER);
		moving = band.moving;
		k_mutex_unlock(&band.lock);
		if (moving) {
			moving_samples++;
		}

		now = k_uptime_get();
		if (ac > prev_ac && ac > (env / 3) && ac > 200) {
			rising = true;
		} else if (rising && ac < prev_ac) {
			int64_t dt = now - last_peak_ms;

			rising = false;
			if (last_peak_ms != 0 && dt >= PPG_MIN_INTERVAL_MS &&
			    dt <= PPG_MAX_INTERVAL_MS && n_intervals < PPG_MAX_INTERVALS) {
				intervals[n_intervals++] = (int)dt;
			}
			last_peak_ms = now;
		}
		prev_ac = ac;
	}

	(void)ppg_mode(PPG_MODE_SHDN);

	if (ret < 0) {
		printk("PPG burst failed: %d\n", ret);
		return ret;
	}

	{
		bool motion = samples > 0 && (moving_samples * 4) >= samples;
		int bpm = 0;
		bool present = false;

		if (n_intervals >= PPG_MIN_PEAKS) {
			int median = interval_median(intervals, n_intervals);

			bpm = 60000 / median;
			present = true;
		}

		k_mutex_lock(&band.lock, K_FOREVER);
		band.hr_bpm = bpm;
		band.hr_present = present;
		band.hr_motion = motion;
		k_mutex_unlock(&band.lock);

		if (!present) {
			printk("HR none after %d samples, %d peaks%s\n", samples, n_intervals,
			       motion ? " (motion)" : "");
		} else {
			printk("HR %d bpm%s\n", bpm, motion ? " (motion)" : "");
		}
	}

	return 0;
}

static void ppg_thread(void *p1, void *p2, void *p3)
{
	ARG_UNUSED(p1);
	ARG_UNUSED(p2);
	ARG_UNUSED(p3);

	if (!device_is_ready(ppg_dev)) {
		printk("PPG absent, heart-rate burst idle\n");
		return;
	}

	/* The driver leaves the red LED running. Hold it off between bursts. */
	if (ppg_mode(PPG_MODE_SHDN) < 0) {
		printk("PPG shutdown failed\n");
		return;
	}
	printk("PPG red LED off until the first burst\n");

	k_msleep(PPG_FIRST_DELAY_MS);

	while (1) {
		(void)ppg_burst();
		k_msleep(PPG_PERIOD_MS);
	}
}

static K_THREAD_STACK_DEFINE(ppg_stack, 2048);
static struct k_thread ppg_thread_data;

void ppg_start(void)
{
	k_thread_create(&ppg_thread_data, ppg_stack, K_THREAD_STACK_SIZEOF(ppg_stack),
			ppg_thread, NULL, NULL, NULL, K_PRIO_PREEMPT(8), 0, K_NO_WAIT);
	k_thread_name_set(&ppg_thread_data, "ppg");
}

#else

void ppg_start(void)
{
	printk("PPG node is not in this board\n");
}

#endif
