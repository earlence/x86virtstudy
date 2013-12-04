//-------------------------------------------------------------------
//	vmxmsrs.c
//
//	This installable Linux Kernel Module creates a pseudo-file 
//	in the '/proc' directory (named '/proc/vmxmsrs') that lets
//	users view current information in several system registers
//	related to Intel's Virtualization Technology capabilities.
//
//		compile using:  $ mmake vmxmsrs
//		install using:  $ /sbin/insmod vmxmsrs.ko
//		execute using:  $ cat /proc/vmxmsrs
//		removal using:  $ /sbin/rmmod vmxmsrs
//
//	Reference: IA-32 Intel Architecture Software Developer's
//	Manual (Volume 3B: System Programming Guide), Appendix G
//	"VMX Capability Reporting Facility"  
//
//	NOTE: Written and tested using Linux x86_64 kernel 2.6.17.
//
//	programmer: ALLAN CRUSE
//	written on: 05 APR 2007
//	revised on: 21 JUL 2008 -- for Linux kernel version 2.6.26.
//-------------------------------------------------------------------

#include <linux/module.h>	// for init_module() 
#include <linux/proc_fs.h>	// for create_proc_read_entry() 
#include <linux/utsname.h>	// for utsname()

#define EFER	0xC0000080	// Extended Feature Enable Register
#define EFCR	0x0000003A	// Extended Feature Control Register

char modname[] = "vmxmsrs";
char title[] = "VMX Capability Model-Specific Registers";
long long  efcr, efer, msr0x480[16];	

const char *legend[ 12 ] = {
			"IA32_VMX_BASIC_MSR",		// 0x480
			"IA32_VMX_PINBASED_CTLS_MSR",	// 0x481
			"IA32_VMX_PROCBASED_CTLS_MSR",	// 0x482
			"IA32_VMX_EXIT_CTLS_MSR",	// 0x483
			"IA32_VMX_ENTRY_CTLS_MSR",	// 0x484
			"IA32_VMX_MISC_MSR",		// 0x485
			"IA32_VMX_CR0_FIXED0_MSR",	// 0x486
			"IA32_VMX_CR0_FIXED1_MSR",	// 0x487
			"IA32_VMX_CR4_FIXED0_MSR",	// 0x488
			"IA32_VMX_CR4_FIXED1_MSR",	// 0x489
			"IA32_VMX_VMCS_ENUM_MSR"	// 0x48A
			};









int 
my_info( char *buf, char **start, off_t off, int count, int *eof, void *data )
{
	struct new_utsname	*uts = utsname();
	int	i, len, cr0, cr4;

	// read the current settings in Control Register 0
	asm(	" mov  %%cr0, %%rax \n mov %%eax, %0 " : "=m" (cr0) :: "ax" );

	// read the current settings in Control Register 4
	asm(	" mov  %%cr4, %%rax \n mov %%eax, %0 " : "=m" (cr4) :: "ax" );

	// read the Extended Feature Control Register
	asm(	" mov 	$0x0000003A, %%rcx	\n"\
		" rdmsr			\n"\
		" mov 	%%eax, efcr+0	\n"\
		" mov 	%%edx, efcr+4	" ::: "cx", "ax", "dx" );

	// read the Extended Feature Enable Register
	asm(	" mov	$0xC0000080, %%rcx	\n"\
		" rdmsr				\n"\
		" mov	%%eax, efer+0		\n"\
		" mov	%%edx, efer+4	" ::: "cx", "ax", "dx" );

	// Read the Extended Feature Capability Registers
	asm(	" xor	%%rbx, %%rbx 	\n"\
		" mov $0x480, %%rcx	\n"\
		".nxmsr:		\n"\
		" rdmsr			\n"\
		" mov %%eax, msr0x480+0(, %%rbx, 8) \n"\
		" mov %%edx, msr0x480+4(, %%rbx, 8) \n"\
		" inc	%%rcx		\n"\
		" inc	%%rbx		\n"\
		" cmp	$0x0A, %%rbx	\n"\
		" jbe .nxmsr		" ::: "bx", "cx", "ax", "dx" ); 

	// Display the contents of relevant registers
	len = 0;
	len += sprintf( buf+len, "\n\n\t  %s  \n\n", title );

	for (i = 0; i < 11; i++)
		{
		len += sprintf( buf+len, "\t%016llX ", msr0x480[i] );
		len += sprintf( buf+len, "= %s \n", legend[ i ] );
		}

	len += sprintf( buf+len, "\n" );
	len += sprintf( buf+len, "\t    CR0=%08X ", cr0 );
	len += sprintf( buf+len, "  EFCR=%016llX \n", efcr );
	len += sprintf( buf+len, "\t    CR4=%08X ", cr4 );
	len += sprintf( buf+len, "  EFER=%016llX \n", efer );

	len += sprintf( buf+len, "\n\t\tstation is " );
	len += sprintf( buf+len, "\'%s\' \n", uts->nodename );

	len += sprintf( buf+len, "\n" );
	return	len;
}


char	cpu_sig[ 16 ];
int	cpu_cap;

int init_module( void )
{
	printk( "<1>\nInstalling \'%s\' module\n", modname );

	// Verify processor-support for VMX capabilities
	asm(	" xor	%%eax, %%eax	\n"\
		" cpuid			\n"\
		" mov	%%ebx, cpu_sig	\n"\
		" mov	%%edx, cpu_sig+4 \n"\
		" mov	%%ecx, cpu_sig+8 \n" ::: "ax", "bx", "cx", "dx" );
	printk( " %s \n", cpu_sig );		
	if ( strncmp( cpu_sig, "GenuineIntel", 12 ) != 0 ) return -ENODEV;
	asm(	" xor	%%eax, %%eax	\n"\
		" inc	%%eax		\n"\
		" cpuid			\n"\
		" mov	%%ecx, cpu_cap	" ::: "ax", "bx", "cx", "dx" );
	if ( ( cpu_cap & (1<<5) ) == 0 ) 
		{ 
		printk( " processor lacks VMX support \n" ); 
		return -ENODEV;
		}
	else	printk( " processor supports VMX capabilities \n" );

	create_proc_read_entry( modname, 0, NULL, my_info, NULL );
	return	0;  //SUCCESS
}


void cleanup_module( void )
{
	remove_proc_entry( modname, NULL );

	printk( "<1>Removing \'%s\' module\n", modname );
}

MODULE_LICENSE("GPL"); 

