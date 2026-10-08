.equ nkib, 32
.equ nbytes, nkib*1024
.equ nwords, nbytes/4

.data
.align 4
guest_mem: .zero nbytes  # array of nbytes

# write and read the entire array for 100 times
.text
.globl _start
_start:
    li t0, 100             # t0 = 100, outer loop counter
    la t1, guest_mem       # t1 = guest_mem, array base addr
    li t2, nwords          # t2 = nwords, upper bound for inner loop counter

outer_loop:
    beqz t0, end_sim       # t0 == 0
    addi t0, t0, -1        # t0 -= 1
    li t3, 0               # t3 = 0, inner loop counter

inner_loop:
    beq t3, t2, outer_loop # t3 == nwords, end inner loop
    slli t4, t3, 2         # t4 = t3 * 4
    add t5, t1, t4         # t5 = (uintptr_t)guest_mem + t4
    sw t3, 0(t5)           # guest_mem[t3] = t3
    lw t6, 0(t5)           # t6 = guest_mem[t3]
    addi t3, t3, 1         # t3++
    j inner_loop

end_sim:
    li a7, 10              # syscall 10: ripes ecall exit
    ecall