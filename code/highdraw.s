//-----------------------------------------------------------------
//	highdraw.s
//
//	This procedure was designed to be entered through a 64-bit 
//	call-gate, using a 'long call' instruction in IA-32e mode,
//	and hence it employs a 'long return' instruction for exit.
//	Its memory-addresses need to be 'relocated' during linking
//	by using a 'linker script' that is designed for conformity
//	with page-mapping tables which will be in use at run-time.
//
//	  to assemble: $ as highdraw.s -o highdraw.o
//	  and to link: $ ld highdraw.o -T hiscript -o highdraw.b
//	  and install: $ dd if=higdraw.b of=/dev/sda4 seek=128
//	
//	NOTE: We assume the 'highcode.b' program-loader will have
//	been installed on our disk-partition beginning at logical
//	block address 1 (immediately following our 'cs686ipl.b').
//
//	programmer: ALLAN CRUSE
//	written on: 09 MAR 2007
//-----------------------------------------------------------------

	.code64
	.section	.text
	.short	0xABCD

	mov	$12, %rax
	imul	$160, %rax, %rdi
	add	$20, %edi
	add	$0xB8000, %rdi

	cld
	lea	msg, %rsi
	mov	len, %rcx
	mov	att, %ah
nxch:	
	lodsb
	stosw
	loop	nxch	

	lretq

msg:	.ascii	" Executing 64-bit code at virtual-address"
	.ascii	" 0xFFFFFFFFC0000000 "
len:	.quad	. - msg
att:	.byte	0x4f 

	.end

