//-----------------------------------------------------------------
//	cs686ipl.s
//
//	Here is a 'boot-loader' that you can use for launching our
//	CS 686 programming demos and exercises during Spring 2007.
//
//	  to assemble: $ as cs686ipl.s -o cs686ipl.o
//	  and to link: $ ld cs686ipl.o -T ldscript -o cs686ipl.b 
//	  and install: $ dd if=cs686ipl.b of=/dev/sda4
//
//	NOTE: This code begins executing with CS:IP = 0000:7C00.
//
//	programmer: ALLAN CRUSE
//	written on: 02 FEB 2007
//	revised on: 09 MAR 2007 -- save partition's LBA at 0x004F0
//	revised on: 22 MAR 2007 -- to give 4GB limits to FS and GS 
//-----------------------------------------------------------------

	.code16				# for x86 'real-mode'
	.section	.text
#------------------------------------------------------------------
start:	ljmp	$0x07C0, $main		# renormalize CS and IP
#------------------------------------------------------------------
# Our initial Device Address Packet for EDD ROM-BIOS Function 0x42
packet:	.byte	16, 0, 1, 0		# read one 512-byte sector
	.word	0x7E00, 0x0000		# where to put disk-sector
	.quad	0			# where to get disk-sector
#------------------------------------------------------------------
relLBA:	.long	0			# current disk start-block
#------------------------------------------------------------------
msg0:	.ascii	"Hit any key to reboot system\n\r"  # message-text
len0:	.short	. - msg0		# length of message-string
msg1:	.ascii	"Unable to read from disk\n\r"	    # message-text
len1:	.short	. - msg1		# length of message-string
msg2:	.ascii	"Disk program is invalid\n\r"	    # message-text
len2:	.short	. - msg2		# length of message-string
msg3:	.ascii	"Linux partitions not found\n\r"    # message-text
len3:	.short	. - msg3		# length of message-string
#------------------------------------------------------------------
main:	# initialize our stack-pointer for servicing interrupts
	xor	%ax, %ax		# address lowest arena
	mov	%ax, %ss		#   with SS register
	mov	$0x7C00, %sp		# stack is beneath code
	sti				# now permit interrupts  

	# setup segment-registers to address our program-data
	mov	%cs, %ax		# address program data
	mov	%ax, %ds		#   with DS register

	# read boot-record from hard-disk into region at 0x7E00 
again:	movw	$0, %ss:0x7FFE		# boot-signature field
	lea	packet, %si		# point DS:SI to packet
	mov	$0x80, %dl		# hard-disk selection 
	mov	$0x42, %ah		# EDD_Read_Sectors
	int	$0x13			# request BIOS service
	jc	rderr			# error? exit w/message 

	# check the boot-record for a valid boot-signature
	cmpw	$0xAA55, %ss:0x7FFE	# boot-signature there?
	jne	inval			# no, exit w/message

	# search the partition-table entries backward
	mov	$1022, %bx		# point DS:BX to signature
	mov	$4, %cx			# number of table entries
nxpte:	sub	$16, %bx		# point to the next entry
	cmpb	$0x05, 4(%bx)		# Extended Partition type?
	je	isext			# yes, need another access
	cmpb	$0x83, 4(%bx)		# Linux Partition type?
	je	found			# Linux Partition found
	loopne	nxpte			# else check next entry
	jmp	nopte			# else exit w/message 	
isext:	# DS:BX points to 'extended' partition table-entry
	# Algoritm:
	#    if this is a 'primary' extended partition, then
	#    change our logical disk's relative starting LBA
	mov	8(%bx), %eax		# get partition base
	add	relLBA, %eax		# add relative start
	cmpl	$0, relLBA		# primary ext-partn?
	jne	inner			# no, retain relLBA
	mov	%eax, relLBA		# else modify relLBA
inner:	mov	%eax, packet+8		# set as packet source
	jmp	again			# get next boot-sector
#------------------------------------------------------------------
rderr:	lea	msg1, %bp		# message-offset in BP
	mov	len1, %cx		# message-length in CX
	jmp	showmsg			# display that message
#------------------------------------------------------------------
inval:	lea	msg2, %bp		# message-offset in BP
	mov	len2, %cx		# message-length in CX
	jmp	showmsg			# display that message
#------------------------------------------------------------------
nopte:	lea	msg3, %bp		# message-offset in BP
	mov	len3, %cx		# message-length in CX
	jmp	showmsg			# display that message
#------------------------------------------------------------------
found:	# DS:BX = table-entry for disk's final linux-partition
	# Algorithm:
	#    adjust packet for reading multiple records
	mov	8(%bx), %eax		# partition starting-LBA
	inc	%eax			# skip past boot-record
	add	%eax, packet+8		# plus disk's start-LBA
	movb	$127, packet+2		# read 127 disk-sectors
	movw	$0x0000, packet+4	# load-address offset
	movw	$0x1000, packet+6	# load-address segment

	# read the CS686 program-blocks into region at 0x10000 
	lea	packet, %si		# point DS:SI to packet
	mov	$0x80, %dl		# read first hard-disk 
	mov	$0x42, %ah		# EDD Read_Sectors
	int	$0x13			# request BIOS service
	jc	rderr

	# check for our application signature
	les	packet+4, %di		# point ES:DI to arena
	cmpw	$0xABCD, %es:(%di)	# our signature there?
	jne	inval			# no, format not valid

	# else perform a direct far call to our application
	mov 	packet+8, %ebx		# pass partition's LBA
	dec 	%ebx			# as parameter in EBX
	mov 	%ebx, %ss:0x04F0	# and as ROM-BIOS data
	lcall	$0x1000, $0x0002	# with call to program

	# accommodate 'quirk' in some ROM-BIOS service-functions
	mov	%cs, %ax		# address our variables
	mov	%ax, %ds		#   using DS register
	lgdt	regGDT			# setup register GDTR
	cli				# turn off interrupts
	mov	%cr0, %eax		# get machine status
	bts	$0, %eax		# set image of PE-bit
	mov	%eax, %cr0		# enter protected-mode
	mov	$8, %dx			# descriptor's selector  
	mov	%dx, %fs		# for 4GB segment-limit
	mov	%dx, %gs		# both in FS and in GS
	btr	$0, %eax		# reset image of PE-bit
	mov	%eax, %cr0		# leave protected-mode
	sti				# interrupts on again

	# show the user our 'reboot' message
	lea	msg0, %bp		# message-offset in BP
	mov	len0, %cx		# message-length in CX
showmsg: 
	# use ROM-BIOS services to write a message to the screen 
	push	%cx			# preserve string-length
	mov	$0x0F, %ah		# get page-number in BH
	int	$0x10			# request BIOS service
	mov	$0x03, %ah		# get cursor locn in DX
	int	$0x10			# request BIOS service
	pop	%cx			# recover string-length
	mov	%ds, %ax		# address our variables
	mov	%ax, %es		#   using ES register
	mov	$0x0F, %bl		# put text colors in BL
	mov	$0x1301, %ax		# write_string function
	int	$0x10			# request BIOS service

	# await our user's keypress
	xor	%ah, %ah		# await keyboard input
	int	$0x16			# request BIOS service

	# invoke the ROM-BIOS reboot service
	int	$0x19			# reboot this workstation
#------------------------------------------------------------------
theGDT:	.quad	0, 0x008F92000000FFFF	# has 4GB data-descriptor 
regGDT:	.word	15, theGDT + 0x7C00, 0	# image for register GDTR
#------------------------------------------------------------------
	.ascii	" cs686ipl 03/22/2007 "	# helps when file-viewing
#------------------------------------------------------------------
	.org	510			# offset of boot-signature
	.byte	0x55, 0xAA		# value for boot-signature
#------------------------------------------------------------------
	.end				# nothing more to assemble
