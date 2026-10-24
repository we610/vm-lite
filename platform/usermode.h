#ifndef VM_LITE_USERMODE_H
#define VM_LITE_USERMODE_H
void enter_usermode(unsigned long entry, unsigned long user_sp);
void mmu_init_tables(void);
void userland_done_c(void);
void el1_panic_c(void);
#endif
