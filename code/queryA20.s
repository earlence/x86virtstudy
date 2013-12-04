//-------------------------------------------------------------------
//	queryA20.s
//
//	This program will report the state of the A20 address-line.
//
//	  to assemble: $ as queryA20.s -o queryA20.o
//	  and to link: $ ld queryA20.o -T ldscript -o quaryA20.b
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 02 JUN 2006
//-------------------------------------------------------------------

	.code16
	.section	.text
#-------------------------------------------------------------------
	.word	0xABCD			# our application signature
#-------------------------------------------------------------------
main:	mov	%sp, %cs:exit_pointer+0 
	mov	%ss, %cs:exit_pointer+2

	mov	%cs, %ax	
	mov	%ax, %ds	
	mov	%ax, %es	
	mov	%ax, %ss	
	lea	tos, %sp	

	# read Port92 
	in	$0x92, %al
	mov	%al, port92

	# convert byte to a hexadecimal string
	xor	%di, %di
	mov	$2, %cx
nxnyb:
	rol	$4, %al
	mov	%ax, %si
	and	$0x0F, %si
	mov	hex(%si), %dl
	mov	%dl, buf1(%di)
	inc	%di
	loop	nxnyb

	# now see if memory at 1-MB matches memory at 0-MB
	cld
	push	%ds

	lea	para1, %di
	mov	$0xFFFF, %ax
	mov	%ax, %ds
	mov	$0x0010, %si
	mov	$16, %cx
	rep	movsb
		
	lea	para0, %di
	mov	$0x0000, %ax
	mov	%ax, %ds
	mov	$0x0000, %si
	mov	$16, %cx
	rep	movsb
	
	pop	%ds

	# compare the paragraphs
	lea	para0, %si
	lea	para1, %di
	mov	$16, %cx
	rep	cmpsb
	setne	differ

	# format the Yes/No response
	mov	differ, %bl
	and	$0xF, %ebx
	mov	yesno(, %ebx, 4), %edx
	mov	%edx, buf2

	# display the response
	mov	$0x0F, %ah
	int	$0x10
	mov	$0x03, %ah
	int	$0x10
	lea	msg, %bp
	mov	len, %cx
	mov	$0x0E, %bl
	mov	$0x1301, %ax
	int	$0x10

	lss	%cs:exit_pointer, %sp	
	lret	
#-------------------------------------------------------------------
exit_pointer: 	.word	0, 0 
#-------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"
yesno:	.ascii	"Yes No  "
port92:	.byte	0
differ:	.byte	0
msg:	.ascii	"\n\r Port 0x92: "
buf1:	.ascii	"xx \n\r\n"
	.ascii	" Memory-paragraphs at 0-MB and 1-MB are identical? "
buf2:	.ascii	"xxxx \n\r\n"
len:	.short	. - msg
para0:	.zero	16
para1:	.zero	16
#-------------------------------------------------------------------
	.align	16
	.space	1024
tos:	
#-------------------------------------------------------------------
	.end

