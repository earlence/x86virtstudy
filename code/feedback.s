//-----------------------------------------------------------------
//	feedback.s
//
//	This example shows how you could write a Linux program in
//	assembly language that would receive a character sent via
//	the "null-modem" cable, display it on your PC's terminal, 
//	and then also send it back to the PC that it came from.     
//
//	     to assemble:  $ as feedback.s -o feedback.o
//	     and to link:  $ ld feedback.o -o feedback
//	     and execute:  $ ./feedback
//
//	NOTE: Remember -- you'll need to use the 'iopl3' command
//	for getting privileges you need to execute this program.
//
//	programmer: ALLAN CRUSE
//	written on: 25 JAN 2007
//-----------------------------------------------------------------

	# manifest constants
	.equ	sys_IOPL, 110		# system-call ID-number
	.equ	sys_WRITE, 4		# system-call ID-number
	.equ	sys_EXIT, 1		# system-call ID-number
	.equ	STDOUT, 1		# device-ID for display
	.equ	IOBASE, 0x03F8		# base io-port for UART


	.section	.data
err1:	.ascii	"iopl: permission denied\n"	  # error-message
len1:	.int	. - err1		# length of error message
inch:	.space	1			# for saving a character


	.section	.text
_start:	# acquire permission-level for direct I/O
	mov	$sys_IOPL, %eax		# EAX = system-call ID
	mov	$3, %ebx		# EBX = new IOPL-value
	int	$0x80			# enter Linux kernel
	or	%eax, %eax		# check return-value
	jz	okio			# zero? call succeeded

	# otherwise write an error-message to the screen
	mov	$sys_WRITE, %eax	# EAX = system-call ID
	mov	$STDOUT, %ebx		# EBX = ID for display  
	lea	err1, %ecx		# ECX = message address
	mov	len1, %edx		# EDX = message length
	int	$0x80			# enter Linux kernel
	jmp	exit			# and conclude program
okio:
	# set the UART's communication parameters
	mov	$IOBASE+3, %dx		# UART's LINE_CONTROL 
	mov	$0x80, %al		# want register-value 
	out	%al, %dx		# to have DLAB-bit=1
	sub	$3, %dx			# UART's DIVISOR_LATCH
	mov	$0x0001, %ax		# use baud-rate 115200
	out	%ax, %dx		# as the UART's speed
	add	$3, %dx			# UART's LINE_CONTROL
	mov	$0x03, %al		# data-format: 8-N-1
	out	%al, %dx		# output this format


	# wait until a new character is received
	mov	$IOBASE+5, %dx		# UART's LINE_STATUS
spin1:	inb	%dx, %al		# input device status
	test	$0x01, %al		# new data received?
	jz	spin1			# no, check it again

	# input the new character and store it
	mov	$IOBASE+0, %dx		# UART RxD register
	inb	%dx, %al		# input new data
	mov	%al, inch		# save it as 'inch'

	# write the received character to the display screen
	mov	$sys_WRITE, %eax	# EAX = system-call ID
	mov	$STDOUT, %ebx		# EBX = ID for display
	lea	inch, %ecx		# ECX = data's address
	mov	$1, %edx		# EDX = data's length
	int	$0x80			# enter Linux kernel

	# wait until the Transmit Holding Register is empty
	mov	$IOBASE+5, %dx		# UART's LINE_STATUS
spin2:	inb	%dx, %al		# input device status
	test	$0x20, %al		# ready to transmit?
	jz	spin2			# no, check it again

	# get the previously saved character and output it 
	mov	inch, %al		# retreive saved data
	mov	$IOBASE+0, %dx		# UART TxD register
	outb	%al, %dx		# output data to TxD

exit:	# now terminate this program
	mov	$sys_EXIT, %eax		# EAX = system-call ID
	int	$0x80			# enter Linux kernel

	.global	_start			# make entry-point public
	.end				# nothing more to assemble

