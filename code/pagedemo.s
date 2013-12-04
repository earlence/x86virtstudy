//-----------------------------------------------------------------
//	pagedemo.s
//
//	This example uses 'repeat-macros' to build page-mapping
//	tables at assembly-time and shows how we can 'relocate' 
//	the video display memory when page-mapping is enabled.
//
//	  assemble:  $ as pagedemo.s -o pagedemo.o
//	  and link:  $ ls pagedemo.o -T ldscript -o pagedemo.b
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 15 FEB 2007
//-----------------------------------------------------------------


	.code16				# for x86 'real-mode'


	.section	.text
#------------------------------------------------------------------
	.short	0xABCD			# our program 'signature'
#------------------------------------------------------------------
begin:	mov	%sp, %cs:exit_pointer+0	# preserve the loader's SP
	mov	%ss, %cs:exit_pointer+2	# preserve the loader's SS

	mov	%cs, %ax		# address program data
	mov	%ax, %ds		#   with DS register
	mov	%ax, %ss		#   also SS register
	lea	tos, %sp		# set new top-of-stack

	call	enter_protected_mode
	call	execute_program_demo
	call	leave_protected_mode
	call	display_confirmation

	lss	%cs:exit_pointer, %sp	# recover original stack
	lret				# and exit to the loader
#------------------------------------------------------------------
exit_pointer:	.short	0, 0		# holds the loader's SS:SP
#------------------------------------------------------------------
	.align	8			# using quadword alignment
theGDT:	# These 'Segment Descriptors' are needed in protected-mode
	.word	0x0000, 0x0000, 0x0000, 0x0000	# null-descriptor
	
	.equ	sel_cs, (. - theGDT)+0	# code-segment's selector	
	.short	0xFFFF, 0x0000, 0x9A01, 0x0000	# code-descriptor

	.equ	sel_ss, (. - theGDT)+0	# data-segment's selector
	.short	0xFFFF, 0x0000, 0x9201, 0x0000	# data-descriptor

	.equ	limGDT, (. - theGDT)-1	# the GDT's segment-limit  
#------------------------------------------------------------------
regGDT:	.short	limGDT, theGDT, 0x0001	# image for GDTR register
#------------------------------------------------------------------
#------------------------------------------------------------------
msg1:	.ascii	" The CPU is executing in protected-mode "
len1:	.short	. - msg1		# length of the message
att1:	.byte	0x5F			# text color-attributes
#------------------------------------------------------------------
msg2:	.ascii	" CPU successfully returned to real-mode \r\n\n"
len2:	.short	. - msg2		# length of the message
att2:	.byte	0x03			# text color-attributes
#------------------------------------------------------------------
enter_protected_mode:

	# setup register GDTR to address our segment descriptors
	lgdt	regGDT			# load register-image

	# setup Control Register CR3 with page-direcrory address
	mov	regCR3, %eax		# get address into EAX
	mov	%eax, %cr3		# so CR3 can be loaded

	# we cannot allow device-interrupts (no Interrupt Gates) 
	cli				# turn off EFLAGS IF-bit
	
	# now we enter protected-mode with page-mapping enabled
	mov	%cr0, %eax		# current machine-status
	bts	$0, %eax		# turn on PE-bit's image
	bts	$31, %eax		# turn on PG-bit's image
	mov	%eax, %cr0		# enter 'protected-mode'

	# here we assure CS and SS hold protected-mode selectors
	ljmp	$sel_cs, $pm		# code-selector into CS 
pm:	mov	$sel_ss, %ax	
	mov	%ax, %ss		# data-selector into SS
	ret
#------------------------------------------------------------------
leave_protected_mode:

	# make sure segment-registers have 'real-mode' attributes
	mov	$sel_ss, %ax		# 64KB writable segment
	mov	%ax, %ss		#    for SS register
	mov	%ax, %ds		#    and DS register
	mov	%ax, %es		#    and ES register

	# now we leave protected-mode (and disable page-mapping)
	mov	%cr0, %eax		# current machine status
	btr	$0, %eax		# reset PE-bit's image
	btr	$31, %eax		# reset PG-bit's image
	mov	%eax, %cr0		# leave 'protected-mode'

	# here we insure segment-registers have 'real-mode' values	
	ljmp	$0x1000, $rm		# segment-address into CS
rm:	mov	%cs, %ax		 
	mov	%ax, %ss		# segment-address into SS
	mov	%ax, %ds		# segment-address into DS
	mov	%ax, %es		# segment-address into ES
	sti				# now we allow interrupts 
	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
execute_program_demo:

	# we draw a string of characters directly to video memory

	mov	$sel_ss, %ax		# address our variables
	mov	%ax, %ds		#   with DS register

	mov	$0x8000, %di		# offset to video memory
	add	$640, %di		# screen's row-number 4

	lea	msg1, %si		# offset to message-string
	mov	len1, %cx		# length of message-string 
	mov	att1, %ah		# colors of message's text
nxchr:
	mov	(%si), %al		# fetch the next character
	mov	%ax, (%di)		# store character and color
	add	$1, %si			# advance source-pointer
	add	$2, %di			# advance dest'n-pointer
	loop	nxchr			# back for next character

	ret
#------------------------------------------------------------------
display_confirmation:

	# setup registers DS and ES to address our program data
	mov	%cs, %ax		# address program data
	mov	%ax, %ds		#   with DS register
	mov	%ax, %es		#   also ES register

	# use ROM-BIOS 'write_string' function to a draw message
	lea	msg2, %bp		# point ES:BP to string
	mov	len2, %cx		# string's length in CX
	mov	att2, %bl		# color-attribute in BL
	mov	$5, %dh			# row-number in DH
	mov	$0, %dl			# col-number in DL
	mov	$0, %bh			# page-number in BH	
	mov	$0x1301, %ax		# write_string function
	int	$0x10			# invoke video service

	ret
#------------------------------------------------------------------














	.section	.data
#------------------------------------------------------------------
# Here we put our page-mapping entries into a separate 'section' 
# because then our linker-script will fill gaps with zero values
#------------------------------------------------------------------
	.align	0x1000			# use page-frame alignment
level1:	entry = 0			# initial physical-address 
	.rept	24			# we map the lowest 96KB
	.long	entry + 0x003		# present and writable
	entry = entry + 0x1000		# advance physical-address
	.endr				# conclusion of this macro
	.long	0x000B8000 + 0x003	# mapping for video memory
#------------------------------------------------------------------
	.align	0x1000			# use page-frame alignment
level2:	.long	level1 + 0x10000 + 0x003    # present and writable
#------------------------------------------------------------------
	.align	0x1000			# start at next page-frame
regCR3:	.long	level2 + 0x10000	# table's physical-address 
#------------------------------------------------------------------
	.space	512			# reserved for stack usage
tos:					# label for 'top-of-stack'
#------------------------------------------------------------------
	.end				# nothing else to assemble




		VIRTUAL-TO-PHYSICAL MAP-DEPICTION

	Our page-mapping makes the initial page-frame of physical
	video-display memory appear to be 'relocated' to virtual- 
	address range 0x18000-19000

					+-----------------------+
					|  0xB8000 - 0xB9000	|
				     /	+-----------------------+
				    /   |			|
	+-----------------------+  /	|			|
	|     next 4KB page	| /	|			|
	+-----------------------+ 	+-----------------------+
	|			| --->	|			|
	|     lowest 96KB	| --->	|    address-range	|
	|   identity-mapped	| --->	|  0x00000 - 0x18000	|
	|		    	| --->	|			|
	+-----------------------+ 	+-----------------------+

	  virtual address space		 physical address-space


