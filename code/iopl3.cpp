//----------------------------------------------------------------
//	iopl3.cpp	 (Lets user programs perform direct I/O)
//
//	This utility for Linux systems allows a user to launch a
//	new command shell which possesses system privileges that
//	each subsequenty executed application will then inherit,
//	and thereafter be able execute the 'iopl()' system-call.
//
//	  compile using:  root# make iopl3
//	     		  root# chmod a+s iopl3  
//	  install using:  root# mv iopl3 /usr/local/bin/.
//
//	  execute using:  user$ iopl3
//
//	programmer: Alex Fedosov
//	commentary: Allan Cruse
//	completion: 26 AUG 2005
//----------------------------------------------------------------

#include <stdio.h>	// for printf()
#include <unistd.h>	// for getuid(), setuid()
#include <sys/io.h>	// for iopl()
#include <stdlib.h>	// for system()

int main(int argc, char *argv[])
{
	// preserve this task's user-identity
        int 	uid = getuid();
        printf( "%d\n", getuid() );

	// change this task's effective user-identity to 'root'
        setuid( 0 );
        printf( "%d\n", getuid() );

	// now 'root' can change this task's I/O Privilege-Level: IOPL=3
        iopl( 3 );

	// restore this task's former user-identity
        setuid( uid );
        printf( "%d\n", getuid()) ;

	// launch a new command-shell which will inherit IOPL=3
        system( "bash --login" );
        return 0;
}

