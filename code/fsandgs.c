//-------------------------------------------------------------------
//	fsandgs.c
//
//	This installable Linux Kernel Module creates a pseudo-file
//	(named "/proc/fsandgs') that allows a user to see the MSRs
//	associated with segment-registers FS and GS in 64bit mode.
//
//	     compile using:  $ mmake fsandgs
//	     install using:  $ /sbin/insmod fsandgs.ko
//	     execute using:  $ cat /proc/fsandgs
//
//	NOTE: Written and tested with Linux x86_64 version 2.6.17.
//
//	programmer: ALLAN CRUSE
//	written on: 01 MAY 2007
//	revised on: 21 JUL 2008 -- for Linux kernel version 2.6.26.
//-------------------------------------------------------------------

#include <linux/module.h>	// for init_module() 
#include <linux/proc_fs.h>	// for create_proc_read_entry() 

char modname[] = "fsandgs";

unsigned long long	msr_fs_base, msr_gs_base, msr_kernel_gs_base;


int 
my_info( char *buf, char **start, off_t off, int count, int *eof, void *data )
{
	int	len;

	asm(	" mov	$0xC0000100, %%ecx	\n"\
		" rdmsr				\n"\
		" mov	%%eax, msr_fs_base+0	\n"\
		" mov	%%edx, msr_fs_base+4	\n"\
		::: "ax", "cx", "dx");

	asm(	" mov	$0xC0000101, %%ecx	\n"\
		" rdmsr				\n"\
		" mov	%%eax, msr_gs_base+0	\n"\
		" mov	%%edx, msr_gs_base+4	\n"\
		::: "ax", "cx", "dx");

	asm(	" mov	$0xC0000102, %%ecx	\n"\
		" rdmsr				\n"\
		" mov	%%eax, msr_kernel_gs_base+0	\n"\
		" mov	%%edx, msr_kernel_gs_base+4	\n"\
		::: "ax", "cx", "dx");


	len = 0;
	len += sprintf( buf+len, "\n" );
	len += sprintf( buf+len, "\t       MSR_FS_BASE = %016llX \n", 
				msr_fs_base );
	len += sprintf( buf+len, "\t       MSR_GS_BASE = %016llX \n", 
				msr_gs_base );
	len += sprintf( buf+len, "\tMSR_KERNEL_GS_BASE = %016llX \n", 
				msr_kernel_gs_base );
	len += sprintf( buf+len, "\n" );

	return	len;
}


int init_module( void )
{
	printk( "<1>\nInstalling \'%s\' module\n", modname );

	create_proc_read_entry( modname, 0, NULL, my_info, NULL );
	return	0;  //SUCCESS
}


void cleanup_module( void )
{
	remove_proc_entry( modname, NULL );

	printk( "<1>Removing \'%s\' module\n", modname );
}

MODULE_LICENSE("GPL"); 

