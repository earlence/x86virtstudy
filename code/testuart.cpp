//-------------------------------------------------------------------
//	testuart.cpp
//
//	This Linux program tests the serial UART's 'loopback' mode.
//
//	     compile using:  $ g++ testuart.cpp -o testuart
//	     execute using:  $ ./testuart
//
//	Note that Linux application-programs normally are prevented
//	by the processor from directly accessing I/O ports, but the
//	operating system can be asked to eliminate this restriction 
//	if a program uses the 'iopl()' system-call; ordinarily that
//	system-call requires the user to possess 'root' privileges,
//	but students may run our 'iopl3' utility as a 'workaround'.
//
//	programmer: ALLAN CRUSE
//	written on: 17 JAN 2007
//-------------------------------------------------------------------

#include <stdio.h>	// for printf(), perror() 
#include <stdlib.h>	// for exit() 
#include <sys/io.h>	// for iopl()

#define UART_PORT	0x03F8	// base port-address for the UART
#define DIVISOR_LATCH	(UART_PORT + 0)
#define TX_DATA_REG	(UART_PORT + 0)
#define RX_DATA_REG	(UART_PORT + 0)
#define LINE_CONTROL	(UART_PORT + 3)
#define MODEM_CONTROL	(UART_PORT + 4)
#define LINE_STATUS	(UART_PORT + 5)

char msg[] = "\n\tThis is a test of the UART's loopback mode\n";

int main( int argc, char **argv )
{
	// set the CPU's I/O Permission-Level to allow port-access
	if ( iopl( 3 ) ) { perror( "iopl" ); exit(1); }

	// establish the UART's operational parameters
	outb( 0x80, LINE_CONTROL );	// set DLAB=1
	outw( 0x0001, DIVISOR_LATCH );	// set 11520 baud
	outb( 0x03, LINE_CONTROL );	// set data-format: 8-N-1
	outb( 0x10, MODEM_CONTROL );	// turn on 'loopback' mode 

	// write each message-character, read it back, and display it
	for (int i = 0; i < sizeof( msg ); i++)
		{
		do { } while ( (inb( LINE_STATUS )&0x20) == 0x00 );
		outb( msg[i], TX_DATA_REG );
		do { } while ( (inb( LINE_STATUS )&0x01) == 0x00 );
		int	data = inb( RX_DATA_REG );
		printf( "%c", data );
		}
	outb( 0x00, MODEM_CONTROL );	// turn off 'loopback' mode 
	printf( "\n" );
}
