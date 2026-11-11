/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Activity service: steps and a moving flag.
 *
 *  Service  fb5a0001-6c4b-4a5a-9f10-b1c2d3e4f500
 *  Steps    fb5a0002-6c4b-4a5a-9f10-b1c2d3e4f500  uint32 little-endian
 *  Moving   fb5a0003-6c4b-4a5a-9f10-b1c2d3e4f500  uint8, 1 while the IMU
 *                                                 reports motion
 */

#include "gatt.h"

#include "band.h"

#include <zephyr/bluetooth/bluetooth.h>
#include <zephyr/bluetooth/gatt.h>
#include <zephyr/bluetooth/uuid.h>
#include <zephyr/sys/byteorder.h>

static const struct bt_uuid_128 activity_svc_uuid =
	BT_UUID_INIT_128(BT_UUID_128_ENCODE(0xfb5a0001, 0x6c4b, 0x4a5a, 0x9f10, 0xb1c2d3e4f500));
static const struct bt_uuid_128 steps_uuid =
	BT_UUID_INIT_128(BT_UUID_128_ENCODE(0xfb5a0002, 0x6c4b, 0x4a5a, 0x9f10, 0xb1c2d3e4f500));
static const struct bt_uuid_128 moving_uuid =
	BT_UUID_INIT_128(BT_UUID_128_ENCODE(0xfb5a0003, 0x6c4b, 0x4a5a, 0x9f10, 0xb1c2d3e4f500));

static bool steps_notify;
static bool moving_notify;

static void steps_ccc_changed(const struct bt_gatt_attr *attr, uint16_t value)
{
	ARG_UNUSED(attr);
	steps_notify = (value == BT_GATT_CCC_NOTIFY);
}

static void moving_ccc_changed(const struct bt_gatt_attr *attr, uint16_t value)
{
	ARG_UNUSED(attr);
	moving_notify = (value == BT_GATT_CCC_NOTIFY);
}

static ssize_t read_steps(struct bt_conn *conn, const struct bt_gatt_attr *attr,
			  void *buf, uint16_t len, uint16_t offset)
{
	uint32_t steps;

	ARG_UNUSED(attr);
	k_mutex_lock(&band.lock, K_FOREVER);
	steps = sys_cpu_to_le32(band.steps);
	k_mutex_unlock(&band.lock);

	return bt_gatt_attr_read(conn, attr, buf, len, offset, &steps, sizeof(steps));
}

static ssize_t read_moving(struct bt_conn *conn, const struct bt_gatt_attr *attr,
			   void *buf, uint16_t len, uint16_t offset)
{
	uint8_t moving;

	ARG_UNUSED(attr);
	k_mutex_lock(&band.lock, K_FOREVER);
	moving = band.moving ? 1U : 0U;
	k_mutex_unlock(&band.lock);

	return bt_gatt_attr_read(conn, attr, buf, len, offset, &moving, sizeof(moving));
}

BT_GATT_SERVICE_DEFINE(activity_svc,
	BT_GATT_PRIMARY_SERVICE(&activity_svc_uuid),
	BT_GATT_CHARACTERISTIC(&steps_uuid.uuid,
			       BT_GATT_CHRC_READ | BT_GATT_CHRC_NOTIFY,
			       BT_GATT_PERM_READ, read_steps, NULL, NULL),
	BT_GATT_CCC(steps_ccc_changed, BT_GATT_PERM_READ | BT_GATT_PERM_WRITE),
	BT_GATT_CHARACTERISTIC(&moving_uuid.uuid,
			       BT_GATT_CHRC_READ | BT_GATT_CHRC_NOTIFY,
			       BT_GATT_PERM_READ, read_moving, NULL, NULL),
	BT_GATT_CCC(moving_ccc_changed, BT_GATT_PERM_READ | BT_GATT_PERM_WRITE),
);

void gatt_activity_notify(void)
{
	uint32_t steps;
	uint8_t moving;

	k_mutex_lock(&band.lock, K_FOREVER);
	steps = sys_cpu_to_le32(band.steps);
	moving = band.moving ? 1U : 0U;
	k_mutex_unlock(&band.lock);

	if (steps_notify) {
		(void)bt_gatt_notify(NULL, &activity_svc.attrs[2], &steps, sizeof(steps));
	}
	if (moving_notify) {
		(void)bt_gatt_notify(NULL, &activity_svc.attrs[5], &moving, sizeof(moving));
	}
}
