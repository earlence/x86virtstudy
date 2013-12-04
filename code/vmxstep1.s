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
//	correction: 13 JUL 2007 -- fixed errors in GDT 'equates'
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

	.equ	guest_selTSS, (. - guest_GDT)+0	# fixed 7/13/2007
	.word	guest_limTSS, guest_TSS, 0x8B01, 0

	.equ	guest_selLDT, (. - guest_GDT)+0	# fixed 7/13/2007
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

	# transmit extra 'null' byte (to restart UART timer)
	mov	$UART+0, %dx
	xor	%al, %al
	out	%al, %dx

	# now try to execute a 'privileged' instruction
	hlt
#------------------------------------------------------------------
digit:	.ascii	"0123456789ABCDEF"	# array of hex numerals
#------------------------------------------------------------------
guest_isrGPF:
	.code32
	vmcall
#------------------------------------------------------------------
# NOTE: Thanks to Martin Mocko for correction of two GDT-selectors. 
#------------------------------------------------------------------

