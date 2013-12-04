#------------------------------------------------------------------
# Here is our assembly language code that "reflects" the handling
# of external device interrupts back to the Virtual-8086 mode VM.
# 				    -- Allan Cruse, 26 April 2007
#------------------------------------------------------------------
guest_isrGPF:
	.code32
	# make sure the fault occurred while in VM86 mode
	btl	$17, 12(%esp)		# was VM=1 in EFLAGS?
	jnc	vmexit			# no, then exit to host

	# make sure an external interrupt occurred
	btl	$0, 0(%esp)		# is EXT=1 in error-code?
	jnc	diagnose		# no, investigate further

	# make sure we have the interrupt's ID-number
	btl	$1, 0(%esp)		# is INT=1 in error-code?
	jnc	diagnose		# no, investigate further 

	# setup access to stack-frame and preserve registers
	push	%ebp			# preserve frame-pointer
	mov	%esp, %ebp		# setup frame access
	push	%eax			# save working registers
	push	%ebx

	# setup selector to access flat address-space
	mov	$guest_selFS0, %ax	# address flat segment
	mov	%ax, %ds		#   with DS register

	# simulate push of FLAGS, CS and IP onto ring3 stack
	subw	$6, 20(%ebp)		# reduce SP by 3 words
	mov	24(%ebp), %ebx		# get ring3 SS-image
	and	$0xFFFF, %ebx		# extend to doubleword
	shl	$4, %ebx		# multiply by sixteen
	mov	20(%ebp), %eax		# get ring3 SP-image
	and	$0xFFFF, %eax		# extend to doubleword
	add	%eax, %ebx		# add to base-address
	movw	16(%ebp), %ax		# get tasks's FLAGS
	movw	%ax, 4(%ebx)		# save on ring3 stack
	movw	12(%ebp), %ax		# get task's CS-image
	movw	%ax, 2(%ebx)		# save on ring3 stack
	movw	8(%ebp), %ax		# get task's IP-image
	movw	%ax, 0(%ebx)		# save on ring3 stack

	# clear the IF and TF bits in the EFLAGS image 
	btrl	$9, 16(%ebp)		# clear the IF-bit
	btrl	$8, 16(%ebp)		# clear the TF-bit

	# compute the interrupt's ID-number in register EBX
	mov	4(%ebp), %ebx		# copy the error-code
	and	$0xFFFF, %ebx		# mask its upper word
	shr	$3, %ebx		# extract the index 
	mov	0(,%ebx,4), %ax		# get vector's loword
	mov	%ax, 8(%ebp)		# overwrite IP-image
	mov	2(,%ebx,4), %ax		# get vector's hiword
	mov	%ax, 12(%ebp)		# overwrite CS-image

	# restore registers, discard error-code, and resume VM86-mode
	pop	%ebx			# recover saved registers
	pop	%eax
	pop	%ebp
	add	$4, %esp		# discard the error-code
	iretl				# resume the VM86 task

diagnose:
	# TODO: display register-information, then exit
vmexit:	
	mov	$0x03F8, %dx		# UART's TxData i/o-port
	xor	%al, %al		# send 'null' data-byte
	out	%al, %dx		# to restart UART timeout

	vmcall				# leave VMX non-root mode
#------------------------------------------------------------------

