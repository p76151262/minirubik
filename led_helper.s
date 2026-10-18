.equ LED_MATRIX_0_BASE, 0xf0000000
.equ LED_MATRIX_0_SIZE, 0xdac
.equ LED_MATRIX_0_WIDTH, 0x23
.equ LED_MATRIX_0_HEIGHT, 0x19

.data
cubie_colors:
    # order: [0]=U/D, [1]=CW face, [2]=CCW face
    # 0: FUL (W, G, O), (U->F->L, CW)
    .word 0xFFFFFF, 0x00FF00, 0xFFA500
    # 1: FUR (W, R, G), (U->R->F, CW)
    .word 0xFFFFFF, 0xFF0000, 0x00FF00
    # 2: FDR (Y, G, R), (D->F->R, CW)
    .word 0xFFFF00, 0x00FF00, 0xFF0000
    # 3: FDL (Y, O, G), (D->L->F, CW)
    .word 0xFFFF00, 0xFFA500, 0x00FF00
    # 4: BUR (W, B, R), (U->B->R, CW)
    .word 0xFFFFFF, 0x0000FF, 0xFF0000
    # 5: BDR (Y, R, B), (D->R->B, CW)
    .word 0xFFFF00, 0xFF0000, 0x0000FF
    # 6: BDL (Y, B, O), (D->B->L, CW)
    .word 0xFFFF00, 0x0000FF, 0xFFA500
    # 7: BUL (W, O, B), (U->L->B, CW)
    .word 0xFFFFFF, 0xFFA500, 0x0000FF

info_str_0: .string "Drawing LED martix..."

.text
.global get_sticker_color
# input: a0 = physical_cubie (0~7), a1 = orientation (0~2), a2 = face_type (0=U/D, 1=CW face, 2=CCW face)
# output: a0 = sticker RGB value
get_sticker_color:
    # calculation: (face_type + o) % 3
    add t0, a2, a1  # t0 = face_type + o
    
    # t0 = t0 % 3 (t0 maximum at 4, minus once or not)
    li t1, 3
    bltu t0, t1, get_sticker_color_L0   # t0 < 3, ok
    sub t0, t0, t1                      # otherwise, t0 -= 3
get_sticker_color_L0:
    # t1 = color array offset = (physical_cubie * 3 + color_idx) * 4
    slli t1, a0, 1    # t1 = a0 * 2
    add t1, t1, a0    # t1 = a0 * 3
    add t1, t1, t0    # t1 += color_idx (0~2)
    slli t1, t1, 2    # t1 *= 4 bytes

    la t2, cubie_colors
    add t2, t2, t1
    lw a0, 0(t2)
    ret

.global draw_sticker
# input: a0 = color, a1 = start_x, a2 = start_y
# draw 3x3 sticker on LED matrix at given coordinate
# note that width = 35, height = 25, and each pixel takes 4 bytes (XRGB, MSB not used)
# each row takes 35 * 4 = 140 bytes
draw_sticker:
    # y (row offset)
    slli t0, a2, 7      # t0 = y * 128
    slli t1, a2, 3      # t1 = y * 8
    slli t2, a2, 2      # t2 = y * 4
    add t0, t0, t1      # t0 = y * 136
    add t0, t0, t2      # t0 = y * 140

    # x (col offset)
    slli t1, a1, 2      # t1 = x * 4
    add t0, t0, t1      # t0 = (y * 140) + (x * 4)

    # t0 = LED_MATRIX_0_BASE + (y * 140) + (x * 4) = 1st pixel memory location
    li t1, LED_MATRIX_0_BASE
    add t0, t1, t0

    li t1, 140          # t1 = stride = 140

    # draw row 0
    sw a0, 0(t0)
    sw a0, 4(t0)
    sw a0, 8(t0)
    
    # draw row 1
    add t0, t0, t1     # t0 = next row
    sw a0, 0(t0)
    sw a0, 4(t0)
    sw a0, 8(t0)

    # draw row 2
    add t0, t0, t1     # t0 = next row
    sw a0, 0(t0)
    sw a0, 4(t0)
    sw a0, 8(t0)

    ret

.global draw_unfolded_map
draw_unfolded_map:
    addi sp, sp, -16
    sw s0, 0(sp)
    sw ra, 12(sp)
    la s0, state

    la a0, info_str_0
    li a7, 4
    ecall
    jal print_state

# The cubie labeled as 0 is fixed in terms of position and orientation
#                          UP
#                       ┌───┬───┐
#                       │ 7 │ 4 │
#                       ├───┼───┤
#                       │ 0 │ 1 │
#                       └───┴───┘
#        LEFT              FRONT             RIGHT              BACK
#     ┌───┬───┐         ┌───┬───┐         ┌───┬───┐         ┌───┬───┐
#     │ 7 │ 0 │         │ 0 │ 1 │         │ 1 │ 4 │         │ 4 │ 7 │
#     ├───┼───┤         ├───┼───┤         ├───┼───┤         ├───┼───┤
#     │ 6 │ 3 │         │ 3 │ 2 │         │ 2 │ 5 │         │ 5 │ 6 │
#     └───┴───┘         └───┴───┘         └───┴───┘         └───┴───┘
#                         DOWN
#                       ┌───┬───┐
#                       │ 3 │ 2 │
#                       ├───┼───┤
#                       │ 6 │ 5 │
#                       └───┴───┘
# remember that state value in program is offset by 1

    # UP

    # BUL's up face
    lbu a0, 6(s0)   # physical_cubie 7 = p[6]
    lbu a1, 13(s0)  # orientation = o[6]
    li a2, 0        # face_type = 0 (U/D)
    addi a0, a0, 1  # offset by 1
    jal get_sticker_color
    
    li a1, 8    # start_x = 8 (3 + 1 + 3 + 1)
    li a2, 0    # start_y = 0
    jal draw_sticker

    # FUL's up face (fixed cubie, position 0)
    li a0, 0    # physical_cubie 0 = 0
    li a1, 0    # orientation = 0
    li a2, 0    # face_type = 0 (U/D)
    jal get_sticker_color

    li a1, 8    # start_x = 8 (3 + 1 + 3 + 1)
    li a2, 4    # start_y = 4 (3 + 1)
    jal draw_sticker

    # BUR's up face
    lbu a0, 3(s0)       # physical_cubie 4 = p[3]
    lbu a1, 10(s0)      # orientation = o[3]
    li a2, 0            # face_type = 0 (U/D)
    addi a0, a0, 1      # offset by 1
    jal get_sticker_color
    
    li a1, 12   # start_x = 4 * 3
    li a2, 0    # start_y = 0
    jal draw_sticker

    # FUR's up face
    lbu a0, 0(s0)       # physical_cubie 1 = p[0]
    lbu a1, 7(s0)       # orientation = o[0]
    li a2, 0            # face_type = 0 (U/D)
    addi a0, a0, 1      # offset by 1
    jal get_sticker_color
    
    li a1, 12   # start_x = 4 * 3
    li a2, 4    # start_y = 4
    jal draw_sticker

    # LEFT

    # FUL's left face
    li a0, 0            # physical_cubie 0 = 0
    li a1, 0            # orientation = 0
    li a2, 2            # face_type = 2 (U->F->L)
    jal get_sticker_color
    
    li a1, 4
    li a2, 8
    jal draw_sticker

    # FDL's left face
    lbu a0, 2(s0)      # physical_cubie 3 = p[2]
    lbu a1, 9(s0)      # orientation = o[2]
    li a2, 1           # face_type = 1 (D->L->F)
    addi a0, a0, 1
    jal get_sticker_color
    
    li a1, 4
    li a2, 12
    jal draw_sticker

    # BDL's left face
    lbu a0, 5(s0)       # physical_cubie 6 = p[5]
    lbu a1, 12(s0)      # orientation = o[5]
    li a2, 2            # face_type = 2 (D->B->L)
    addi a0, a0, 1
    jal get_sticker_color
    
    li a1, 0
    li a2, 12
    jal draw_sticker

    # BUL's left face
    lbu a0, 6(s0)       # physical_cubie 7 = p[6]
    lbu a1, 13(s0)      # orientation = o[6]
    li a2, 1            # face_type = 1 (U->L->B)
    addi a0, a0, 1
    jal get_sticker_color
    
    li a1, 0
    li a2, 8
    jal draw_sticker

    # FRONT

    # FUL's front face
    li a0, 0    # physical_cubie 0 = 0
    li a1, 0    # orientation = 0
    li a2, 1    # face_type = 1 (U->F->L)
    jal get_sticker_color

    li a1, 8
    li a2, 8
    jal draw_sticker

    # FUR's front face
    lbu a0, 0(s0)       # physical_cubie 1 = p[0]
    lbu a1, 7(s0)       # orientation = o[0]
    li a2, 2            # face_type = 2 (U->R->F)
    addi a0, a0, 1
    jal get_sticker_color
    
    li a1, 12
    li a2, 8
    jal draw_sticker

    # FDR's front face
    lbu a0, 1(s0)       # physical_cubie 2 = p[1]
    lbu a1, 8(s0)       # orientation = o[1]
    li a2, 1            # face_type = 1 (D->F->R)
    addi a0, a0, 1
    jal get_sticker_color
    
    li a1, 12
    li a2, 12
    jal draw_sticker

    # FDL's front face
    lbu a0, 2(s0)       # physical_cubie 3 = p[2]
    lbu a1, 9(s0)       # orientation = o[2]
    li a2, 2            # face_type = 2 (D->L->F)
    addi a0, a0, 1
    jal get_sticker_color
    
    li a1, 8
    li a2, 12
    jal draw_sticker

    # DOWN

    # FDR's down face
    lbu a0, 1(s0)       # physical_cubie 2 = p[1]
    lbu a1, 8(s0)       # orientation = o[1]
    li a2, 0            # face_type = 0 (U/D)
    addi a0, a0, 1
    jal get_sticker_color
    
    li a1, 12
    li a2, 16
    jal draw_sticker

    # FDL's down face
    lbu a0, 2(s0)       # physical_cubie 3 = p[2]
    lbu a1, 9(s0)       # orientation = o[2]
    li a2, 0            # face_type = 0 (U/D)
    addi a0, a0, 1
    jal get_sticker_color
    
    li a1, 8
    li a2, 16
    jal draw_sticker

    # BDR's down face
    lbu a0, 4(s0)       # physical_cubie 5 = p[4]
    lbu a1, 12(s0)      # orientation = o[4]
    li a2, 0            # face_type = 0 (U/D)
    addi a0, a0, 1
    jal get_sticker_color
    
    li a1, 12
    li a2, 20
    jal draw_sticker

    # BDL's down face
    lbu a0, 5(s0)       # physical_cubie 6 = p[5]
    lbu a1, 12(s0)       # orientation = o[5]
    li a2, 0            # face_type = 0 (U/D)
    addi a0, a0, 1
    jal get_sticker_color

    li a1, 8
    li a2, 20
    jal draw_sticker

    # RIGHT

    # FUR's right face
    lbu a0, 0(s0)       # physical_cubie 1 = p[0]
    lbu a1, 7(s0)       # orientation = o[0]
    li a2, 1            # face_type = 1 (U->R->F)
    addi a0, a0, 1      
    jal get_sticker_color

    li a1, 16
    li a2, 8
    jal draw_sticker

    # FDR's right face
    lbu a0, 1(s0)       # physical_cubie 2 = p[1]
    lbu a1, 8(s0)       # orientation = o[1]
    li a2, 2            # face_type = 2 (D->F->R)
    addi a0, a0, 1      
    jal get_sticker_color

    li a1, 16
    li a2, 12
    jal draw_sticker

    # BUR's right face
    lbu a0, 3(s0)       # physical_cubie 4 = p[3]
    lbu a1, 10(s0)      # orientation = o[3]
    li a2, 2            # face_type = 2 (U->B->R)
    addi a0, a0, 1      
    jal get_sticker_color

    li a1, 20
    li a2, 8
    jal draw_sticker

    # BDR's right face
    lbu a0, 4(s0)       # physical_cubie 5 = p[4]
    lbu a1, 11(s0)      # orientation = o[4]
    li a2, 1            # face_type = 2 (D->R->B)
    addi a0, a0, 1      
    jal get_sticker_color

    li a1, 20
    li a2, 12
    jal draw_sticker

    # BACK

    # BUR's back face
    lbu a0, 3(s0)       # physical_cubie 4 = p[3]
    lbu a1, 10(s0)      # orientation = o[3]
    li a2, 1            # face_type = 2 (U->B->R)
    addi a0, a0, 1      
    jal get_sticker_color

    li a1, 24
    li a2, 8
    jal draw_sticker

    # BDR's back face
    lbu a0, 4(s0)       # physical_cubie 5 = p[4]
    lbu a1, 11(s0)      # orientation = o[4]
    li a2, 2            # face_type = 2 (D->R->B)
    addi a0, a0, 1      
    jal get_sticker_color

    li a1, 24
    li a2, 12
    jal draw_sticker

    # BDL's back face
    lbu a0, 5(s0)       # physical_cubie 6 = p[5]
    lbu a1, 12(s0)      # orientation = o[5]
    li a2, 1            # face_type = 2 (D->B->L)
    addi a0, a0, 1      
    jal get_sticker_color

    li a1, 28
    li a2, 12
    jal draw_sticker

    # BUL's back face
    lbu a0, 6(s0)       # physical_cubie 7 = p[6]
    lbu a1, 13(s0)      # orientation = o[6]
    li a2, 2            # face_type = 2 (U->L->B)
    addi a0, a0, 1      
    jal get_sticker_color

    li a1, 28
    li a2, 8
    jal draw_sticker

    lw s0, 0(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

.global draw_background
draw_background:
    li t0, LED_MATRIX_0_BASE
    li t3, LED_MATRIX_0_SIZE
    add t1, t0, t3  # t1 = start of invalid LED mem addr
    li t4, 0x48494B # background color
    li t2, 0        # t2 = i = 0
draw_background_L0:
    sw t4, 0(t0)
    addi t0, t0, 4
    bltu t0, t1, draw_background_L0
    ret

.global sleep_ms
sleep_ms:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 0(sp)
    sw s1, 4(sp)
    mv s1, a0       # s1 = ms to sleep

    li a7, 30       # Time_msec
    ecall
    mv s0, a0       # s0 = start_time
sleep_loop:
    # get current time
    li a7, 30
    ecall

    sub t0, a0, s0  # t0 = current_time - start_time
    bltu t0, s1, sleep_loop

    lw s0, 0(sp)
    lw s1, 4(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret
