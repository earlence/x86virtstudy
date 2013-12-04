//-----------------------------------------------------------------
//	controls.s
//
//	This program displays the contents in hexadecimal format 
//	of the processor's Control Registers CR0, CR2, CR3, CR4.
//
//	 to assemble:  $ as controls.s -o controls.o
//	 and to link:  $ ld control.o -T ldscript -o controls.b
//	 and install:  $ dd if=controls.b of=/dev/sda4 seek=1
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 05 FEB 2007
//-----------------------------------------------------------------


	.code16				# for x86 'real-mode'

	.section	.text
#------------------------------------------------------------------
	.short	0xABCD			# our program 'signature'
#------------------------------------------------------------------
	mov	%sp, %cs:exit_pointer+0	# preserve the loader's SP
	mov	%ss, %cs:exit_pointer+2	# preserve the loader's SS

	mov	%cs, %ax		# address our program data
	mov	%ax, %ds		#   with the DS register
	mov	%ax, %ss		#   also the SS register
	lea	tos, %sp		# establish new stack-top

	call	save_control_regs
	call	format_the_report
	call	output_the_report

	lss	%cs:exit_pointer, %sp	# recover loader's SS:SP
	lret				# and exit to the loader
#------------------------------------------------------------------
exit_pointer:	.short	0, 0		# saves loader's SS and SP
#------------------------------------------------------------------
regCR0:	.long	0			# holds the value from CR0
regCR2:	.long	0			# holds the value from CR2
regCR3:	.long	0			# holds the value from CR3
regCR4:	.long	0			# holds the value from CR4
#------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"	# the hexadecimal numerals
#------------------------------------------------------------------
msg:	.ascii	"\r\n\n        "	# our multi-line message 
buf0:	.ascii	"xxxxxxxx=CR0  "	# showing CR0 contents
buf2:	.ascii	"xxxxxxxx=CR2  "	# showing CR2 contents
buf3:	.ascii	"xxxxxxxx=CR3  "	# showing CR3 contents
buf4:	.ascii	"xxxxxxxx=CR4  "	# showing CR4 contents
	.ascii	"\r\n\n"		# followed by blank line
len:	.short	. - msg			# length of message-string
att:	.byte	0x0D			# message color attributes 
#------------------------------------------------------------------
#------------------------------------------------------------------
save_control_regs:

	mov	%cr0, %eax		# get value from CR0
	mov	%eax, regCR0		# and save in memory

	mov	%cr2, %eax		# get value from CR2
	mov	%eax, regCR2		# and save in memory

	mov	%cr3, %eax		# get value from CR3
	mov	%eax, regCR3		# and save in memory

	mov	%cr4, %eax		# get value from CR4
	mov	%eax, regCR4		# and save in memory

	ret
#------------------------------------------------------------------
format_the_report:

	mov	regCR0, %eax		# load CR0 contents
	lea	buf0, %di		#  point to buffer
	call	eax2hex			# convert to string

	mov	regCR2, %eax		# load CR2 contents
	lea	buf2, %di		#  point to buffer
	call	eax2hex			# convert to string

	mov	regCR3, %eax		# load CR3 contents
	lea	buf3, %di		#  point to buffer
	call	eax2hex			# convert to string

	mov	regCR4, %eax		# load CR4 contents
	lea	buf4, %di		#  point to buffer
	call	eax2hex			# convert to string

	ret
#------------------------------------------------------------------
output_the_report:

	mov	$0x0F, %ah		# get BH = video page
	int	$0x10			# request BIOS service
	
	mov	$0x03, %ah		# get DX = cursor-locn
	int	$0x10			# request BIOS service

	mov	%cs, %ax		# address program data
	mov	%ax, %es		#   with ES register
	lea	msg, %bp		# point ES:BP to string
	mov	len, %cx		# string's length in CX
	mov	att, %bl		# color attribute in BL
	mov	$0x01, %al		# move cursor afterward
	mov	$0x13, %ah		# write_string function
	int	$0x10			# request BIOS service

	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
eax2hex:
#
# This helper-routine converts the value found in register EAX to
# its representation as a string of hexadecimal numerals at DS:DI
#
	push	%bx			# save working registers
	push	%cx
	push	%dx
	push	%di

	mov	$8, %cx			# setup loop-iterations
nxnyb:
	rol	$4, %eax		# next nybble into AL
	mov	%al, %bl		# copy nybble into BL
	and	$0xF, %bx		# clear all but 4 bits
	mov	hex(%bx), %dl		# lookup its ascii-code
	mov	%dl, (%di)		# and put code in buffer
	inc	%di			# advance buffer-pointer
	loop	nxnyb			# again for next nybble

	pop	%di			# recover saved registers
	pop	%dx
	pop	%cx
	pop	%bx
	ret				# return control to caller
#------------------------------------------------------------------
	.align	16			# assures stack-alignment
	.space	256			# area reserved for stack 
tos:					# label for the stack-top
#------------------------------------------------------------------
	.end				# no more tgo be assembled

