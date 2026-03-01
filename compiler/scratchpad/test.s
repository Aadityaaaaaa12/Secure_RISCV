	.file	"test.c"
	.option nopic
	.attribute arch, "rv32i2p1"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.globl	sink
	.section	.sbss,"aw",@nobits
	.align	2
	.type	sink, @object
	.size	sink, 4
sink:
	.zero	4
	.text
	.align	2
	.globl	good_func
	.type	good_func, @function
good_func:
	addi	sp,sp,-48
	sw	s0,44(sp)
	addi	s0,sp,48
	sw	a0,-36(s0)
	sw	a1,-40(s0)
	lw	a5,-36(s0)
	addi	a5,a5,1
	sw	a5,-20(s0)
	lw	a4,-40(s0)
	li	a5,305418240
	addi	a5,a5,1656
	xor	a5,a4,a5
	sw	a5,-24(s0)
	lw	a5,-20(s0)
	slli	a4,a5,2
	lw	a5,-24(s0)
	srli	a5,a5,3
	add	a5,a4,a5
	sw	a5,-28(s0)
	lw	a4,-28(s0)
	lui	a5,%hi(sink)
	sw	a4,%lo(sink)(a5)
	lw	a5,-28(s0)
	mv	a0,a5
	lw	s0,44(sp)
	addi	sp,sp,48
	jr	ra
	.size	good_func, .-good_func
	.align	2
	.globl	bad_func
	.type	bad_func, @function
bad_func:
	addi	sp,sp,-48
	sw	s0,44(sp)
	addi	s0,sp,48
	sw	a0,-36(s0)
	lw	a5,-36(s0)
	addi	a5,a5,7
	sw	a5,-20(s0)
	lw	a5,-20(s0)
	addi	a5,a5,-3
	sw	a5,-24(s0)
	lw	a4,-24(s0)
	lui	a5,%hi(sink)
	sw	a4,%lo(sink)(a5)
	lw	a5,-24(s0)
	mv	a0,a5
	lw	s0,44(sp)
	addi	sp,sp,48
	jr	ra
	.size	bad_func, .-bad_func
	.align	2
	.globl	main
	.type	main, @function
main:
	addi	sp,sp,-32
	sw	ra,28(sp)
	sw	s0,24(sp)
	addi	s0,sp,32
	li	a5,5
	sw	a5,-20(s0)
	li	a5,16
	sw	a5,-24(s0)
	lw	a5,-20(s0)
	lw	a4,-24(s0)
	mv	a1,a4
	mv	a0,a5
	call	good_func
	mv	a5,a0
	sw	a5,-28(s0)
	lw	a5,-28(s0)
	mv	a0,a5
	call	bad_func
	mv	a5,a0
	sw	a5,-32(s0)
	lw	a4,-32(s0)
	lui	a5,%hi(sink)
	sw	a4,%lo(sink)(a5)
	lui	a5,%hi(sink)
	lw	a5,%lo(sink)(a5)
	andi	a5,a5,255
	mv	a0,a5
	lw	ra,28(sp)
	lw	s0,24(sp)
	addi	sp,sp,32
	jr	ra
	.size	main, .-main
	.ident	"GCC: (13.2.0-11ubuntu1+12) 13.2.0"
