/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * LSM6DSO accelerometer at 26 Hz and a peak step counter.
 * Gyro stays off. The ST Zephyr driver needs hal_st, which this tree does
 * not vendor, so the registers are programmed from the application.
 */

#include "band.h"

#include <math.h>
#include <stdlib.h>

#include <zephyr/device.h>
#include <zephyr/devicetree.h>
#include <zephyr/drivers/i2c.h>
#include <zephyr/kernel.h>
#include <zephyr/sys/printk.h>

#define LSM6DSO_REG_WHOAMI  0x0F
#define LSM6DSO_WHOAMI      0x6C
#define LSM6DSO_REG_CTRL1_XL 0x10
#define LSM6DSO_REG_CTRL2_G  0x11
#define LSM6DSO_REG_CTRL3_C  0x12
#define LSM6DSO_REG_CTRL6_C  0x15
#define LSM6DSO_REG_STATUS   0x1E
#define LSM6DSO_REG_OUTX_L_A 0x28

/* 26 Hz, ±2 g. XL_HM_MODE = 1 selects the low-power accelerometer path. */
#define LSM6DSO_CTRL1_26HZ_2G 0x20
#define LSM6DSO_CTRL3_BDU_INC 0x44
#define LSM6DSO_CTRL6_LP      0x10

/* 1 LSB at ±2 g is 0.061 mg, about 0.598 mm/s^2. */
#define LSM6DSO_MM_S2_NUM 598
#define LSM6DSO_MM_S2_DEN 1000

#define STEP_PEAK_MM_S2     1200
#define STEP_REARM_MM_S2    400
#define STEP_MIN_INTERVAL_MS 300
#define MOVE_MM_S2          400
#define IMU_PERIOD_MS       38

#if DT_HAS_COMPAT_STATUS_OKAY(smartband_lsm6dso)

static const struct i2c_dt_spec imu_i2c =
	I2C_DT_SPEC_GET(DT_COMPAT_GET_ANY_STATUS_OKAY(smartband_lsm6dso));

static int32_t raw_to_mm_s2(int16_t raw)
{
	return ((int32_t)raw * LSM6DSO_MM_S2_NUM) / LSM6DSO_MM_S2_DEN;
}

static int imu_configure(void)
{
	uint8_t who = 0;
	int ret;

	if (!i2c_is_ready_dt(&imu_i2c)) {
		printk("IMU bus is not ready\n");
		return -ENODEV;
	}

	ret = i2c_reg_read_byte_dt(&imu_i2c, LSM6DSO_REG_WHOAMI, &who);
	if (ret < 0) {
		printk("IMU whoami read failed: %d\n", ret);
		return ret;
	}
	if (who != LSM6DSO_WHOAMI) {
		printk("IMU whoami 0x%02x, expected 0x%02x\n", who, LSM6DSO_WHOAMI);
		return -ENODEV;
	}

	ret = i2c_reg_write_byte_dt(&imu_i2c, LSM6DSO_REG_CTRL3_C, LSM6DSO_CTRL3_BDU_INC);
	if (ret == 0) {
		ret = i2c_reg_write_byte_dt(&imu_i2c, LSM6DSO_REG_CTRL2_G, 0x00);
	}
	if (ret == 0) {
		ret = i2c_reg_write_byte_dt(&imu_i2c, LSM6DSO_REG_CTRL6_C, LSM6DSO_CTRL6_LP);
	}
	if (ret == 0) {
		ret = i2c_reg_write_byte_dt(&imu_i2c, LSM6DSO_REG_CTRL1_XL, LSM6DSO_CTRL1_26HZ_2G);
	}
	if (ret < 0) {
		printk("IMU configure failed: %d\n", ret);
		return ret;
	}

	printk("LSM6DSO accel 26 Hz, gyro off\n");
	return 0;
}

static int imu_read(int32_t *x, int32_t *y, int32_t *z)
{
	uint8_t status = 0;
	uint8_t raw[6];
	int16_t sx, sy, sz;
	int ret;

	ret = i2c_reg_read_byte_dt(&imu_i2c, LSM6DSO_REG_STATUS, &status);
	if (ret < 0) {
		return ret;
	}
	if ((status & BIT(0)) == 0) {
		return -EAGAIN;
	}

	ret = i2c_burst_read_dt(&imu_i2c, LSM6DSO_REG_OUTX_L_A, raw, sizeof(raw));
	if (ret < 0) {
		return ret;
	}

	sx = (int16_t)((raw[1] << 8) | raw[0]);
	sy = (int16_t)((raw[3] << 8) | raw[2]);
	sz = (int16_t)((raw[5] << 8) | raw[4]);
	*x = raw_to_mm_s2(sx);
	*y = raw_to_mm_s2(sy);
	*z = raw_to_mm_s2(sz);
	return 0;
}

static void imu_thread(void *p1, void *p2, void *p3)
{
	int32_t grav = 0;
	bool grav_ready = false;
	bool step_armed = true;
	uint8_t move_hold = 0;
	int64_t last_step_ms = 0;
	uint32_t ticks = 0;
	int ret;

	ARG_UNUSED(p1);
	ARG_UNUSED(p2);
	ARG_UNUSED(p3);

	ret = imu_configure();
	if (ret < 0) {
		printk("IMU absent, step counter idle\n");
		return;
	}

	while (1) {
		int32_t x, y, z, dyn, mag_i;
		float mag;
		bool moving;
		uint32_t steps = 0;
		bool stepped = false;

		ret = imu_read(&x, &y, &z);
		if (ret == -EAGAIN) {
			k_msleep(5);
			continue;
		}
		if (ret < 0) {
			printk("IMU read failed: %d\n", ret);
			k_msleep(IMU_PERIOD_MS);
			continue;
		}

		mag = sqrtf((float)x * (float)x + (float)y * (float)y + (float)z * (float)z);
		mag_i = (int32_t)mag;
		if (!grav_ready) {
			grav = mag_i;
			grav_ready = true;
		} else {
			grav += (mag_i - grav) / 16;
		}
		dyn = mag_i - grav;

		if (abs(dyn) > MOVE_MM_S2) {
			move_hold = 8;
		} else if (move_hold > 0) {
			move_hold--;
		}
		moving = move_hold > 0;

		if (step_armed && dyn > STEP_PEAK_MM_S2) {
			int64_t now = k_uptime_get();

			if ((now - last_step_ms) >= STEP_MIN_INTERVAL_MS) {
				last_step_ms = now;
				stepped = true;
			}
			step_armed = false;
		} else if (dyn < STEP_REARM_MM_S2) {
			step_armed = true;
		}

		k_mutex_lock(&band.lock, K_FOREVER);
		if (stepped) {
			band.steps++;
		}
		band.moving = moving;
		steps = band.steps;
		k_mutex_unlock(&band.lock);

		ticks++;
		if (stepped || (ticks % 26) == 0) {
			printk("accel %d %d %d mm/s2 steps %u%s\n", x, y, z, steps,
			       moving ? " moving" : "");
		}

		k_msleep(IMU_PERIOD_MS);
	}
}

static K_THREAD_STACK_DEFINE(imu_stack, 1536);
static struct k_thread imu_thread_data;

void imu_start(void)
{
	k_thread_create(&imu_thread_data, imu_stack, K_THREAD_STACK_SIZEOF(imu_stack),
			imu_thread, NULL, NULL, NULL, K_PRIO_PREEMPT(7), 0, K_NO_WAIT);
	k_thread_name_set(&imu_thread_data, "imu");
}

#else

void imu_start(void)
{
	printk("IMU node is not in this board\n");
}

#endif
