//-------------------------------------------------------------------
//	vmxdemo.s
//
//	Here is the runtime initialization code for our VMX demo,
//	which also includes three additional source-files (namely
//	'vmxstep1.s', 'vmxstep2.s', and 'vmxstep3.s').  Our Guest
//	VM executes a Virtual-8086 task which transmits a message
//	via the serial-UART.  Our Host VMM, which executes in 64-
//	mode, launches the guest-task, then regains control after
//	the guest-task has concluded.  This Host displays the ID-
//	number for the guest's 'Exit Reason', then transitions to
//	real-mode and awaits a user's 'reboot' keystroke-request.
//
//	 to assemble: $ as vmxdemo.s -o vmxdemo.o 
//	 and to link: $ ld vmxdemo.o -T ldscript -o vmxdemo.b 
//	 and install: $ dd if=vmxdemo.b of=/dev/sda4 seek=1 
//
//	NOTE: This program begins executing with CS:IP = 1000:0002. 
//
//	programmer: ALLAN CRUSE
//	date begun: 21 APR 2007
//	completion: 24 APR 2007
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

	call	enter_ia32e_mode	
	call	execute_our_demo	
	call	leave_ia32e_mode	

	lss	%cs:exit_pointer, %sp	# recover saved SS and SP
	lret				# exit back to the loader
#-------------------------------------------------------------------
exit_pointer:	.word	0, 0 		# for loader's SS and SP 
#-------------------------------------------------------------------
	.include	"vmxstep3.s"
#-------------------------------------------------------------------
regGDT:	.word	host_limGDT, host_GDT, 0x0001	# image for GDTR 
regIDT:	.word	host_limIDT, host_IDT, 0x0001	# image for IDTR 
regIVT:	.word	0x03FF, 0x0000, 0x0000		# image for IDTR 
#-------------------------------------------------------------------
#-------------------------------------------------------------------
enter_ia32e_mode:
	.code16

	# setup the Extended Feature Enable Register 
	mov	$0xC0000080, %ecx 
	rdmsr 
	bts	$8, %eax 		# set LME-bit in EFER 
	wrmsr 

	# setup system control register CR4  
	mov	host_CR4, %eax
	mov	%eax, %cr4 

	# setup system control register CR3  
	mov	host_CR3, %eax 
	mov	%eax, %cr3 		# setup page-mapping 

	# setup system control register CR0  
	cli				# no device interrupts
	mov	host_CR0, %eax
	mov	%eax, %cr0 		# turn on protection 

	# setup the system descriptor-table registers 
	lgdt	regGDT			# setup GDTR register 
	lidt	regIDT			# setup IDTR register 

	# load segment-registers with suitable selectors 
	ljmp	$host_sel_cs, $pm	# reload register CS
pm:
	mov	$host_sel_ds, %ax		
	mov	%ax, %ss		# reload register SS
	mov	%ax, %ds		# reload register DS
	mov	%ax, %es		# reload register ES

	xor	%ax, %ax		# use "null" selector
	mov	%ax, %fs		# to purge invalid FS
	mov	%ax, %gs		# to purge invalid GS

	ret	
#-------------------------------------------------------------------
execute_our_demo: 

	# preserve the stack-address 
	mov	%esp, tossave+0		# preserve 32-bit offset 
	mov	%ss,  tossave+4		#  plus 16-bit selector 

	# transfer via call-gate to 64-bit code-segment 
	lcall	$host_gate64, $0 	# transfer to 64-bit code 

	# restore saved stack-address 
fin:	lss	%cs:tossave, %esp 	# reload our saved SS:ESP 
	ret				# return to main function 
#-------------------------------------------------------------------
tossave:  .long	0, 0 			# stores a 48-bit pointer 
#-------------------------------------------------------------------
#-------------------------------------------------------------------
leave_ia32e_mode:
	.code16

	# insure segment-register caches have 'real' attributes 
	mov	$host_sel_ds, %ax	# address 64K r/w segment 
	mov	%ax, %ds		#   using DS register 
	mov	%ax, %es		#    and ES register 

	# modify system control register CR0 
	mov	%cr0, %eax		# get machine status
	btr	$0, %eax		# reset PE-bit to 0 
	btr	$31, %eax		# reset PG-bit to 0 
	mov	%eax, %cr0		# disable protection

	# reload segment-registers with real-mode addresses 
	ljmp	$0x1000, $rm		# reload register CS
rm:
	mov	%cs, %ax		
	mov	%ax, %ss		# reload register SS
	mov	%ax, %ds		# reload register DS
	mov	%ax, %es		# reload register ES

	# restore real-mode interrupt-vectors 
	lidt	regIVT			# restore vector table
	sti				# and allow interrupts

	ret	
#-------------------------------------------------------------------
	.align	16 			# insure stack alignment 
	.space	512 			# reserved for stack use 
tos:					# label for top-of-stack 
#-------------------------------------------------------------------
	.end				# no more to be assembled

