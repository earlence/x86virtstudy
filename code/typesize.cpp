//-------------------------------------------------------------------
//	typesize.cpp
//
//	This program displays the widths (in bytes) of the standard
//	scalar data-types, supported in the C programming language. 
//	For documentation purposes (in case the program's output is
//	redirected to a printer), this station's hostname is shown.
//
//	      compile using:  $ g++ typesize.cpp -o typesize
//	      execute using:  $ ./typesize
//
//	IN-CLASS EXERCISE: compare this program's outputs when it's
//	run on a 32-bit Linux system, and on a 64-bit Linux system.
//	Be sure you 'recompile' this program in each environment or
//	you might be mislead by IA-32e 'compatibility mode' output.
//
//	programmer: ALLAN CRUSE
//	written on: 01 FEB 2007
//-------------------------------------------------------------------

#include <stdio.h>	// for printf()  
#include <unistd.h>	// for gethostname()  

int main( int argc, char **argv )
{
	char	hostname[ 64 ];
	gethostname( hostname, 64 );
	printf( "\nhostname: \'%s\' \n", hostname );

	printf( "\n" );
	printf( "sizeof( char ) = %d bytes\n", sizeof( char ) );
	printf( "sizeof( short ) = %d bytes\n", sizeof( short ) );
	printf( "sizeof( int ) = %d bytes\n", sizeof( int ) );
	printf( "sizeof( long ) = %d bytes\n", sizeof( long ) );
	printf( "sizeof( long long ) = %d bytes\n", sizeof( long long ) );
	printf( "sizeof( float ) = %d bytes\n", sizeof( float ) );
	printf( "sizeof( double ) = %d bytes\n", sizeof( double ) );
	printf( "sizeof( long double ) = %d bytes\n", sizeof( long double ) );
	printf( "sizeof( void * ) = %d bytes\n", sizeof( void * ) );
	printf( "\n" );
}
