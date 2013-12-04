//--------------------------------------------------------------------
//	ljpages.cpp
//
//	This application submits a specified textfile for printing on
//	a designated printer (or on the default printer if no printer 
//	is specified); a page-number appears at the bottom each page.
//
//		usage:  $ ljpages <textfile> [ -P <printer> ]
//
//	        compile using:  $ g++ ljpages.cpp -o ljpages
//
//	programmer: ALLAN CRUSE
//	written on: 18 AUG 2005
//	revised on: 05 JAN 2006 -- so longer lines will get truncated  
//--------------------------------------------------------------------

#include <stdio.h>	// for fopen(), fgets(), fprintf(), etc
#include <stdlib.h>	// for system(), mkstemp()
#include <unistd.h>	// for unlink()

#define LINES_PER_PAGE	56
#define CHARS_PER_LINE	95

void page_out( FILE *lp, int page_number );

int main( int argc, char *argv[] )
{
	// check for the required command-line argument
	if ( argc == 1 )
		{ 
		fprintf( stderr, "Usage: %s <textfile> ", argv[0] );
		fprintf( stderr, "[ -P <printer> ] \n" );
		return -1; 
		}

	// open the file to be printed
	FILE 	*input = fopen( argv[1], "r" );
	if ( input == NULL ) { perror( argv[1] ); return -1; }

	// create a temporary file for output destined for the printer  
	char	tempname[] = "pclXXXXXX";
	int	pcl = mkstemp( tempname );
	FILE	*prout = fdopen( pcl, "w" );
	if ( prout == NULL ) 
		{
		fprintf( stderr, "Could not create temporary file.\n" ); 
		return -1; 
		} 

	// issue the printer's initialization sequence
	fprintf( prout, "\eE" );		// initialize the printer 
	fprintf( prout, "\e&l4E" );		// top-margin: 4 lines
	fprintf( prout, "\e&a8L" );		// left-margin: 8 columns	
	fprintf( prout, "\e(10U" );		// symbol set: PC-8 
	fprintf( prout, "\e(s0p11.00h12.0s3b4099T" ); // font: courier

	// notify the user that printing is now in progress
	fprintf( stderr, "Now printing file \"%s\" ... ", argv[1] );

	// main loop to print the input-file's numbered pages
	char	in_line[ 128 ], outline[ 8192 ];
	int	pagecount = 0, linecount = 0, i, j;
	while ( fgets( in_line, sizeof( in_line), input ) )
		{
		++linecount;
		// perform tab-expansion (for uniform line-truncations)
		for (i = 0, j = 0; i < sizeof( in_line ); i++)
			{
			int	inch = in_line[ i ];
			if ( inch == '\n' ) break;
			if ( inch != '\t' ) outline[ j++ ] = inch; 
			else  do outline[ j++ ] = ' '; while ( j % 8 );
			}
		outline[ j++ ] = '\0';
		// here we truncate any lines that exceeed paper width 
		outline[ CHARS_PER_LINE ] = '\0';
		fprintf( prout, "\r%s\n", outline );
		if ( linecount == LINES_PER_PAGE ) 
			{ page_out( prout, ++pagecount ); linecount = 0; }  
		}
	if ( linecount != 0 ) page_out( prout, ++pagecount );
	fclose( prout );

	// let the user know that the output is now being submitted
	fprintf( stderr, "finished.\n" );

	// use "lpr" to send temporary file's contents to the printer
	char	command[ 128 ] = {0};
	int	len = sprintf( command, "lpr %s ", tempname );
	for (int i = 2; i < argc; i++) 
		len += sprintf( command+len, "%s ", argv[i] ); 
	system( command );	// submit the temporary file  
	unlink( tempname );	// delete the temporary file
}

void page_out( FILE *lp, int page_number )
{
	fprintf( lp, "\e&a%dR", LINES_PER_PAGE+2 );	// cursor row
	fprintf( lp, "\e&a%dC", CHARS_PER_LINE/2 );	// cursor column	
	fprintf( lp, "%d\r\f", page_number );		// page-number
}

