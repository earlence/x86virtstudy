//-----------------------------------------------------------------
//	emitinfo.s
//
//	This boot-time program shows how an exception-handler can
//	transmit some diagnostic information via the serial-port.
//	It sends some ANSI character-rendition sequences to place
//	the cursor at desired screen-locations on the remote text
//	terminal's display-screen.  
//	
//	  assemble:  $ as emitinfo.s -o emotinfo.o
//	  and link:  $ ld emitinfo.o -T ldscript -o emotinfo.b
//	  
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 01 MAR 2007
//	revised on: 02 MAR 2007 -- for more cautious UART setup
//-----------------------------------------------------------------

	# manifest constants
	.equ	UART, 0x03F8
	.equ	DIVISOR_LATCH, UART+0
	.equ	RX_DATA, UART+0
	.equ	TX_DATA, UART+0
	.equ	INTERRUPT_ENABLE, UART+1
	.equ	INTERRUPT_IDENT, UART+2
	.equ	FIFO_CONTROL, UART+2
	.equ	LINE_CONTROL, UART+3
	.equ	MODEM_CONTROL, UART+4
	.equ	LINE_STATUS, UART+5
	.equ	MODEM_STATUS, UART+6


	.section	.text
#------------------------------------------------------------------
	.short	0xABCD
#------------------------------------------------------------------
begin:	.code16				# for x86 'real-mode'
	mov	%sp, %cs:exit_pointer+0
	mov	%ss, %cs:exit_pointer+2

	mov	%cs, %ax
	mov	%ax, %ds
	mov	%ax, %ss
	lea	tos, %sp

	call	create_system_tables
	call	enter_protected_mode
	call	execute_program_demo
	call	leave_protected_mode
	
	lss	%cs:exit_pointer, %sp
	lret
#------------------------------------------------------------------
exit_pointer:	.short	0, 0
#------------------------------------------------------------------
#------------------------------------------------------------------
theGDT:	.quad	0x0000000000000000

	.equ	sel_CS, (. - theGDT)+0
	.quad	0x00409A010000FFFF

	.equ	sel_cs, (. - theGDT)+0
	.quad	0x00009A010000FFFF

	.equ	sel_ds, (. - theGDT)+0
	.quad	0x000092010000FFFF

	.equ	sel_es, (. - theGDT)+0
	.quad	0x0000920B8000FFFF

	.equ	limGDT, (. - theGDT)-1
#------------------------------------------------------------------
theIDT:	.space	256 * 8
	.equ	limIDT, (. - theIDT)-1
#------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001
regIDT:	.word	limIDT, theIDT, 0x0001
regIVT:	.word	0x03FF, 0x0000, 0x0000
#------------------------------------------------------------------
create_system_tables:

	# create gate-descriptor for General Protection Exceptions
	mov	$0x0D, %bx
	imul	$8, %bx, %di
	lea	theIDT(%di), %di
	movw	$isrGPF, 0(%di)
	movw	$sel_CS, 2(%di)
	movw	$0x8E00, 4(%di)
	movw	$0x0000, 6(%di)

	ret
#------------------------------------------------------------------
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
#------------------------------------------------------------------
#------------------------------------------------------------------
leave_protected_mode:

	mov	$sel_ds, %ax
	mov	%ax, %ds
	mov	%ax, %es
	mov	%ax, %ss

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
#------------------------------------------------------------------
divslat: .word	0
intr_en: .byte 	0
lineCtl: .byte 	0
modmCtl: .byte	0
picmask: .byte	0
tossave: .int	0, 0
#------------------------------------------------------------------
execute_program_demo:

	mov	%esp, tossave+0
	mov	%ss, tossave+4

	call	configure_uart 
	int	$15	# <-- invalid instruction, tests 'isrGPF'
	call	restore_system

	lss	%cs:tossave, %esp	
	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
configure_uart:

	mov	$INTERRUPT_ENABLE, %dx	
	in	%dx, %al
	mov	%al, intr_en
	mov	$0x00, %al
	out	%al, %dx

	mov	$FIFO_CONTROL, %dx
	mov	$0x00, %al
	out	%al, %dx
	mov	$0xC7, %al		
	out	%al, %dx

	mov	$LINE_CONTROL, %dx		# line-control
	in	%dx, %al
	mov	%al, lineCtl
	or	$0x80, %al
	out	%al, %dx
	mov	$DIVISOR_LATCH, %dx
	in	%dx, %ax
	mov	%ax, divslat
	mov	$0x0001, %ax
	out	%ax, %dx
	mov	$LINE_CONTROL, %dx
	mov	$0x03, %al
	out	%al, %dx

	mov	$MODEM_CONTROL, %dx
	in	%dx, %al
	mov	%al, modmCtl
	mov	$0x03, %al
	out	%al, %dx

	mov	$MODEM_STATUS, %dx
	in	%dx, %al
	mov	$LINE_STATUS, %dx
	in	%dx, %al
	mov	$RX_DATA, %dx
	in	%dx, %al
	mov	$INTERRUPT_IDENT, %dx
	in	%dx, %al
	
	ret
#------------------------------------------------------------------
restore_system:

	mov	$INTERRUPT_ENABLE, %dx	
	mov	intr_en, %al
	out	%al, %dx

	mov	$FIFO_CONTROL, %dx
	mov	$0x00, %al
	out	%al, %dx
	mov	$0xC7, %al		
	out	%al, %dx

	mov	$LINE_CONTROL, %dx		# line-control
	in	%dx, %al
	or	$0x80, %al
	out	%al, %dx
	mov	$DIVISOR_LATCH, %dx
	mov	divslat, %ax
	out	%ax, %dx
	mov	$LINE_CONTROL, %dx
	mov	lineCtl, %al
	out	%al, %dx

	mov	$MODEM_CONTROL, %dx
	mov	modmCtl, %al
	out	%al, %dx

	mov	$MODEM_STATUS, %dx
	in	%dx, %al
	mov	$LINE_STATUS, %dx
	in	%dx, %al
	mov	$RX_DATA, %dx
	in	%dx, %al
	mov	$INTERRUPT_IDENT, %dx
	in	%dx, %al
	
	ret
#------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"
crs:	.ascii	"\033["
row:	.ascii	"01;"
col:	.ascii	"64H"
buf:	.asciz	" nnn=xxxxxxxx "
names:	.ascii	"  ES  DS EDI ESI EBP ESP EDX ECX EBX EAX"
	.ascii	" err EIP  CS EFL"
	.equ	N_ELTS, (. - names)/4
#------------------------------------------------------------------
isrGPF:	.code32

	push	%eax
	push	%ebx
	push	%ecx
	push	%edx
	push	%esp
	addl	$20, (%esp)
	push	%ebp
	push	%esi
	push	%edi
	pushl	%ds
	pushl	%es		

	mov	$sel_ds, %ax
	mov	%ax, %ds
	
	mov	$sel_es, %ax
	mov	%ax, %es

	xor	%ebx, %ebx
nxelt:
	# setup element-name
	mov	names(, %ebx, 4), %eax
	mov	%eax, buf

	# setup element-value
	mov	(%esp, %ebx, 4), %eax
	lea	buf+5, %edi
	call	eax2hex

	# setup element's output-position
	mov	$20, %eax
	sub	%ebx, %eax	
	mov	$10, %cl
	div	%cl
	add	$0x3030, %ax
	mov	%ax, row

	# output information to serial-port
	lea	crs, %esi
	call	emit_crs	
	
	inc	%ebx
	cmp	$N_ELTS, %ebx
	jb	nxelt

	popl	%es
	popl	%ds
	pop	%edi
	pop	%esi
	pop	%ebp
	add	$4, %esp
	pop	%edx
	pop	%ecx
	pop	%ebx
	pop	%eax
	add	$4, %esp
	addl	$2, (%esp)
	iretl
#------------------------------------------------------------------
eax2hex: .code32
	pushal
	
	mov	$8, %ecx
nxnyb:	rol	$4, %eax
	mov	%al, %bl
	and	$0x0F, %ebx
	mov	hex(%ebx), %dl
	mov	%dl, (%edi)
	inc	%edi
	loop	nxnyb

	popal
	ret
#------------------------------------------------------------------
emit_crs: .code32	
#
#	EXPECTS:	DS:ESI = address of asciz-string
#		
	push	%eax
	push	%edx
	push	%esi

ckthre:	mov	$LINE_STATUS, %dx
	in	%dx, %al
	test	$0x20, %al
	jz	ckthre

	cmpb	$0, (%esi)
	je	txdone

	mov	$TX_DATA, %dx
	mov	(%esi), %al
	out	%al, %dx
	inc	%esi
	jmp	ckthre
txdone:
	pop	%esi
	pop	%edx
	pop	%eax
	ret
#------------------------------------------------------------------
	.align	16
	.space	512
tos:
#------------------------------------------------------------------
	.end


