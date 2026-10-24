#ifndef VM_LITE_PLATFORM_UART_H
#define VM_LITE_PLATFORM_UART_H

/*
 * PL011 串口 —— QEMU virt 机器的标准调试通道
 *
 * ARM32 virt 机型：UART0 基地址 0x09000000
 * 真实硬件与虚拟硬件走同一个 hwif 契约，这里只是最底层的字符输出，
 * 用于把 guest 内核的启动阶段打出来，不参与 hwif 抽象层。
 */

void uart_putc(char c);
void uart_puts(const char *s);
void uart_puthex(unsigned int v);

#endif /* VM_LITE_PLATFORM_UART_H */
