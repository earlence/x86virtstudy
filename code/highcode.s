//-----------------------------------------------------------------
//	highcode.s
//
//	This example shows how to construct page-mapping tables to
//	permit execution of code in 64-bit mode which was designed
//	to reside in a very high page of the virtual memory space.  
//	(Here we will employ a special linker script that performs 
//	the appropriate "code-relocation" for this demonstration.)  
//	
//		$ as highcode.s -o highcode.o
//		$ as highdraw.s -o highdraw.o
//		$ ld highcode.o -T ldscript -o highcode.b
//		$ ld highdraw.o -T hiscript -o highdraw.b
//		$ dd if=highcode.b of=/dev/sda4 seek=1
//		$ dd if=highdraw.b of=/dev/sda4 seek=128
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 09 MAR 2006
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

	call	load_demo_module
	call	enter_ia32e_mode
	call	execute_the_demo
	call	leave_ia32e_mode

	lss	%cs:exit_pointer, %sp
	lret
exit_pointer: 	.short	0, 0

theGDT:	.quad	0x0000000000000000

	.equ	sel_CS, (. - theGDT)+0
	.quad	0x00209A0000000000

	.equ	sel_cs, (. - theGDT)+0
	.quad	0x00009A010000FFFF

	.equ	sel_ss, (. - theGDT)+0
	.quad	0x000092010000FFFF

	.equ	sel_es, (. - theGDT)+0
	.quad	0x0000920B8000FFFF

	.equ	gate64, (. - theGDT)+0
	.word	0x0002, sel_CS, 0x8C00, 0xC000
	.word	0xFFFF, 0xFFFF, 0x0000, 0x0000
	
	.equ	limGDT, (. - theGDT)-1

packet:	.byte	16, 0, 1, 0
	.short	0x0000, 0x2000
	.quad	128

regCR3:	.long	level4 + 0x10000
regGDT:	.word	limGDT, theGDT, 0x0001

load_demo_module:

	# adjust our Data Address Packet's LBA field
	add	%ebx, packet+8	# add partition's initial LBA

	lea	packet, %si
	mov	$0x80, %dl
	mov	$0x42, %ah
	int	$0x13

	xor	$0x2000, %ax
	mov	%ax, %es
	cmpw	$0xABCD, %es:0		
	je	ldok

	mov	$0x0E58, %ax
	mov	$0x0000, %bx
	int	$0x10

	mov	%es:0, %al
	mov	$0x0E, %ah
	int	$0x10


	lss	%cs:exit_pointer, %sp
	lret

ldok:	ret

enter_ia32e_mode:

	mov	$0xC0000080, %ecx
	rdmsr
	bts	$8, %eax
	wrmsr

	mov	%cr4, %eax
	bts	$5, %eax
	mov	%eax, %cr4 

	mov	regCR3, %eax
	mov	%eax, %cr3

	cli

	mov	%cr0, %eax
	bts	$0, %eax
	bts	$31, %eax
	mov	%eax, %cr0	
	
	lgdt	regGDT
	ljmp	$sel_cs, $pm
pm:
	mov	$sel_ss, %ax
	mov	%ax, %ss
	mov	%ax, %ds

	ret

execute_the_demo:
	mov	%esp, tossave+0
	mov	%ss,  tossave+4
	
	mov	$0x20000, %esp
	lcall	$gate64, $0 

	lss	%cs:tossave, %esp
	ret
tossave: .long	0, 0


leave_ia32e_mode:

	mov	$sel_ss, %ax
	mov	%ax, %ss
	mov	%ax, %ds
	mov	%ax, %es
	mov	%ax, %fs
	mov	%ax, %gs

	mov	%cr0,%eax
	btr	$0, %eax
	btr 	$31, %eax
	mov	%eax, %cr0

	ljmp	$0x1000, $rm
rm:
	mov	%cs, %ax
	mov	%ax, %ss
	mov	%ax, %ds

	sti

	ret

	.align	16
	.space	512
tos:
	


	.section	.data
	.align	0x1000
lvl1_L:	entry = 0
	.rept	256
	.quad	entry + 7
	entry = entry + 0x1000
	.endr
	.align	0x1000
#------------------------------------------------------------------	
lvl1_H:	.quad	0x20000 + 7
	.space	511 * 8
#------------------------------------------------------------------	
lvl2_L:	.quad	lvl1_L + 0x10000 + 7
	.space	511 * 8
#------------------------------------------------------------------	
lvl2_H:	.quad	lvl1_H + 0x10000 + 7	
	.space	511 * 8
#------------------------------------------------------------------
lvl3_L: .quad	lvl2_L + 0x10000 + 7
	.space	511 * 8
#------------------------------------------------------------------
lvl3_H: .space 511 * 8 
	.quad	lvl2_H + 0x10000 + 7
#------------------------------------------------------------------
level4:	.quad	lvl3_L + 0x10000 + 7
	.space	510 * 8
	.quad	lvl3_H + 0x10000 + 7
#------------------------------------------------------------------
	.end

