//-------------------------------------------------------------------
//	ioapic.c
//
//	This module creates a pseudo-file (named '/proc/ioapic') 
//	which allows users to view the contents of the registers
//	that belong to the memory-mapped IO APIC. 
//
//	NOTE: Written and tested with Linux kernel version 2.6.12.
//
//	programmer: ALLAN CRUSE
//	written on: 07 MAY 2006
//	revised on: 26 DEC 2006
//	revised on: 21 JUL 2008 -- for Linux kernel version 2.6.26.
//-------------------------------------------------------------------

#include <linux/module.h>	// for init_module(), printk()
#include <linux/proc_fs.h>	// for create_proc_read_entry()
#include <asm/io.h>		// for ioremap(), iounmap()

#define IOAPIC_BASE 0xFEC00000

char modname[] = "ioapic";

int 
my_info( char *buf, char **start, off_t off, int count, int *eof, void *data )
{
	void	*io = ioremap_nocache( IOAPIC_BASE, PAGE_SIZE );
	void	*to = (void*)((long)io + 0x00);
	void	*fr = (void*)((long)io + 0x10);
	int	i, maxirq, len = 0;

	len += sprintf( buf+len, "\n  IO APIC  " );
	for (i = 0; i < 3; i++)
		{
		unsigned int	val;
		iowrite32( i, to );
		val = ioread32( fr );
		len += sprintf( buf+len, "  %04X: %08X   ", i, val );
		}
	len += sprintf( buf+len, "\n" );

	iowrite32( 1, to );
	maxirq = ( ioread32( fr ) >> 16 )&0x0FF;

	for (i = 0; i <= maxirq; i++)
		{
		unsigned int	val_lo, val_hi;
		iowrite32( 0x10 + 2*i, to );
		val_lo = ioread32( fr );
		iowrite32( 0x10+2*i+1, to );
		val_hi = ioread32( fr );
		if ( ( i % 3 ) == 0 ) len += sprintf( buf+len, "\n" );
		len += sprintf( buf+len, "  %04X: ", i );
		len += sprintf( buf+len, "%08X%08X  ", val_hi, val_lo );
		}
	len += sprintf( buf+len, "\n\n" );
	
	iounmap( io );
	return	len;  
}


int init_module( void )
{
	printk( "<1>\nInstalling \'%s\' module\n", modname );
	create_proc_read_entry( modname, 0, NULL, my_info, NULL );
	return	0; // SUCCESS
}


void cleanup_module( void )
{
	printk( "<1>Removing \'%s\' module\n", modname );
	remove_proc_entry( modname, NULL );
}

MODULE_LICENSE("GPL");

