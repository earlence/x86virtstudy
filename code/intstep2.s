//-----------------------------------------------------------------
//	vmxstep2.s
//
//	This is the (tentative) 'Host' component for our proposed 
//	VMX demo-program.  It will need to be linked with 'Guest' 
//	and 'Control' components, plus initialization at runtime.
//
//	     assemble using:  $ as vmxstep2.s -o vmxstep2.o
//
//	programmer: ALLAN CRUSE
//	date begun: 14 APR 2007
//	completion: 24 APR 2007 
//-----------------------------------------------------------------


	# manifest constant
	.equ	ARENA, 0x10000		# program 'load-address'


	# list of the exported symbols
	.global	host_TOS0, host_level4
	.global	host_TSS, host_GDT, host_IDT
	.global	host_selCS0, host_selDS0, host_selTSS
	.global	host_task, theVMM, ARENA


	# list of the imported symbols
	.extern	fin, machine, ELEMENTS, results, ROCOUNT	


	.section	.bss
#------------------------------------------------------------------
msr0x480:	.space	88
#------------------------------------------------------------------
	.align	16
	.space	512
host_TOS0:
#------------------------------------------------------------------


	.section	.data
#------------------------------------------------------------------
host_TSS:
	.space	26 * 4

	.equ	host_limTSS, (. - host_TSS)-1
#------------------------------------------------------------------
host_IDT:
	.space	13 * 16

	# interrupt-gate for General Protection Exceptions
	.short	host_isrGPF, host_selCS0, 0x8E00, 0, 0,0,0,0

	.space	18 * 16
	.equ	host_limIDT, (. - host_IDT)-1
#------------------------------------------------------------------
#------------------------------------------------------------------
host_GDT:
	.quad	0x0000000000000000

	.equ	host_sel_cs, (. - host_GDT)+0
	.quad	0x00009A010000FFFF

	.equ	host_sel_ds, (. - host_GDT)+0
	.quad	0x000092010000FFFF

	.equ	host_selCS0, (. - host_GDT)+0
	.quad	0x00209A0000000000

	.equ	host_selDS0, (. - host_GDT)+0
	.quad	0x008F92000000FFFF

	.equ	host_selTSS, (. - host_GDT)+0
	.word	host_limTSS, host_TSS, 0x8B01, 0, 0,0,0,0

	.equ	host_gate64, (. - host_GDT)+0
	.word	host_task, host_selCS0, 0x8C00, 0, 0,0,0,0

	.equ	host_limGDT, (. - host_GDT)-1
#------------------------------------------------------------------
	.align	0x1000
#------------------------------------------------------------------
host_level1:
	entry = ARENA
	.rept	16
	.quad	entry + 0x003
	entry = entry + 0x1000
	.endr

	entry = ARENA
	.rept	240
	.quad	entry + 0x003
	entry = entry + 0x1000
	.endr

	.align	0x1000
#------------------------------------------------------------------
host_level2:
	.quad	host_level1 + ARENA + 0x003
	.space	511 * 8
#------------------------------------------------------------------
host_level3:
	.quad	host_level2 + ARENA + 0x003
	.space	511 * 8
#------------------------------------------------------------------
host_level4:
	.quad	host_level3 + ARENA + 0x003
	.space	511 * 8
#------------------------------------------------------------------
vmcs0:	.zero	0x1000
vmcs1:	.zero	0x1000
#------------------------------------------------------------------
#------------------------------------------------------------------
vmxon_region:	.quad	vmcs0 + ARENA
guest_region:	.quad	vmcs1 + ARENA
#------------------------------------------------------------------

	.section	.text
#------------------------------------------------------------------
host_task:
	.code64

	# turn on A20-line
	in	$0x92, %al
	or	$0x02, %al
	out	%al, $0x92

	# read the VMX-Capabality MSRs
	xor	%rbx, %rbx
	mov	$0x480, %ecx
nxmsr:	rdmsr
	mov	%eax, msr0x480+0(, %rbx, 4)	
	mov	%edx, msr0x480+4(, %rbx, 4)	
	inc	%ecx
	inc	%rbx
	cmp	$11, %rbx
	jb	nxmsr

	# initialize the two VMCS regions
	mov	msr0x480, %eax
	mov	%eax, vmcs0
	mov	%eax, vmcs1

	# Enter VMX Operation (and establish the Host's VMCS)
	vmxon	vmxon_region
	jc	xxx
	jz 	yyy

	# Clear the VMCS region to be used by our Guest VM
	vmclear	guest_region
	jc	xxx
	jz 	yyy

	# Establish our Guest's VMCS as the 'current' VM
	vmptrld	guest_region
	jc	xxx
	jz 	yyy

	# loop to initialize VMCS components for the current VM
	xor	%rdx, %rdx
	mov	$ELEMENTS, %rcx
nxvwr:	mov	machine+0(%rdx), %eax	# encoding
	mov	machine+4(%rdx), %ebx	# location
	vmwrite	(%ebx), %rax
	jc	xxx
	jz 	yyy
	add	$8, %rdx
	loop	nxvwr

	# Now try to initiate execution of the Guest VM
	vmlaunch

	# if unsuccessful, then leave VMX Operation and exit
yyy:	vmxoff
xxx:	int	$0

theVMM:	# this is where 'Host' gains control when 'Guest' exits 
	push	%rax
	push	%rbx
	push	%rcx
	push	%rdx

	# loop to extract read-only information from current VMCS
	xor	%rdx, %rdx
	mov	$ROCOUNT, %rcx
nxvrd:	mov	results+0(%rdx), %eax	# encoding
	mov	results+4(%rdx), %ebx	# location
	vmread	%rax, (%ebx)
	add	$8, %rdx
	loop	nxvrd

	# display a report about the VM exit
	call	host_report

	pop	%rdx
	pop	%rcx
	pop	%rbx
	pop	%rax

	#-- this is temporary (initial demo never reenters VM) --
	vmxoff
	ljmp	*depart
	#--------------------------------------------------------	

	vmresume
#------------------------------------------------------------------
msg2:	.ascii	" VMexit-Reason: "
buf2:	.ascii	"xxxxxxxxxxxxxxxx (hex) "
len2:	.quad	. - msg2
att2:	.byte	0x50
#------------------------------------------------------------------
host_report:
	.code64

	mov	info_vmexit_reason, %rax
	lea	buf2, %rdi
	call	rax2hex

	mov	$16, %rax
	imul	$160, %rax, %rdi
	add	$0xB8000, %rdi
	cld
	lea	msg2, %rsi
	mov	len2, %rcx
	mov	att2, %ah
.R0:	lodsb
	stosw
	loop	.R0

	ret
#------------------------------------------------------------------
host_isrGPF:
	.code64

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
depart:	.long	fin, host_sel_cs	# target for indirect jump 
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

