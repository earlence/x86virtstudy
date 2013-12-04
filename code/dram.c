//-------------------------------------------------------------------
//	dram.c
//
//	This module implements a Linux character-mode device-driver
//	for the processor's installed physical memory.  It utilizes
//	the direct mapping of all physical memory into the kernel's
//	virtual address-space for the 64-bit version of the kernel,
//	observing that it continued to work with our 32-bit kernel.
//	We implement an 'llseek()' method so that users can readily 
//	find out how much physical processor-memory is installed. 
//
//	NOTE: Developed and tested with Linux kernel version 2.6.10
//
//	programmer: ALLAN CRUSE
//	written on: 30 JAN 2005
//	revised on: 30 MAR 2007 -- for Linux kernel version 2.6.17
//-------------------------------------------------------------------

#include <linux/module.h>	// for init_module() 
#include <linux/mm.h>		// for num_physpages
#include <asm/io.h>		// for phys_to_virt()
#include <asm/uaccess.h>	// for copy_to_user() 

char modname[] = "dram";	// for displaying driver's name
int my_major = 85;		// note static major assignment 
unsigned long dram_size;	// total bytes of system memory

loff_t my_llseek( struct file *file, loff_t offset, int whence );
ssize_t my_read( struct file *file, char *buf, size_t count, loff_t *pos );

struct file_operations 
my_fops =	{
		owner:		THIS_MODULE,
		llseek:		my_llseek,
		read:		my_read,
		};


int init_module( void )
{
	printk( "<1>\nInstalling \'%s\' module ", modname );
	printk( "(major=%d)\n", my_major );
	
	dram_size = num_physpages * PAGE_SIZE;
	printk( "<1>  ramtop=%016lX (%lu MB)\n", dram_size, dram_size >> 20 );
	return 	register_chrdev( my_major, modname, &my_fops );
}


void cleanup_module( void )
{
	unregister_chrdev( my_major, modname );
	printk( "<1>Removing \'%s\' module\n", modname );
}


ssize_t my_read( struct file *file, char *buf, size_t count, loff_t *pos )
{
	void		*from;
	int		more;
	
	// we cannot read beyond the end-of-file
	if ( *pos >= dram_size ) return 0;

	// we can only read up to the end of physical memory
	if ( *pos + count > dram_size ) count = dram_size - *pos;

	// find where the physical address is mapped to its virtual address
	from = phys_to_virt( *pos );

	// now transfer count bytes from mapped page to user-supplied buffer 	
	more = copy_to_user( buf, from, count );
	
	// an error occurred if less than count bytes got copied
	if ( more ) return -EFAULT;
	
	// otherwise advance file-pointer and report number of bytes read
	*pos += count;
	return	count;
}


loff_t my_llseek( struct file *file, loff_t offset, int whence )
{
	loff_t	newpos = -1;

	switch( whence )
		{
		case 0: newpos = offset; break;			// SEEK_SET
		case 1: newpos = file->f_pos + offset; break; 	// SEEK_CUR
		case 2: newpos = dram_size + offset; break; 	// SEEK_END
		}

	if (( newpos < 0 )||( newpos > dram_size )) return -EINVAL;
	file->f_pos = newpos;
	return	newpos;
}

MODULE_LICENSE("GPL");
