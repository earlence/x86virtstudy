//----------------------------------------------------------------
//	newproc.cpp	Creates the skeleton for a '/proc' module
//
//	This application creates skeleton-code for a Linux kernel 
//	module which whill install a pseudo-file into the '/proc' 
//	directory.  It modifies our earlier 'newinfo.cpp' utility
//	(to accommodate the kernel developers' decision to remove 
//	their older 'get_info()' interface from kernels 2.6.26+).  
//
//			usage:	$ newproc <modname>
//
//	programmer: ALLAN CRUSE
//	written on: 20 FEB 2002
//	revised on: 12 MAY 2002 -- to incorporate MODULE_LICENSE
//	revised on: 20 JAN 2005 -- for Linux kernel version 2.6.
//	revised on: 17 JUN 2007 -- to use new-style init/cleanup
//	revised on: 17 JUL 2008 -- to use 'proc_read' interface   
//----------------------------------------------------------------

#include <stdio.h>	// for fprintf(), fopen(), fclose(), etc
#include <string.h>	// for strncpy(), strncat(), memset()
#include <time.h>	// time(), localtime()

char authorname[] = "<YOUR NAME>";
char monthlist[] = "JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC";

int main( int argc, char *argv[] )
{
	// check for module-name as command-line argument
	if ( argc == 1 ) 
		{
		fprintf( stderr, "Must specify a module-name\n" );
		return	-1;
		}

	// prepare module name (without any suffix) 
	char	modname[33] = "";
	strncpy( modname, argv[1], 28 );
	strtok( modname, "." );

	// prepare code-file name (with ".c" suffix)
	char	srcname[33] = "";
	strncpy( srcname, modname, 28 );
	strncat( srcname, ".c", 2 );

	// announce this program's purpose 
	printf( "\nCreating skeleton for module " );
	printf( "named \'%s\' \n", srcname );

	// insure source-file doesn't already exist
	FILE	*fp = fopen( srcname, "rb" );
	if ( fp != NULL )
		{
		fclose( fp );
		fprintf( stderr, "File \'%s\' already exists\n", srcname );
		return	-1;
		}

	// create the new source-file
	fp = fopen( srcname, "wb" );
	if ( fp == NULL )
		{
		fprintf( stderr, "Cannot create source-file\n" );
		return	-1;
		}

	time_t		now = time( (time_t *)NULL );
	struct tm	*t = localtime( &now );
	char	month[4] = "";
	strncpy( month, monthlist+3*t->tm_mon, 3 );
	month[3] = '\0';

	char	when[16] = "";
	sprintf( when, "%02d %3s %04d", t->tm_mday, month, 1900+t->tm_year );	

	char	border[68] = "";
	memset( border, '-', 67 );

	fprintf( fp, "//%s\n", border );
	fprintf( fp, "//\t%s\n", srcname );
	fprintf( fp, "//\n" );
	fprintf( fp, "//\tprogrammer: %s\n", authorname );
	fprintf( fp, "//\tdate begun: %s\n", when );
	fprintf( fp, "//%s\n", border );
	fprintf( fp, "\n" );
	fprintf( fp, "#include <linux/module.h>" );
	fprintf( fp, "\t// for init_module() \n" );
	fprintf( fp, "#include <linux/proc_fs.h>" );
	fprintf( fp, "\t// for create_proc_read_entry() \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "char modname[] = \"%s\";\n", modname );

	fprintf( fp, "\nint my_proc_read( char *buf, " );
	fprintf( fp, "char **start, off_t off, int count, \n" );
	fprintf( fp, "\t\t\t\t\t\t int *eof, void *data ) \n" );
	fprintf( fp, "{\n" );
	fprintf( fp, "\tint\tlen;\n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tlen = 0;\n" );
	fprintf( fp, "\tlen += sprintf( buf+len, \"\\n%%s\\n\", modname );\n" );
	fprintf( fp, "\tlen += sprintf( buf+len, \"\\n\" );\n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\treturn\tlen;\n" );
	fprintf( fp, "}\n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\nstatic int __init %s_init( void )\n", modname );
	fprintf( fp, "{\n" );
	fprintf( fp, "\tprintk( \"<1>\\nInstalling \\\'%%s\\\' " );
	fprintf( fp, "module\\n\", modname );\n" );
	fprintf( fp, "\n\tcreate_proc_read_entry( modname, 0, NULL, " );
	fprintf( fp, "my_proc_read, NULL );\n" );
	fprintf( fp, "\treturn\t0;  //SUCCESS\n" );
	fprintf( fp, "}\n" );
	
	fprintf( fp, "\n" );
	fprintf( fp, "\nstatic void __exit %s_exit(void )\n", modname );
	fprintf( fp, "{\n" );
	fprintf( fp, "\tremove_proc_entry( modname, NULL );\n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tprintk( \"<1>Removing \\\'%%s\\\' " );
	fprintf( fp, "module\\n\", modname );\n" );
	fprintf( fp, "}\n" );

	fprintf( fp, "\n" );
	fprintf( fp, "module_init( %s_init );\n", modname );	
	fprintf( fp, "module_exit( %s_exit );\n", modname );	
	fprintf( fp, "MODULE_LICENSE(\"GPL\"); \n" );
	fprintf( fp, "\n" );

	fclose( fp );
	printf( "\n" );
}
