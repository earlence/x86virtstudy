//-----------------------------------------------------------------
//	vm86trap.s
//
//	This example illustrates the 'trap-and-emulate' concept,
//	which is fundamental for implementing a virtual machine.
//	(The 'mov %cr0, reg' instruction is not normally allowed
//	to execute in Virtual-8086 mode, but here we show how to
//	'emulate' the behavior of that instruction as if it were
//	being executed in real-mode; for comparison, we show the
//	actual contents of this register obtained using 'smsw'.)
//
//	 to assemble:  $ as vm86trap.s -o vm86trap.o
//	 and to link:  $ ld vm86trap.o -T ldscript -o vm86trap.b
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 17 APR 2007
//	correction: 22 JAN 2008 -- changed PAE to PSE in comment 
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

	.equ	sel_fs, (. - theGDT)+0	# selector for 'flat' data-
	.quad	0x008F92000000FFFF	# segment: base=0,limit=4GB

	.equ	selTSS, (. - theGDT)+0	# selector for Task-State
	.word	limTSS, theTSS, 0x8901, 0x0000	# TSS descriptor

	.equ	limGDT, (. - theGDT)-1	# segment-limit for GDT
#------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001	# image for register GDTR
regIDT:	.word	limIDT, theIDT, 0x0001	# image for register IDTR
regIVT:	.word	0x03FF, 0x0000, 0x0000	# image for register IDTR
regCR3:	.long	pgdir + 0x10000		# image for register CR3
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

	# load page-directory physical-address into CR3
	mov	regCR3, %eax		# get CR3 register-image
	mov	%eax, %cr3		# and load into register

	# enable Page-Size Extensions in Control Register CR4
	mov	%cr4, %eax		# current CR4 value
	bts	$4, %eax		# turn on PSE-bit <-- corrected 1/22/08
	mov	%eax, %cr4		# revised CR4 value

	# enable paging in Control Register CR0
	mov	%cr0, %eax		# current CR0 value
	bts	$31, %eax		# turn on PG-bit
	mov	%eax, %cr0		# revised CR0 value

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
	pushl	$trapdemo 		# image for IP register
	iretl				# enter Virtual-8086 mode
#------------------------------------------------------------------
trapdemo: # this procedure will be executed in Virtual-8086 mode

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

	# setup segment-register DS to address our variables
	mov	%cs, %ax		# address program data
	mov	%ax, %ds		#   with DS register

	# here we try to execute a privileged 'mov' instruction
	mov	%cr0, %edx		# current CR0 contents
	mov	%edx, regCR0		# written to a variable

	# then we execute the unprivileged 'smswl' instruction
	smswl	%eax			# current MSW contents
	mov	%eax, regMSW		# written to a variable

	# next we format these values for display 
	mov	regCR0, %eax		# recover stored value
	lea	buf1, %di		# point to buffer-field
	call	eax2hex			# convert to hex string

	mov	regMSW, %eax		# recover stored value
	lea	buf2, %di		# point to buffer-field
	call	eax2hex			# convert to hex string

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
done:	in	%dx, %al		# input current status
	test	$0x40, %al		# all bytes are sent?
	jz	done			# no, spin until done

	# send extra null-byte to restart UART's FIFO timeout
	mov	$UART+0, %dx		# select TxData port
	mov	$0x00, %al		# setup 'null' datum
	out	%al, %dx		# restart FIFO timer

	# now we try to execute the privileged 'hlt' instruction
	hlt				# triggers an exception 
#------------------------------------------------------------------
regMSW:	.long	0			# for actual CR0 value
regCR0:	.long	0			# for the emulated CR0
gmsg:	.ascii	"\033[2J\033[10;26H"	# ansi-terminal commands
	.ascii	"Hello from Virtual-8086 mode"	# message-text
	.ascii	"\033[12;26H CR0="	# command and reg-name
buf1:	.ascii	"xxxxxxxx  MSW="	# buffer for CR0-value
buf2:	.ascii	"xxxxxxxx "		# buffer for MSW-value
	.asciz	"\033[23;1H\n         "	# cursor to bottom row 
#------------------------------------------------------------------
eax2hex: # converts value in EAX to hexadecimal string at DS:DI
	pushal				# preserve registers
	mov	$8, %cx			# number of nybbles
nxnyb:	rol	$4, %eax		# next nybble into AL
	mov	%al, %bl		# copy nybble into BL
	and	$0xF, %bx		# isolate nybble's bits
	mov	hex(%bx), %dl		# lookup nybble's numeral
	mov	%dl, (%di)		# store numeral in buffer
	inc	%di			# advance buffer-pointer
	loop	nxnyb			# again for other nybbles
	popal				# restore saved registers
	ret				# return back to caller
#------------------------------------------------------------------
#------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"	# table of hex numerals
#------------------------------------------------------------------
isrGPF:	# This is our fault-handler for General Protection faults

	# verify that the exception was triggered in VM86 mode
	btl	$17, 12(%esp)		# was EFLAGS VM-bit set? 
	jnc	depart			# no, terminate program	

	# preserve registers and setup stackframe access
	pushal
	mov	%esp, %ebp
	
	# setup register DS to address the 'flat' 4GB-segment
	pushl	%ds
	mov	$sel_fs, %ax
	mov	%ax, %ds

	# compute the address of the faulting instruction
	movw	40(%ebp), %di		# image of CS
	movzx	%di, %edi		# as 32-bit value
	shl	$4, %edi		# times 16
	movw	36(%ebp), %ax		# image of IP
	movzx	%ax, %eax		# as 32-bit value
	add	%eax, %edi		# instruction-address

	# verify that instruction was 'mov %cr0, reg'
	mov	%ds:(%edi), %edx	# fetch the instruction
	and	$0x00F8FFFF, %edx	# isolate relevant bits
	cmp	$0x00C0200F, %edx	# is it 'mov %cr0, reg'?
	je	emulate			# yes, we 'emulate' it
	jne	depart			# else terminate program
emulate:
	# fetch instruction's 'mod-r/m' byte	
	mov	%ds:2(%edi), %dl	# mod-r/m into DL
	and	$0x07, %edx		# get register-number
	neg 	%edx
	add 	$7, %edx
	mov	%cr0, %eax		# actual value of CR0
	btr	$0, %eax		# clear PE-bit image
	btr	$31, %eax		# clear PG-bit imake
	mov	%eax, (%ebp, %edx, 4)	# overwrite reg-image

	# advance image of IP to 'skip' the 3-byte instruction
	addw	$3, 36(%ebp)		# advance IP reg-image
	
	# resume the interrupted VM86 procedure
	popl	%ds
	popal
	add	$4, %esp
	iretl

depart:	
	lss	%cs:theTSS+4, %esp	# reload former SS:ESP
	ret				# back to main routine
#------------------------------------------------------------------
#------------------------------------------------------------------
leave_protected_mode:

	mov	$sel_ds, %ax		# assure 64K r/w data
	mov	%ax, %ds		#  using DS register
	mov	%ax, %es		#   and ES register

	mov	%cr0, %eax		# get machine status
	btr	$0, %eax		# reset PE-bit to 0
	btr	$31, %eax		# reset PG-bit to 0
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

	.section	.data
	.align	0x1000
#------------------------------------------------------------------
# This page-directory identically maps the bottom 4-MB of memory
#------------------------------------------------------------------
pgdir:	.long	0x00000087		# identity-map 4MB-frame
	.zero	1023 * 4		# zeros in other entries 
#------------------------------------------------------------------
	.end				# nothing else to assemble

