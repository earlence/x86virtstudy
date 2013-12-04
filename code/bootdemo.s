//-----------------------------------------------------------------
//	bootdemo.s
//
//	This program will be installed in the boot-sector of our
//	classroom's unused disk-partition, known as '/dev/sda4'.
//	Then, when you restart your computer, the GRUB menu will
//	allow you the option to 'boot' from that disk-partition.
//	This program will simply display a message, wait for any
//	key to be pressed, and then it will reboot your machine. 
//
//			        REQUIREMENTS
//
//	Your executable program-file must be small enough to fit 
//	within a single disk-sector (i.e., only 512 bytes); also
//	its final two bytes must be the values 0x55, 0xAA (known
//	as the 'boot-signature'); and finally your code and data
//	must be designed to reside at memory-address 0x7C00, and
//	begin executing in 'real-mode' with CS:IP = 0000:7C00.
//
//	 to assemble: $ as bootdemo.s -o bootdemo.o
//	 and to link: $ ld bootdemo.o -T ldscript -o bootdemo.b
//	 and install: $ dd if=bootdemo.b of=/dev/sda4
//
//	Note that a special 'linker script' is required here for
//	'ld' to produce an executable file with 'binary' format.
//
//	programmer: ALLAN CRUSE
//	written on: 08 FEB 2007
//-----------------------------------------------------------------

	.code16				# for x86 'real-mode'

	.section	.text
#------------------------------------------------------------------
	ljmp	$0x07C0, $main		# renormalize CS and IP
#------------------------------------------------------------------
msg:	.ascii	"\r\n Computer Science 686 \r\n\n"	
len:	.word	. - msg			# length of the message
att:	.byte	0x05			# magenta against black
#------------------------------------------------------------------
main:	# establish a 'safe' stack-address

	xor	%ax, %ax		# address segment zero
	mov	%ax, %ss		#   with SS register
	mov	$0x7C00, %sp		# stack-top below code

	# setup registers DS and ES to address our program's data

	mov	%cs, %ax		# address program data
	mov	%ax, %ds		#   with DS register
	mov	%ax, %es		#   also ES register

	# now use some ROM-BIOS video services to print a message

	mov	$0x0F, %ah		# get video page in BH
	int	$0x10			# request BIOS service

	mov	$0x03, %ah		# cursor row,col in DH,DL
	int	$0x10			# request BIOS service

	lea	msg, %bp		# point ES:BP to string
	mov	len, %cx		# string's length in CX
	mov	att, %bl		# text-attributes in BL
	mov	$0x01, %al		# how to treat cursor  
	mov	$0x13, %ah		# write_string function
	int	$0x10			# request BIOS service

	# now use BIOS keyboard-service to wait for a keypress

	mov	$0, %ah			# get_keyboard_input
	int	$0x16			# request BIOS service

	# finally use BIOS service to reboot the computer

	int	$0x19			# request BIOS service
#------------------------------------------------------------------
	.org	510			# boot-signature's offset
	.byte	0x55, 0xAA		# boot-signature's values
#------------------------------------------------------------------
	.end				# nothing else to assemble

