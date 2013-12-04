//-------------------------------------------------------------------
//	activity.c
//
//	This module creates a pseudo-file named '/proc/activity'
//	that is both readable and writable by user applications.
//	The file consists of an array of counters (corresponding
//	to the 256 different possible processor interrupts), and 
//	each counter will be incremented whenever its associated 
//	interrupt service routine gets executed.  The array also
//	gets reinitialized if an application writes to the file.
//
//	NOTE: Developed and tested using kernel version 2.4.18.
//
//	programmer: ALLAN CRUSE
//	written on: 23 MAR 2003
//	revised on: 08 MAY 2006 -- for Linux kernel version 2.6.12
//-------------------------------------------------------------------

#include <linux/module.h>	// for init_module()
#include <linux/proc_fs.h>	// for create_proc_entry() 
#include <asm/uaccess.h>	// for copy_to_user()

#define	PROC_DIR	NULL
#define	PROC_MODE	0666

char modname[] = "activity";
unsigned short oldidtr[3], newidtr[3];
unsigned long long *oldidt, *newidt;
unsigned long kpage, counter[ 256 ];
unsigned long isr_original[ 256 ];
const int filesize = sizeof( counter );

ssize_t
my_write( struct file *file, const char *buf, size_t len, loff_t *pos ),
my_read( struct file *file, char *buf, size_t len, loff_t *pos );

struct file_operations 
my_fops =	{
		owner:		THIS_MODULE,
		write:		my_write,
		read:		my_read,
		};


void load_IDTR( void *regimage )
{
	asm(" lidtl %0 " : : "m" (*(unsigned short*)regimage) );
}


asmlinkage void isr_common( unsigned long *tos )
{
	int	i = tos[ 10 ];		// interrupt ID-number
	counter[ i ] += 1;		// adjust that counter
	tos[ 10 ] = isr_original[ i ];	// setup chain-address
}

//--------  INTERRUPT SERVICE ROUTINES  ---------//
void isr_entry( void );
asm("	.text					");
asm("	.type	isr_entry, @function		");
asm("	.align	16				");
asm("isr_entry:					");
asm("	i = 0					");
asm("	.rept	256				");
asm("	pushl	$i				");
asm("	jmp	ahead				");
asm("	i = i + 1				");
asm("	.align	16				");
asm("	.endr					");
asm("ahead:					");
asm("	pushal					");
asm("	pushl	%ds				");
asm("	pushl	%es				");
//
asm("	movl	%ss, %eax			");
asm("	movl	%eax, %ds			");
asm("	movl	%eax, %es			");
//
asm("	pushl	%esp				");	
asm("	call	isr_common			");
asm("	addl	$4, %esp			");
//
asm("	popl	%es				");
asm("	popl	%ds				");
asm("	popal					");
asm("	ret					");
//-----------------------------------------------//



ssize_t
my_read( struct file *file, char *buf, size_t len, loff_t *pos )
{
	if ( *pos >= filesize ) return -EINVAL;
	if ( *pos + len > filesize ) len = filesize - *pos;
	if ( copy_to_user( buf, counter, len ) ) return -EFAULT;
	*pos += len;
	return	len;
}


ssize_t
my_write( struct file *file, const char *buf, size_t len, loff_t *pos )
{
	memset( counter, 0, sizeof( counter ) );
	return	len;	
}





int init_module( void )
{
	struct proc_dir_entry	*entry;
	unsigned long		i, isrlocn;
	
	printk( "<1>\nInstalling \'%s\' module\n", modname );

	// allocate kernel memory for a new Interrupt Descriptor Table
	kpage = get_zeroed_page( GFP_KERNEL );
	if ( !kpage ) return -ENOMEM;

	// initialize our module's global variables
	asm(" sidtl oldidtr \n sidtl newidtr ");
	memcpy( newidtr+1, &kpage, sizeof( unsigned long ) );
	oldidt = (unsigned long long*)(*(unsigned long*)(oldidtr+1));
	newidt = (unsigned long long*)(*(unsigned long*)(newidtr+1));
	memcpy( newidt, oldidt, 256 * sizeof( unsigned long long ) );
	
	// setup our array of indirect jump-addresses
	for (i = 0; i < 256; i++)
		{
		unsigned long long  gate = oldidt[ i ];
		gate &= 0xFFFF00000000FFFFLL;
		gate |= ( gate >> 32 );
		gate &= 0x00000000FFFFFFFFLL;
		isr_original[ i ] = gate;
		}

	// build our new table of interrupt descriptors
	isrlocn = (unsigned long)isr_entry;
	for (i = 0; i < 256; i++)
		{
		unsigned long long oldgate, newgate;
		oldgate = oldidt[ i ];
		oldgate &= 0x0000FF00FFFF0000LL;
		newgate = isrlocn;
		newgate &= 0x00000000FFFFFFFFLL;
		newgate |= ( newgate << 32 );
		newgate &= 0xFFFF00000000FFFFLL;
		newgate |= oldgate;
		newidt[ i ] = newgate;
		isrlocn += 16;
		}
	
	// activate the new Interrupt Descriptor Table
	load_IDTR( newidtr );
	smp_call_function( load_IDTR, newidtr, 1, 1 );
	
	// create proc file with read-and-write capabilities
	entry = create_proc_entry( modname, PROC_MODE, PROC_DIR );
	entry->proc_fops = &my_fops;
	return	0;  // SUCCESS
}


void cleanup_module( void )
{
	// destroy our module's proc file
	remove_proc_entry( modname, PROC_DIR );

	// reactivate original Interrupt Descriptor Table
	smp_call_function( load_IDTR, oldidtr, 1, 1 );
	load_IDTR( oldidtr );

	// release allocated kernel memory
	if ( kpage ) free_page( kpage );
	printk( "<1>Removing \'%s\' module\n", modname );
}

MODULE_LICENSE("GPL");

