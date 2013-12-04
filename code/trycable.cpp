//-------------------------------------------------------------------
//	trycable.cpp
//
//	This program is for testing a "null-modem" cable-connection:
//	you run it on one PC while our 'uartecho' program is already
//	running on the PC at the other end of your null-modem cable. 
//
//	      compile using:  $ g++ trycable.cpp -o trycable
//	      prepare using:  $ iopl3
//	      execute using:  $ ./trycable
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

	// set the UART communication parameters
	outb( 0x80, PORT + 3 );		// Line Control register
	outw( 0x0001, PORT + 0 );	// Divisor Latch register
	outb( 0x03, PORT + 3 );		// Line Control register
	outb( 0x03, PORT + 4 );		// Modem Control register
	
	char	msg[] = "Hello\n";	// the test message
	for (int i = 0; i < 6; i++)
		{
		// wait until Transmitter Holding Register is empty
		while ( (inb( PORT + 5 )&0x20) == 0x00 );
		// write next character to Transmit Data register
		outb( msg[ i ], PORT + 0 );
		// wait until the Receive Buffer is not empty
		while ( (inb( PORT + 5 )&0x01) == 0x00 );
		// input the data from the Received Data register
		int	data = inb( PORT + 0 );
		// display the received character (do it immediately)
		printf( "%c", data );  fflush( stdout );
		}
}
