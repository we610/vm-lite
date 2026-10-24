    .section .text
    .global user_entry
    .global user_crash

/* 正常：连打 USER 后 svc exit */
user_entry:
    mov x8, #1
    mov x0, #'U' ; svc #0
    mov x0, #'S' ; svc #0
    mov x0, #'E' ; svc #0
    mov x0, #'R' ; svc #0
    mov x0, #'\n'; svc #0
    mov x8, #2      /* 取 magic 值 */
    svc #0
    mov x8, #0      /* exit */
    svc #0
1:  b 1b

/* 崩溃：故意访问 0x0，应被内核捕获 */
user_crash:
    mov x8, #1
    mov x0, #'C' ; svc #0
    mov x0, #'\n'; svc #0
    mov x1, #0
    ldr x2, [x1]    /* ← 这里必崩 */
    mov x0, #'!'    /* 不该执行到 */
    svc #0
1:  b 1b
