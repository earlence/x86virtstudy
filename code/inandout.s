//-----------------------------------------------------------------
//	inandout.s
//
//	This program executes at boot-time and illustrates the 
//	steps needed to make the transitions from real-mode to
//	64bit protected-mode (with page-mapping enabled), then
//	return (via 'compatibility-mode') back to 'real-mode'.
//	
//	 assemble: $ as inandout.s -o inandout.o
//	 and link: $ ld inandout.o -T ldscript -o inandout.b
//
//	NOTE: This program is launched with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	date begun: 08 FEB 2007
//	completion: 17 FEB 2007
//-----------------------------------------------------------------

	.section	.text
#------------------------------------------------------------------
	.short	0xABCD			# our loader expects this
#------------------------------------------------------------------
begin:	.code16				# cpu starts in real-mode
	mov	%sp, %cs:exit_pointer+0	# save the loader's SP
	mov	%ss, %cs:exit_pointer+2	# save the loader's SS

	mov	%cs, %ax		# address program data
	mov	%ax, %ds		#   with DS register
	mov	%ax, %es		#   also ES register
	mov	%ax, %ss		#   also SS register
	lea	tos, %sp		# and set top-of-stack 

	call	verify_EM64T_support
	call	execute_program_demo

	lss	%cs:exit_pointer, %sp	# recover loader's stack
	lret				# and reenter the loader
#------------------------------------------------------------------
exit_pointer:	.short	0, 0		# for the loader's SS:SP
#------------------------------------------------------------------
msg0:	.ascii	" Intel EM64T capability not implemented \r\n\n "
len0:	.quad	. - msg0		# length of the string
att0:	.byte	0x04			# color attribute-code
#------------------------------------------------------------------
msg1:	.ascii	" OK, processor is now executing in 64-bit mode "
len1:	.quad	. - msg1		# length of the string
att1:	.byte	0x1F			# color attribute-code
#------------------------------------------------------------------
msg2:	.ascii	" Executing 16-bit code in 'compatibility' mode "
len2:	.quad	. - msg2		# length of the string
att2:	.byte	0x5F			# color attribute-code
#------------------------------------------------------------------
msg3:	.ascii	" CPU successfully returned to real-mode \r\n\n "
len3:	.quad	. - msg3		# length of the string
att3:	.byte	0x02			# color attribute-code
#------------------------------------------------------------------
#------------------------------------------------------------------
vendorID: 	.ascii	"GenuineIntel"	# official vendor string
#------------------------------------------------------------------
verify_EM64T_support:

	# check for the Intel vendor-identification string
	xor	%eax, %eax		# setup input-value
	cpuid				# execute cpuid
	sub	vendorID+0, %ebx	# bytes 3..1
	sub	vendorID+4, %edx	# bytes 7..4
	sub	vendorID+8, %ecx	# bytes 11..8
	or	%ecx, %edx		# merge bits
	or	%edx, %ebx		# merge bits
	jnz	doexit			# nonzero? exit

	# ok, check for the enhanced processor-extensions
	mov	$0x80000001, %eax	# input-value
	cpuid				# execute cpuid
	bt	$29, %edx		# EM64T supported?
	jnc	doexit			# no, we must exit
	ret				# else we proceed 
	
doexit:	# show error-message, then terminate this demo
	lea	msg0, %bp		# point ES:BP to string
	mov	len0, %cx		# string-length into CX
	mov	att0, %bl		# color-attributes in BL
	mov	$0x0, %bh		# page-number in BH
	mov	$0x5, %dh		# row-number in DH
	mov	$0x3, %dl		# column-number in DL
	mov	$0x1301, %ax		# write_string 
	int	$0x10			# request BIOS service

	lss	exit_pointer, %sp	# restore loader's stack
	lret				# and exit back to loader
#------------------------------------------------------------------
theGDT:	# These segment-descriptors are needed for protected-mode
	.quad	0x0000000000000000	# null descriptor

	.equ	sel_CS, (. - theGDT)+0	# selector for 64bit code
	.quad	0x00209A0000000000	# code-segment descriptor

	.equ	sel_cs, (. - theGDT)+0	# selector for 16bit code
	.quad	0x00009A010000FFFF	# code-segmenr descriptor

	.equ	sel_ds, (. - theGDT)+0	# selector for 16bit data
	.quad	0x000092010000FFFF	# data-segment descriptor

	.equ	sel_es, (. - theGDT)+0	# selector for 16bit data
	.quad	0x0000920B8000FFFF	# vram-segment descriptor
	
	.equ	gate64, (. - theGDT)+0	# selector for call-gate 
	.word	prog64, sel_CS, 0x8C00, 0x0001	# for transition
	.word	0x0000, 0x0000, 0x0000, 0x0000	# 16bit-to-64bit

	.equ	limGDT, (. - theGDT)-1	# segment-limit for GDTR
#------------------------------------------------------------------
#------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001	# image for GDTR register
regCR3:	.long	level4 + 0x10000	# image for CR3 register
#------------------------------------------------------------------
execute_program_demo:
	# preserve the address of our 'real-mode' stack
	mov	%esp, tossave+0		# save contents of ESP
	mov	%ss, tossave+4		# save contents of SS

	# enable 'long-mode' in Extended Feature Enable Register
	mov	$0xC0000080, %ecx	# ID-number for EFER
	rdmsr				# read this MSR
	bts	$8, %eax		# set the LME-bit
	wrmsr				# write this MSR

	# enable Page-Address Extensions in control register CR4
	mov	%cr4, %eax		# get current settings
	bts	$5, %eax		# set the PAE-bit
	mov	%eax, %cr4		# set revised settings

	# establish our page-mapping base-address in register CR3
	mov	regCR3, %eax		# table's physical address
	mov	%eax, %cr3		# loaded into CR3 register

	# initialize the Global Descriptor Table register
	lgdt	regGDT			# setup register GDTR 

	# disable device-interrupts
	cli				# no interrupts permited

	# activate 'long-mode' by setting PE-bit and PG-bit in CR0
	mov	%cr0, %eax
	bts	$0, %eax		# set image of the PE-bit
	bts	$31, %eax		# set image of the PG-bit
	mov	%eax, %cr0		# enter 'protected-mode'

	# now transfer through our call-gate to 64-bit code
	ljmp	$gate64, $0		# transfer via call-gate
#------------------------------------------------------------------
prog64:	.code64
	# draw the message that confirms our arrival here 
	mov	$3, %rbx		# setup screen row-number
	imul	$160, %rbx, %rdi	# compute row's offset
	add	$0xB8000, %rdi		# plus vram base-address
	cld				# use forward processing
	mov	$0x10000, %eax		# program's load-address 
	lea	msg1(%eax), %rsi	# plus offset to message
	mov	len1(%eax), %rcx	# message-length in RCX
	mov	att1(%eax), %ah		# message-colors in AH
.P1:	lodsb				# fetch next character
	stosw				# store char and color
	loop	.P1			# again for more chars 

	# transfer from 64-bit mode to 16-bit 'compatibility' mode
	ljmp	*(compat + 0x10000)	# use indirect far jump 
#------------------------------------------------------------------
#------------------------------------------------------------------
compat:	.long	prog16, sel_cs		# pointer to jump-target
#------------------------------------------------------------------
prog16:	.code16
	# write a message that confirms our arrival here 
	mov	$sel_es, %ax		# address video memory
	mov	%ax, %es		#   with ES register
	mov	$4, %bx			# setup screen row-number
	imul	$160, %bx, %di		# compute row's offset 
	cld				# use forward processing
	mov	$sel_ds, %ax		# address program data
	mov	%ax, %ds		#   with DS register
	lea	msg2, %si		# point DS:SI to string
	mov	len2, %cx		# string-length into CX
	mov	att2, %ah		# string-colors into AH
.P2:	lodsb				# fetch next character
	stosw				# store char and color
	loop	.P2			# again for more chars
	
	# disable IA-32e mode (by turning off the PG-bit in CR0)
	mov	%cr0, %eax		# current machine status
	btr	$31, %eax		# reset image of PG-bit
	btr	$0, %eax		# reset image of PE-bit
	mov	%eax, %cr0		# leave protected-mode

	# ok, here we are executing in 'real-mode' again
	ljmp	$0x1000, $rm		# reload the CS register
rm:	lss	%cs:tossave, %esp	# reload the SS register

	# draw a confirmation-message
	mov	%cs, %ax		# address program data
	mov	%ax, %ds		#   with DS register
	mov	%ax, %es		#   also ES register
	lea	msg3, %bp		# point ES:BP to string
	mov	len3, %cx		# string-length into CX
	mov	att3, %bl		# string-colors into BL
	mov	$0, %bh			# page-number in BH
	mov	$5, %dh			# row-number in DH
	mov	$3, %dl			# column-number in DL
	mov	$1, %al			# cursor-directive 
	mov	$0x13, %ah		# write_string
	int	$0x10			# request BIOS service

	ret				# back to main procedure
#------------------------------------------------------------------
tossave:	.long	0, 0		# saves 'real-mode' SS:ESP
#------------------------------------------------------------------
	.align	16			# assures stack alignment
	.space	512			# space reserved as stack
tos:					# label for our stack-top
#------------------------------------------------------------------






	.section	.data
	.align	0x1000			# use page-frame alignment
#------------------------------------------------------------------
# NOTE: To enter 64bit-mode requires using a 4-level page-mapping.
# Here we construct an 'identity-mapping' for the lowest megabyte.
#------------------------------------------------------------------
level1:	# Here we use a 'repeat-macro' to construct table-entries
	entry = 0			# initialize page-address
	.rept	256			# number of table-entries
	.quad	entry + 7 		# present, writable, user
	entry = entry + 0x1000 		# page-address advances
	.endr				# conclusion of the macro
	.align	0x1000			# use page-frame alignment
#------------------------------------------------------------------
level2:	.quad	level1 + 0x10000 + 7	# present, writable, user
	.align	0x1000			# use page-frame alignment
#------------------------------------------------------------------
level3:	.quad	level2 + 0x10000 + 7	# present, writable, user
	.align	0x1000			# use page-frame alignment
#------------------------------------------------------------------
level4:	.quad	level3 + 0x10000 + 7	# present, writable, user 
	.align	0x1000			# use page-frame alignment
#------------------------------------------------------------------
	.end				# nothing else to assemble


     NOTES for this demo:

     1) We were able to omit the construction of interrupt and
	exception handlers, and an Interrupt Descriptor Table,
	by disabling device-interrupts while in protected mode
	and avoiding operations that could violate privileges.

     2)	We were able to avoid allocating a separate stack-area
	for use while in 64-bit mode by making sure we did not
	perform any operations that required stack-access, and
	again by leaving dvice-interrupts turned off.

     3) Our goal here was to keep this demo-program brief.  We
	wanted to focus on just those steps that are necessary 
	to take the processor from real-mode to 64bit mode and
	then back to real-mode. 


