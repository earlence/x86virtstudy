//-------------------------------------------------------------------
//	cpuid.cpp
//
//	This program employs inline assembly language to execute the
//	processor's 'cpuid' instruction and displays the processor's
//	vendor identification and features information, and also its 
//	brand string if indeed that capability has been implemented.  
//
//		compile-and-link:  $ g++ cpuid.cpp -o cpuid
//
//	programmer: ALLAN CRUSE
//	written on: 04 FEB 2007
//-------------------------------------------------------------------

#include <stdio.h>	// for printf()
#include <unistd.h>	// for gethostname()  
#include <string.h>	// for strncpy()

int main( int argc, char **argv )
{
	char	ident[65] = {0};
	char	oemid[13] = {0};
	char	hostname[ 65 ];
	int	i, j, k, n = 0;

	gethostname( hostname, sizeof( hostname ) );
	printf( "\nstation \'%s\' \n", hostname );

	for (i = 0; i <= n; i++)
		{
		int	reg_eax, reg_ebx, reg_ecx, reg_edx;
		asm(" movl %0, %%eax " :: "m" (i) );
		asm(" cpuid ");
		asm(" mov %%eax, %0 " : "=m" (reg_eax) );
		asm(" mov %%ebx, %0 " : "=m" (reg_ebx) );
		asm(" mov %%ecx, %0 " : "=m" (reg_ecx) );
		asm(" mov %%edx, %0 " : "=m" (reg_edx) );

		if ( i == 0 )
			{
			n = reg_eax;
			strncpy( oemid+0, (char*)&reg_ebx, 4 );
			strncpy( oemid+4, (char*)&reg_edx, 4 );
			strncpy( oemid+8, (char*)&reg_ecx, 4 );
			printf( "\n%s ", oemid );
			}

		printf( "\nCPUID.0x%08X: ", i );
		printf( "eax=%08X ", reg_eax );
		printf( "ebx=%08X ", reg_ebx );
		printf( "ecx=%08X ", reg_ecx );
		printf( "edx=%08X ", reg_edx );
		}
	printf( "\n" );


	// early exit if the brand string capability is unimplemented
	asm(" mov %1, %%eax \n cpuid \n mov %%eax, %0 " 
		: "=m" (n) : "i" (0x80000000) : "ax", "bx", "cx", "dx" );
	if ( (n >> 31) == 0 ) { printf( "\n" ); return 0; }

	for (i = 0x80000000; i <= n; i++)
		{
		int	reg_eax, reg_ebx, reg_ecx, reg_edx;
		asm(" movl %0, %%eax " :: "m" (i) );
		asm(" cpuid ");
		asm(" mov %%eax, %0 " : "=m" (reg_eax) );
		asm(" mov %%ebx, %0 " : "=m" (reg_ebx) );
		asm(" mov %%ecx, %0 " : "=m" (reg_ecx) );
		asm(" mov %%edx, %0 " : "=m" (reg_edx) );

		printf( "\nCPUID.0x%08X: ", i );
		printf( "eax=%08X ", reg_eax );
		printf( "ebx=%08X ", reg_ebx );
		printf( "ecx=%08X ", reg_ecx );
		printf( "edx=%08X ", reg_edx );

		j = i & 0xFFFF;
		switch( j )
			{
			case 2:
			case 3:
			case 4:
			case 5:
			k = (j-2)*16;	
			strncpy( ident+k+0,  (char*)&reg_eax, 4 );
			strncpy( ident+k+4,  (char*)&reg_ebx, 4 );
			strncpy( ident+k+8,  (char*)&reg_ecx, 4 );
			strncpy( ident+k+12, (char*)&reg_edx, 4 );
			break;
			}
		}
	printf( "\n%s\n\n", ident );
}
