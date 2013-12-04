//-----------------------------------------------------------------
//	vmxstep1.s
//
//	This is the 'Guest' component for our proposed VMX demo. 
//	It will need to be linked with our 'Host' and 'Control' 
//	components (as well as runtime initialization routines).
//
//	  to assemble:  $ as vmxstep1.s -o vmxstep1.o
//	  and to link:  $ as vmxstep1.o -T ldscript -o vmxstep1.b
//
//	programmer: ALLAN CRUSE
//	written on: 13 APR 2007
//	revised on: 24 APR 2007 -- added display of register CR0
//-----------------------------------------------------------------

	.global	guest_TSS, guest_limTSS, guest_selTSS
	.global	guest_LDT, guest_limLDT, guest_selLDT
	.global	guest_GDT, guest_limGDT 
	.global	guest_IDT, guest_limIDT 
	.global	guest_selCS0, guest_selDS0 
	.global	guest_selES0, guest_selFS0 
	.global	guest_PGDIR, guest_TOS0, guest_TOS3
	.global	guest_task, guest_isrGPF

	.section	.bss
	.align	16
#------------------------------------------------------------------
	.space	512
guest_TOS3:
#------------------------------------------------------------------
	.space	512
guest_TOS0:
#------------------------------------------------------------------

	.section	.data
#------------------------------------------------------------------
guest_TSS:	
	.long	0, guest_TOS0, guest_selDS0
	.space	22 * 4
	.word	0, IOBASE - guest_TSS
	.zero	0x20
IOBASE:	.zero	0x2000
	.byte	0xFF
	.equ	guest_limTSS, (. - guest_TSS)-1
#------------------------------------------------------------------
guest_GDT:
	.quad	0x0000000000000000

	.equ	guest_selTSS, (. - guest_TSS)+0
	.word	guest_limTSS, guest_TSS, 0x8B01, 0

	.equ	guest_selLDT, (. - guest_LDT)+0
	.word	guest_limLDT, guest_LDT, 0x8201, 0

	.equ	guest_limGDT, (. - guest_GDT)-1
#------------------------------------------------------------------
#------------------------------------------------------------------
guest_LDT:

	.equ	guest_selCS0, (. - guest_LDT)+4
	.quad	0x00409A010000FFFF

	.equ	guest_selDS0, (. - guest_LDT)+4
	.quad	0x004092010000FFFF

	.equ	guest_selES0, (. - guest_LDT)+4
	.quad	0x0040920B8000FFFF

	.equ	guest_selFS0, (. - guest_LDT)+4
	.quad	0x00CF92000000FFFF

	.equ	guest_limLDT, (. - guest_LDT)-1
#------------------------------------------------------------------
guest_IDT:
	.space	13 * 8

	# interrupt-gate for General Protection Exceptions
	.word	guest_isrGPF, guest_selCS0, 0x8E00, 0

	.space	18 * 8
	.equ	guest_limIDT, (. - guest_IDT)-1
#------------------------------------------------------------------
	.align	0x1000
#------------------------------------------------------------------
guest_PGDIR:
	.long	0x00000087
	.zero	1023 * 4
#------------------------------------------------------------------


	.section	.text
#------------------------------------------------------------------
guest_msg1: 
	.ascii	"\033[2J\033[10;30H"
	.ascii	" Hello from Guest VM "
	.ascii	"\033[12;33H"
	.ascii	" CR0="
msw:	.ascii	"xxxxxxxx "
	.asciz	"\033[23;1H\n         " 
#------------------------------------------------------------------
guest_msg2:
	.ascii	"\033[20;29H"
	.ascii	" Timer-tick: "
tbuf:	.asciz	"             "
#------------------------------------------------------------------
guest_task:
	.code16				# for Virtual-8086 mode

	# format image from system-register MSW (aka CR0)
	mov	%cs, %ax
	mov	%ax, %ds
	smsw	%eax
	lea	msw, %di
	mov	$8, %cx
nxrol:	rol	$4, %eax
	mov	%al, %bl
	and	$0xF, %bx
	mov	digit(%bx), %dl
	mov	%dl, (%di)
	inc	%di
	loop	nxrol

	# initialize the serial-UART (115200-baud, 8-N-1)
	.equ	UART, 0x03F8
	mov	$UART+3, %dx
	in	%dx, %al
	or	$0x80, %al
	out	%al, %dx
	mov	$UART+0, %dx
	mov	$0x0001, %ax
	out	%ax, %dx
	mov	$UART+3, %dx
	mov	$0x03, %al
	out	%al, %dx

	# transmit message-string via UART in "polled" mode
	xor	%si, %si
nxbyte:	mov	$UART+5, %dx
	in	%dx, %al
	test	$0x20, %al
	jz	nxbyte
	mov	guest_msg1(%si), %al
	or	%al, %al
	jz	issent
	mov	$UART+0, %dx
	out	%al, %dx
	inc	%si
	jmp	nxbyte
issent:	in	%dx, %al
	test	$0x40, %al
	jz	issent

	# repeatedly displays the current timer-tick counter
	mov	$0x40, %ax	# address ROM-BIOS DATA-AREA
	mov	%ax, %fs 	#   using FS register

	mov	%fs:0x006C, %eax	# get current count
	add	$182, %eax
	mov	%eax, timeout		
nxshow:
	mov	%fs:0x006C, %eax	# get current count
	cmp	%eax, timeout		# timeout exhausted?
	jbe	noshow

	# format the count for display
	lea	tbuf, %di
	mov	$10, %ebx	
	xor	%cx, %cx
nxdiv:	xor	%edx, %edx
	div	%ebx
	push	%dx
	inc	%cx
	or	%eax, %eax
	jnz	nxdiv
nxdgt:	pop	%dx
	or	$'0', %dl
	mov	%dl, (%di)
	inc	%di
	loop	nxdgt

	# transmit message-string via UART in "polled" mode
	xor	%si, %si
nxbytt:	mov	$UART+5, %dx
	in	%dx, %al
	test	$0x20, %al
	jz	nxbytt
	mov	guest_msg2(%si), %al
	or	%al, %al
	jz	issenn
	mov	$UART+0, %dx
	out	%al, %dx
	inc	%si
	jmp	nxbytt
issenn:	in	%dx, %al
	test	$0x40, %al
	jz	issenn

	jmp	nxshow	
noshow:

	# transmit extra 'null' byte (to restart UART timer)
	mov	$UART+0, %dx
	xor	%al, %al
	out	%al, %dx

	# now try to execute a 'privileged' instruction
	hlt
#------------------------------------------------------------------
digit:	.ascii	"0123456789ABCDEF"	# array of hex numerals
timeout: .long	0
#------------------------------------------------------------------
guest_isrGPF:
	.code32

	# make sure we were in Virtual-8086 mode
	btl	$17, 12(%esp)	# is VM-bit set?
	jnc	vmexit		# no, time to exit to VMM

	# make sure it was an external interrupt
	btl	$0, 0(%esp)	# is EXT-bit set?
	jnc	diagnose	# no, find out why we're here
	btl	$1, 0(%esp)	# is INT-bit set?
	jnc	diagnose	# no, find out why

	# preserve registers and setup stack-frame pointer
	push	%ebp
	mov	%esp, %ebp

	push	%eax
	push	%ebx

	# setup register DS to address flat address-space
	mov	$guest_selFS0, %ax
	mov	%ax, %ds

	# simulate the push of FLAGS, CS, and IP onto ring3 stack
	subw	$6, 20(%ebp)	# reduce SP-image by 3-words
	
	movw	24(%ebp), %bx	# get SS-image
	and	$0xFFFF, %ebx	# extend to 32-bits
	shl	$4, %ebx	# multiply segment by 16
	movw	20(%ebp), %ax	# get SP-image
	and	$0xFFFF, %eax
	add	%eax, %ebp	# this is top-of-stack address

	mov	16(%ebp), %ax
	mov	%ax, %ds:4(%ebx)
	
	mov	12(%ebp), %ax
	mov	%ax, %ds:2(%ebx)

	mov	8(%ebp), %ax
	mov	%ax, %ds:0(%ebx)

	# clear the IF and TF bits in EFLAGS imasge
	btrl	$9, 16(%ebp)	# clear IF image
	btrl	$8, 16(%ebp)	# clear TF image

	# extract the device's interrupt-ID number
	mov	4(%ebp), %bx	# get error-code
	and	$0xFFFF, %ebx	# extend to 32-bits
	shr	$3, %ebx	# discard bottom 3 bits

	# put interrupt-vector's parts on ring0 stack 
	movw	%ds:0(, %ebx, 4), %ax
	mov	%ax, 8(%ebp)	# vector loword for IP

	mov	%ds:2(, %ebx, 4), %ax
	mov	%ax, 12(%ebp)	# vector hiword for CS

	# restore resisters, discard error-code, and resume task
	pop	%ebx
	pop	%eax
	pop	%ebp
	add	$4, %esp
	iretl   

diagnose:	
	# TODO: show register information
vmexit:


	vmcall
#------------------------------------------------------------------

