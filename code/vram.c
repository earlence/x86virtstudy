//-------------------------------------------------------------------
//	vram.c	       
//
//	This character-mode Linux device-driver allows applications
//	to both read and write directly to graphics display memory.   
//	It invokes the kernel's PCI bus-interface routines, to find
//	the physical address of the display adapter's video memory;
//	it calls the kernel's 'ioremap()' and 'iounmap()' functions 
//	to setup and destroy temporary mappings of VRAM page-frames 
//	into the Pentium processor's virtual address-space; it uses 
//	the kernel's 'memcpy_toio()' and 'memcpy_fromio()' to write
//	and read these mapped pages of video memory.  It implements
//	an 'mmap()' method, thus allowing applications to treat the
//	video display memory as an ordinary array in user-space.  
//
//	In this driver the device major number is hard-coded as 99,
//	and it is left to the user (or the system administrator) to
//	create the corresponding device-node, using the 'mknod' and 
//	'chmod' shell commands:
//
//		root# mknod /dev/vram c 98 0
//		root# chmod a+rw /dev/vram 
//	
//	NOTE: Written and tested using Linux kernel version 2.6.10.
//
//	programmer: ALLAN CRUSE
//	written on: 14 MAR 2005
//	revised on: 08 AUG 2005 -- for kernel 2.6.12 with ATI Radeon
//	revised on: 17 MAR 2006 -- for kernel 2.6.15 with Intel GPU 
//	revised on: 04 AUG 2006 -- for kernel 2.6.17 (my_major = 98)
//	revised on: 25 MAY 2007 -- for ATI Radeon GPUs (on 'anchor') 
//-------------------------------------------------------------------

#include <linux/module.h>	// for init_module() 
#include <linux/pci.h>		// for pci_find_class() 

#define VENDOR_ID 0x1002	// Advanced Techlologies, Inc
#define DEVICE_ID 0x515E	// ATI Radeon graphics processor 

//#define VENDOR_ID 0x8086	// Intel Corporation, Inc
//#define DEVICE_ID 0x2772	// 82945G Graphics Processor 

char modname[] = "vram";	// used for displaying driver-name
int my_major = 98;		// driver's assigned major-number
unsigned long fb_base;		// physical address of frame-buffer
unsigned long fb_size;		// size of the frame-buffer (bytes)

loff_t my_llseek( struct file *file, loff_t pos, int whence )
{
	loff_t	newpos = -1;

	switch ( whence )
		{
		case 0:	newpos = pos; break;			// SEEK_SET
		case 1:	newpos = file->f_pos + pos; break;	// SEEK_CUR
		case 2: newpos = fb_size + pos; break;		// SEEK_END
		}
	
	if (( newpos < 0 )||( newpos > fb_size )) return -EINVAL;
	file->f_pos = newpos;
	return	newpos;
}	

ssize_t
my_write( struct file *file, const char *buf, size_t count, loff_t *pos )
{
	unsigned long	phys_address = fb_base + *pos;
	unsigned long	page_number = phys_address / PAGE_SIZE;
	unsigned long	page_indent = phys_address % PAGE_SIZE;
	unsigned long	where;
	void		*vaddr;

	// sanity check: we cannot write anything past end-of-vram
	if ( *pos >= fb_size ) return 0;

	// we can only write up to the end of the current page
	if ( page_indent + count > PAGE_SIZE ) count = PAGE_SIZE - page_indent;

	// ok, map the current page of physical vram to virtual address
	where = page_number * PAGE_SIZE;	// page-addrerss
	vaddr = ioremap( where, PAGE_SIZE );	// setup mapping
	
	// copy 'count' bytes from the caller's buffer to video memory
	memcpy_toio( vaddr + page_indent, buf, count );
	iounmap( vaddr );			// unmap memory
	
	// tell the kernel how many bytes were actually transferred
	*pos += count;
	return	count;
}

ssize_t	
my_read( struct file *file, char *buf, size_t count, loff_t *pos )
{
	unsigned long	phys_address = fb_base + *pos;
	unsigned long	page_number = phys_address / PAGE_SIZE;
	unsigned long	page_indent = phys_address % PAGE_SIZE;
	unsigned long	where;
	void		*vaddr;

	// sanity check: we cannot read anything past end-of-vram
	if ( *pos >= fb_size ) return 0;

	// we can only read up to the end of the current page
	if ( page_indent + count > PAGE_SIZE ) count = PAGE_SIZE - page_indent;

	// ok, map the current page of physical vram to virtual address
	where = page_number * PAGE_SIZE;	// page-addrerss
	vaddr = ioremap( where, PAGE_SIZE );	// setup mapping
	
	// copy 'count' bytes from video memory to the caller's buffer 
	memcpy_fromio( buf, vaddr + page_indent, count );
	iounmap( vaddr );			// unmap memory
	
	// tell the kernel how many bytes were actually transferred
	*pos += count;
	return	count;
}

int my_mmap( struct file *file, struct vm_area_struct *vma )
{
	unsigned long	region_origin = vma->vm_pgoff * PAGE_SIZE;
	unsigned long	region_length = vma->vm_end - vma->vm_start;
	unsigned long	physical_addr = fb_base + region_origin;	
	unsigned long	user_virtaddr = vma->vm_start;
	
	// sanity check: mapped region cannot expend past end of vram
	if ( region_origin + region_length > fb_size ) return -EINVAL;
	
	// let the kernel know not to try swapping out this region
	vma->vm_flags |= VM_RESERVED;

	// tell the kernel to exclude this region from core dumps
	vma->vm_flags |= VM_IO;

	// invoke kernel function that sets up the page-table entries
	if ( remap_pfn_range( vma, user_virtaddr, physical_addr >> PAGE_SHIFT,
		region_length, vma->vm_page_prot ) ) return -EAGAIN;

	return	0;  // SUCCESS
}

struct file_operations my_fops = {
				owner:	THIS_MODULE,
				llseek:	my_llseek,
				write:	my_write,
				read:	my_read,
				mmap:	my_mmap,
				};

int init_module( void )
{
	static struct pci_dev *devp = NULL;

	printk( "<1>\nInstalling \'%s\' module ", modname );
	printk( "(major=%d) \n", my_major );

	// identify the video display device
	devp = pci_find_device( VENDOR_ID, DEVICE_ID, devp );
	if ( !devp ) return -ENODEV;
	
	// determine location and length of the frame buffer
	fb_base = pci_resource_start( devp, 0 );
	fb_size = pci_resource_len( devp, 0 );
	printk( "<1>  address-range of frame-buffer: " );
	printk( "%08lX-%08lX ", fb_base, fb_base+fb_size );
	printk( "(%lu MB) \n", fb_size >> 20 );

	return	register_chrdev( my_major, modname, &my_fops );
}

void cleanup_module( void )
{
	unregister_chrdev( my_major, modname );
	printk( "<1>Removing \'%s\' module\n", modname );
}

MODULE_LICENSE("GPL");
