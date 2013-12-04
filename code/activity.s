//-----------------------------------------------------------------
//	activity.s
//
//	This program provides a dynamic display of the interrupts
//	that are occurring at boot-time (before the BSP processor 
//	has been switched from real-mode to protected-mode or has
//	awakened any other processors that might be programmed to
//	aid in executing some of the Interrupt Service Routines).  
//	The scheme used here is to create an alternative table of
//	interrupt-vectors pointing into an array of stub-routines 
//	which will increment counters corresponding to interrupts
//	that have occurred, but then transfer to the usual ISR to
//	finish handling a particular interrupt in the normal way;  
//	meanwhile, a program-loop located in the 'main' procedure
//	continuously displays the values of these counters, until
//	the user hits the <ESCAPE>-key to terminate this program. 	
//
//	   assemble: $ as activity.s -o activity.o
//	   and link: $ ld activity.o -T ldscript -o activity.b
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 30 NOV 2006
//-----------------------------------------------------------------

	#---------------------------------------------------
	# This macro will generate the 256 new ISR 'stubs'.
	# Due to a unwanted 'optimization' by our assembler
	# of the 'push immediate' instruction for values of
	# the operand in the range 0-127, we had to replace
	# the assembly language mnemonic by machine-code in
	# order to assure uniform stub-length in all cases.
	#---------------------------------------------------
	.macro	isr id
	pushf				# push FLAGS value
	.byte	0x68			# opcode for pushw	
	.word	\id			# interrupt-number 
	call	action			# call common code 
	.endm

	.code16				# for Pentium 'real-mode'

	.section	.text
#------------------------------------------------------------------
	.word	0xABCD			# programming signature
#------------------------------------------------------------------
main:	mov	%sp, %cs:exit_pointer+0	
	mov	%ss, %cs:exit_pointer+2

	mov	%cs, %ax		# address our variables
	mov	%ax, %ds		#   with DS register
	mov	%ax, %es		#   also ES register
	mov	%ax, %ss		#   also SS register
	lea	tos, %sp		# and setup a new stack

	call	erase_video_console	# clean up the screen
	call	draw_display_legend	# show title for info
	call	hide_console_cursor	# stop showing cursor  
	lidt	newIVT			# switch to new table

again:	call	format_the_counters	# format count-values
	call	redraw_the_grid		# update video screen
	call	await_user_keypress	# check for <ESC>-key
	cmpb	$0, done		# user wants to quit? 
	je	again			# no, continue update

	lidt	oldIVT			# switch to old table
	call	show_console_cursor	# make cursor visible

	lss	%cs:exit_pointer, %sp
	lret
#------------------------------------------------------------------
exit_pointer:	.word	0, 0
#------------------------------------------------------------------
action:	# the common portion of our interrupt-interception code
	enter	$0, $0			# setup stackframe access
	pusha				# preserve CPU registers
	pushw	%ds			# including register DS 

	# increment the counter for this interrupt-number 
	mov	%cs, %ax		# address program data
	mov	%ax, %ds		#   with DS register
	mov	4(%bp), %ax		# get vector ID-number
	imul	$2, %ax, %di		# counter's array-offset
	incw	count(%di)		# increment the counter

	# setup the stack for a transfer to the old handler
	xor	%ax, %ax		# address vector-table
	mov	%ax, %ds		#   with DS register
	mov	4(%bp), %ax		# get vector ID-number
	imul	$4, %ax, %si		# vector's array-offset 
	mov	0(%si), %ax		# fetch vector loword
	mov	%ax, 2(%bp)		# store vector loword
	mov	2(%si), %ax		# fetch vector hiword
	mov	%ax, 4(%bp)		# store vector hiword

	popw	%ds			# recover the registers
	popa
	leave				# discard frame-pointer
	iret				# transfer to 'old' ISR
#------------------------------------------------------------------
# Here are the 'stub' routines that will intercept any interrupts
	.align	16
myISRs:	id = 0
	.rept	256
	isr	id
	id = 1 + id
	.endr
	.equ	ISRSIZ, (. - myISRs)/256
#------------------------------------------------------------------
# Here is our new vector-table for intercepting interrupt-handlers
	.align	16
ourIVT:	off = myISRs
	.rept	256
	.word	off, 0x1000
	off = off + ISRSIZ
	.endr
#------------------------------------------------------------------
newIVT:	.word	0x03FF, ourIVT, 0x0001	# image for register IDTR 
oldIVT:	.word	0x03FF, 0x0000, 0x0000	# image for register IDTR
#------------------------------------------------------------------
msg0:	.ascii	"INTERRUPT ACTIVITY MONITOR"
len0:	.short	. - msg0
loc0:	.byte	27, 2 
#------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"
count:	.zero	256*2
place:	.zero	256*2
radix:	.int	16
row:	.int	0
col:	.int	0
done:	.byte	0
cursor:	.word	0
#------------------------------------------------------------------
erase_video_console:

	# clear the screen
	mov	$0x0003, %ax		# standard 80x25 text
	int	$0x10			# invoke BIOS service
	ret
#------------------------------------------------------------------
draw_display_legend:

	# use ROM-BIOS write-string function to draw the title
	lea	msg0, %bp		# point ES:BP to string
	mov	len0, %cx		# setup length in CX
	mov	loc0, %dx		# setup DH=row, DL=col
	mov	$0x0007, %bx		# setup BH=page, BL=color
	mov	$0x1300, %ax		# specify write_string
	int	$0x10			# invoke BIOS service

	ret
#------------------------------------------------------------------
hide_console_cursor:

	# save the cursor-type
	mov	$0x03, %ah		# return_cursor_type
	xor	%bh, %bh		# for display-page 0
	int	$0x10			# request BIOS service
	mov	%cx, cursor		# save cursor type
	
	# hide the cursor
	mov	$0x01, %ah		# set cursor type
	xor	%bh, %bh		# for display-page 0
	mov	cursor, %cx		# get cursor's type
	or	$0x20, %ch		# disable cursor visibility
	int	$0x10

	ret
#------------------------------------------------------------------
show_console_cursor:

	mov	$0x02, %ah		# set_cursor_location
	xor	%bh, %bh		# for display-page 0
	mov	$0x1700, %dx		# row=23, column=0
	int	$0x10			# request BIOS service

	mov	$0x01, %ah		# set_cursor_type
	mov	cursor, %cx		# restore the original 
	int	$0x10			# request BIOS service

	ret
#------------------------------------------------------------------
await_user_keypress: 

	mov	$0x01, %ah		# peek in keyboard queue
	int	$0x16			# request BIOS service
	jz	waitx			# queue empty? return
	
	mov	$0x00, %ah		# pull data from queue
	int	$0x16			# request BIOS service

	cmp	$0x1B, %al		# was it <ESCAPE>-key?
	jne	waitx			# no, then disregard
	orb	$0x01, done		# else set 'done' flag
waitx:
	ret
#------------------------------------------------------------------
ax2num:	# expresses AX as a three-digit decimal-string at DS:DI
	pusha

	mov	$10, %bx		# decimal-system base
	mov	$3, %cx			# show only 3 digits
	add	%cx, %di		# point past 3 places
nxdiv:	xor	%dx, %dx		# extend AX to 32-bits
	div	%bx			# divide by number-base
	add	$'0', %dl		# remainder to numeral
	dec	%di			# back up the pointer
	mov	%dl, (%di)		# and write the digit
	loop	nxdiv			# do remaining digits
	
	popa
	ret
#------------------------------------------------------------------
grid:	.ascii	"    "
	.ascii	"  0   1   2   3   4   5   6   7 "
	.ascii	"  8   9   A   B   C   D   E   F "
	
	.ascii	"00: "
	.ascii	"--- --- --- --- --- --- --- --- "
	.ascii	"--- --- --- --- --- --- --- --- "

	.ascii	"10: "
	.ascii	"--- --- --- --- --- --- --- --- "
	.ascii	"--- --- --- --- --- --- --- --- "

	.ascii	"20: "
	.ascii	"--- --- --- --- --- --- --- --- "
	.ascii	"--- --- --- --- --- --- --- --- "

	.ascii	"30: "
	.ascii	"--- --- --- --- --- --- --- --- "
	.ascii	"--- --- --- --- --- --- --- --- "

	.ascii	"40: "
	.ascii	"--- --- --- --- --- --- --- --- "
	.ascii	"--- --- --- --- --- --- --- --- "

	.ascii	"50: "
	.ascii	"--- --- --- --- --- --- --- --- "
	.ascii	"--- --- --- --- --- --- --- --- "

	.ascii	"60: "
	.ascii	"--- --- --- --- --- --- --- --- "
	.ascii	"--- --- --- --- --- --- --- --- "

	.ascii	"70: "
	.ascii	"--- --- --- --- --- --- --- --- "
	.ascii	"--- --- --- --- --- --- --- --- "

	.ascii	"80: "
	.ascii	"--- --- --- --- --- --- --- --- "
	.ascii	"--- --- --- --- --- --- --- --- "

	.ascii	"90: "
	.ascii	"--- --- --- --- --- --- --- --- "
	.ascii	"--- --- --- --- --- --- --- --- "

	.ascii	"A0: "
	.ascii	"--- --- --- --- --- --- --- --- "
	.ascii	"--- --- --- --- --- --- --- --- "

	.ascii	"B0: "
	.ascii	"--- --- --- --- --- --- --- --- "
	.ascii	"--- --- --- --- --- --- --- --- "

	.ascii	"C0: "
	.ascii	"--- --- --- --- --- --- --- --- "
	.ascii	"--- --- --- --- --- --- --- --- "

	.ascii	"D0: "
	.ascii	"--- --- --- --- --- --- --- --- "
	.ascii	"--- --- --- --- --- --- --- --- "

	.ascii	"E0: "
	.ascii	"--- --- --- --- --- --- --- --- "
	.ascii	"--- --- --- --- --- --- --- --- "

	.ascii	"F0: "
	.ascii	"--- --- --- --- --- --- --- --- "
	.ascii	"--- --- --- --- --- --- --- --- "

#------------------------------------------------------------------
redraw_the_grid:
	
	# for each row-number from 0 through 16 
	# we draw the 68 characters (=4*17) from our grid-array
	# row is indented by 6 places
	# column is indented by 5 places 	

	xor	%si, %si		# initial row-number
nxline:
	# compute this row's grid-offset in register BP
	imul	$68, %si, %bp		# ES:BP = string-address
	lea	grid(%bp), %bp	
	# compute the screen-location (row,col) in (DH,DL)
	mov	%si, %dx		# row-number into DX
	add	$5, %dx			# skip topmost 5 rows 
	shl	$8, %dx			# row-number into DH
	mov	$6, %dl			# and indent 6 columns
	# setup other parameters for BIOS write_string function
	mov	$68, %cx		# CX = length (68=4*17)
	mov	$0x0007, %bx		# BH=page, BL=attribute
	# invoke ROM-BIOS write_string service to draw grid-row
	mov	$0x1300, %ax		# write_string function
	int	$0x10			# invoke BIOS service
	inc	%si			# increment row-number
	cmp	$17, %si		# more rows to show?
	jb	nxline			# yes, show next row

	ret
#------------------------------------------------------------------
format_the_counters:

	# we format the nonzero count-values as decimal-strings
	xor	%esi, %esi		# initial interrupt-ID
nxfmt:	
	# see if the count is nonzero
	cmpw	$0, count(, %esi, 2)	# count-entry equals zero?
	jz	fmtok			# yes, then retain dashes

	# locate the grid-position
	mov	%esi, %eax		# array-index into EAX
	xor	%edx, %edx		# extended to quadword 
	mov	$16, %ecx		# setup divisor in ECX
	div	%ecx			# perform the division
	inc	%eax			# increment row-number
	inc	%edx			# increment col-number
	imul	$68, %eax, %edi		# row-number times 68
	imul	$4, %edx		# col-number times 4
	add	%edx, %edi		# add row to column
	lea	grid(%edi), %edi	# EDI = grid-position

	mov	count(, %esi, 2), %ax	# load counter into AX
	call	ax2num			# format as digit-string 
fmtok:
	incl	%esi			# advance interrupt-ID
	cmp	$256, %esi		# more entries to do?
	jb	nxfmt			# yes, do the next one

	ret
#------------------------------------------------------------------
	.align	16
	.space	256
tos:
#------------------------------------------------------------------
	.end	
