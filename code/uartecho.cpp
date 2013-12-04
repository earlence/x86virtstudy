//-------------------------------------------------------------------
//	uartecho.cpp
//
//	This program is for testing a "null-modem" cable-connection:
//	after you start it running on one PC, you run our 'trycable'
//	program on the PC at the other end of your null-modem cable.
//	When you are done, you hit <CONTROL>-C to stop this program. 
//
//	      compile using:  $ g++ uartecho.cpp -o uartecho
//	      prepare using:  $ g++ iopl3
//	      execute using:  $ ./uartecho
//
//	programmer: ALLAN CRUSE
//	written on: 17 JAN 2007
//-------------------------------------------------------------------

#include <stdio.h>	// for printf(), perror() 
#include <stdlib.h>	// for exit() 
#include <sys/io.h>	// for iopl()

#define	PORT	0x03F8

int main( int argc, char **argv )
{
	if ( iopl( 3 ) ) { perror( "iopl" ); exit(1); }
	printf( "Hit <CONTROL>-C to terminate this program\n" );

	// set the UART communication parameters
	outb( 0x80, PORT + 3 );		// Line Control register
	outw( 0x0001, PORT + 0 );	// Divisor Latch register
	outb( 0x03, PORT + 3 );		// Line Control register
	outb( 0x03, PORT + 4 );		// Modem Control register

	// main loop to transmit anything received
	for(;;)	{
		// wait until the Receive Buffer is not empty
		while ( (inb( PORT + 5 )&0x01) == 0x00 );
		// input new byte from the Received Data register
		int	data = inb( PORT + 0 );
		// let the user see that this data was received
		printf( "%c", data ); fflush( stdout );
		// check that the Transmit Holding Register is empty
		while ( (inb( PORT + 5 )&0x20) == 0x00 );
		// output the byte to the Transmit Data register
		outb( data, PORT + 0 );
		}
}
