//-------------------------------------------------------------------
//	activity.cpp
//
//	This application continuously reads the volatile kernel data 
//	that is stored in a pseudo-file (named '/proc/activity') and 
//	displays it on the screen until the <ESCAPE> key is pressed.  
//	The 'data' consists of an array of 256 counters representing   
//	invocations of the kernel's 256 interrupt service routines.
//	 
//	   compile-and-link using: $ g++ activity.cpp -o activity
//
//	This program makes use of the 'select()' library-function to
//	support efficient handling of its multiplexed program-input.
//	It requires that an accompanying kernel object (activity.ko)
//	has already been compiled and installed in the Linux kernel.
//
//	NOTE: Developed and tested with Linux kernel version 2.6.12.
//
//	programmer: ALLAN CRUSE
//	written on: 08 MAY 2006
//-------------------------------------------------------------------

#include <stdio.h>	// for printf(), fprintf() 
#include <fcntl.h>	// for open() 
#include <stdlib.h>	// for exit() 
#include <unistd.h>	// for read(), write(), close() 
#include <termios.h>	// for tcgetattr(), tcsetattr()

#define KEY_ESCAPE 27			// ASCII code for ESCAPE-key
#define FILENAME "/proc/activity"	// name of input pseudo-file 

int main( void )
{
	// open the pseudo-file for reading 
	int	fd = open( FILENAME, O_RDONLY );
	if ( fd < 0 ) 
		{
		fprintf( stderr, "could not find \'%s\' \n", FILENAME );
		exit(1);
		}	

	// enable noncanonical terminal-mode
	struct termios	tty_orig;
	tcgetattr( STDIN_FILENO, &tty_orig );
	struct termios	tty_work = tty_orig;
	tty_work.c_lflag &= ~( ECHO | ICANON | ISIG );
	tty_work.c_cc[ VMIN ] = 1;
	tty_work.c_cc[ VTIME ] = 0;
	tcsetattr( STDIN_FILENO, TCSAFLUSH, &tty_work );

	// initialize file-descriptor bitmap for 'select()' 
	fd_set	permset;
	FD_ZERO( &permset );
	FD_SET( STDIN_FILENO, &permset );
	FD_SET( fd, &permset );

	// initialize the screen-display	
	printf( "\e[H\e[J" );		// clear the screen
	printf( "\e[?25l" );		// hide the cursor
	
	// draw the screen's title, headline and sideline
	int	i, ndev = 1+fd, row = 2, col = 27;
	printf( "\e[%d;%dHINTERRUPT ACTIVITY MONITOR", row, col );
	for (i = 0; i < 16; i++)
		{
		row = i+6;
		col = 6;
		printf( "\e[%d;%dH%02X:", row, col, i*16 );
		row = 5;
		col = i*4 + 12;
		printf( "\e[%d;%dH%X", row, col, i );
		}
	fflush( stdout );
	
	// main loop: continuously responds to multiplexed input	
	for(;;)	{
		// sleep until some new data is ready to be read
		fd_set	readset = permset;
		if ( select( ndev, &readset, NULL, NULL, NULL ) < 0 ) break;

		// process new data read from the keyboard
		char	inch;
		if ( FD_ISSET( STDIN_FILENO, &readset ) )
			if ( read( STDIN_FILENO, &inch, 1 ) > 0 )
				if ( inch == KEY_ESCAPE ) break;

		// process new data read from the pseudo-file
		if ( FD_ISSET( fd, &readset ) )
			{
			unsigned long counter[ 256 ] = {0};
			lseek( fd, 0, SEEK_SET );
			if ( read( fd, counter, 1024 ) < 1024 ) break;
			for (i = 0; i < 256; i++)
				{
				int 	row = ( i / 16 ) + 6;
				int	col = ( i % 16 ) * 4 + 10;
				unsigned long	what = counter[ i ] % 1000;
				printf( "\e[%d;%dH", row, col );
				if ( !counter[i] ) printf( "---" );
				else	printf( "%03d", what );
				}
			row = 23;
			col = 0;
			}
		fflush( stdout );
		}

	// restore the standard user-interface	
	tcsetattr( STDIN_FILENO, TCSAFLUSH, &tty_orig );
	printf( "\e[23;0H\e[?25h\n" );		// show the cursor
}
