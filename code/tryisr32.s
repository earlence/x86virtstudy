//-----------------------------------------------------------------
//	tryisr32.s
//
//	This example invokes an interrupt-handler in 32-bit mode.
//
//	 to assemble:  $ as tryisr32.s -o tryisr32.o
//	 and to link:  $ ld tryisr32.o -T ldscript -o tryisr32.b
//	 and install:  $ dd if=tryisr32.b of=/dev/sda4 seek=1
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 25 FEB 2007
//	revised on: 16 MAR 2007 -- used '.long' in place of .quad
//-----------------------------------------------------------------

	.section	.text
#------------------------------------------------------------------
	.short	0xABCD
#------------------------------------------------------------------
begin:	.code16
	mov	%sp, %cs:exit_pointer+0	# preserve the loader's SP
	mov	%ss, %cs:exit_pointer+2	# preserve the loader's SS

	mov	%cs, %ax		# address program data
	mov	%ax, %ds		#   with DS register
	mov	%ax, %ss		#   also SS register
	lea	tos, %sp		# setup a new stacktop

	call	create_system_tables
	call	initialize_variables
	call	enter_protected_mode
	call	execute_program_demo
	call	leave_protected_mode
	call	update_machine_state

	lss	%cs:exit_pointer, %sp	# recover loader's SS:SP
	lret				# for exit back to loader
#------------------------------------------------------------------
exit_pointer:	.short	0, 0		# holds loader's SS and SP 
#------------------------------------------------------------------
create_system_tables:

	# install an interrupt-gate for the timer-tick interrupt
	mov	$0x08, %bx		# timer's interrupt-ID
	imul	$8, %bx, %di		# times descriptor-size
	lea	theIDT(%di), %di	# point DS:DI to entry
	movw	$isrTMR, 0(%di)		# entry-point [15..0]
	movw	$sel_CS, 2(%di)		# 32-bit code-selector
	movw	$0x8E00, 4(%di)		# 80386 interrupt-gate
	movw	$0x0000, 6(%di)		# entry-point [31..16]
	ret
#------------------------------------------------------------------
theIDT:	.space	256 * 8			# for 256 gate-descriptors
	.equ	limIDT, (. - theIDT)-1	# our IDT-segment's limit
#------------------------------------------------------------------
#------------------------------------------------------------------
theGDT:	# Our Global Descriptor Table (needed for protected-mode)
	.quad	0x0000000000000000		# null-descriptor

	.equ	sel_CS, (. - theGDT)+0	# selector for 32bit code
	.quad	0x00409A010000FFFF		# code-descriptor

	.equ	sel_cs, (. - theGDT)+0	# selector for 16bit code
	.quad	0x00009A010000FFFF		# code-descriptor

	.equ	sel_ds, (. - theGDT)+0	# selector for 16bit data
	.quad	0x000092010000FFFF		# data-descriptor

	.equ	sel_es, (. - theGDT)+0	# selector for 16bit data
	.quad	0x0000920B8000FFFF		# vram-descriptor

	.equ	sel_fs, (. - theGDT)+0	# selector for 16bit data
	.quad	0x000092000000FFFF		# bios-descriptor

	.equ	limGDT, (. - theGDT)-1	# our GDT-segment's limit
#------------------------------------------------------------------
regCR3:	.long	level3 + 0x10000	# level3 physical-address 
regGDT:	.word	limGDT, theGDT, 0x0001	# register-image for GDTR
regIDT:	.word	limIDT, theIDT, 0x0001	# register-image for IDTR
#------------------------------------------------------------------
saveCR0: .long	0			# stores the original CR0
saveCR3: .long	0			# stores the original CR3
saveCR4: .long	0			# stores the original CR4
saveGDT: .word	0, 0, 0			# stores the original GDTR
saveIDT: .word	0, 0, 0			# stores the original IDTR
picmask: .byte	0			# stores the 8259-PIC mask
#------------------------------------------------------------------
enter_protected_mode:

	cli				# interrupts not allowed

	mov	%cr0, %eax		# current machine status
	bts	$0, %eax		# turn on PE-bit image
	bts	$31, %eax		# turn on PG-bit image
	mov	%eax, %cr0		# enable protected-mode

	lgdt	regGDT			# setup GDTR register
	lidt	regIDT			# setup IDTR register

	ljmp	$sel_cs, $pm		# code-selector into CS
pm:	
	mov	$sel_ds, %ax		# load our data-selector
	mov	%ax, %ss		#  into the SS register
	mov	%ax, %ds		#  also the DS register
	mov	%ax, %es		#  also the ES register

	ret				# back to main routine
#------------------------------------------------------------------
jiffies: .int	0			# for timer-tick counter
timeout: .int	91 * 3			# for 15-second duration
#------------------------------------------------------------------
#------------------------------------------------------------------
initialize_variables:

	xor	%ax, %ax		# address rom-bios data 
	mov	%ax, %fs		#   with FS register
	mov	%ax, %gs		#   also GS register
	mov	%fs:0x046C, %eax	# get system tick-count
	mov	%eax, jiffies		# and save as 'jiffies'
	add	%eax, timeout		# also add to 'timeout'
	
	sidt	saveIDT			# save system's IDTR
	sgdt	saveGDT			# save system's GDTR

	mov	%cr0, %eax		# get register CR0
	mov	%eax, saveCR0		# save system's CR0
	mov	%cr3, %eax		# get register CR3
	mov	%eax, saveCR3		# save system's CR3
	mov	%cr4, %eax		# get register CR4
	mov	%eax, saveCR4		# save system's CR4
	bts	$5, %eax		# set PAE-bit image
	mov	%eax, %cr4		# in register CR4
	mov	regCR3, %eax		# setup pagemap base
	mov	%eax, %cr3		# in register CR3

	inb	$0x21, %al		# get master-PIC mask
	mov	%al, picmask		# save system's mask
	mov	$0xFE, %al		# mask all but timer
	out	%al, $0x21		# from interrupting

	ret
#------------------------------------------------------------------
leave_protected_mode:

	mov	saveCR0, %eax		# recover original CR0
	mov	%eax, %cr0		# to reenter real-mode

	mov	saveCR3, %eax		# recover original CR3
	mov	%eax, %cr3		# to flush out the TLB

	mov	saveCR4, %eax		# recover original CR4
	mov	%eax, %cr4		# to restore PAE-bit

	ljmp	$0x1000, $rm		# reload CS register
rm:	mov	%cs, %ax		# for 'real-mode'
	mov	%ax, %ss		# also SS register
	mov	%ax, %ds		# also DS register

	lidt	saveIDT			# restore former IDTR
	lgdt	saveGDT			# restore former GDTR

	mov	picmask, %al		# restore PIC's mask
	out	%al, $0x21		# to allow interrupts
	sti				# from former devices

	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
execute_program_demo:

	mov	$sel_ds, %ax		# address program data
	mov	%ax, %ds		#   with DS register
	mov	$sel_es, %ax		# address video memory
	mov	%ax, %es		#   with ES register

	sti				# allow device interrupts
again:
	call	calculate_current_time	
	call	format_time_components
	call	write_report_to_screen
	
	mov	jiffies, %eax		# get current tick-count
	cmp	%eax, timeout		# timeout value reached?
	ja	again			# no, update the display 

	cli				# else disable interrupts
	ret				# go back to main routine
#------------------------------------------------------------------
msg:	.ascii	" Time is xx:xx:xx xm "	# buffer for time-message 	
len:	.int	. - msg			# length of message-string
att:	.byte	0x50			# message color-attributes
ss:	.int	0			# storage for current secs
mm:	.int	0			# storage for current mins
hh:	.int	0			# storage for current hour
hd:	.int	0			# storage for halfday flag 
ap:	.ascii	"ap"			# characters for 'am'/'pm'
#------------------------------------------------------------------
calculate_current_time:

	mov	jiffies, %eax		# get current tick-count
	mov	$10, %edx		# setup ten as multiplier
	mul	%edx			# perform multiplication
	mov	$182, %ecx		# use 18.2 * 10 as divisor
	div	%ecx			# perform the division
	
	xor	%edx, %edx		# zero-extend the quotient 
	mov	$60, %ecx		# number of secs-per-min
	div	%ecx			# perform the division
	mov	%edx, ss		# remainder gives secs
	
	xor	%edx, %edx		# zero-extend the quotient
	mov	$60, %ecx		# number of mins-per-hour
	div	%ecx			# perform the division
	mov	%edx, mm		# remainder gives mins

	xor	%edx, %edx		# zero-extend the quotient
	mov	$12, %ecx		# number of hours-per-halfday
	div	%ecx			# perform the division
	mov	%edx, hh		# remainder gives hours
	mov	%eax, hd		# quotient gives halfdays

	ret	
#------------------------------------------------------------------
#------------------------------------------------------------------
format_time_components:

	mov	ss, %ax			# get current seconds
	mov	$10, %bl		# setup ten as divisor
	div	%bl			# perform byte division
	or	$0x3030, %ax		# convert both results 
	mov	%ax, msg+15		# put numerals in message

	mov	mm, %ax			# get current minutes
	mov	$10, %bl		# setup ten as divisor
	div	%bl			# perform byte division
	or	$0x3030, %ax		# convert both results
	mov	%ax, msg+12		# put numerals in message

	mov	hh, %ax			# get current hours
	mov	$10, %bl		# setup ten as divisor
	div	%bl			# perform byte division
	or	$0x3030, %ax		# put numerals in message
	mov	%ax, msg+9

	mov	hd, %eax		# get the halfday flag
	mov	ap(%eax), %dl		# 'am' or 'pm' character
	mov	%dl, msg+18		# put character in message

	ret
#------------------------------------------------------------------
write_report_to_screen:

	mov	$12, %ax		# setup row-number in AX
	imul	$160, %ax, %di		# compute row-offset in DI
	add	$60, %di		# advance past 30 columns
	cld				# use 'forward' processing
	lea	msg, %si		# point DS:SI to message
	mov	len, %cx		# message's length in CX
	mov	att, %ah		# attribute-code into AH
nxpel:	
	lodsb				# fetch next character
	stosw				# store char and color
	loop	nxpel			# again for next char

	ret	
#------------------------------------------------------------------
update_machine_state:

	xor	%ax, %ax		# address rom-bios data
	mov	%ax, %fs		#   with FS register
	mov	jiffies, %eax		# copy final tick-count
	mov	%eax, %fs:0x046C	# into rom-bios variable

	ret
#------------------------------------------------------------------
	.align	16			# insure stack alignment
	.space	512			# allocate stack storage
tos:					# label for top-of-stack
#------------------------------------------------------------------
#------------------------------------------------------------------
# Here is our INTERRUPT SERVICE ROUTINE for the Timer's interrupts
#------------------------------------------------------------------
isrTMR:	.code32

	push	%eax			# must preserve registers
	push	%ds			#  used by this routine

	mov	$sel_ds, %ax		# address our variable
	mov	%ax, %ds		#   with DS register

	incl	jiffies			# add one to 'jiffies'

	mov	$0x20, %al		# issue End-Of-Interrupt
	out	%al, $0x20		# to the 8259 controller

	pop	%ds			# must restore registers
	pop	%eax			# that we clobbered here 

	iretl				# resume interrupted job
#------------------------------------------------------------------



	.section	.data
	.align	0x1000
#------------------------------------------------------------------
# NOTE: Here we create the 3-level page-mapping tables needed for
# execution in protected-mode with 36-bit Page-Address Extensions
# using an 'identity-mapping' of the lowest 1-megabyte of memory.
#------------------------------------------------------------------
level1:	entry = 0x00000			# initial physical-address
	.rept	256			# map 256 4-KB page-frames
	.quad	entry + 0x003		# 'present' and 'writable'
	entry = entry + 0x1000		# next page-frame address
	.endr				# end of our repeat-macro
	.align	0x1000			# rest of table has zeros
#------------------------------------------------------------------
level2:	.long	level1 + 0x10003, 0	# initial directory-entry <--- 3/16/07
	.align	0x1000			# rest of table has zeros
#------------------------------------------------------------------
level3:	.long	level2 + 0x10001, 0	# initial 'pointer' entry <--- 3/16/07
	.align	0x0020			# rest of table has zeros
#------------------------------------------------------------------
	.end				# no more to be assembled

NOTE: We changed the two lines, marked 3/16/07 above, to allow us
to assemble this program with the 32-bit version of our assembler
(instead of requiring us to use the 64-bit version of 'as').  The
desirability of such a change was made apparent by questions from
Erli Ling and Seng Konglertviboon.  Thanks.  

