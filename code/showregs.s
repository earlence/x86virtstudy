//-----------------------------------------------------------------
//	showregs.s
//
//	This assembly language program was written for execution
//	on an x86-compatible platform running a version of Linux 
//	written for Intel's "Extended Memory 64-bit Technology",
//	such as our machines with the new Core-2 Duo processors. 
//	The program is supposed to display the initial values in
// 	the processor's 64-bit "general-purpose" registers using 
//	hexadecimal format, but evidently this programmer forgot
//	about the extra eight general-purpose registers that the
//	processor provides when it's running in its 64-bit mode.
//
//	Can you modify the program-code to remedy that omission?
//
//	      to assemble:  $ as showregs.s -o showregs.o
//	      and to link:  $ ld showregs.o -o showregs
//            and execute:  $ ./showregs
//
//	programmer: ALLAN CRUSE
//	written on: 22 FEB 2007
//-----------------------------------------------------------------


	# manifest constants
	.equ	n_regs, 8		# the number of registers
	.equ	dev_stdout, 1		# device-file ID-number
	.equ	sys_write, 4		# system-call ID-number
	.equ	sys_exit, 1		# system-call ID-number



	.section	.data
hex:	.ascii	"0123456789ABCDEF"	# table of hex numerals
reg:	.space	64			# holds register-values 
names:	.ascii	" RAX RBX RCX RDX"	# our list of names for 
	.ascii	" RSP RBP RSI RDI"	# the general registers
buf:	.ascii	" nnn=xxxxxxxxxxxxxxxx \n"	# output-buffer
len:	.quad	. - buf			# buffer-length (bytes)  


	.code64
	.section	.text
_start:	
	# save the values found in the general registers

	mov	%rax, reg+0x00		# save register RAX
	mov	%rbx, reg+0x08		# save register RBX
	mov	%rcx, reg+0x10		# save register RCX
	mov	%rdx, reg+0x18		# save register RDX
	mov	%rsp, reg+0x20		# save register RSP
	mov	%rbp, reg+0x28		# save register RBP
	mov	%rsp, reg+0x30		# save register RSI
	mov	%rbp, reg+0x38		# save register RDI


	# display the values found in the general registers
	
	xor	%rsi, %rsi		# initial array-index
nxreg:
	# copy register's name to the output-buffer
	mov	names(,%rsi,4), %eax	# get name from table
	mov	%eax, buf		# put name into buffer

	# generate register's hex-value in the output-buffer 
	lea	buf+5, %rdi		# point to value-field
	mov	reg(,%rsi,8), %rax	# get register's value
	mov	$16, %rcx		# setup count of digits 
nxnyb:	rol	$4, %rax		# next nybble into AL
	mov	%al, %bl		# then copy byte to BL
	and	$0xF, %rbx		# isolate lowest 4-bits
	mov	hex(%rbx), %dl		# lookup nybble's digit
	mov	%dl, (%rdi)		# put digit into buffer
	inc	%rdi			# advance buffer-pointer
	loop	nxnyb			# again for next nybble

	# system-call to write the output-buffer to the screen
	mov	$sys_write, %eax	# system-call ID-number
	mov	$dev_stdout, %ebx	# device-file ID-number
	lea	buf, %ecx		# address of the buffer
	mov	len, %edx		# length of the buffer
	int	$0x80			# invoke kernel service

	# increment our array-index
	inc	%rsi			# increase ESI by one 
	cmp	$n_regs, %rsi		# all registers shown?
	jb	nxreg			# no, then show another


	# terminate this program

	mov	$sys_exit, %eax		# system-call ID-number
	xor	%ebx, %ebx		# use zero as exit-code
	int	$0x80			# invoke kernel service

	.global	_start			# make entry-point visible
	.end				# nothing else to assemble

