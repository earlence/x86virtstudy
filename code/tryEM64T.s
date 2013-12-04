//-------------------------------------------------------------------
//	tryEM64T.s
//
//	This program demonstrates the steps that are needed in order
//	to activate the Extended Memory 64-bit Technology (EM64T) in
//	Intel's Pentium-D and Core-2 processors, and then to display
//	some text characters while executing in 64-bit mode and also
//	"compatibility" mode, before finally returning to real-mode.
//
//	 to assemble: $ as tryEM64T.s -o tryEM64T.o 
//	 and to link: $ ld tryEM64T.o -T ldscript -o tryEM64T.b 
//
//	NOTE: This program begins executing with CS:IP = 1000:0002. 
//
//	programmer: ALLAN CRUSE
//	written on: 22 MAY 2006
//	revised on: 15 JAN 2007 -- page-tables built at compile-time
//-------------------------------------------------------------------

	.section	.text
#-------------------------------------------------------------------
	.word	0xABCD			# our application signature
#-------------------------------------------------------------------
main:	.code16				# for Pentium 'real-mode' 
	mov	%sp, %cs:exit_pointer+0	# preserve the loader's SP
	mov	%ss, %cs:exit_pointer+2	# preserve the loader's SS

	mov	%cs, %ax		# address program's data 
	mov	%ax, %ds		#   with DS register     
	mov	%ax, %es		#   also ES register     
	mov	%ax, %ss		#   also SS register     
	lea	tos, %sp		# and setup new stacktop 

	call	initialize_os_tables	
	call	enter_protected_mode	
	call	execute_program_demo	
	call	leave_protected_mode	
	call	display_confirmation

	lss	%cs:exit_pointer, %sp	# recover saved SS and SP
	lret				# exit back to the loader
#-------------------------------------------------------------------
exit_pointer:	.word	0, 0 		# for loader's SS and SP 
#-------------------------------------------------------------------
msg1:	.ascii	" OK, processor is now executing in 64-bit mode "
len1:	.quad	. - msg1		# length of the string
att1:	.byte	0x1F			# color attribute-code
#-------------------------------------------------------------------
msg2:	.ascii	" Executing 16-bit code in 'compatibility' mode "
len2:	.word	. - msg2		# length of the string
att2:	.byte	0x5F			# color attribute-code
#-------------------------------------------------------------------
msg3:	.ascii	" CPU successfully returned to real-mode \r\n\n"
len3:	.word	. - msg3		# length of the string
att3:	.byte	0x0E			# color attribute-code
#-------------------------------------------------------------------
#-------------------------------------------------------------------
	.align	16	 		# optimal memory alignment 
theGDT:	# This is our Global Descriptor Table (octaword entries)
	.octa	0x00000000000000000000000000000000	# null desc

	# the selector and descriptor for our 16-bit code-segment
	.equ	sel_cs, (.-theGDT)+0	# selector for code-segment 
	.octa	0x000000000000000000009A010000FFFF	# code 16bit

	# the selector and descriptor for our 16-bit data-segment
	.equ	sel_ds, (.-theGDT)+0	# selector for data-segment 
	.octa	0x0000000000000000000092010000FFFF	# data 16bit

	# the selector and descriptor for our 64-bit code-segment
	.equ	sel_CS, (.-theGDT)+0	# selector for code-segment 
	.octa	0x000000000000000000209A0000000000	# code 64bit

	# the selector and descriptor for our 4-GB data-segment
	.equ	sel_fs, (.-theGDT)+0	# selector for data-segment 
	.octa	0x0000000000000000008F92000000FFFF	# data 4GB

	# the selector and descriptor for our vram data-segment
	.equ	sel_es, (.-theGDT)+0	# selector for vram-segment
	.octa	0x00000000000000000080920B80000007	# vram 32K

	# the selector and descriptor for our 16to64-bit call-gate
	.equ	gate64, (.-theGDT)+0	# selector for call-gate
	.word	prog64, sel_CS, 0x8C00, 0x0000	# call-cate lo-quad
	.word	0x0000, 0x0000, 0x0000, 0x0000	# call-gate hi-quad

	.equ	limGDT, (.-theGDT)-1	# our GDT-segment's limit 
#-------------------------------------------------------------------
theIDT:	.space	256 * 16	# enough for 256 gate-descriptors 
	.equ	limIDT, (.-theIDT)-1	# our IDT-segment's limit 
#-------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 1, 0, 0	# register-image for GDTR 
regIDT:	.word	limIDT, theIDT, 1, 0, 0	# register-image for IDTR 
regIVT:	.word	0x03FF, 0x0000, 0, 0, 0	# register-image for IDTR 
#-------------------------------------------------------------------
initialize_os_tables:	

	# initialize IDT descriptor for gate 0x0D 
	mov	$0x0D, %ebx 		# ID-number for the gate 
	imul	$16, %ebx		# times size of IDT gate
	lea	theIDT(%ebx), %di 	# gate's offset-address 
	movw	$isrGPF, 0(%di)		# entry-point 15..0
	movw	$sel_CS, 2(%di)		# code-segment selector
	movw	$0x8E00, 4(%di)		# 386 interrupt-gate   
	movw	$0x0001, 6(%di)		# entry-point 31..16 
	movw	$0x0000, 8(%di)		# entry-point 47..32
	movw	$0x0000, 10(%di)	# entry-point 63..48
	movw	$0x0000, 12(%di)	# reserved word
	movw	$0x0000, 14(%di)	# reserved word 

	ret	
#-------------------------------------------------------------------
#-------------------------------------------------------------------
enter_protected_mode:	

	cli				# no device interrupts

	mov	%cr0, %eax		# get machine status
	bts	$0, %eax		# set PE-bit to 1
	mov	%eax, %cr0		# enable protection

	lgdt	regGDT			# setup GDTR register
	lidt	regIDT			# setup IDTR register

	ljmp	$sel_cs, $pm		# reload register CS
pm:
	mov	$sel_ds, %ax		
	mov	%ax, %ss		# reload register SS
	mov	%ax, %ds		# reload register DS

	xor	%ax, %ax		# use "null" selector
	mov	%ax, %es		# to purge invalid ES
	mov	%ax, %fs		# to purge invalid FS
	mov	%ax, %gs		# to purge invalid GS

	ret	
#-------------------------------------------------------------------
leave_protected_mode:	

	mov	$sel_ds, %ax		# address 64K r/w segment
	mov	%ax, %ds		#   using DS register
	mov	%ax, %es		#    and ES register

	mov	$sel_fs, %ax		# address 4GB r/w segment
	mov	%ax, %fs		#   using FS register
	mov	%ax, %gs		#    and GS register 

	mov	%cr0, %eax		# get machine status
	btr	$0, %eax		# reset PE-bit to 0 
	mov	%eax, %cr0		# disable protection

	ljmp	$0x1000, $rm		# reload register CS
rm:
	mov	%cs, %ax		# CS segment-address 	
	mov	%ax, %ss		# reload register SS
	mov	%ax, %ds		# reload register DS
	mov	%ax, %es		# reload register ES

	lidt	regIVT			# restore vector table
	sti				# now allow interrupts

	ret	
#-------------------------------------------------------------------
tossave:  .long	0, 0 			# stores a 48-bit pointer 
#-------------------------------------------------------------------
fin:	lss	%cs:tossave, %esp 	# reload our saved SS:ESP 
	ret				# return to main function 
#-------------------------------------------------------------------
#-------------------------------------------------------------------
execute_program_demo: 

	# save our 16-bit code's stack-address for return-to-main
	mov	%esp, tossave+0		# preserve 32-bit offset 
	mov	%ss,  tossave+4		#  plus 16-bit selector 

	#--------------------------------------------------
	# prepare the processor for activating IA-32e mode
	#--------------------------------------------------

	# step 1: Enable long-mode in Extended Feature Enable Register
	mov	$0xC0000080, %ecx	# MSR-address for EFER 
	rdmsr				# read current setting
	bts	$8, %eax		# set LME-bit (bit 8)
	wrmsr				# write new EFER value

	# step 2: Enable Page-Address Extensions in register CR4
	mov	%cr4, %eax		# get CPU's option-flags
	bts	$5, %eax		# set the PAE-bit for
	mov	%eax, %cr4		# Page-Address Extensions

	# step 3: Establish the page-mapping base-address in CR3
	mov	regCR3, %eax		# table's physical address 
	mov	%eax, %cr3		# loaded into register CR3

	# step 4: Activate IA-32e mode by setting PG-bit in CR0
	mov	%cr0, %eax		# get machine status
	bts	$31, %eax		# set PG-bit (bit 31)
	mov	%eax, %cr0		# to turn on 'paging'

	# int $0	# <--- temporarily included while testing

	# use a call-gate to transfer from 16-bit to 64-bit code
	ljmp	$gate64, $0		# transfer to 64-bit code
#-------------------------------------------------------------------
display_confirmation:

	# seup segment-registers DS and ES to address our data
	mov	%cs, %ax		# address program data
	mov	%ax, %ds		#   with DS register
	mov	%ax, %es		#   also ES register

	# use a ROM-BIOS video service to show concluding message
	lea	msg3, %bp		# point ES:BP to string
	mov	len3, %cx		# setup chatacter-count
	mov	att3, %bl		# setup color-attribute
	mov	$0, %bh			# set page-number in BH
	mov	$6, %dh			# set row-number in DH
	mov	$3, %dl			# set col-number in DL
	mov	$1, %al			# advance cursor after
	mov	$0x13, %ah		# write_string function
	int	$0x10			# request BIOS service

	ret
#-------------------------------------------------------------------
#-------------------------------------------------------------------
prog64:	.code64

	# we draw a confirming message directly to video memory
	mov	$3, %rbx		# setup screen row-number 
	imul	$160, %rbx, %rdi	# compute row's offset
	add	$0xB8000, %rdi		# plus vram base-address
	cld
	lea	msg1, %rsi		# point DS:RSI to string
	mov	len1, %rcx		# setup character-count
	mov	att1, %ah		# setup color-attributes
.P1:  	lodsb				# fetch next araracter
	stosw				# store char and color
	loop	.P1			# again if chars remain

	# Now we want to transfer to 'compatibility mode'
	ljmp	*destination		# indirect far jump
#-------------------------------------------------------------------
destination:	.long	prog16, sel_cs	# pointer to jump-target
#-------------------------------------------------------------------
prog16:	.code16

	# we draw a confirming message directly to video memory
	mov	$sel_ds, %ax		# address program data
	mov	%ax, %ds		#   with DS register
	mov	$sel_es, %ax		# address video memory
	mov	%ax, %es		#   with ES register
	cld				# do forward processing
	mov	$4, %bx			# setup screen row-number
	imul	$160, %bx, %di		# compute row's offset
	lea	msg2, %si		# point DS:SI to string
	mov	len2, %cx		# setup character-count
	mov	att2, %ah		# setup color-attribute
.P2:	lodsb				# fetch next character
	stosw				# store char and color
	loop	.P2			# again if chars remain

	# disable IA-32e mode (by turning off the PG-bit in CR0)
	mov	%cr0, %eax		# get machine status
	btr	$31, %eax		# clear the PG-bit
	mov	%eax, %cr0		# to disable paging

	# we are executing 16-bit code in 'legacy' protected-mode
	mov	%cr4, %eax		# get CPU's option-flags
	btr	$5, %eax		# clear PAE-bit turns off
	mov	%eax, %cr4		# Page-Address Extensions
	
	# disable long-mode (bit #8 in EFER register)
	mov	$0xC0000080, %ecx	# Extended Feature Enable
	rdmsr				# read the selected MSR
	btr	$8, %eax		# clear Long Mode Enable
	wrmsr				# write new EFER setting

	# now we return to 'main' so we can leave protected-mode
	jmp	fin			# to restore 16-bit stack
#-------------------------------------------------------------------
#-------------------------------------------------------------------
isrGPF:	# our 'fault-handler' for General Protection Exceptions 
	.code64
	pushq	%rax			# store registers on stack
	pushq	%rcx
	pushq	%rdx
	pushq	%rbx
	pushq	%rsp
	addq	$32, (%rsp)		# adjust RSP for 4 pushes
	pushq	%rbp
	pushq	%rsi
	pushq	%rdi
	pushq	$0			# clear a space for DS		
	mov	%ds, (%rsp)		# then store DS-value 
	pushq	$0			# clear a space for ES
	mov	%es, (%rsp)		# then store ES-value 
	pushq	$0			# clear a space for FS
	mov	%fs, (%rsp)		# then store FS-value
	pushq	$0			# clear a space for GS
	mov	%gs, (%rsp)		# then store GS-value 

	mov	%rsp, %rbp		# setup frame-base in RBP 
	call	draw_stack		# and show register-values 

	ljmp	*destination		# indirect far jump to quit
#-------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"	# array of hex digits
names:	.ascii	"  GS  FS  ES  DS" 
	.ascii	" RDI RSI RBP RSP RBX RDX RCX RAX" 
	.ascii	" err RIP  CS EFL RSP  SS" 
	.equ	NELTS, (. - names)/4 	# number of elements 
buf:	.ascii	" nnn=xxxxxxxxxxxxxxxx " # buffer for output 
len:	.quad	. - buf 		# length of output 
att:	.byte	0x70			# color attributes 
#-------------------------------------------------------------------
rax2hex:  # converts value in RAX to hexadecimal string at DS:RDI 
	push	%rbx			# save working registers
	push	%rcx
	push	%rdx
	push	%rdi

	mov	$16, %rcx 		# setup digit counter 
nxnyb:	rol	$4, %rax 		# next nybble into AL 
	mov	%al, %bl 		# copy nybble into BL 
	and	$0xF, %rbx		# isolate nybble's bits 
	mov	hex(%rbx), %dl		# lookup ascii-numeral 
	mov	%dl, (%rdi) 		# put numeral into buf 
	inc	%rdi			# advance buffer index 
	loop	nxnyb			# back for next nybble

	pop	%rdi 			# restore saved registers
	pop	%rdx 
	pop	%rcx 
	pop	%rbx 
	ret 
#-------------------------------------------------------------------
#-------------------------------------------------------------------
draw_stack: 
	push	%rax			# save working registers
	push	%rbx
	push	%rcx
	push	%rdx
	push	%rsi
	push	%rdi

	cld				# do forward processing 
	xor	%rbx, %rbx 		# initial element index 
nxelt: 
	# put element's label into buf 
	mov	names(, %rbx, 4), %eax 	# fetch element's label 
	mov	%eax, buf		# store label into buf 

	# put element's value into buf 
	mov	(%rbp, %rbx, 8), %rax 	# fetch element's value 
	lea	buf+5, %rdi 		# point to value field 
	call	rax2hex			# convert value to hex 

	# compute element's screen-offset 
	mov	$0xB8000, %rdi
	add	$3790, %rdi 		# from starting location 
	imul	$160, %rbx, %rax 	# offset to screen line 
	sub	%rax, %rdi 		# destination goes in EDI 

	# write buf to screen memory 
	lea	buf, %rsi 		# point DS:ESI to buffer 
	mov	len, %rcx 		# setup buffer's length 
	mov	att, %ah 		# setup color attribute 
nxpel:	lodsb 				# fetch next character 
	stosw 				# store char and color 
	loop	nxpel 			# again if more chars 

	# increment the element-index and test for exit-condition
	inc	%rbx 			# increment element number 
	cmp	$NELTS, %rbx 		# more elements to show? 
	jb	nxelt 			# yes, back for next one 

	pop	%rdi			# restore registers 
	pop	%rsi 
	pop	%rdx 
	pop	%rcx 
	pop	%rbx 
	pop	%rax 
	ret 				# and return to caller 
#-------------------------------------------------------------------


	.section	.bss
#-------------------------------------------------------------------
	.align	16			# assure stack alignment 
	.space	512			# reserved for stack use 
tos:					# label for top-of-stack 
#-------------------------------------------------------------------


	.section	.data
#-------------------------------------------------------------------
# Here we let the assembler build our page-tables at assembly-time.
# We construct an identity-mapping of virtual-to-physical addresses 
# except for the bottom 64KB (which we map linearly upward by 64K).
# Because our program-loader places our executable file at 0x10000,
# this mapping permits our code to use symbolic addresses in 16-bit
# 'segmented' mode, or in 64-bit 'flat' mode, without relocations.
#-------------------------------------------------------------------
	.align	0x1000			# align on 4K-page boundary
pgtbl:	entry = 0x10007			#   0x00000 --> 0x10000
	.rept	16			# lowest sixteen pageframes
	.quad	entry  			#  linearly mapped upward
	entry = 0x1000 + entry		# according to the formula: 
	.endr				# physaddr = virtaddr + 64K
	entry = 0x10007			# subsequent pageframes are
	.rept	256			#    identically mapped 
	.quad	entry			# according to the formula:
	entry = 0x1000 + entry		#   physaddr = virtaddr
	.endr				# for 'conventional' memory
#-------------------------------------------------------------------
	.align	0x1000			# align on 4K-page boundary
pgdir:	.quad	pgtbl + 0x10007		# only one Level-1 entry
#-------------------------------------------------------------------
	.align	0x1000			# align on 4K-page boundary
pgptr:	.quad	pgdir + 0x10007		# only one Level-2 entry
#-------------------------------------------------------------------
	.align	0x1000			# align on 4K-page boundary
plvl3:	.quad	pgptr + 0x10007		# only one Level-3 entry
#-------------------------------------------------------------------
	.align	0x1000			# data-value follows table
regCR3:	.quad	plvl3 + 0x10000		# table's physical-address 
#-------------------------------------------------------------------
	.end				# nothing more to assemble 
