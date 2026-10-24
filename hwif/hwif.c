#include "hwif.h"

/*
 * hwif.c —— 硬件统一接口实现骨架
 *
 * 关键点：注册表不区分后端。
 * 真实硬件驱动与 VMM 虚拟设备调用同一个 hwif_register，
 * Guest 内核调用同一个 hwif_get，按 type 取用，不感知后端差异。
 */

#define HWIF_MAX_DEV 16

static hwif_device_t *g_table[HWIF_MAX_DEV];
static int g_count;

int hwif_register(hwif_device_t *dev)
{
    if (!dev || !dev->ops || g_count >= HWIF_MAX_DEV)
        return -1;

    /* 后端为 PHYSICAL 或 VIRTUAL 不影响注册流程，二者待遇完全相同 */
    g_table[g_count++] = dev;
    return 0;
}

int hwif_unregister(hwif_device_t *dev)
{
    int i, j;
    if (!dev) return -1;

    for (i = 0; i < g_count; i++) {
        if (g_table[i] == dev) {
            for (j = i; j < g_count - 1; j++)
                g_table[j] = g_table[j + 1];
            g_count--;
            return 0;
        }
    }
    return -1;
}

hwif_device_t *hwif_get(hwif_dev_type_t type)
{
    int i;
    for (i = 0; i < g_count; i++) {
        if (g_table[i] && g_table[i]->type == type)
            return g_table[i];
    }
    return NULL;
}
