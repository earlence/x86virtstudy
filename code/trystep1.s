//-----------------------------------------------------------------
//	trystep1.s
//
//	This is a 'testbed' for the 'vmxstep1.s' component of our
//	proposed VMX demo-program; it allows us to confirm before
//	we proceed further that our 'Guest' task works correctly.
//	Below are commands to assemble-link-install this testbed:
//
//	  $ as trystep1.s -o trystep1.o
//	  $ as vmxstep1.s -o vmxstep1.o
//	  $ ld trystep1.o vmxstep1.o -T ldscript -o trystep1.b
//	  $ dd if=trystep1.b of=/dev/sda4 seek=1
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 14 APR 2007
//-----------------------------------------------------------------

	.section	.text
	.short	0xABCD
main:	.code16

	mov	%sp, %cs:exit_pointer+0
	mov	%ss, %cs:exit_pointer+2

	mov	%cs, %ax
	mov	%ax, %ds
	mov	%ax, %es
	mov	%ax, %ss
	lea	tos, %sp	

	call	enter_protected_mode
	call	execute_program_demo
	call	leave_protected_mode

	lss	%cs:exit_pointer, %sp
	lret

exit_pointer:	.short	0, 0


tmpGDT:	.quad	0x0000000000000000
	
	.equ	sel_cs, (. - tmpGDT)+0
	.quad	0x00009A010000FFFF	

	.equ	sel_ds, (. - tmpGDT)+0
	.quad	0x000092010000FFFF	

	.equ	sel_TSS, (. - tmpGDT)+0
	.short	guest_limTSS, guest_TSS, 0x8901, 0x0000

	.equ	limGDT, (. - tmpGDT)-1


tmpIDT:	.space	13 * 8
	.short	isrGPF, sel_cs, 0x8E00, 0x0000
	.space	18 * 8
	.equ	limIDT, (. - tmpIDT)-1


regGDT:	.short	limGDT, tmpGDT, 0x0001
regIDT:	.short	limIDT, tmpIDT, 0x0001
regIVT:	.short	0x03FF, 0x0000, 0x0000


enter_protected_mode:

	cli

	mov	%cr0, %eax
	bts	$0, %eax
	mov	%eax, %cr0

	lgdt	regGDT
	lidt	regIDT

	ljmp	$sel_cs, $pm
pm:
	mov	$sel_ds, %ax
	mov	%ax, %ss
	mov	%ax, %ds
	mov	%ax, %es

	ret


leave_protected_mode:

	mov	$sel_ds, %ax
	mov	%ax, %ds
	mov	%ax, %es
	mov	%ax, %fs
	mov	%ax, %gs

	mov	%cr0, %eax
	btr	$0, %eax
	mov	%eax, %cr0

	ljmp	$0x1000, $rm
rm:
	mov	%cs, %ax
	mov	%ax, %ss
	mov	%ax, %ds

	lidt	regIVT
	sti
	ret



execute_program_demo:

	mov	%esp, tossave+0
	mov	%ss,  tossave+4

	mov	%esp, guest_TSS+4
	mov	%ss,  guest_TSS+8

	mov	$sel_TSS, %ax
	ltr	%ax

	pushl	$0x0000
	pushl	$0x0000
	pushl	$0x0000
	pushl	$0x0000
	pushl	$0x1000
	pushl	$guest_TOS3
	pushl	$0x00020002
	pushl	$0x1000
	pushl	$guest_task
	iretl


tossave:  .long	0, 0


isrGPF:	.code16
	lss	%cs:tossave, %esp
	ret


	.align	16
	.space	512
tos:

