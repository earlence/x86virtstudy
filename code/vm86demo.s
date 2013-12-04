//-----------------------------------------------------------------
//	vm86demo.s
//
//	This program enters protected-mode, then executes a real-
//	mode procedure in Virtual-8086 emulation mode.  It leaves
//	VM86-mode when a General Protection Fault is triggered by
//	the attempt to execute a privileged instruction in ring3.
//
//	 to assemble:  $ as vm86demo.s -o vm86demo.o
//	 and to link:  $ ld vm86demo.o -T ldscript -o vm86demo.b
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 05 APR 2007
//-----------------------------------------------------------------

	.section	.text
#------------------------------------------------------------------
	.short	0xABCD
#------------------------------------------------------------------
main:	.code16
	mov	%sp, %cs:exit_pointer+0	# preserve the loader's SP
	mov	%ss, %cs:exit_pointer+2	# preserve the loader's SS

	mov	%cs, %ax		# address program data
	mov	%ax, %ds		#   with DS register
	mov	%ax, %es		#   also ES register
	mov	%ax, %ss		#   also SS register
	lea	tos0, %esp		# establish a new stack

	call	enter_protected_mode 
	call	execute_program_demo
	call	leave_protected_mode 

	lss	%cs:exit_pointer, %sp	# recover saved SS and SP
	lret				# back to program loader
#------------------------------------------------------------------
exit_pointer:	.short	0, 0
#------------------------------------------------------------------
theTSS:	.long	0, 0, 0			# 32bit Task-State Segment
	.equ	limTSS, (. - theTSS)-1	# segment-limit for TSS
#------------------------------------------------------------------
theGDT:	.quad	0x0000000000000000

	.equ	sel_cs, (. - theGDT)+0	# selector for 16-bit code
	.quad	0x00009A010000FFFF	# code-segment descriptor

	.equ	sel_ds, (. - theGDT)+0	# selector for 16-bit data
	.quad	0x000092010000FFFF	# data-segment descriptor

	.equ	selTSS, (. - theGDT)+0	# selector for Task-State
	.word	limTSS, theTSS, 0x8901, 0x0000	# TSS descriptor

	.equ	limGDT, (. - theGDT)-1	# segment-limit for GDT
#------------------------------------------------------------------
#------------------------------------------------------------------
theIDT:	.space	8 * 13			# 13 'not-present' gates
	.word	isrGPF, sel_cs, 0x8F00, 0x0000	# 80386 trap-gate
	.equ	limIDT, (. - theIDT)-1	# segment-limit for IDT
#------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001	# image for register GDTR
regIDT:	.word	limIDT, theIDT, 0x0001	# image for register IDTR
regIVT:	.word	0x03FF, 0x0000, 0x0000	# image for register IDTR
#------------------------------------------------------------------
enter_protected_mode:

	cli				# no device interrupts

	mov	%cr0, %eax		# get machine status
	bts	$0, %eax		# set PE-bit to 1
	mov	%eax, %cr0		# enable protection

	lgdt	regGDT			# load GDTR register
	lidt	regIDT			# load IDTR register

	ljmp	$sel_cs, $pm		# reload CS register
pm:
	mov	$sel_ds, %ax		
	mov	%ax, %ss		# reload SS register
	mov	%ax, %ds		# reload DS register
	mov	%ax, %es		# reload ES register

	ret				# back to main routine
#------------------------------------------------------------------
execute_program_demo:

	# initialize the Task-State Segment's SS0:ESP0 fields
	mov	%esp, theTSS+4		# preserve ESP register
	mov	%ss,  theTSS+8		#  and the SS register

	# setup register TR with selector for Task-State Segment
	mov	$selTSS, %ax		# selector for the TSS
	ltr	%ax			#  is loaded into TR 

	# make sure the NT-bit is clear in the EFLAGS register
	pushfl				# push EFLAGS settings
	btrl	$14, (%esp)		# reset NT-bit to zero
	popfl				# pop back into EFLAGS

	# setup current stack for 'return' to Virtual-8086 mode
	pushl	$0x0000			# image for GS register
	pushl	$0x0000			# image for FS register
	pushl	$0x0000			# image for DS register
	pushl	$0x0000			# image for ES register
	pushl	$0x1000			# image for SS register
	pushl	$tos3			# image for SP register
	pushl	$0x00020002		# image for EFLAGS (VM=1)
	pushl	$0x1000			# image for CS register
	pushl	$turnblue 		# image for IP register
	iretl				# enter Virtual-8086 mode
#------------------------------------------------------------------
#------------------------------------------------------------------
turnblue: # this procedure will be executed in Virtual-8086 mode

	# change the color-attribute of every picture-element
	mov	$0xB800, %ax		# address video memory
	mov	%ax, %ds		#   with DS register
	mov	%ax, %es		#   also ES register
	xor	%si, %si		# point DS:SI to start
	xor	%di, %di		# point ES_DI to start
	cld				# use forward processing
	mov	$2000, %cx		# number of screen cells
nxpel:	lodsw				# fetch next char/attrib
	mov	$0x1F, %ah		# set new attribute byte
	stosw				# store that char/attrib
	loop	nxpel			# again for other cells

	# now try to execute a 'privileged' instruction
	hlt				# triggers VM86-mode exit
#------------------------------------------------------------------
isrGPF:	# restore the former stack-address for a return to 'main'
	lss	%cs:theTSS+4, %esp	# reload former SS:ESP
	ret				# back to main routine
#------------------------------------------------------------------
leave_protected_mode:

	mov	$sel_ds, %ax		# assure 64K r/w data
	mov	%ax, %ds		#  using DS register
	mov	%ax, %es		#   and ES register

	mov	%cr0, %eax		# get machine status
	btr	$0, %eax		# reset PE-bit to 0
	mov	%eax, %cr0		# disable protection

	ljmp	$0x1000, $rm		# reload CS register
rm:
	mov	%cs, %ax		
	mov	%ax, %ss		# reload SS register
	mov	%ax, %ds		# reload DS register
	mov	%ax, %es		# reload ES register

	lidt	regIVT			# reload IDTR register
	sti				# interrupts allowed

	ret				# back to main routine
#------------------------------------------------------------------
	.align	16			# insure stack alignment
	.space	512			# region for ring3 stack
tos3:					# label for the stacktop 
	.space	512			# region for ring0 stack
tos0:					# label for the stacktop
#------------------------------------------------------------------
	.end				# nothing else to assemble
