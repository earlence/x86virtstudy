//-----------------------------------------------------------------
//	vm86uart.s
//
//	Here we have modified our earlier 'vm86demo.s' program so
//	that the procedure which executes in Virtual-8086 mode is
//	changed, transmitting a message over the null-modem cable
//	instead of merely writing color-attributes to local vram.
//	This has required us to enlarge the Task-State Segment so 
//	an i/o-permission bitmap will be included that allows the
//	Virtual-8086 code to execute 'in' and 'out' instructions.
//	
//	 to assemble:  $ as vm86uart.s -o vm86uart.o
//	 and to link:  $ ld vm86uart.o -T ldscript -o vm86uart.b
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 05 APR 2007
//	revised on: 12 APR 2007 -- for an i/o-permission bitmap
//-----------------------------------------------------------------


	.section	.text
#------------------------------------------------------------------
	.short	0xABCD
#------------------------------------------------------------------
main:	.code16
	mov	%sp, %cs:exit_pointer+0	# preserve the loader's SP
	mov	%ss, %cs:exit_pointer+2	# preserve the loader's SS

	mov	%cs, %ax		# address program data
	mov	%ax, %ds		#   with DS register
	mov	%ax, %es		#   also ES register
	mov	%ax, %ss		#   also SS register
	lea	tos0, %esp		# establish a new stack

	call	enter_protected_mode 
	call	execute_program_demo
	call	leave_protected_mode 

	lss	%cs:exit_pointer, %sp	# recover saved SS and SP
	lret				# back to program loader
#------------------------------------------------------------------
exit_pointer:	.short	0, 0
#------------------------------------------------------------------
# Our enlarged Task-State Segment (with its i/o-permission bitmap)
theTSS:	.space	25 * 4			# uninitialized longwords	
	.word	0, IOMAP - theTSS	# the i/o-bitmap's offset
IOMAP:	.zero	0x2000			# here is that i/o-bitmap 
	.byte	0xFF			# appended byte is needed 
	.equ	limTSS, (. - theTSS)-1	# segment-limit for TSS
#------------------------------------------------------------------
theIDT:	.space	8 * 13			# 13 'not-present' gates
	.word	isrGPF, sel_cs, 0x8F00, 0x0000	# 80386 trap-gate
	.equ	limIDT, (. - theIDT)-1	# segment-limit for IDT
#------------------------------------------------------------------
#------------------------------------------------------------------
theGDT:	.quad	0x0000000000000000

	.equ	sel_cs, (. - theGDT)+0	# selector for 16-bit code
	.quad	0x00009A010000FFFF	# code-segment descriptor

	.equ	sel_ds, (. - theGDT)+0	# selector for 16-bit data
	.quad	0x000092010000FFFF	# data-segment descriptor

	.equ	selTSS, (. - theGDT)+0	# selector for Task-State
	.word	limTSS, theTSS, 0x8901, 0x0000	# TSS descriptor

	.equ	limGDT, (. - theGDT)-1	# segment-limit for GDT
#------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001	# image for register GDTR
regIDT:	.word	limIDT, theIDT, 0x0001	# image for register IDTR
regIVT:	.word	0x03FF, 0x0000, 0x0000	# image for register IDTR
#------------------------------------------------------------------
enter_protected_mode:

	cli				# no device interrupts

	mov	%cr0, %eax		# get machine status
	bts	$0, %eax		# set PE-bit to 1
	mov	%eax, %cr0		# enable protection

	lgdt	regGDT			# load GDTR register
	lidt	regIDT			# load IDTR register

	ljmp	$sel_cs, $pm		# reload CS register
pm:
	mov	$sel_ds, %ax		
	mov	%ax, %ss		# reload SS register
	mov	%ax, %ds		# reload DS register
	mov	%ax, %es		# reload ES register

	ret				# back to main routine
#------------------------------------------------------------------
execute_program_demo:

	# initialize the Task-State Segment's SS0:ESP0 fields
	mov	%esp, theTSS+4		# preserve ESP register
	mov	%ss,  theTSS+8		#  and the SS register

	# setup register TR with selector for Task-State Segment
	mov	$selTSS, %ax		# selector for the TSS
	ltr	%ax			#  is loaded into TR 

	# make sure the NT-bit is clear in the EFLAGS register
	pushfl				# push EFLAGS settings
	btrl	$14, (%esp)		# reset NT-bit to zero
	popfl				# pop back into EFLAGS

	# setup current stack for 'return' to Virtual-8086 mode
	pushl	$0x0000			# image for GS register
	pushl	$0x0000			# image for FS register
	pushl	$0x0000			# image for DS register
	pushl	$0x0000			# image for ES register
	pushl	$0x1000			# image for SS register
	pushl	$tos3			# image for SP register
	pushl	$0x00020002		# image for EFLAGS (VM=1)
	pushl	$0x1000			# image for CS register
	pushl	$sendtext 		# image for IP register
	iretl				# enter Virtual-8086 mode
#------------------------------------------------------------------
sendtext: # this procedure will be executed in Virtual-8086 mode

	# here we initialize the serial-UART (115200-baud, 8-N-1)
	.equ	UART, 0x03F8		# base i/o port-address
	mov	$UART+3, %dx		# Line-Control register
	in	%dx, %al		# input current setting
	or	$0x80, %al		# set DLAB=1 (bit 7) to
	out	%al, %dx		# access Divisor Latch 
	mov	$UART+0,%dx		# Divisor Latch register
	mov	$0x0001, %ax		# smallest nonzero value
	out	%ax, %dx		# for 115200 baud-rate
	mov	$UART+3, %dx		# Line-Control register
	mov	$0x03, %al		# use 8-N-1 data-format
	out	%al, %dx		# for transmitting data

	# this loop uses 'polled' mode to transmit our message
	mov	%cs, %ax		# address program data
	mov	%ax, %ds		#   with DS register
	xor	%si, %si		# initial array-index
nxdata:	mov	$UART+5, %dx		# Line-Status register
	in	%dx, %al		# input current status
	test	$0x20, %al		# is the THRE-bit set?
	jz	nxdata			# no, spin until set
	mov	gmsg(%si), %al		# fetch message byte
	or	%al, %al		# is it final null?
	jz	done			# yes, message sent
	mov	$UART+0, %dx		# else TxData port
	out	%al, %dx		# send message byte
	inc	%si			# and advance index
	jmp	nxdata			# go back for more
done:	
	in	%dx, %al		# input current status
	test	$0x40, %al		# all bytes are sent?
	jz	done			# no, spin until done

	# send extra null-byte to restart UART's FIFO timeout
	mov	$UART+0, %dx		# select TxData port
	mov	$0x00, %al		# setup 'null' datum
	out	%al, %dx		# restart FIFO timer

	# now we try to execute a 'privileged' instruction
	hlt				# triggers an exception 
#------------------------------------------------------------------
gmsg:	.ascii	"\033[2J\033[10;26H"	# ansi-terminal commands
	.ascii	"Hello from Virtual-8086 mode"	# message-text
	.asciz	"\033[23;1H\n         "	# cursor to bottom row 
#------------------------------------------------------------------
#------------------------------------------------------------------
isrGPF:	# restore the former stack-address for a return to 'main'
	lss	%cs:theTSS+4, %esp	# reload former SS:ESP
	ret				# back to main routine
#------------------------------------------------------------------
leave_protected_mode:

	mov	$sel_ds, %ax		# assure 64K r/w data
	mov	%ax, %ds		#  using DS register
	mov	%ax, %es		#   and ES register

	mov	%cr0, %eax		# get machine status
	btr	$0, %eax		# reset PE-bit to 0
	mov	%eax, %cr0		# disable protection

	ljmp	$0x1000, $rm		# reload CS register
rm:
	mov	%cs, %ax		
	mov	%ax, %ss		# reload SS register
	mov	%ax, %ds		# reload DS register
	mov	%ax, %es		# reload ES register

	lidt	regIVT			# reload IDTR register
	sti				# interrupts allowed

	ret				# back to main routine
#------------------------------------------------------------------
	.align	16			# insure stack alignment
	.space	512			# region for ring3 stack
tos3:					# label for the stacktop 
	.space	512			# region for ring0 stack
tos0:					# label for the stacktop
#------------------------------------------------------------------
	.end				# nothing else to assemble
