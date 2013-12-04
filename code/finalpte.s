//-----------------------------------------------------------------
//	finalpte.s
//
//	This program shows how to read the hard-disk's boot-sector
//	and displays the final valid entry in its Partition Table.
//
//	 assemble with: $ as finalpte.s -o finalpte.o
//	 and link with: $ ld finalpte.o -T ldscript -o finalpte.b
//
//	NOTE: This program begins execution with CS:IP = 0000:7C00
//
//	programmer: ALLAN CRUSE
//	written on: 05 SEP 2006
//-----------------------------------------------------------------

	.equ	seg_boot, 0x07C0  	# the BOOT_LOCN's segment

	.code16				# for Pentium 'real-mode'

	.section	.text
#------------------------------------------------------------------
start:	ljmp	$seg_boot, $main	# re-normalizes CS and IP
#------------------------------------------------------------------
packet:	.byte	16, 0, 1, 0		# packet-size and sectors
	.word	0x0200, seg_boot	# transfer-area's address
	.quad	0			# logical block's address
#------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"	# array of the hex digits
msg:	.ascii	"\n\r  Final Partition-Table Entry: "
buf:	.ascii	"xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx \n\r"
len:	.word	. - msg			# length of message-string
hue:	.byte	0x0E			# colors: yellow-on-black
#------------------------------------------------------------------
main:	# setup segment-registers
	mov	$seg_boot, %ax		# address our variables
	mov	%ax, %ds		#   with DS register
	mov	%ax, %es		#   also ES register

	# read the Hard Disk's Master Boot Record
	lea	packet, %si		# point DS:SI to packet
	mov	$0x80, %dl		# setup Drive-ID in DL
	mov	$0x42, %ah		# setup EDD_READ in AH
	int	$0x13			# invoke BIOS service
	jc	over			# failure? skip search

	# search Partition-Table backwards for last valid entry	
	mov	$0x03FE, %si		# point to signature
	cmpw	$0xAA55, (%si)		# confirm signature
	jne	over			# absence? no search

	mov	$4, %cx			# number of entries
nxpte:	sub	$16, %si		# back up to entry
	cmp	$0x00, 4(%si)		# has partition-type?
	loope	nxpte			# no, check next entry
	jcxz	over			# none found? finish

	# format our message with the Table-Entry's data
	lea	buf, %di		# point to message-field
	mov	$4, %cx			# count of longwords
nxlwd:	
	mov	(%si), %eax		# fetch next longword
	call	eax2hex			# convert to hexadecimal

	add	$4, %si			# advance source pointer
	add	$9, %di			# advance dest'n pointer
	loop	nxlwd			# do remaining longwords

over:	# display message showing table-entry's contents
	mov	$0x0F, %ah		# get_display_status
	int	$0x10			# request BIOS service
	mov	$0x03, %ah		# get_cursor_location
	int	$0x10			# request BIOS service
	lea	msg, %bp		# point ES:BP to string
	mov	len, %cx		# setup character-count
	mov	hue, %bl		# setup color attribute
	mov	$0x1301, %ax		# write_string function
	int	$0x10			# request BIOS service

	# await keypress
	mov	$0x00, %ah		# get_keyboard_input
	int	$0x16			# request BIOS service

	# reboot workstation
	int	$0x19			# request BIOS service
#------------------------------------------------------------------
eax2hex: # converts value in EAX to hexadecimal-string at DS:DI
	pusha				
	mov	$8, %cx			# number of hex digits
nxnyb:	
	rol	$4, %eax		# next nybble into AL
	mov	%al, %bl		# copy nybble into BL
	and	$0x0F, %bx		# isolate nybble bits
	mov	hex(%bx), %dl		# lookup hex numeral
	mov	%dl, (%di)		# store the numeral  
	inc	%di			# advance buf index
	loop	nxnyb			# do remaining nybbles
	popa
	ret
#------------------------------------------------------------------
	.org	510			# location for signature
	.byte	0x55, 0xAA		# boot-signature's value
#------------------------------------------------------------------
	.end				# nothing more to assemble
