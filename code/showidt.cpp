//-------------------------------------------------------------------
//	showidt.cpp
//
//	programmer: ALLAN CRUSE
//	written on: 18 MAR 2006
//	revised on: 15 DEC 2006 -- for virtual-to-physical translate
//-------------------------------------------------------------------

#include <stdio.h>	// for printf(), perror() 
#include <fcntl.h>	// for open() 
#include <stdlib.h>	// for exit() 
#include <unistd.h>	// for read(), write(), close() 

//#define START_KERNEL_map 0xFFFFFFFF80000000
#define VIRT_2_PHYS_mask 0x000000007FFFFFFF

char devname[] = "/dev/dram";
unsigned short 	idtr[5];
unsigned long	idt_virt_address, idt_phys_address;

int main( int argc, char **argv )
{
	asm(" sidtq idtr ");
	printf( "\n                IDTR=" );
	for (int i = 0; i < 5; i++) printf( "%04X", idtr[ 4-i ] );
	printf( "\n" );



	idt_virt_address = *(unsigned long*)(idtr+1);
	//idt_phys_address = idt_virt_address - START_KERNEL_map;
	idt_phys_address = idt_virt_address & VIRT_2_PHYS_mask;

	printf( "\n" );
	printf( "    idt_virt_address=%016lX ", idt_virt_address );
	printf( "    idt_phys_address=%016lX ", idt_phys_address );
	printf( "\n" );

	int	n_elts = (1 + idtr[0])/16;

	int	fd = open( devname, O_RDONLY );
	if ( fd < 0 ) { perror( devname ); exit(1); }

	lseek( fd, idt_phys_address, SEEK_SET );

	for (int i = 0; i < n_elts; i++)
		{
		if ( ( i % 2 ) == 0 ) printf( "\n" );
		unsigned long	desc[2];
		read( fd, &desc, sizeof( desc ) );
		printf( " %02X: %016lX%016lX ", i, desc[1], desc[0] );
		}
	printf( "\n\n" );
}
