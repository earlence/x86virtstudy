//-----------------------------------------------------------------
//	trycpuid.s
//
//	This assembly language program uses the CPUID instruction
//	to obtain the processor's 'Vendor Identification String'.
//
//	  	to assemble:  $ as trycpuid.s -o trycpuid.o
//	  	and to link:  $ ld trycpuid.o -o trycpuid
//
//	programmer: ALLAN CRUSE
//	written on: 06 FEB 2007
//-----------------------------------------------------------------

	.equ	dev_STDOUT, 1		# device-file ID-number
	.equ	sys_WRITE, 4		# system-call ID-number
	.equ	sys_EXIT, 1		# system-call ID-number

	.section	.data
report:	.ascii	"\n     processor is '"	# explanation for display
vendor:	.ascii	"xxxxxxxxxxxx' \n\n"	# buffer for vendor string
msglen:	.int	. - report		# length of message-string

	.section	.text
_start:	# use CPUID instruction with input-value equal to zero
	xor	%eax, %eax		# setup the input-value
	cpuid				# then execute CPUID
	mov	%ebx, vendor+0		# store bytes 0..3
	mov	%edx, vendor+4		# store bytes 4..7
	mov	%ecx, vendor+8		# store bytes 8..11

	# use the 'write' system-call to display our report
	mov	$sys_WRITE, %eax	# ID-number for function
	mov	$dev_STDOUT, %ebx	# ID-number for device
	lea	report, %ecx		# message-string address
	mov	msglen, %edx		# message-string length
	int	$0x80			# request kernel service

	# terminate this program
	mov	$sys_EXIT, %eax		# ID-number for function
	xor	%ebx, %ebx		# value 0 for exit-code
	int	$0x80			# request kernel service

	.global	_start			# make entry-point public
	.end				# no more to be assembled

