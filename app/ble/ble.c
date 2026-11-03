/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Advertise as SmartBand. Heart Rate, Battery, Device Information, and the
 * activity service are in the GATT database once a phone connects.
 */

#include "ble.h"
#include "gatt.h"

#include "band.h"

#include <zephyr/bluetooth/bluetooth.h>
#include <zephyr/bluetooth/conn.h>
#include <zephyr/bluetooth/gatt.h>
#include <zephyr/bluetooth/hci.h>
#include <zephyr/bluetooth/services/bas.h>
#include <zephyr/bluetooth/services/hrs.h>
#include <zephyr/bluetooth/uuid.h>
#include <zephyr/kernel.h>
#include <zephyr/sys/atomic.h>
#include <zephyr/sys/printk.h>
#include <zephyr/sys/util.h>

static atomic_t conn_active;
static atomic_t restart_adv;

static const struct bt_data ad[] = {
	BT_DATA_BYTES(BT_DATA_FLAGS, (BT_LE_AD_GENERAL | BT_LE_AD_NO_BREDR)),
	BT_DATA_BYTES(BT_DATA_UUID16_ALL,
		      BT_UUID_16_ENCODE(BT_UUID_HRS_VAL),
		      BT_UUID_16_ENCODE(BT_UUID_BAS_VAL),
		      BT_UUID_16_ENCODE(BT_UUID_DIS_VAL)),
};

static const struct bt_data sd[] = {
	BT_DATA(BT_DATA_NAME_COMPLETE, CONFIG_BT_DEVICE_NAME, sizeof(CONFIG_BT_DEVICE_NAME) - 1),
};

static void connected(struct bt_conn *conn, uint8_t err)
{
	if (err) {
		printk("BLE connect failed: 0x%02x %s\n", err, bt_hci_err_to_str(err));
		return;
	}

	printk("BLE connected\n");
	atomic_set(&conn_active, 1);
}

static void disconnected(struct bt_conn *conn, uint8_t reason)
{
	ARG_UNUSED(conn);
	printk("BLE disconnected: 0x%02x %s\n", reason, bt_hci_err_to_str(reason));
	atomic_set(&conn_active, 0);
	atomic_set(&restart_adv, 1);
}

BT_CONN_CB_DEFINE(conn_callbacks) = {
	.connected = connected,
	.disconnected = disconnected,
};

static int advertise(void)
{
	int err;

	err = bt_le_adv_start(BT_LE_ADV_CONN_FAST_1, ad, ARRAY_SIZE(ad), sd, ARRAY_SIZE(sd));
	if (err) {
		printk("Advertising failed: %d\n", err);
	} else {
		printk("Advertising as %s\n", CONFIG_BT_DEVICE_NAME);
	}

	return err;
}

static void publish_metrics(void)
{
	int hr_bpm;
	bool hr_present;
	int battery_pct;

	k_mutex_lock(&band.lock, K_FOREVER);
	hr_bpm = band.hr_bpm;
	hr_present = band.hr_present;
	battery_pct = band.battery_pct;
	k_mutex_unlock(&band.lock);

	if (hr_present && hr_bpm > 0) {
		(void)bt_hrs_notify((uint16_t)hr_bpm);
	}

	if (battery_pct >= 0) {
		uint8_t level = (uint8_t)CLAMP(battery_pct, 0, 100);

		(void)bt_bas_set_battery_level(level);
	}

	gatt_activity_notify();
}

static void ble_thread(void *p1, void *p2, void *p3)
{
	int err;

	ARG_UNUSED(p1);
	ARG_UNUSED(p2);
	ARG_UNUSED(p3);

	err = bt_enable(NULL);
	if (err) {
		printk("Bluetooth init failed: %d\n", err);
		return;
	}

	printk("Bluetooth ready\n");

	if (advertise() != 0) {
		return;
	}

	while (1) {
		if (atomic_cas(&restart_adv, 1, 0)) {
			(void)advertise();
		}

		if (atomic_get(&conn_active) != 0) {
			publish_metrics();
		}

		k_msleep(1000);
	}
}

static K_THREAD_STACK_DEFINE(ble_stack, 1536);
static struct k_thread ble_thread_data;

int ble_start(void)
{
	k_thread_create(&ble_thread_data, ble_stack, K_THREAD_STACK_SIZEOF(ble_stack),
			ble_thread, NULL, NULL, NULL, K_PRIO_PREEMPT(8), 0, K_NO_WAIT);
	k_thread_name_set(&ble_thread_data, "ble");
	return 0;
}
