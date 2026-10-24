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
static void put64(unsigned long v)
{
    int i;
    uart_puts("0x");
    for (i = 60; i >= 0; i -= 4) {
        unsigned n = (v >> i) & 0xf;
        uart_putc(n < 10 ? '0' + n : 'a' + (n - 10));
    }
}

void mmu_init_tables(void)
{
    volatile unsigned long *l1 = (volatile unsigned long *)__ttbr0_l1;
    int i;
    unsigned long mair, tcr, sctlr, rb;

    for (i = 0; i < 512; i++) l1[i] = 0;

    /* L1[0] 0x0-0x3FFFFFFF : Device, EL1 RW */
    l1[0] = 0x00000000UL | (1UL << 10) | (0UL << 8)
          | (0UL << 6) | (1UL << 2) | (1UL << 0);

    /* L1[1] 0x40000000-0x7FFFFFFF : Normal, EL1 RW + EL0 RW, 可执行 */
    l1[1] = 0x40000000UL | (1UL << 10) | (3UL << 8)
          | (1UL << 6) | (0UL << 2) | (1UL << 0);

    mair = 0xFFUL | (0x00UL << 8);
    __asm__ volatile("msr MAIR_EL1, %0" :: "r"(mair));

    tcr = (25UL << 0)      /* T0SZ=25 */
        | (0UL  << 14)     /* TG0 = 00 -> 4KB */
        | (25UL << 16)     /* T1SZ=25 */
        | (1UL  << 30)     /* ★ TG1 = 01 -> 4KB（之前错写成 2） */
        | (2UL  << 32);    /* IPS = 40bit */
    __asm__ volatile("msr TCR_EL1, %0" :: "r"(tcr));

    __asm__ volatile("msr TTBR0_EL1, %0" :: "r"((unsigned long)l1));
    __asm__ volatile("msr TTBR1_EL1, %0" :: "r"((unsigned long)l1));
    __asm__ volatile("dsb sy" ::: "memory");

    uart_puts("\n[mmu] -- 寄存器实况 --\n");
    uart_puts("  L1[1]="); put64(l1[1]); uart_putc('\n');
    __asm__ volatile("mrs %0, MAIR_EL1" : "=r"(rb));
    uart_puts("  MAIR ="); put64(rb); uart_putc('\n');
    __asm__ volatile("mrs %0, TCR_EL1" : "=r"(rb));
    uart_puts("  TCR  ="); put64(rb); uart_putc('\n');
    __asm__ volatile("mrs %0, SCTLR_EL1" : "=r"(sctlr));
    uart_puts("  SCTLR="); put64(sctlr); uart_putc('\n');
    uart_puts("  (L1[1]应为40000741, TCR bit31:30应为01)\n");
    __asm__ volatile("mrs %0, TTBR0_EL1" : "=r"(rb));
    uart_puts("  TTBR0="); put64(rb); uart_putc('\n');
    __asm__ volatile("mrs %0, TTBR1_EL1" : "=r"(rb));
    uart_puts("  TTBR1="); put64(rb); uart_putc('\n');
    uart_puts("  (应与 __ttbr0_l1 地址 0x40003000 相同)\n");
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

static void put_hex(unsigned long v)
{
    int i;
    uart_puts("0x");
    for (i = 60; i >= 0; i -= 4) {
        unsigned n = (v >> i) & 0xf;
        uart_putc(n < 10 ? '0' + n : 'a' + n - 10);
    }
}

void el1_panic_c(void)
{
    unsigned long esr, elr, far;
    __asm__ volatile("mrs %0, ESR_EL1" : "=r"(esr));
    __asm__ volatile("mrs %0, ELR_EL1" : "=r"(elr));
    __asm__ volatile("mrs %0, FAR_EL1" : "=r"(far));
    uart_puts("\n[!!] EL1 PANIC\n");
    uart_puts("  ESR="); put_hex(esr); uart_putc('\n');
    uart_puts("  ELR="); put_hex(elr); uart_putc('\n');
    uart_puts("  FAR="); put_hex(far); uart_putc('\n');
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
