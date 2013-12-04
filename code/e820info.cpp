//-------------------------------------------------------------------
//	e820info.cpp
//
//	This application uses device-driver services provided by our
//	'newvmm64.c' Linux Kernel Module in order to invoke a series
//	of calls to 16-bit "real-mode" code in system firmware which 
//	reports our station's allocations of physical address-space. 
//
//	Further details in "Query System Address Map", Chapter 14 of
//	 "Advanced Configuration and Power Interface Specification",
//	 Revision 1.0b, Intel-Microsoft-Toshiba (1999), pp. 289-293. 
//
//	NOTE: Written and tested using x68_64 kernel version 2.6.26.
//
//	programmer: ALLAN CRUSE
//	written on: 28 JUL 2008
//-------------------------------------------------------------------

#include <stdio.h>		// for printf(), perror() 
#include <fcntl.h>		// for open() 
#include <stdlib.h>		// for exit() 
#include <sys/mman.h>		// for mmap()
#include <sys/ioctl.h>		// for ioctl()
#include <sys/utsname.h>	// for utsname()
#include "myvmx.h"		// for 'regs_ia32'

#define  TOS	0x0000FFE0	// stackbase address

typedef struct	{
		unsigned long long	base_address;
		unsigned long long	region_length;
		unsigned int		memory_type;
		} DESCRIPTOR;

regs_ia32	vm;
struct utsname 	uts;
DESCRIPTOR	*desc = (DESCRIPTOR*)(TOS + 8);

const char *leg[] = {   "                    ", 
			"AddressRangeMemory  ",		// Type 1
			"AddressRangeReserved",		// Type 2
			"AddressRangeACPI    ",		// Type 3
			"AddressRangeNVS     ",		// Type 4
			"AddressRangeUnusable",		// Type 5
			"AddressRangeNotKnown"	};	// Type 6

int int86( int fd, int id, regs_ia32 &vm )
{
	unsigned int	*eoi = (unsigned int*)TOS;	
	eoi[0] = 0x9090A20F;	// CPUID-instruction, NOP, NOP

	unsigned short	*tos = (unsigned short*)TOS;
	tos[-1] = (1<<9);	// IF-bit (in EFLAGS)
	tos[-2] = (TOS >> 4);	// real-mode CS-value
	tos[-3] = (TOS & 0xF);	// real-mode IP-value

	vm.eflags = 0x23200;	// VM=1, IOPL=3, IF=1	
	vm.eip = *(unsigned short*)( id*4 + 0);
	vm.cs  = *(unsigned short*)( id*4 + 2);
	vm.esp = TOS - 6;
	vm.ss  = 0x0000;

	return	ioctl( fd, sizeof( regs_ia32 ), &vm );	
}


int main( int argc, char **argv )
{
	int	fd = open( "/dev/vmm", O_RDWR );
	if ( fd < 0 ) { perror( "/dev/vmm" ); exit(1); }

	int	size = 0x110000; 	
	int	prot = PROT_READ | PROT_WRITE | PROT_EXEC;
	int	flag = MAP_FIXED | MAP_SHARED;
	if ( mmap( NULL, size, prot, flag, fd, 0 ) == MAP_FAILED )
		{ perror( "mmap" ); exit(1); }

	printf( "\n\n\n\n\n" );  
	printf( "   " );
	printf( "         " );
	printf( "           Physical Address-Space Map           \n" );
	printf( "\n" );
	printf( "         " );
	printf( "  BaseAddress       RangeLength       RangeType \n" );

	vm.ebx = 0;
	do	{
		vm.eax = 0x0000E820;		// service-ID
		vm.edx = *(int*)("PAMS");	// 'SMAP' 
		vm.ecx = sizeof( DESCRIPTOR );	// buffer-length
		vm.edi = (TOS+8) & 0xF;		// offset-address
		vm.es = ((TOS+8) >> 4);		// segment-address	

		int	retval = int86( fd, 0x15, vm );
		if ( retval < 0 ) { perror( "ioctl" ); exit(1); }

		printf( "\n " );
		printf( "         " );
		printf( " %016llX ", desc->base_address );
		printf( " %016llX ", desc->region_length );
		printf( " %s ", leg[ desc->memory_type & 7 ] );
		}
	while ( vm.ebx );
	printf( "\n\n" );

	uname( &uts );
	printf( "\n            " );
	printf( " %s-%s  %s ", uts.sysname, uts.machine, uts.release );
	printf( " on station \'%s\' \n\n\n\n\n", uts.nodename );
}
