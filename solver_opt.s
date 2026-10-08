.data
state_str: .string "21345671111111"

.text
_start:
    la a0, state_str
    li a7, 4  # print string
    ecall
    li a7, 10 # exit
    ecall

parse_state:
