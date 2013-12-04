//----------------------------------------------------------------
//	gdtr.s
//
//	This program shows how to display the initial contents of 
//	the processor's GDTR register as a 48-bit binary value.
//
//	        assemble using:  $ as gdtr.s -o gdtr.o
//	        and link using:  $ ld gdtr.o -o gdtr
//
//	programmer: ALLAN CRUSE
//	written on: 30 JAN 2006
//----------------------------------------------------------------

	.equ		sys_write, 4
	.equ		sys_exit,  1
	.equ		device_ID, 1

	.section	.data
regGDT:	.space		6		# storage for GDTR contents
msg:	.ascii		"\n\tGDTR="
buf: 	.ascii		"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
 	.ascii		"xxxxxxxxxxxxxxxx \n\n"
len:	.int		. - msg

	.section	.text
_start:
	# transfer contents of GDTR to register EDX:BP
	sgdt		regGDT
	movw		regGDT, %bp
	movl		regGDT+2, %edx

	# counted loop: generate the 48 binary digits 
	movl		$buf, %ebx
	movl		$48, %ecx
again:
	movb		$0, %al
	addw		%bp, %bp
	adcl		%edx, %edx
	adcb		$'0', %al
	movb		%al, (%ebx)
	incl		%ebx
	decl		%ecx
	jnz		again

	# write our message to the display device
	movl		$sys_write, %eax
	movl		$device_ID, %ebx
	movl		$msg, %ecx
	movl		len, %edx
	int		$0x80

	# terminate this program
	movl		$sys_exit, %eax
	movl		$0, %ebx
	int		$0x80

	.global		_start
	.end

