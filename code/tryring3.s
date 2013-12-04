//-------------------------------------------------------------------
//	tryring3.s		  
//
//	This example demonstrates how a privilege-level transition
//	(and its accompanying stack-switch) is accomplished as the
//	processor is executing in 64-bit mode.  To simplify memory
//	references to symbolic addresses in the 64-bit mode 'flat' 
//	virtual address-space, our page-table here linearly remaps 
//	the lowest 64K upward to our 'load' address at 0x00010000.   
//
//	  to assemble: $ as tryring3.s -o tryring3.o
//	  and to link: $ ld tryring3.o -T ldscript -o tryring3.b
//        and install: $ dd if=tryring3.b of=/dev/sda4 seek=1 
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE 
//	written on: 03 MAR 2007
//-------------------------------------------------------------------

	.section	.text
#-------------------------------------------------------------------
	.word	0xABCD			# our application signature
#-------------------------------------------------------------------
main:	.code16				# start in x86 'real-mode'
	mov	%sp, %cs:exit_pointer+0	# save stack's offset-addr
	mov	%ss, %cs:exit_pointer+2	# and stack's segment-addr

	mov	%cs, %ax		# address our program data
	mov	%ax, %ds		#   with the DS register
	mov	%ax, %ss		#   also the SS register
	lea	tos0, %sp		# establish ring0 stacktop

	call	enter_protected_mode
	call	exec_ring3_procedure
	call	leave_protected_mode

	lss	%cs:exit_pointer, %sp	# recover loader's stackptr
	lret				#  and return to the loader
#-------------------------------------------------------------------
exit_pointer:	.word	0, 0		# storage for stack-address 
#-------------------------------------------------------------------
theGDT:	.quad	0x0000000000000000	# required null-descriptor

	.equ	sel_CS0, (.-theGDT)+0
	.quad	0x00209A0000000000	# 64-bit code-descriptor

	.equ	sel_CS3, (.-theGDT)+3
	.quad	0x0020FA0000000000	# 64-bit code-descriptor

	.equ	sel_cs0, (.-theGDT)+0
	.quad	0x00009A010000FFFF	# 16-bit code-descriptor

	.equ	sel_ss0, (.-theGDT)+0
	.quad	0x000092010000FFFF	# 16-bit data-descriptor

	.equ	sel_cs3, (.-theGDT)+3
	.quad	0x0000FA010000FFFF	# 16-bit code-descriptor

	.equ	sel_ss3, (.-theGDT)+3
	.quad	0x0000F2010000FFFF	# 16-bit data-descriptor

	.equ	sel_tss, (.-theGDT)+0
	.short	limTSS, theTSS, 0x8901, 0x0000	# task-descriptor
	.short	0x0000, 0x0000, 0x0000, 0x0000	# for EM64T task

	.equ	sel_ret, (.-theGDT)+3
	.short	finis, sel_CS0, 0xEC00, 0x0001	# gate-descriptor
	.short	0x0000, 0x0000, 0x0000, 0x0000	# for EM64T gate

	.equ	limGDT, (.-theGDT)-1	# segment-limit for GDT
#-------------------------------------------------------------------
theIDT:	.space	13 * 16			# 13 gates 'not present'
	.short	isrGPF, sel_CS0, 0x8E00, 0x0001	# an interrupt-gate 
	.short	0x0000, 0x0000, 0x0000, 0x0000	# for GP-exceptions
	.equ	limIDT, (.-theIDT)-1	# segment-limit for IDT
#-------------------------------------------------------------------
theTSS:	.short	0x0000, 0x0000			# task back-link
	.quad	0x0000000000000000		# for ESP0 image 
	.equ	limTSS, (.-theTSS)-1	# segment-limit for TSS
#-------------------------------------------------------------------
regCR3:	.short	level4, 0x0001			# image for CR3
regGDT:	.short	limGDT, theGDT, 0x0001		# image for GDTR
regIDT:	.short	limIDT, theIDT, 0x0001		# image for IDTR
regIVT:	.short	0x03FF, 0x0000, 0x0000		# image for IDTR
#-------------------------------------------------------------------
enter_protected_mode:

	# Turn on the LME-bit in Extended Feature Enable Register
	mov	$0xC0000080, %ecx
	rdmsr
	bts	$8, %eax
	wrmsr

	# setup control-registers CR3 and CR4
	mov	regCR3, %eax
	mov	%eax, %cr3
	mov	%cr4, %eax
	bts	$5, %eax
	mov	%eax, %cr4
	
	# NOTE: we are unprepared for interrupts in protected-mode

	cli				# no device interrupts

	# turn on the PE-bit in system register CR0

	mov	%cr0, %eax		# get machine status
	bts	$0, %eax		#   set the PE-bit
	bts	$31, %eax		#   set the PG-bit
	mov	%eax, %cr0		# turn on protection

	# reinitialize the CS ans SS segment-register caches

	lgdt	regGDT			# initialize GDTR
	lidt	regIDT			# initialize IDTR
	ljmp	$sel_cs0, $pm		# reload CS register
pm:
	mov	$sel_ss0, %ax		
	mov	%ax, %ss		# reload SS register
	mov	%ax, %ds		# reload DS register

	# nullify 'stale' values in other segment-registers
	
	xor	%ax, %ax		# purge invalid values
	mov	%ax, %es		#   from ES register	
	mov	%ax, %fs		#   from FS register	
	mov	%ax, %gs		#   from GS register	
	ret
#-------------------------------------------------------------------
leave_protected_mode:

	# insure segment-registers have real-mode attributes

	mov	%ss, %ax		# put limit and rights
	mov	%ax, %ds		#   into the DS cache 
	mov	%ax, %es		#   into the ES cache 
	mov	%ax, %fs		#   into the FS cache 
	mov	%ax, %gs		#   into the GS cache 

	# turn off protection

	mov	%cr0, %eax		# get machine status
	btr	$0, %eax		#  reset the PE-bit
	btr	$31, %eax		#  reset the PG-bit
	mov	%eax, %cr0		# disable protection

	# reinitialize CS, SS, DS for real-mode addressing
	
	ljmp	$0x1000, $rm		# reload CS register
rm:	
	mov	%cs, %ax		
	mov	%ax, %ss		# reload SS register
	mov	%ax, %ds		# reload DS register

	# NOTE: now let the system handle interrupts again

	lidt	regIVT			# 'real' vector-table
	sti				# device interrupts ok
	ret	
#-------------------------------------------------------------------
tossave: .long	0, 0
#-------------------------------------------------------------------
exec_ring3_procedure:

	mov	%esp, tossave+0
	mov	%ss,  tossave+4

	movw	%sp, 	 theTSS+4
	movw	$0x0001, theTSS+6

	ljmp	$sel_CS0, $prog64 
#-------------------------------------------------------------------	
prog64: .code64

	# initialize the TR register

	mov	$sel_tss, %ax		# address task-state
	ltr	%ax			#  with TR register

	# setup ring0 stack for a 'return' to ring3 procedure

	and	$~7, %rsp		# quadword-align
	pushq	$sel_ss3		# push SS-image
	pushq	$tos3			# push RSP-image
	pushq	$sel_CS3		# push CS-image
	pushq	$showmsg		# push RIP-image
	lretq				# now transfer to ring3
#-------------------------------------------------------------------
msg3:	.ascii	" Now executing 64-bit code in ring3 "	# message
len3:	.quad	. - msg3		# message-size (in bytes)
att3:	.byte	0x1F			# intense white upon blue 
#-------------------------------------------------------------------
showmsg: .code64

	# display our ring3 confirmation-message
	cld				# use forward processing
	mov	$0xB8000, %rdi		# base-address of vram
	add	$480, %rdi		# point ES:RDI to screen
	lea	msg3, %rsi		# point DS:RSI to string
	mov	len3, %rcx		# setup character-count
	mov	att3, %ah		# setup color-attribute
nxchr:	lodsb				# fetch next character
	stosw				# store char and color
	loop	nxchr			# show entire message

	## int 	$9	# <--- included during testing of 'isrGPF'

	# transfer control through call-gate back to ring0
	lcall	*(supervisor)		# use long indirect call
#-------------------------------------------------------------------
supervisor: .long	0, sel_ret
#-------------------------------------------------------------------
finis:	.code64

	## int 	$7	# <--- included during testing of 'isrGPF'

	# transfer via long indirect jump to 'compatibility-mode'
	ljmp	*(departure)		# use long indirect jump
#-------------------------------------------------------------------
departure: .long	prog16, sel_cs0
#-------------------------------------------------------------------
prog16:	.code16
	lss	%cs:tossave, %esp	# restore 16-bit stacktop
	ret				# for near-return to main
#-------------------------------------------------------------------
#===================================================================
#-------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"
names:	.ascii	"  TR  CS  SS  GS  FS  ES  DS"
	.ascii	" RDI RSI RBP RSP RDX RCX RBX RAX"
	.ascii	" err RIP  CS EFL RSP  SS"
	.equ	N_ELTS, (. - names) / 4
buf:	.ascii	" nnn=xxxxxxxxxxxxxxxx "
buflen:	.quad	. - buf
#-------------------------------------------------------------------
isrGPF:	.code64

	push	%rax
	push	%rbx
	push	%rcx
	push	%rdx
	push	%rsp
	add	$40, (%rsp)
	push	%rbp
	push	%rsi
	push	%rdi

	pushq	$0
	mov	%ds, (%rsp)

	pushq	$0
	mov	%es, (%rsp)

	pushq	$0
	mov	%fs, (%rsp)

	pushq	$0
	mov	%gs, (%rsp)

	pushq	$0
	mov	%ss, (%rsp)

	pushq	$0
	mov	%cs, (%rsp)

	pushq	$0
	str	(%rsp)

	xor	%rbx, %rbx
nxelt:
	# put element-name
	mov	names(, %rbx, 4), %eax
	mov	%eax, buf

	# put element-value
	mov	(%rsp, %rbx, 8), %rax
	lea	buf+5, %edi
	call	rax2hex

	# setup element's screen-position
	mov	$22, %rax
	sub	%rbx, %rax
	imul	$160, %rax, %rdi
	add	$0x110, %rdi
	add	$0xB8000, %edi
	
	# copy buffer to screen
	lea	buf, %rsi
	mov	buflen, %rcx
	mov	$0x70, %ah
	cld
nxch:	lodsb
	stosw
	loop	nxch

	inc	%rbx
	cmp	$N_ELTS, %rbx
	jb	nxelt

	ljmp	*(departure)
#-------------------------------------------------------------------
rax2hex: .code64
	push	%rax
	push	%rbx
	push	%rcx
	push	%rdx
	push	%rdi

	mov	$16, %rcx
nxnyb:	rol	$4, %rax
	mov	%al, %bl
	and	$0xF, %rbx
	mov	hex(%rbx), %dl
	mov	%dl, (%rdi)
	inc	%rdi
	loop	nxnyb

	pop	%rdi
	pop	%rdx
	pop	%rcx
	pop	%rbx
	pop	%rax
	ret
#-------------------------------------------------------------------
	.align	16			# assures stack-alignment
	.space	512			# space for 'ring3' stack
tos3:					# labels 'ring3' stacktop
	.space	512			# space for 'ring0' stack
tos0:					# labels 'ring0' stacktop
#-------------------------------------------------------------------


	.section	.data
#------------------------------------------------------------------
	.align	0x1000
#------------------------------------------------------------------
level0:	entry = 0x10000
	.rept	16
	.quad	entry + 7
	entry = entry + 0x1000
	.endr
	entry = 0x10000
	.rept	240
	.quad	entry + 7
	entry = entry + 0x1000
	.endr
	.align	0x1000
#------------------------------------------------------------------
level2:	.quad	level0 + 0x10000 + 7
	.align	0x1000
#------------------------------------------------------------------
level3:	.quad	level2 + 0x10000 + 7
	.align	0x1000
#------------------------------------------------------------------
level4:	.quad	level3 + 0x10000 + 7
	.align	0x1000
#------------------------------------------------------------------
	.end
