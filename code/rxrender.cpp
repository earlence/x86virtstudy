//-------------------------------------------------------------------
//	rxrender.cpp
//
//	This program was written to assist you in developing your
//	own "console-redirection" capability, needed by protected
//	mode applications that are launched at 'boot-time' on our
//	remotely-located Core-2 Duo machines.  (You can test your
//	design on a pair of our classroom or CS-lab machines that
//	are connected by a serial 'null-modem' cable.)  When this
//	Linux program is executed, it will 'listen' to the serial
//	port, and it will write any characters it receives to the 
//	standard output device (i.e., the terminal screen) in the
//	same way your Core-2 Duo machine sends output to 'colby'.
//	(You hit <CONTROL-C> when you want to quit this program.)
//
//	    compile using:  $ g++ rxrender.cpp -o rxrender
//	    execute using:  $ ./rxrender
//
//	NOTE: You will need to run the 'iopl3' utility beforehand.
//
//	programmer: ALLAN CRUSE
//	written on: 24 FEB 2007
//	revised on: 01 MAR 2007 -- changed 'printf()' to 'write()'
//-------------------------------------------------------------------

#include <sys/io.h>	// for inb(), outb()
#include <unistd.h>	// for write()

#define UART		0x03F8		

int main( int argc, char **argv )
{
	// initialize the UART (115200-baud, 8-N-1)
	outb( 0x00, UART+1 );	// interrupt-enable register	
	outb( 0x00, UART+2 );	// fifo-control register
	outb( 0xC7, UART+2 );	// fifo-control register
	outb( 0x80, UART+3 ); 	// line-control register
	outw( 0x0001, UART );	// divisor-latch register
	outb( 0x03, UART+3 );	// line-control register
	outb( 0x03, UART+4 );	// modem-control register
	
	// clear any stale-data or status-settings
	inb( UART+6 );		// modem-status
	inb( UART+5 );		// line-status
	inb( UART+0 );		// received-data
	inb( UART+2 );		// interrupt-identification

	// enter an endless-loop to output any received bytes
	for(;;)	{
		int	line_status = inb( UART+5 );
		if ( (line_status & 0x01) == 0x01 ) 
			{
			int 	ch = inb( UART );
			write( 1, &ch, 1); 
			}
		}
}
