/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Custom activity GATT service. Heart Rate, Battery, and Device Information
 * come from the Zephyr standard services.
 */

#ifndef APP_GATT_H_
#define APP_GATT_H_

void gatt_activity_notify(void);

#endif
