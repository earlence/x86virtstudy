//-------------------------------------------------------------------
//	tryvideo.cpp
//
//	This demo-program constitutes our "proof-of-concept", that
//	indeed we can execute the real-mode Video BIOS routines to
//	set a graphical display mode within an x86_64 Linux kernel
//	by utilizing an Intel processor's new VMX instruction-set.
//	(Our 'vram.c' device-driver is required for memory-mapping
//	the graphical frame-buffer into the user's address-space.)
//
//	This program relies on services of our 'nmiexits.c' kernel
//	module to execute a 'real-mode' procedure inside a virtual 
//	machine that is running in Virtual-8086 emulation mode (as
//	a guest-process managed by a Linux x86_64 host-process).
//
//		to compile:  $ g++ tryvideo.cpp -o tryvideo
//		to prepare:  $ /sbin/insmod nmiexits.ko
//		to prepare:  $ /sbin/insmod vram.ko
//		to execute:  $ ./tryvideo
//		to restore:  $ /sbin/rmmod nmiexits
//
//	programmer: ALLAN CRUSE
//	written on: 25 MAY 2007
//-------------------------------------------------------------------

#include <stdio.h>	// for printf(), perror() 
#include <fcntl.h>	// for open() 
#include <stdlib.h>	// for exit() 
#include <unistd.h>	// for read(), write(), close()
#include <string.h>	// for memcpy()
#include <sys/mman.h>	// for mmap()
#include <sys/ioctl.h>	// for ioctl()
#include "myvmx.h"	// for 'regs_ia32' 

#define	VRAM_BASE	0xA0000000
#define VESA_MODE	0x4105
#define TEXT_MODE	0x0003

regs_ia32	vm;
char devname[] = "/dev/vmm";
const int  hres = 1024, vres = 768;
unsigned char	*vram = (unsigned char*)VRAM_BASE;

int main( int argc, char **argv )
{
	// open our graphics-memory device-file
	int	fb = open( "/dev/vram", O_RDWR );
	if ( fb < 0 ) { perror( "/dev/vram" ); exit(1); }

	// open the virtual-machine device-file
	int	fd = open( devname, O_RDWR );
	if ( fd < 0 ) { perror( devname ); exit(1); }

	// map in the legacy 8086 memory-area
	int	size = 0x110000;
	int	prot = PROT_READ | PROT_WRITE;
	int	flag = MAP_FIXED | MAP_SHARED;
	if ( mmap( (void*)0, size, prot, flag, fd, 0 ) == MAP_FAILED )
		{ perror( "mmap" ); exit(1); }

	// map in the graphical frame-buffer
	size = lseek( fb, 0, SEEK_END );
	if ( mmap( (void*)vram, size, prot, flag, fb, 0 ) == MAP_FAILED )
		{ perror( "mmap" ); exit(1); }
	
	// fetch the vector for the desired interrupt
	unsigned int	interrupt_number = 0x10;
	unsigned int	vector = *(unsigned int*)( interrupt_number << 2 );

	// plant the 'return' stack and code
	unsigned short	*tos = (unsigned short*)0x8000;
	unsigned int	*eoi = (unsigned int*)0x8000;

	// transition to our Virtual Machine Monifor
	eoi[ 0 ] = 0x90C1010F;	// 'vmcall' instruction

	tos[ -1 ] = 0x0000;	// image of FLAGS
	tos[ -2 ] = 0x0000;	// image of CS
	tos[ -3 ] = 0x8000;	// image of IP

	// initialize the virtual-machine registers
	vm.eflags = 0x00023000;
	vm.eip    = vector & 0xFFFF;
	vm.cs	  = (vector >> 16);
	vm.esp	  = 0x7FFA;
	vm.ss	  = 0x0000;
	vm.eax	= 0x00004F02;	// VESA SetMode
	vm.ebx	= VESA_MODE;	// 800x600 8-bpp

	// invoke the virtual-machine
	int	retval = ioctl( fd, sizeof( vm ), &vm );

	// draw a yellow screen-border 
	int	x = 0, y = 0, color = 14;
	do { vram[ y*hres + x ] = color; ++x; } while ( x < hres-1 );
	do { vram[ y*hres + x ] = color; ++y; } while ( y < vres-1 );
	do { vram[ y*hres + x ] = color; --x; } while ( x > 0 );
	do { vram[ y*hres + x ] = color; --y; } while ( y > 0 );

	// await user-keypress
	getchar();

	// reinitialize the virtual-machine registers
	vm.eflags = 0x00023000;
	vm.eip    = vector & 0xFFFF;
	vm.cs	  = (vector >> 16);
	vm.esp	  = 0x7FFA;
	vm.ss	  = 0x0000;
	vm.eax	= 0x00004F02;	// VESA SetMode
	vm.ebx	= TEXT_MODE;	// 80x25 text

	eoi[ 0 ] = 0x90C1010F;	// 'vmcall' instruction
	tos[ -1 ] = 0x0000;	// image of FLAGS
	tos[ -2 ] = 0x0000;	// image of CS
	tos[ -3 ] = 0x8000;	// image of IP

	// invoke the virtual-machine
	retval = ioctl( fd, sizeof( vm ), &vm );
	printf( "\n\n" );
}

