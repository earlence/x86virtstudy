//-----------------------------------------------------------------
//	hangdemo.s
//
//	This program will investigates the cause of the mysterious
//	return-to-real-mode program 'hang' phenomenon, observed on
//	some platforms when ROM-BIOS service-functions are invoked
//	with the segment-registers FS and GS retaining 64K limits.
//
//	  to assemble: $ as hangdemo.s -o hangdemo.o 
//	  and to link: $ ld hangdemo.o -T ldscript -o hangdemo.b
//	  and install: $ dd if=hangdemo.b of=/dev/sda4 seek=1 
//
//	NOTE: This code begins executing with CS:IP = 1000:0002
//
//	programmer: ALLAN CRUSE
//	written on: 22 MAR 2007
//-----------------------------------------------------------------


	.code16				# for x86 'real-mode'


	.section	.text
#------------------------------------------------------------------
	.short	0xABCD
#------------------------------------------------------------------
main:	# setup segment-registers and establish stack-address
	mov	%cs, %ax
	mov	%ax, %ds
	mov	%ax, %es
	mov	%ax, %ss
	lea	tos, %sp

	# install new fault-handler in interrupt vector table
	xor	%ax, %ax
	mov	%ax, %fs
	mov	$13, %ax
	imul	$4, %ax, %di
	mov	$isrGPF, %ax
	mov	%ax, %fs:0(%di)
	mov	%cs, %fs:2(%di)

	# install invalid segment-limits in registers FS and GS
	cli
	lgdt	%cs:regGDT
	mov	%cr0, %eax
	bts	$0, %eax
	mov	%eax, %cr0
	xor 	%ax, %ax
	mov	%ax, %fs
	mov	%ax, %gs
	mov	%cr0, %eax
	btr	$0, %eax
	mov	%eax, %cr0
	sti

	# now execute ROM-BIOS service-functions
	mov	%cs, %ax
	mov	%ax, %ds
	mov	%ax, %es
	mov	$0x0F, %ah
	int	$0x10
	mov	$0x03, %ah
	int	$0x10
	lea	msg1, %bp
	mov	len1, %cx
	mov	att1, %bl
	mov	$0x1301, %ax
	int	$0x10

	# await user keypress
	xor	%ah, %ah
	int	$0x16

	# reboot the computer
	int	$0x19
#------------------------------------------------------------------
	.align	16
theGDT:	.quad	0x0000000000000000

	.equ	sel_ds, (.-theGDT)+0
	.quad	0x000092000000FFFF

	.equ	sel_fs, (.-theGDT)+0
	.quad	0x008F92000000FFFF

	.equ	limGDT, (.-theGDT)-1
#------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001  
#------------------------------------------------------------------
msg1:	.ascii	"\r\n Press any key to reboot \r\n\n"
len1:	.short	. - msg1
att1:	.byte	0x05
#------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"
#------------------------------------------------------------------
ax2hex:	# converts word in AX to hexadecimal string at DS:DI
	pusha

	mov	$4, %cx
nxnyb:	
	rol	$4, %ax
	mov	%al, %bl
	and	$0xF, %bx
	mov	hex(%bx), %dl
	mov	%dl, (%di)
	inc	%di
	loop	nxnyb

	popa
	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
msg:	.ascii	" General Protection Fault at CS:IP = "
buf:	.ascii	"xxxx:xxxx  "
ops:	.ascii	"ii ii ii ii ii ii ii ii "
len:	.short	. - msg
att:	.byte	0x70
tmp:	.long	0
#------------------------------------------------------------------
isrGPF:	# our exception-handler for any General Protection Faults

	# setup frame-pointer to access faulting-instruction CS:IP
	push	%bp
	mov	%sp, %bp

	# preserve all registers for retry of faulting instruction
	pusha
	push	%ds
	push	%es
	push	%fs
	push	%gs
	
	# setup DS to address our program-variables
	mov	%cs, %ax
	mov	%ax, %ds

	# format bytes from the instruction-stream in hex
	les	2(%bp), %si		# point ES:SI to instruction
	lea	ops, %bx		# point DS:BX to buffer 
	mov	$8, %cx			# number of bytes to dump
nxop:	mov	%es:(%si), %al		# get next instruction-byte
	lea	tmp, %di		# point DS:DI to 'tmp' 
	call	ax2hex			# convert AX to hex format
	mov	tmp+2, %dx		# get lowest two numerals  
	mov	%dx, (%bx)		# place these into buffer
	inc	%si			# advance instruction-ptr
	add	$3, %bx			# advance buffer pointer
	loop	nxop			# again if bytes remain

	# format faulting CS-value
	mov	4(%bp), %ax
	lea	buf, %di
	call	ax2hex
	
	# format faulting IP-value
	mov	2(%bp), %ax
	lea	buf+5, %di
	call	ax2hex
	
	# draw fault-message directly to video memory
	mov	$0xB800, %ax
	mov	%ax, %es
	mov	$1600, %di
	lea	msg, %si
	mov	len, %cx
	mov	att, %ah
	cld
.L0:	lodsb
	stosw
	loop	.L0

	# reload registers FS and GS with 4GB segment-limits
	lgdt	%cs:regGDT
	mov	%cr0, %eax
	bts	$0, %eax
	mov	%eax, %cr0
	mov	$sel_fs, %ax
	mov	%ax, %fs
	mov	%ax, %gs
	mov	%cr0, %eax
	btr	$0, %eax
	mov	%eax, %cr0
	
	# restore registers, discard frame-pointer, and retry
	pop	%gs
	pop	%fs
	pop	%es
	pop	%ds
	popa
	leave
	iret
#------------------------------------------------------------------
	.align	16
	.space	512
tos:
#------------------------------------------------------------------
	.end

