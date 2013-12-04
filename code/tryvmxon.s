//-------------------------------------------------------------------
//	tryvmxon.s	(One solution for the in-class exercise)
//
//
//	 to assemble: $ as tryvmxon.s -o tryvmxon.o 
//	 and to link: $ ld tryvmxon.o -T ldscript -o tryvmxon.b 
//	 and install: $ dd if=tryvmxon.b of=/dev/sda4 seek=1 
//
//	NOTE: This program begins executing with CS:IP = 1000:0002. 
//
//	programmer: ALLAN CRUSE
//	Written on: 19 APR 2007
//-------------------------------------------------------------------

	.equ	ARENA, 0x10000 		# program's load-address 

	.section	.text
#-------------------------------------------------------------------
	.word	0xABCD			# our application signature
#-------------------------------------------------------------------
main:	.code16				# for x86 'real-mode' 
	mov	%sp, %cs:exit_pointer+0	# preserve the loader's SP
	mov	%ss, %cs:exit_pointer+2	# preserve the loader's SS

	mov	%cs, %ax		# address program's data 
	mov	%ax, %ds		#   with DS register     
	mov	%ax, %es		#   also ES register     
	mov	%ax, %ss		#   also SS register     
	lea	tos, %sp		# and setup new stacktop 

	call	enter_ia32e_mode	
	call	execute_our_demo	
	call	leave_ia32e_mode	

	lss	%cs:exit_pointer, %sp	# recover saved SS and SP
	lret				# exit back to the loader
#-------------------------------------------------------------------
exit_pointer:	.word	0, 0 		# for loader's SS and SP 
#-------------------------------------------------------------------
theGDT:	.quad	0x0000000000000000	# required null descriptor 

	.equ	sel_cs, (.-theGDT)+0	# selector for code-segment 
	.quad	0x00009A010000FFFF	# 16-bit code-descriptor 

	.equ	sel_CS, (.-theGDT)+0	# selector for code-segment 
	.quad	0x00209A0000000000	# 64-bit code-descriptor 

	.equ	sel_ds, (.-theGDT)+0	# selector for data-segment 
	.quad	0x000092010000FFFF	# 16-bit data-descriptor 

	.equ	gate64, (.-theGDT)+0	# selector for call-gate 
	.word	prog64, sel_CS, 0x8C00, 0x0000 
	.word	0x0000, 0x0000, 0x0000, 0x0000 

	.equ	limGDT, (.-theGDT)-1	# our GDT-segment's limit 
#-------------------------------------------------------------------
#-------------------------------------------------------------------
theIDT:	.space	13 * 16			# first 13 gate-descriptors 

	# interrupt-gate for General Protection Faults 
	.word	isrGPF, sel_CS, 0x8E00, 0x0000 	 
	.word	0x0000, 0x0000, 0x0000, 0x0000 	 

	.equ	limIDT, (.-theIDT)-1	# our IDT-segment's limit 
#-------------------------------------------------------------------
regCR3:	.long	level4 + ARENA 		# register-image for CR3 
regGDT:	.word	limGDT, theGDT, 0x0001	# register-image for GDTR 
regIDT:	.word	limIDT, theIDT, 0x0001	# register-image for IDTR 
regIVT:	.word	0x03FF, 0x0000, 0x0000	# register-image for IDTR 
#-------------------------------------------------------------------
enter_ia32e_mode:

	# setup the Extended Feature Enable Register 
	mov	$0xC0000080, %ecx 
	rdmsr 
	bts	$8, %eax 		# set LME-bit in EFER 
	wrmsr 

	# setup system control register CR4  
	mov	%cr4, %eax 
	bts	$5, %eax 		# set PAE-bit in CR4 
	mov	%eax, %cr4 

	# setup system control register CR3  
	mov	regCR3, %eax 
	mov	%eax, %cr3 		# setup page-mapping 

	# setup system control register CR0  
	cli				# no device interrupts
	mov	%cr0, %eax 
	bts	$0, %eax 		# set PE-bit in CR0 
	bts	$31, %eax 		# set PG-bit in CR0 
	mov	%eax, %cr0 		# turn on protection 

	# setup the system descriptor-table registers 
	lgdt	regGDT			# setup GDTR register 
	lidt	regIDT			# setup IDTR register 

	# load segment-registers with suitable selectors 
	ljmp	$sel_cs, $pm		# reload register CS
pm:
	mov	$sel_ds, %ax		
	mov	%ax, %ss		# reload register SS
	mov	%ax, %ds		# reload register DS
	mov	%ax, %es		# reload register ES

	xor	%ax, %ax		# use "null" selector
	mov	%ax, %fs		# to purge invalid FS
	mov	%ax, %gs		# to purge invalid GS

	ret	
#-------------------------------------------------------------------
#-------------------------------------------------------------------
leave_ia32e_mode:

	# insure segment-register caches have 'real' attributes 
	mov	$sel_ds, %ax		# address 64K r/w segment 
	mov	%ax, %ds		#   using DS register 
	mov	%ax, %es		#    and ES register 

	# modify system control register CR0 
	mov	%cr0, %eax		# get machine status
	btr	$0, %eax		# reset PE-bit to 0 
	btr	$31, %eax		# reset PG-bit to 0 
	mov	%eax, %cr0		# disable protection

	# reload segment-registers with real-mode addresses 
	ljmp	$0x1000, $rm		# reload register CS
rm:
	mov	%cs, %ax		
	mov	%ax, %ss		# reload register SS
	mov	%ax, %ds		# reload register DS
	mov	%ax, %es		# reload register ES

	# restore real-mode interrupt-vectors 
	lidt	regIVT			# restore vector table
	sti				# and allow interrupts

	ret	
#-------------------------------------------------------------------
execute_our_demo: 

	# preserve the stack-address 
	mov	%esp, tossave+0		# preserve 32-bit offset 
	mov	%ss,  tossave+4		#  plus 16-bit selector 

	# transfer via call-gate to 64-bit code-segment 
	lcall	$gate64, $0   		# transfer to 64-bit code 

	# restore saved stack-address 
fin:	lss	%cs:tossave, %esp 	# reload our saved SS:ESP 
	ret				# return to main function 
#-------------------------------------------------------------------
tossave:  .long	0, 0 			# stores a 48-bit pointer 
#-------------------------------------------------------------------
msg1:	.ascii	" Now executing 64-bit code " 
len1:	.quad	. - msg1 
att1:	.byte	0x50     
#-------------------------------------------------------------------
prog64:	.code64 

	# display confirmation-message 
	mov	$3, %rax 
	imul	$160, %rax, %rdi 
	add	$0xB8000, %rdi 
	cld 
	lea	msg1, %rsi 
	mov	len1, %rcx 
	mov	att1, %ah  
.M0: 	lodsb 
	stosw 
	loop	.M0 

	# turn on A20
	in	$0x92, %al
	or	$0x02, %al
	out	%al, $0x92

	# turn on VMXE_bit
	mov	%cr4, %rax
	bts	$13, %rax
	mov	%rax, %cr4

	# turn on NE_bit
	mov	%cr0, %rax
	bts	$5, %rax
	mov	%rax, %cr0

	# try to execute 'vmxon'
	vmxon	region
	nop
	nop

	# ok, 'vmoff' will fault if 'vmxon' was unsuccessful	
	vmxoff
	nop
	nop

	lretq 
#-------------------------------------------------------------------
isrGPF:	.code64 

	# our fault-handler for General Protection Exceptions 
	push	%rax	
	push	%rbx	
	push	%rcx	
	push	%rdx	
	push	%rsp	
	addq	$40, (%rsp)	
	push	%rbp	
	push	%rsi	
	push	%rdi	

	pushq	$0				
	mov	%ds, (%rsp)		# store DS 
	pushq	$0				
	mov	%es, (%rsp)		# store ES 
	pushq	$0				
	mov	%fs, (%rsp)		# store FS 
	pushq	$0				
	mov	%gs, (%rsp)		# store GS 
	pushq	$0				
	mov	%ss, (%rsp)		# store SS 
	pushq	$0				
	mov	%cs, (%rsp)		# store CS 

	xor	%rbx, %rbx 		# initialize element-index 
nxelt: 
	# place element-name in buffer 
	mov	names(, %rbx, 4), %eax 	
	mov	%eax, buf 

	# place element-value in buffer 
	mov	(%rsp, %rbx, 8), %rax 
	lea	buf+5, %rdi 
	call	rax2hex 

	# compute element-location in RDI 
	mov	$23, %rax 
	sub	%rbx, %rax 
	imul	$160, %rax, %rdi 
	add	$0xB8000, %rdi 
	add	$110, %rdi 

	# draw buffer-contents to screen-location 
	cld 
	lea	buf, %rsi 
	mov	len, %rcx 
	mov	att, %ah  
nxpel:	lodsb 
	stosw 
	loop	nxpel 

	# advance the element-index 
	inc	%rbx 
	cmp	$N_ELTS, %rbx 
	jb	nxelt 

	# now transfer to demo finish 
	ljmp	*depart			# indirect long jump 
#-------------------------------------------------------------------
depart:	.long	fin, sel_cs 		# target for indirect jump 
#-------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"	# array of hex digits
names:	.ascii	"  CS  SS  GS  FS  ES  DS" 
	.ascii	" RDI RSI RBP RSP RDX RCX RBX RAX" 
	.ascii	" err RIP  CS RFL RSP  SS" 
	.equ	N_ELTS, (. - names)/4 	# number of elements 
buf:	.ascii	" nnn=xxxxxxxxxxxxxxxx "	# buffer for output 
len:	.quad	. - buf 		# length of output 
att:	.byte	0x70			# color attributes 
#-------------------------------------------------------------------
rax2hex: .code64 
	# converts value in EAX to hexadecimal string at DS:EDI 
	push	%rax 
	push	%rbx 
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

	pop	%rdi 
	pop	%rdx 
	pop	%rcx 
	pop	%rbx 
	pop	%rax 
	ret 
#-------------------------------------------------------------------
	.align	16 			# insure stack alignment 
	.space	512 			# reserved for stack use 
tos:					# label for top-of-stack 
#-------------------------------------------------------------------


	.section	.data 
#-------------------------------------------------------------------
# NOTE: Here we create the 4-level page-mapping tables, needed for 
# execution in protected-mode with 64-bit Page-Address Extensions. 
# The lowest 64-KB of the virtual-address space is linearly mapped 
# upward to the load-address at 0x10000, which facilitates our use 
# of symbolic addresses when a segment's base-address equals zero. 
# Otherwise, the rest of the bottom megabyte is "identity-mapper". 
#-------------------------------------------------------------------
level1:	entry = ARENA 			# initial physical address 
	.rept	16 			# sixteen 4-KB page-frames 
	.quad	entry + 3 		# 'present' and 'writable' 
	entry = entry + 0x1000 		# next page-frame address 
	.endr 				# end of this repeat-macro 
	entry = ARENA 			# initial physical address 
	.rept	240 			# remainder of bottom 1-MB 
	.quad	entry + 3 		# 'present' and 'writable' 
	entry = entry + 0x1000 		# next page-frame address 
	.endr 				# end of this repeat-macro 
	.align	0x1000 			# rest of table has zeros 
#-------------------------------------------------------------------
level2:	.quad	level1 + ARENA + 3 	# initial directory entry 
	.align	0x1000 			# rest of table has zeros 
#-------------------------------------------------------------------
level3:	.quad	level2 + ARENA + 3 	# initial 'pointer' entry 
	.align	0x1000 			# rest of table has zeros 
#-------------------------------------------------------------------
level4:	.quad	level3 + ARENA + 3 	# initial 'level-4' entry 
	.align	0x1000 			# rest of table has zeros 
#-------------------------------------------------------------------


	.align	0x1000
#-------------------------------------------------------------------
vmcs1:	.long	0x00000007
	.zero	4092
#-------------------------------------------------------------------
region:	.quad	vmcs1 + ARENA
#-------------------------------------------------------------------
	.end				# no more to be assembled 
