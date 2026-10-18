.data
state_str: .string "21345671111111"
.equ DRAW_DELAY, 3000
source:
    .byte 1, 4, 2, 0, 3, 5, 6
    .byte 0, 1, 2, 4, 5, 6, 3
    .byte 0, 2, 5, 3, 1, 4, 6
twist:
    .byte 1, 2, 0, 2, 1, 0, 0
    .byte 0, 0, 0, 1, 2, 1, 2
    .byte 0, 0, 0, 0, 0, 0, 0
p_fact_lut:
    .half 0, 720, 1440, 2160, 2880, 3600, 4320, 0
    .half 0, 120, 240, 360, 480, 600, 720, 0
    .half 0, 24, 48, 72, 96, 120, 144, 0
    .half 0, 6, 12, 18, 24, 30, 36, 0
    .half 0, 2, 4, 6, 8, 10, 12, 0
    .half 0, 1, 2, 3, 4, 5, 6, 0
    .half 0, 1, 2, 3, 4, 5, 6, 0
o_tenary_lut:
    .half 0, 243, 486 ,0
    .half 0, 81, 162, 0
    .half 0, 27, 54, 0
    .half 0, 9, 18, 0
    .half 0, 3, 6, 0
    .half 0, 1, 2, 0
move_to_face:
    .byte 0, 0, 0, 1, 1, 1, 2, 2, 2
move_mod3:
    .byte 0, 1, 2, 0, 1, 2, 0, 1, 2
o_plus_twist_mod3:
    .byte 0, 1, 2, 0, 1
.global state
state: .zero 14
temp_state: .zero 14    # for apply move
parsing_str: .string "Parsing state string: "
invalid_input_str_0: .string "Input state "
invalid_input_str_1: .string " is invalid!\n"
rank_p_str: .string "rank_p = "
rank_o_str: .string "rank_o = "
ida_found_str:  .string "IDA*: found solution under bound "
ida_fail_str:   .string "IDA*: failed to find solution under bound "
solution_path:  .zero 11

move_str0: .string "R"
move_str1: .string "R2"
move_str2: .string "R'"
move_str3: .string "B"
move_str4: .string "B2"
move_str5: .string "B'"
move_str6: .string "D"
move_str7: .string "D2"
move_str8: .string "D'"
move_names:
    .word move_str0
    .word move_str1
    .word move_str2
    .word move_str3
    .word move_str4
    .word move_str5
    .word move_str6
    .word move_str7
    .word move_str8

.text
.globl _start
_start:
    jal parse_state

    # state parsed successfully
    jal rank_state
    mv s0, a0   # s0 = start_p
    mv s1, a1   # s1 = start_o

    la a0, rank_p_str
    li a7, 4
    ecall
    mv a0, s0   # print start_p
    li a7, 1
    ecall
    li a0, 10 # newline
    li a7, 11
    ecall

    la a0, rank_o_str
    li a7, 4
    ecall
    mv a0, s1   # print start_o
    li a7, 1
    ecall
    li a0, 10 # newline
    li a7, 11
    ecall

    jal print_state

    la t0, h_p
    add t0, t0, s0
    lbu s2, 0(t0)               # s2 = h_p[start_p]
    la t0, h_o
    add t0, t0, s1
    lbu t0, 0(t0)               # t0 = h_o[start_o]
    bgeu s2, t0, idfs_driver    # if h_p[start_p] > h_o[start_o], ok
    mv s2, t0                   # otherwise, swap
idfs_driver:
    # s2 = start_bound = h = max(h_p[start_p], h_o[start_o])
    li s3, 12
idfs_driver_L0:
    bgeu s2, s3, _start_L0  # if bound <= 11, loop
    mv a0, s0
    mv a1, s1
    mv a2, s2
    jal idfs
    bnez a0, idfs_driver_L1 # dfs return 1, break
    la a0, ida_fail_str
    li a7, 4
    ecall
    mv a0, s2
    li a7, 1
    ecall
    li a0, 10
    li a7, 11
    ecall
    addi s2, s2, 1  # bound++
    j idfs_driver_L0
idfs_driver_L1:
    # print solution
    mv s11, s2  # s11 = num_moves
    la a0, ida_found_str
    li a7, 4
    ecall
    mv a0, s2
    li a7, 1
    ecall
    li a0, 10
    li a7, 11
    ecall
    li t0, 0        # i = 0
    la t1, solution_path
    la t2, move_names
idfs_driver_L2:
    bgeu t0, s2, _start_L0  # i < bound
    add a0, t1, t0
    lbu a0, 0(a0)   # a0 = solution_path[i]
    slli a0, a0, 2  # a0 *= 4
    add a0, t2, a0
    lw a0, 0(a0)    # a0 = move_names[solution_path[i]]
    li a7, 4
    ecall
    addi t0, t0, 1  # i++
    li a0, 32       # space
    li a7, 11
    ecall
    j idfs_driver_L2
_start_L0:
    li a0, 10
    li a7, 11
    ecall

.ifdef DRAW_LED
    jal draw_background
    jal draw_unfolded_map
    li a0, DRAW_DELAY
    jal sleep_ms
.endif

    # apply solution moves and update LED matrix
    la s1, solution_path
    li s0, 0    # i == 0
_start_L1:
    bgeu s0, s11, _start_L2 # i < bound
    add t0, s1, s0
    lbu a0, 0(t0)   # a0 = solution_path[i]
    jal apply_move
.ifdef DRAW_LED
    jal draw_unfolded_map
    li a0, DRAW_DELAY
    jal sleep_ms
.endif
    addi s0, s0, 1  # i++
    j _start_L1

_start_L2:
    jal print_state

    # exit with 0
    li a0, 0
    j exit

parse_state:
    la t0, state_str
    la t1, state
    li t5, 7
    # print "Parsing state <state_str>\n"
    la a0, parsing_str
    li a7, 4
    ecall
    mv a0, t0
    li a7, 4
    ecall
    li a0, 10 # newline
    li a7, 11
    ecall

    li a0, 49   # a0 = '1'
    li a1, 55   # a1 = '7'
    li a2, 51   # a2 = '3'

    # permutations
    lbu t2, 0(t0)               # t2 = str[0]
    bltu t2, a0, invalid_input  # invalid if t2 < '1'
    bgtu t2, a1, invalid_input  # invalid if t2 > '7'
    addi t2, t2, -49            # t2 -= '1'
    sb t2, 0(t1)                # state[0] = t2
    lbu t2, 1(t0)
    bltu t2, a0, invalid_input  # invalid if t2 < '1'
    bgtu t2, a1, invalid_input  # invalid if t2 > '7'
    addi t2, t2, -49
    sb t2, 1(t1)
    lbu t2, 2(t0)
    bltu t2, a0, invalid_input  # invalid if t2 < '1'
    bgtu t2, a1, invalid_input  # invalid if t2 > '7'
    addi t2, t2, -49
    sb t2, 2(t1)
    lbu t2, 3(t0)
    bltu t2, a0, invalid_input  # invalid if t2 < '1'
    bgtu t2, a1, invalid_input  # invalid if t2 > '7'
    addi t2, t2, -49
    sb t2, 3(t1)
    lbu t2, 4(t0)
    bltu t2, a0, invalid_input  # invalid if t2 < '1'
    bgtu t2, a1, invalid_input  # invalid if t2 > '7'
    addi t2, t2, -49
    sb t2, 4(t1)
    lbu t2, 5(t0)
    bltu t2, a0, invalid_input  # invalid if t2 < '1'
    bgtu t2, a1, invalid_input  # invalid if t2 > '7'
    addi t2, t2, -49
    sb t2, 5(t1)
    lbu t2, 6(t0)
    bltu t2, a0, invalid_input  # invalid if t2 < '1'
    bgtu t2, a1, invalid_input  # invalid if t2 > '7'
    addi t2, t2, -49
    sb t2, 6(t1)

    # orientations
    lbu t2, 7(t0)               # t2 = str[7]
    bltu t2, a0, invalid_input  # invalid if t2 < '1'
    bgtu t2, a2, invalid_input  # invalid if t2 > '3'
    addi t2, t2, -49            # t2 -= '1'
    sb t2, 7(t1)                # state[7] = t2
    lbu t2, 8(t0)
    bltu t2, a0, invalid_input  # invalid if t2 < '1'
    bgtu t2, a2, invalid_input  # invalid if t2 > '3'
    addi t2, t2, -49
    sb t2, 8(t1)
    lbu t2, 9(t0)
    bltu t2, a0, invalid_input  # invalid if t2 < '1'
    bgtu t2, a2, invalid_input  # invalid if t2 > '3'
    addi t2, t2, -49
    sb t2, 9(t1)
    lbu t2, 10(t0)
    bltu t2, a0, invalid_input  # invalid if t2 < '1'
    bgtu t2, a2, invalid_input  # invalid if t2 > '3'
    addi t2, t2, -49
    sb t2, 10(t1)
    lbu t2, 11(t0)
    bltu t2, a0, invalid_input  # invalid if t2 < '1'
    bgtu t2, a2, invalid_input  # invalid if t2 > '3'
    addi t2, t2, -49
    sb t2, 11(t1)
    lbu t2, 12(t0)
    bltu t2, a0, invalid_input  # invalid if t2 < '1'
    bgtu t2, a2, invalid_input  # invalid if t2 > '3'
    addi t2, t2, -49
    sb t2, 12(t1)
    lbu t2, 13(t0)
    bltu t2, a0, invalid_input  # invalid if t2 < '1'
    bgtu t2, a2, invalid_input  # invalid if t2 > '3'
    addi t2, t2, -49
    sb t2, 13(t1)

    li a0, 10 # newline
    li a7, 11
    ecall

    # detect invalid state, check the following conditions
    # 1. stat_str[14] is null terminater
    # 2. no duplicate p[i]
    # 3. if sum of o[i]s' is multiple of 3
    lbu t0, 14(t0)
    bnez t0, invalid_input  # str[14] != '\0'
    # t0 already = '\0' = 0, otherwise
    li t5, 7                # t5 = i's upper bound
    li t6, 3                # t6 = 3, for sum % 3
    li t2, 0                # t2 = sum = 0
parse_state_L0:
    add a0, t1, t0              # a0 = state.p + i
    lbu a1, 7(a0)               # a1 = state.o[i]
    lbu a0, 0(a0)               # a0 = state.p[i]
    li t4, 0                    # t4 = j = 0
parse_state_L1:
    bgeu t4, t0, parse_state_L2 # j < i
    add t3, t1, t4              # t3 = state.p + j
    lbu t3, 0(t3)               # t3 = state.p[j]
    beq t3, a0, invalid_input   # state.p[j] == state.p[i]
    addi t4, t4, 1              # j++
    j parse_state_L1
parse_state_L2:
    add t2, t2, a1              # sum += state.o[i]
    addi t0, t0, 1              # i++
    bltu t0, t5, parse_state_L0 # i < 7
parse_state_L3:
    bltu t2, t6, parse_state_L4 # if sum < 3, don't subtract
    addi t2, t2, -3             # sum -= 3
    j parse_state_L3
parse_state_L4:
    bnez t2, invalid_input      # sum != 0, invalid
    ret

# TODO: print out reason of invalid
invalid_input:
    la a0, invalid_input_str_0
    li a7, 4
    ecall
    la a0, state_str
    li a7, 4
    ecall
    la a0, invalid_input_str_1
    li a7, 4
    ecall
    li a0, 2    # exit with status code 2
    j exit

rank_state:
    la a2, state
    la a3, p_fact_lut
    la a4, o_tenary_lut
    li a0, 0 # p = 0
    li a1, 0 # o = 0

    li t0, 0 # i = 0
    li t1, 7 # t2 = 7
rank_state_L0:
    beq t0, t1, rank_state_L3
    li t2, 0       # smaller = 0
    addi t3, t0, 1 # j = i + 1
rank_state_L1:
    beq t3, t1, rank_state_L2
    add t4, a2, t3
    lbu t5, 0(t4)   # t5 = state->p[j]
    add t4, a2, t0
    lbu t6, 0(t4)   # t6 = state->p[i]
    sltu t5, t5, t6
    add t2, t2, t5  # smaller += (state->p[j] < state->p[i])
    addi t3, t3, 1  # j++
    j rank_state_L1
rank_state_L2:
    slli t4, t0, 3
    add t4, t4, t2 # t4 = i * 8 + samller
    slli t4, t4, 1 # t4 *= 2
    add t4, t4, a3
    lhu t4, 0(t4)
    add a0, a0, t4 # p += p_fact_lut[i][smaller];
    addi t0, t0, 1 # i++
    j rank_state_L0
rank_state_L3:
    addi t0, a2, 7 # t0 = state->o
    lbu t1, 0(t0)  # t1 = state->o[0]
    slli t1, t1, 1 # t1 = state->o[0] * 2
    add t1, t1, a4 # o_tenary_lut + t1
    lhu t1, 0(t1)  # o_tenary_lut[0][state->o[0]]
    add a1, a1, t1 # o += ...

    lbu t1, 1(t0)  # t1 = state->o[1]
    slli t1, t1, 1 # t1 = state->o[1] * 2
    addi t2, a4, 8 # t2 = o_tenary_lut[1]
    add t1, t1, t2 # o_tenary_lut[1] + t1
    lhu t1, 0(t1)  # o_tenary_lut[1][state->o[1]]
    add a1, a1, t1 # o += ...

    lbu t1, 2(t0)   # t1 = state->o[2]
    slli t1, t1, 1  # t1 = state->o[2] * 2
    addi t2, a4, 16 # t2 = o_tenary_lut[2]
    add t1, t1, t2  # o_tenary_lut[2] + t1
    lhu t1, 0(t1)   # o_tenary_lut[2][state->o[2]]
    add a1, a1, t1  # o += ...

    # o_tenary_lut[3][state->o[3]]
    lbu t1, 3(t0)
    slli t1, t1, 1
    addi t2, a4, 24
    add t1, t1, t2
    lhu t1, 0(t1)
    add a1, a1, t1

    # o_tenary_lut[4][state->o[4]]
    lbu t1, 4(t0)
    slli t1, t1, 1
    addi t2, a4, 32
    add t1, t1, t2
    lhu t1, 0(t1)
    add a1, a1, t1

    # o_tenary_lut[5][state->o[5]]
    lbu t1, 5(t0)
    slli t1, t1, 1
    addi t2, a4, 40
    add t1, t1, t2
    lhu t1, 0(t1)
    add a1, a1, t1
    ret

# a0 = start_p, a1 = start_o, a2 = bound
idfs:
    or   t0, a0, a1     # start_p == 0 && start_o == 0
    bnez t0, idfs_L0
    li   a0, 1          # already solved state, return 1
    ret
idfs_L0:
    # 0(sp) - 23(sp): p_stk
    # 24(sp) - 47(sp): o_stk
    # 48(sp) - 59(sp): face_stk
    # 60(sp) - 71(sp): turn_stk
    addi sp, sp, -80
    la t5, h_p      # t5 = h_p
    la t6, h_o      # t6 = h_o
    sh a0, 0(sp)    # p_stk[0] = start_p
    sh a1, 24(sp)   # o_stk[0] = start_o
    li a3, 0        # a3 = depth = 0
idfs_enter_level:
    li t0, 0                # t0 = face = 0
    li t1, 0xFF             # t1 = last_face = 0xFF
    blez a3, idfs_face_loop # branch if depth <= 0
    addi t1, a3, -1         # t1 = depth - 1
    add t1, sp, t1
    lbu t1, 48(t1)          # t1 = last_face = face_stk[depth - 1]
idfs_face_loop:
    beq t0, t1, idfs_next_face  # pruning 2: if face == last_face
    slli t3, a3, 1  # t1 = depth * 2
    add t3, sp, t3
    lhu a4, 0(t3)   # a4 = next_p = p_stk[depth]
    lhu a5, 24(t3)  # a5 = next_o = o_stk[depth]

    # calculate next_rank_*[face][0] addresses, store in a6/a7
    la a6, next_rank_p
    la a7, next_rank_o
    beqz t0, idfs_L1    # face == 0, addresses are ok
    li t2, 10080
    add a6, a6, t2      # + 5040*2
    addi a7, a7, 1458   # + 729*2
    li t3, 1
    beq t0, t3, idfs_L1 # if face == 1, 1 addition, else 2 additions
    add a6, a6, t2      # + 5040*2
    addi a7, a7, 1458   # + 729*2
idfs_L1:
    li t2, 0            # t2 = turn = 0
idfs_turn_loop:
    slli t3, a4, 1      # t3 = next_p * 2
    add t3, a6, t3      # t3 = &next_rank_p[face][0] + t3
    lhu a4, 0(t3)       # a4 = next_p = next_rank_p[face][next_p]
    slli t3, a5, 1      # t3 = next_o * 2
    add t3, a7, t3      # t3 = &next_rank_o[face] + t3
    lhu a5, 0(t3)       # a5 = next_o = next_rank_o[face][next_o]

    # t3 = h = max(h_p[next_p], h_o[next_o])
    add t3, t5, a4          # t3 = h_p + next_p
    lbu t3, 0(t3)           # t3 = h_p[next_p]
    add t4, t6, a5          # t4 = h_o + next_o
    lbu t4, 0(t4)           # t4 = h_o[next_o]
    bgeu t3, t4, idfs_L2    # if t3 >= t4, ok
    mv t3, t4               # otherwise swap
idfs_L2:
    add t3, t3, a3                  # t3 = h + depth
    addi t3, t3, 1                  # t3 = depth + 1 + h
    bgtu t3, a2, idfs_resume_turn   # pruning 1: depth + 1 + h <= bound
    add t3, sp, a3                  # t3 = sp + depth
    sb t0, 48(t3)                   # face_stk[depth] = face
    sb t2, 60(t3)                   # turn_stk[depth] = turn

    or t3, a4, a5           # if (next_p == 0 && next_o == 0) is ture -> solution found
    bnez t3, idfs_L3        # branch if solution not found
    addi t3, t3, 0          # i = 0
    # t6 was h_o, however, since solution found, can be safely overwritten
    la t6, solution_path
idfs_sol_loop:
    # 48(sp) - 59(sp): face_stk
    # 60(sp) - 71(sp): turn_stk
    addi t4, sp, 48 # t4 = face_stk
    add t5, t4, t3  # t5 = face_stk + i
    lbu t5, 0(t5)   # t5 = face_stk[i]
    slli t4, t5, 1  # t4 = face_stk[i] << 1
    add t4, t4, t5  # t4 = (face_stk[i] << 1) + face_stk[i]
    addi t5, sp, 60 # t5 = turn_stk
    add t5, t5, t3  # t5 = turn_stk + i
    lbu t5, 0(t5)   # t5 = turn_stk[i]
    add t4, t4, t5  # t4 = (face_stk[i] << 1) + face_stk[i] + turn_stk[i]
    add t5, t6, t3  # t5 = solution_path + i
    sb t4, 0(t5)    # solution_path[i] = t4

    addi t3, t3, 1              # i++
    bleu t3, a3, idfs_sol_loop  # i <= depth ?
    # solution_path filled
    addi sp, sp, 80
    li a0, 1                    # return 1
    ret
idfs_L3:
    # solution not found yet
    # 0(sp) - 23(sp): p_stk
    # 24(sp) - 47(sp): o_stk
    addi a3, a3, 1  # depth++
    slli t3, a3, 1  # t3 = depth * 2
    add t4, sp, t3  # t4 = sp + depth * 2 = p_stk + depth * 2
    sh a4, 0(t4)    # p_stk[depth] = next_p
    addi t4, sp, 24 # t4 = sp + 24
    add t4, t4, t3  # t4 = sp + 24 + depth * 2
    sh a5, 0(t4)    # o_stk[depth] = next_o
    j idfs_enter_level
idfs_resume_turn:
    addi t2, t2, 1              # ++turn
    li t3, 2                    # t3 = 2
    bleu t2, t3, idfs_turn_loop # if turn <= 2, branch
idfs_next_face:
    addi t0, t0, 1              # ++face
    li t3, 2                    # t3 = 2
    bleu t0, t3, idfs_face_loop # if face <=2, branch

    addi a3, a3, -1                     # --depth
    blt a3, zero, idfs_search_failed    # if depth < 0, return 0

    # 0(sp) - 23(sp): p_stk
    # 24(sp) - 47(sp): o_stk
    # 48(sp) - 59(sp): face_stk
    # 60(sp) - 71(sp): turn_stk
    addi t3, sp, 48 # t3 = sp + 48 = face_stk
    add t3, t3, a3  # t3 = face_stk + depth
    lbu t0, 0(t3)   # t0 = face = face_stk[depth]
    addi t3, sp, 60 # t3 = sp + 60 = turn_stk
    add t3, t3, a3  # t3 = turn_stk + depth
    lbu t2, 0(t3)   # t2 = turn = turn_stk[depth]
    addi t3, a3, 1  # t3 = depth + 1
    slli t3, t3, 1  # t3 = (depth + 1) * 2
    add t4, sp, t3  # t4 = p_stk + (depth + 1) * 2
    lhu a4, 0(t4)   # a4 = next_p = p_stkp[depth + 1]
    addi t3, t3, 24 # t3 = 24 + (depth + 1) * 2
    add t3, sp, t3  # t3 = sp + 24 + (depth + 1) * 2 = o_stk + (depth + 1) * 2
    lhu a5, 0(t3)   # a5 = next_o = o_stk[depth + 1]

    la a6, next_rank_p
    la a7, next_rank_o
    beqz t0, idfs_L4
    li t4, 10080
    add a6, a6, t4
    addi a7, a7, 1458
    li t4, 1
    beq t0, t4, idfs_L4
    li t4, 10080
    add a6, a6, t4
    addi a7, a7, 1458
idfs_L4:
    li t1, 0xFF                 # t1 = last_face = 0xFF
    blez a3, idfs_resume_turn   # if depth <= 0, b, then last_face = 0xFF
    addi t3, a3, -1
    add t3, t3, sp
    lbu t1, 48(t3)              # t1 = last_face = face_stk[depth - 1]
    j idfs_resume_turn
idfs_search_failed:
    addi sp, sp, 80
    li a0, 0
    ret

quarter_turn:
    mv t0, a3                           # t0 = source[0]
    mv t1, a4                           # t1 = twist[0]
    beqz a0, quarter_turn_L0      # face == 0
    addi t0, t0, 7                      # t0 = source[1]
    addi t1, t1, 7                      # t1 = twist[1]
    li t2, 1
    beq a0, t2, quarter_turn_L0         # face == 1
    addi t0, t0, 7                      # t0 = source[2]
    addi t1, t1, 7                      # t1 = twist[2]
quarter_turn_L0:
    # i = 0
    lbu t2, 0(t0)   # t2 = from = source[face][0]
    # p[0]
    add t3, a6, t2  # t3 = state.p + from
    lbu t4, 0(t3)   # t4 = state.p[from]
    sb t4, 0(a7)    # temp_state.p[0] = state.p[from]
    # o[0]
    lbu t3, 7(t3)   # t3 = state.p[from + 7] = state.o[from]
    lbu t4, 0(t1)   # t4 = twist[face][0]
    add t3, t3, t4
    add t3, t3, a5  # t3 = &o_plus_twist_mod3[t3]
    lbu t3, 0(t3)   # t3 = o_plus_twist_mod3[t3]
    sb t3, 7(a7)    # temp_state.o[0] = t3

    # i = 1
    lbu t2, 1(t0)   # t2 = from = source[face][1]
    # p[1]
    add t3, a6, t2  # t3 = state.p + from
    lbu t4, 0(t3)   # t4 = state.p[from]
    sb t4, 1(a7)    # temp_state.p[1] = state.p[from]
    # o[1]
    lbu t3, 7(t3)   # t3 = state.p[from + 7] = state.o[from]
    lbu t4, 1(t1)   # t4 = twist[face][1]
    add t3, t3, t4
    add t3, t3, a5  # t3 = &o_plus_twist_mod3[t3]
    lbu t3, 0(t3)   # t3 = o_plus_twist_mod3[t3]
    sb t3, 8(a7)    # temp_state.o[1] = t3

    # i = 2
    lbu t2, 2(t0)   # t2 = from = source[face][2]
    add t3, a6, t2  # t3 = state.p + from
    lbu t4, 0(t3)   # t4 = state.p[from]
    sb t4, 2(a7)    # temp_state.p[2] = state.p[from]
    lbu t3, 7(t3)   # t3 = state.p[from + 7] = state.o[from]
    lbu t4, 2(t1)   # t4 = twist[face][2]
    add t3, t3, t4
    add t3, t3, a5  # t3 = &o_plus_twist_mod3[t3]
    lbu t3, 0(t3)   # t3 = o_plus_twist_mod3[t3]
    sb t3, 9(a7)    # temp_state.o[2] = t3

    # i = 3
    lbu t2, 3(t0)
    add t3, a6, t2
    lbu t4, 0(t3)
    sb t4, 3(a7) 
    lbu t3, 7(t3)
    lbu t4, 3(t1)
    add t3, t3, t4
    add t3, t3, a5
    lbu t3, 0(t3)
    sb t3, 10(a7)

    # i = 4
    lbu t2, 4(t0)
    add t3, a6, t2
    lbu t4, 0(t3)
    sb t4, 4(a7) 
    lbu t3, 7(t3)
    lbu t4, 4(t1)
    add t3, t3, t4
    add t3, t3, a5
    lbu t3, 0(t3)
    sb t3, 11(a7)

    # i = 5
    lbu t2, 5(t0)
    add t3, a6, t2
    lbu t4, 0(t3)
    sb t4, 5(a7) 
    lbu t3, 7(t3)
    lbu t4, 5(t1)
    add t3, t3, t4
    add t3, t3, a5
    lbu t3, 0(t3)
    sb t3, 12(a7)

    # i = 6
    lbu t2, 6(t0)
    add t3, a6, t2
    lbu t4, 0(t3)
    sb t4, 6(a7) 
    lbu t3, 7(t3)
    lbu t4, 6(t1)
    add t3, t3, t4
    add t3, t3, a5
    lbu t3, 0(t3)
    sb t3, 13(a7)

    # update state with temp_state
    lw t0, 0(a7)
    lw t1, 4(a7)
    lw t2, 8(a7)
    lhu t3, 12(a7)  # temp_state[12],[13]
    sw t0, 0(a6)
    sw t1, 4(a6)
    sw t2, 8(a6)
    sh t3, 12(a6)

    addi a2, a2, 1  # i++
    bleu a2, a1, quarter_turn
    ret

# input: a0 = move number
apply_move:
    mv a2, a0
    la a1, move_to_face
    add a0, a1, a2      # a0 = &move_to_face[move]
    lbu a0, 0(a0)       # a0 = move_to_face[move]
    la a1, move_mod3
    add a1, a1, a2
    lbu a1, 0(a1)       # a1 = turns = move_mod3[move]
    li a2, 0            # a2 = i = 0
    la a3, source
    la a4, twist
    la a5, o_plus_twist_mod3
    la a6, state
    la a7, temp_state
    j quarter_turn

.global print_state
print_state:
    la t0, state
    lw t1, 0(t0)
    lw t2, 4(t0)
    lw t3, 8(t0)
    lhu t4, 12(t0)

    andi a0, t1, 0xFF
    addi a0, a0, 1
    li a7, 1
    ecall
    srli t1, t1, 8
    andi a0, t1, 0xFF
    addi a0, a0, 1
    li a7, 1
    ecall
    srli t1, t1, 8
    andi a0, t1, 0xFF
    addi a0, a0, 1
    li a7, 1
    ecall
    srli t1, t1, 8
    andi a0, t1, 0xFF
    addi a0, a0, 1
    li a7, 1
    ecall

    andi a0, t2, 0xFF
    addi a0, a0, 1
    li a7, 1
    ecall
    srli t2, t2, 8
    andi a0, t2, 0xFF
    addi a0, a0, 1
    li a7, 1
    ecall
    srli t2, t2, 8
    andi a0, t2, 0xFF
    addi a0, a0, 1
    li a7, 1
    ecall
    srli t2, t2, 8
    andi a0, t2, 0xFF
    addi a0, a0, 1
    li a7, 1
    ecall

    andi a0, t3, 0xFF
    addi a0, a0, 1
    li a7, 1
    ecall
    srli t3, t3, 8
    andi a0, t3, 0xFF
    addi a0, a0, 1
    li a7, 1
    ecall
    srli t3, t3, 8
    andi a0, t3, 0xFF
    addi a0, a0, 1
    li a7, 1
    ecall
    srli t3, t3, 8
    andi a0, t3, 0xFF
    addi a0, a0, 1
    li a7, 1
    ecall

    andi a0, t4, 0xFF
    addi a0, a0, 1
    li a7, 1
    ecall
    srli t4, t4, 8
    andi a0, t4, 0xFF
    addi a0, a0, 1
    li a7, 1
    ecall

    li a0, 10
    li a7, 11
    ecall
    ret

exit:
    li a7, 93 # exit with status code in a0
    ecall
