    .section .text
    .global user_entry
    .global user_crash

/* 测试1：正常用 svc 打印并退出 */
user_entry:
    mov x8, #1
    mov x0, #'U' ; svc #0
    mov x0, #'S' ; svc #0
    mov x0, #'E' ; svc #0
    mov x0, #'R' ; svc #0
    mov x0, #'\n'; svc #0
    mov x8, #2          /* 取 magic */
    svc #0
    mov x8, #0          /* exit */
    svc #0
1:  b 1b

/* 测试2：EL0 执行特权指令 → 必触发异常 */
user_crash:
    mov x8, #1
    mov x0, #'C' ; svc #0
    mov x0, #'\n'; svc #0
    mrs x2, CurrentEL   /* ★ EL0 读系统寄存器 → 未定义异常 */
    mov x0, #'!'        /* 不该执行到 */
    svc #0
1:  b 1b
