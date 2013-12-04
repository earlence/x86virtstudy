//-------------------------------------------------------------------
//	showgdt.cpp
//
//	programmer: ALLAN CRUSE
//	written on: 18 MAR 2006
//	correction: 15 DEC 2006 -- for virtual-to-physical translate
//-------------------------------------------------------------------

#include <stdio.h>	// for printf(), perror() 
#include <fcntl.h>	// for open() 
#include <stdlib.h>	// for exit() 
#include <unistd.h>	// for read(), write(), close() 

//#define START_KERNEL_map 0xFFFFFFFF80000000
#define VIRT_2_PHYS_mask 0x000000007FFFFFFF

char devname[] = "/dev/dram";
unsigned short 	gdtr[5];
unsigned long	gdt_virt_address, gdt_phys_address;

int main( int argc, char **argv )
{
	asm(" sgdtq gdtr ");
	
	printf( "\n                   GDTR=" );
	for (int i = 0; i < 5; i++) printf( "%04X", gdtr[4-i] );
	printf( "\n" );

	gdt_virt_address = *(unsigned long*)(gdtr+1);
	//gdt_phys_address = gdt_virt_address - START_KERNEL_map;
	gdt_phys_address = gdt_virt_address & VIRT_2_PHYS_mask;

	printf( "\n       " );
	printf( "gdt_virt_address=%016lX ", gdt_virt_address );
	printf( "gdt_phys_address=%016lX ", gdt_phys_address );
	printf( "\n" );

	int	n_elts = (1 + gdtr[0])/8;

	int	fd = open( devname, O_RDONLY );
	if ( fd < 0 ) { perror( devname ); exit(1); }

	lseek( fd, gdt_phys_address, SEEK_SET );

	for (int i = 0; i < n_elts; i++)
		{
		if ( ( i % 4 ) == 0 ) printf( "\n %04X: ", i*8 );
		unsigned long	desc;
		read( fd, &desc, sizeof( desc ) );
		printf( "%016lX ", desc );
		}
	printf( "\n\n" );

}
