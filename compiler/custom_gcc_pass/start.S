# start.S
    .section .text.start
    .globl _start
    .type _start, @function

_start:
    # Set stack pointer (choose a safe RAM top that your FPGA memory actually has)
    lui     sp, %hi(_stack_top)
    addi    sp, sp, %lo(_stack_top)

    # Call main
    jal     ra, main

1:  # If main returns, loop forever
    j       1b
