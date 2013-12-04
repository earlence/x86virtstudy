//----------------------------------------------------------------
//	eflags.s
//
//	This program shows how to display the initial contents of 
//	the processor's EFLAGS register as a 32-bit binary value.
//
//	        assemble using:  $ as eflags.s -o eflags.o
//	        and link using:  $ ld eflags.o -o eflags
//
//	programmer: ALLAN CRUSE
//	written on: 29 JAN 2006
//----------------------------------------------------------------

	.equ		sys_write, 4
	.equ		sys_exit,  1
	.equ		device_ID, 1

	.section	.data
msg:	.ascii		"\n\tEFLAGS="
buf: 	.ascii		"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n\n"
len:	.int		. - msg

	.section	.text
_start:
	# transfer contents of EFLAGS to register EDX
	pushfl				
	popl		%edx

	# counted loop: generate the 32 binary digits 
	movl		$buf, %ebx
	movl		$32, %ecx
again:
	movb		$0, %al
	addl		%edx, %edx
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

