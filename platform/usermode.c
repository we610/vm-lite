#include <stdint.h>
#include "uart.h"
#include "usermode.h"

extern void userland_done(void);
extern void user_crash(void);
extern void user_entry(void);
extern unsigned long __ttbr0_l1[];
extern unsigned long __el0_stack_top;

#define TF_X0   5
#define TF_X8   13
#define TF_ESR  2
#define TF_ELR  3
#define TF_SPSR 0
#define ESR_EC(esr) (((esr) >> 26) & 0x3f)
#define EC_SVC_A64  0x15
#define EC_DABT_LOW 0x24
#define EC_IABT_LOW 0x20

/* ============ 最简 MMU：identity map ============ */
void mmu_init_tables(void)
{
    volatile unsigned long *l1 = (volatile unsigned long *)__ttbr0_l1;
    int i;
    unsigned long mair, tcr;

    uart_putc('A');

    for (i = 0; i < 512; i++) l1[i] = 0;
    uart_putc('B');

    l1[0] = 0x00000000UL | 1UL | (1UL<<2) | (0UL<<6) | (3UL<<8) | (1UL<<10);
    uart_putc('C');

    /* L1[1]: RAM, Normal, EL1 RW / EL0 RW, EL0 可执行
       UXN(bit54)=0  PXN(bit53)=0 → 这两位不设即为 0，EL0 可取指 */
    l1[1] = 0x40000000UL
          | (1UL << 0)          /* Valid */
          | (0UL << 1)          /* Table/Block = Block */
          | (0UL << 2)          /* AttrIndx=0 Normal */
          | (1UL << 5)          /* NS */
          | (1UL << 6)          /* AP=01: EL1 RW, EL0 RW */
          | (0UL << 53)         /* PXN=0  允许 EL1 执行 */
          | (0UL << 54)         /* UXN=0  允许 EL0 执行 */
          | (3UL << 8)          /* SH */
          | (1UL << 10);        /* AF */
    uart_putc('D');

    mair = 0xFFUL | (0x04UL << 8);
    __asm__ volatile("msr mair_el1, %0" :: "r"(mair));
    uart_putc('E');

    tcr = (25UL << 0) | (0UL << 14);
    __asm__ volatile("msr tcr_el1, %0" :: "r"(tcr));
    uart_putc('F');

    __asm__ volatile("msr ttbr0_el1, %0" :: "r"((unsigned long)l1));
    uart_putc('G');

    __asm__ volatile("dsb sy" ::: "memory");
    uart_puts("\n[mmu] 配置完成\n");
}

/* ============ EL0 同步异常 ============ */
void el0_sync_handler(unsigned long *tf)
{
    unsigned long esr = tf[TF_ESR];
    unsigned ec = ESR_EC(esr);
    unsigned long nr;

    if (ec == EC_SVC_A64) {
        nr = tf[TF_X8];
        if (nr == 1) { uart_putc((char)tf[TF_X0]); return; }
        if (nr == 2) { tf[TF_X0] = 0x1234; return; }
        if (nr == 0) {
            uart_puts("\n[el0] svc exit -> 回内核\n");
            tf[TF_ELR]  = (unsigned long)userland_done;
            tf[TF_SPSR] = 0x3c5;
            return;
        }
        uart_puts("[el0] 未知 syscall\n");
        return;
    }

    if (ec == EC_DABT_LOW || ec == EC_IABT_LOW) {
        uart_puts("\n[el0] 捕获用户态崩溃 — 内核接管\n");
        tf[TF_ELR]  = (unsigned long)userland_done;
        tf[TF_SPSR] = 0x3c5;
        return;
    }

    uart_puts("\n[el0] 未处理异常\n");
    tf[TF_ELR]  = (unsigned long)userland_done;
    tf[TF_SPSR] = 0x3c5;
}

void el1_panic_c(void)
{
    uart_puts("\n[!!] EL1 意外异常\n");
    for (;;) __asm__ volatile("wfi");
}

void userland_done_c(void)
{
    static int phase = 0;
    if (phase == 0) {
        phase = 1;
        uart_puts("[kernel] 测试1 通过：EL0 svc 往返 OK\n");
        uart_puts("===== 测试2：用户态崩溃捕获 =====\n");
        enter_usermode((unsigned long)user_crash,
                       (unsigned long)&__el0_stack_top - 0x4000);
    }
    uart_puts("[kernel] 测试2 通过：崩溃被捕获，内核存活\n");
    uart_puts("[kernel] 全部通过 OK\n");
    for (;;) __asm__ volatile("wfi");
}
