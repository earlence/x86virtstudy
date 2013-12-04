//-------------------------------------------------------------------
//	int0x11.s
//
//	This program executes the ROB-BIOS 'Equipment_Check' service
//	(interrupt-0x11) and shows what is returned in register EAX.
//
//	 to assemble: $ as int0x11.s -o int0x11.o 
//	 and to link: $ ld int0x11.o -T ldscript -o int0x11.b 
//	 and install: $ dd if=int0x11.b of=/dev/sda4 seek=1 
//
//	NOTE: This program begins executing with CS:IP = 1000:0002. 
//
//	programmer: ALLAN CRUSE
//	written on: 04 MAY 2007
//-------------------------------------------------------------------

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

	# invoke the Equipment_Check ROM-BIOS function
	mov	$0xAAAAAAAA, %eax	# setup pattern in EAX
	int	$0x11			# call Equipment_Check
	lea	buf, %di		# point to output buffer
	call	eax2hex			# convert restlt to hex

	# get the current display-page number 
	mov	$0x0F, %ah		# BH = page_number
	int	$0x10			# request BIOS service

	# get the current page's cursor-location
	mov	$0x03, %ah		# (DH,DL) = cursor-locn
	int	$0x10			# request BIOS service

	# write message to current page at current location
	lea	msg, %bp		# point ES:BP to string
	mov	len, %cx		# specify string length
	mov	att, %bl		# specify text coloring
	mov	$0x1301, %ax		# write_string function
	int	$0x10			# request BIOS service

	lss	%cs:exit_pointer, %sp	# recover saved SS and SP
	lret				# exit back to the loader
#-------------------------------------------------------------------
exit_pointer:	.word	0, 0 		# for loader's SS and SP 
#-------------------------------------------------------------------
#-------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"	# array of hex digits
msg:	.ascii	"\r\n Equipment_Check: "
buf:	.ascii	"xxxxxxxx \r\n\n"	# buffer for output 
len:	.word	. - msg 		# length of output 
att:	.byte	0x70			# color attributes 
#-------------------------------------------------------------------
eax2hex:  # converts value in EAX to hexadecimal string at DS:DI 
	pushal

	mov	$8, %cx 		# setup digit counter 
nxnyb:	rol	$4, %eax 		# next nybble into AL 
	mov	%al, %bl 		# copy nybble into BL 
	and	$0xF, %bx		# isolate nybble's bits 
	mov	hex(%bx), %dl		# lookup ascii-numeral 
	mov	%dl, (%di) 		# put numeral into buf 
	inc	%di			# advance buffer index 
	loop	nxnyb			# back for next nybble

	popal
	ret 
#-------------------------------------------------------------------
	.align	16 			# insure stack alignment 
	.space	512 			# reserved for stack use 
tos:					# label for top-of-stack 
#-------------------------------------------------------------------
	.end				# no more to be assembled
