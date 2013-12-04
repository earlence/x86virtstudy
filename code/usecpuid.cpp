//-----------------------------------------------------------------
//	usecpuid.cpp
//
//	This example shows how you can use the 'asm' construct to
//	include some 'inline' assembly language in a C++ program.
//	(It displays the processor's Vendor Identification String
//	obtained using the CPUID instruction with input-value 0.)
//
//	     compile using:  $ g++ usecpuid.cpp -o usecpuid
//
//	programmer: ALLAN CRUSE
//	written on: 06 FEB 2007
//-----------------------------------------------------------------

#include <string.h>	// for strncat(), strlen()
#include <unistd.h>	// for write(), STDOUT_FILENO

int main( void )
{
	char	message[ 80 ] = "\n\tVendor Identification String is ";
	int	regEBX, regECX, regEDX;

	// get the processor's Vendor Identification String
	asm(	" mov	%3, %%eax	\n"\
		" cpuid			\n"\
		" mov	%%ebx, %0	\n"\
		" mov	%%edx, %1	\n"\
		" mov	%%ecx, %2	\n"
		: "=m" (regEBX), "=m" (regEDX), "=m" (regECX)
		: "i" (0)	: "ax", "bx", "cx", "dx" );

	// format the message that we intend to display
	strncat( message, "\'", 1 );
	strncat( message, (char*)&regEBX, 4 );
	strncat( message, (char*)&regEDX, 4 );
	strncat( message, (char*)&regECX, 4 );
	strncat( message, "\'", 1 );
	strncat( message, "\n\n", 2 );

	// use the 'write' function in the standard runtime library 
	write( STDOUT_FILENO, message, strlen( message ) );
}	
