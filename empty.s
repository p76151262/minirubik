.global _start
_start:
    mov $60, %rax  # sys_exit
    xor %rdi, %rdi # status 0
    syscall
