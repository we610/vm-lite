#include "uart.h"

/* QEMU virt (ARM32) 的 PL011 寄存器布局 */
#define UART0_BASE  0x09000000u

#define UART_DR     (*(volatile unsigned int *)(UART0_BASE + 0x00u))
#define UART_FR     (*(volatile unsigned int *)(UART0_BASE + 0x18u))

#define UART_FR_TXFF (1u << 5)   /* 发送 FIFO 满 */

void uart_putc(char c)
{
    while (UART_FR & UART_FR_TXFF)
        ;                        /* 等待可发送 */
    UART_DR = (unsigned int)c;
}

void uart_puts(const char *s)
{
    if (!s)
        return;
    while (*s) {
        if (*s == '\n')
            uart_putc('\r');     /* 裸终端需要 CR+LF */
        uart_putc(*s++);
    }
}

void uart_puthex(unsigned int v)
{
    static const char *hex = "0123456789abcdef";
    int i;

    uart_puts("0x");
    for (i = 7; i >= 0; i--)
        uart_putc(hex[(v >> (i * 4)) & 0xfu]);
}
