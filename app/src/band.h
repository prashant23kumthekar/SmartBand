/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Shared metrics for the phase-3 sensor slice.
 */

#ifndef BAND_H_
#define BAND_H_

#include <stdbool.h>
#include <stdint.h>

#include <zephyr/kernel.h>

struct band_metrics {
	struct k_mutex lock;
	uint32_t steps;
	bool moving;
	int hr_bpm;
	bool hr_present;
	bool hr_motion;
	int battery_pct;
};

extern struct band_metrics band;

void band_init(void);
void imu_start(void);
void ppg_start(void);
void ui_start(void);

#endif
