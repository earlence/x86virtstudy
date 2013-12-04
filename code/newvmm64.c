//-------------------------------------------------------------------
//	newvmm64.c
//
//	This is a fresh implementation of our former virtual-machine
//	manager, crafted as a 'character-mode' device-driver for our 
//	Linux x86_64 Intel-based platform.  Several pseudo-files are
//	implemented, to assist us with debugging and with clarifying 
//	the behavior of various 'Virtualization Technology' options. 
//	
//	     $ cat /proc/vmmhelp    # shows the list of pseudo-files
//
//	NOTE: With this module, our 'e820info.cpp' application could
//	successfully execute ROM-BIOS calls to display a memory-map.
//
//	programmer: ALLAN CRUSE 
//	date begun: 25 MAY 2008
//	completion: 10 JUN 2008
//	revised on: 28 JUL 2008 -- for Linux kernel version 2.6.26.
//	revised on: 30 JUL 2008 -- for cleanup of vmexit conditions
//	revised on: 04 AUG 2008 -- fix for machines with > 4GB ram
//-------------------------------------------------------------------

#include <linux/module.h>	// for init_module() 
#include <linux/proc_fs.h>	// for create_proc_read_entry() 
#include <linux/mm.h>		// for remap_pfn_range()
#include <asm/io.h>		// for virt_to_phys()
#include <asm/uaccess.h>	// for copy_from_user()
#include "machine.h"		// storage for the VMCS fields
#include "myvmx.h"		// for 'regs_ia32' structure 

#define MSR_VMX_CAPS	0x480	// index for VMX Capabilities MSRs
#define EFER_MSR   0xC0000080	// index for Extended Feature Enable
#define EFCR_MSR   0x0000003A	// index for Extended Feature Control

#define SEGMENT_SIZE 0x010000	// address-reach for 16-bit offsets
#define LEGACY_REACH 0x110000	// address-reach in 80386 REAL-mode
#define LEGACY_HIMEM 0x100000	// address-reach in 80386 VM86-mode
#define LEGACY_VIDEO 0x0A0000	// address-base in VGA graphics mode
#define KMEM_LENGTH  0x100000	// one-megabyte allocation of memory

#define __SELECTOR_TASK 0x0008
#define __SELECTOR_LDTR 0x0010
#define __SELECTOR_CODE 0x0004
#define __SELECTOR_DATA 0x000C
#define __SELECTOR_VRAM 0x0014
#define __SELECTOR_FLAT 0x001C

#define VMXON_OFFSET	0x0000
#define GUEST_OFFSET	0x1000
#define PAGE_DIR_OFFSET	0x2000
#define PAGE_TBL_OFFSET 0x3000
#define IOBITMAP_OFFSET 0x4000
#define IDT_KERN_OFFSET 0x6000
#define GDT_KERN_OFFSET 0x6800
#define LDT_KERN_OFFSET 0x6A00
#define TSS_KERN_OFFSET 0x6C00
#define SS0_KERN_OFFSET 0xA000
#define ISR_KERN_OFFSET 0xA000
#define MSR_KERN_OFFSET	0xC000


// function prototypes for device-driver methods
int my_ioctl( struct inode *, struct file *, unsigned int, unsigned long );
int my_mmap( struct file *, struct vm_area_struct *vma );
int my_open( struct inode *, struct file * );


struct file_operations	my_fops = {
				owner:		THIS_MODULE,
				ioctl:		my_ioctl,
				open:		my_open,
				mmap:		my_mmap,
				};

char modname[] = "newvmm64";
char devname[] = "vmm";
char iname_caps[] = "vmmcaps";
char iname_ctls[] = "vmmctls";
char iname_host[] = "vmmhost";
char iname_task[] = "vmmguest";
char iname_read[] = "vmmread";
char iname_mmap[] = "vmmmmap";
char iname_help[] = "vmmhelp";
int	my_major = 88;
char	cpu_oem[ 16 ];
int	cpu_features;
unsigned long long  msr0x480[ 11 ];
unsigned long long  efcr, efer;
unsigned long	    original_CR0;
unsigned long	    original_CR4;
void	*kmem;
unsigned long long  lower_region;
unsigned long long  himem_region;
unsigned long long  reach_region;

unsigned long long  vmxon_region;
unsigned long long  guest_region;
unsigned long long  pgdir_region;
unsigned long long  pgtbl_region;
unsigned long long  iomap_region;
unsigned long long  g_IDT_region;
unsigned long long  g_GDT_region;
unsigned long long  g_LDT_region;
unsigned long long  g_TSS_region;
unsigned long long  g_SS0_region;
unsigned long long  g_ISR_region;
unsigned long long  h_MSR_region;

regs_ia32    vm;
int retval, extints, nmiints;
unsigned long	guest_RAX, guest_RBX, guest_RCX, guest_RDX;
unsigned long	guest_RBP, guest_RSI, guest_RDI;
unsigned short	host_gdtr[5], host_idtr[5], host_ldtr;
unsigned long	msr_index, msr_value;
void		*next_host_MSR_entry;


int my_info_help( char *buf, char **start, off_t off, int count, 
							int *eof, void *data )
{
	int	len = 0;

	len += sprintf( buf+len, "\n\n\n\n\n    " );
	len += sprintf( buf+len, "List of our diagnostic pseudo-files: \n" );

	len += sprintf( buf+len, "\n\t /proc/%s - ", iname_caps );
	len += sprintf( buf+len, "view processor's VMX-Capability registers" );
	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, "\n\t /proc/%s - ", iname_ctls );
	len += sprintf( buf+len, "view a selection of the VMX controls " );
	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, "\n\t /proc/%s - ", iname_host );
	len += sprintf( buf+len, "view the Host's register-state " );
	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, "\n\t /proc/%s - ", iname_task );
	len += sprintf( buf+len, "view the Guest's register-state " );
	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, "\n\t /proc/%s - ", iname_read );
	len += sprintf( buf+len, "view the VMX Read-Only registers " );
	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, "\n\t /proc/%s - ", iname_mmap );
	len += sprintf( buf+len, "view map of driver's memory regions" );
	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, "\n\t /proc/%s - ", iname_help );
	len += sprintf( buf+len, "view this list of driver's pseudo-files" );
	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, "\n\n\n\n" );
	return	len;
}

char *legend[] = {	"IA32_VMX_BASIC_MSR",		// 0x480
			"IA32_VMX_PINBASED_CTLS_MSR",	// 0x481
			"IA32_VMX_PROCBASED_CTLS_MSR",	// 0x482
			"IA32_VMX_EXIT_CTLS_MSR",	// 0x483
			"IA32_VMX_ENTRY_CTLS_MSR",	// 0x484
			"IA32_VMX_MISC_MSR",		// 0x485
			"IA32_VMX_CR0_FIXED0_MSR",	// 0x486
			"IA32_VMX_CR0_FIXED1_MSR",	// 0x487
			"IA32_VMX_CR4_FIXED0_MSR",	// 0x488
			"IA32_VMX_CR4_FIXED1_MSR",	// 0x489
			"IA32_VMX_VMCS_ENUM_MSR",	// 0x48A
		};

int my_info_caps( char *buf, char **start, off_t off, int count, 
							int *eof, void *data )
{
	int	i, len = 0;

	len += sprintf( buf+len, "\n\n\n " );
	len += sprintf( buf+len, "VMX-Capability Model-Specific Registers" );
	len += sprintf( buf+len, "\n\n" );
	for (i = 0; i < 11; i++)
		{
		len += sprintf( buf+len, "     %016llX ", msr0x480[ i ] );
		len += sprintf( buf+len, "= %s \n", legend[ i ] );
		}
	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, "\n" );
	len += sprintf( buf+len, " original_CR0=%08lX ", original_CR0 );
	len += sprintf( buf+len, " PG=%ld", (original_CR0 >> 31)&1 );
	len += sprintf( buf+len, " CD=%ld", (original_CR0 >> 30)&1 );
	len += sprintf( buf+len, " NW=%ld", (original_CR0 >> 29)&1 );
	len += sprintf( buf+len, " AM=%ld", (original_CR0 >> 18)&1 );
	len += sprintf( buf+len, " WP=%ld", (original_CR0 >> 16)&1 );
	len += sprintf( buf+len, " NE=%ld", (original_CR0 >> 5)&1 );
	len += sprintf( buf+len, " ET=%ld", (original_CR0 >> 4)&1 );
	len += sprintf( buf+len, " TS=%ld", (original_CR0 >> 3)&1 );
	len += sprintf( buf+len, " EM=%ld", (original_CR0 >> 2)&1 );
	len += sprintf( buf+len, " MP=%ld", (original_CR0 >> 1)&1 );
	len += sprintf( buf+len, " PE=%ld", (original_CR0 >> 0)&1 );
	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, " original_CR4=%08lX ", original_CR4 );
	len += sprintf( buf+len, " VMXE=%ld", (original_CR4 >> 13)&1 );
	len += sprintf( buf+len, " PGE=%ld", (original_CR4 >> 7)&1 );
	len += sprintf( buf+len, " MCE=%ld", (original_CR4 >> 6)&1 );
	len += sprintf( buf+len, " PAE=%ld", (original_CR4 >> 5)&1 );
	len += sprintf( buf+len, " PSE=%ld", (original_CR4 >> 4)&1 );
	len += sprintf( buf+len, " DE=%ld",  (original_CR4 >> 3)&1 );
	len += sprintf( buf+len, " TSD=%ld", (original_CR4 >> 2)&1 );
	len += sprintf( buf+len, " PVI=%ld", (original_CR4 >> 1)&1 );
	len += sprintf( buf+len, " VME=%ld", (original_CR4 >> 0)&1 );
	len += sprintf( buf+len, "\n\n" );

	len += sprintf( buf+len, "\n physical address of userspace: " );
	len += sprintf( buf+len, "0x%08llX \n", lower_region );
	len += sprintf( buf+len, "\n\n" );
	return	len;
}


int my_info_mmap( char *buf, char **start, off_t off, int count,
						int *eof, void *data )
{
	int	len = 0;

	len += sprintf( buf+len, "\n\n\n " );
	len += sprintf( buf+len, "Physical addresses for VM memory-regions" );
	len += sprintf( buf+len, "\n\n " );

	len += sprintf( buf+len, "\n" );
	len += sprintf( buf+len, "\t lower_region=%08llX \n", lower_region );
	len += sprintf( buf+len, "\t himem_region=%08llX \n", himem_region );
	len += sprintf( buf+len, "\n" );
	len += sprintf( buf+len, "\t vmxon_region=%08llX \n", vmxon_region );
	len += sprintf( buf+len, "\t guest_region=%08llX \n", guest_region );
	len += sprintf( buf+len, "\t pgdir_region=%08llX \n", pgdir_region );
	len += sprintf( buf+len, "\t pgtbl_region=%08llX \n", pgtbl_region );
	len += sprintf( buf+len, "\t iomap_region=%08llX \n", iomap_region );
	len += sprintf( buf+len, "\t g_IDT_region=%08llX \n", g_IDT_region );
	len += sprintf( buf+len, "\t g_GDT_region=%08llX \n", g_GDT_region );
	len += sprintf( buf+len, "\t g_LDT_region=%08llX \n", g_LDT_region );
	len += sprintf( buf+len, "\t g_TSS_region=%08llX \n", g_TSS_region );
	len += sprintf( buf+len, "\t g_SS0_region=%08llX \n", g_SS0_region );
	len += sprintf( buf+len, "\t g_ISR_region=%08llX \n", g_ISR_region );
	len += sprintf( buf+len, "\t h_MSR_region=%08llX \n", h_MSR_region );
	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, "\n\n" );
	return	len;
}


int my_info_ctls( char *buf, char **start, off_t off, int count,
							int *eof, void *data )
{
	int	len = 0;

	len += sprintf( buf+len, "\n VMX Execution Controls \n\n" );

	len += sprintf( buf+len, " 0x%08X ", control_VMX_pin_based );
	len += sprintf( buf+len, "= control_VMX_pin_based \n" );

	len += sprintf( buf+len, " 0x%08X ", control_VMX_cpu_based );
	len += sprintf( buf+len, "= control_VMX_cpu_based \n" );

	len += sprintf( buf+len, " 0x%08X ", control_exception_bitmap );
	len += sprintf( buf+len, "= control_exception_bitmap \n" );

	len += sprintf( buf+len, " 0x%08X ", control_pagefault_errorcode_mask );
	len += sprintf( buf+len, "= control_pagefault_errorcode_mask \n" );

	len += sprintf( buf+len, " 0x%08X ", control_pagefault_errorcode_match);
	len += sprintf( buf+len, "= control_pagefault_errorcode_match \n" );

	len += sprintf( buf+len, " 0x%08X ", control_CR3_target_count );
	len += sprintf( buf+len, "= control_CR3_target_count \n" );

	len += sprintf( buf+len, " 0x%08X ", control_VM_exit_controls );
	len += sprintf( buf+len, "= control_VM_exit_controls \n" );

	len += sprintf( buf+len, " 0x%08X ", control_VM_entry_controls );
	len += sprintf( buf+len, "= control_VM_entry_controls \n" );

	len += sprintf( buf+len, " 0x%08X ", 
			control_VM_entry_interruption_information );
	len += sprintf( buf+len, 
			"= control_VM_entry_interruption_information \n" );

	len += sprintf( buf+len, " 0x%08X ", 
			control_VM_entry_exception_errorcode );
	len += sprintf( buf+len, 
			"= control_VM_entry_exception_errorcode \n" );

	len += sprintf( buf+len, " 0x%08X ", 
			control_VM_entry_instruction_length );
	len += sprintf( buf+len, 
			"= control_VM_entry_instruction_length \n" );

	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, " 0x%016llX ", control_CR0_mask );
	len += sprintf( buf+len, "= control_CR0_mask \n" );

	len += sprintf( buf+len, " 0x%016llX ", control_CR4_mask );
	len += sprintf( buf+len, "= control_CR4_mask \n" );

	len += sprintf( buf+len, " 0x%016llX ", control_CR0_shadow );
	len += sprintf( buf+len, "= control_CR0_shadow \n" );

	len += sprintf( buf+len, " 0x%016llX ", control_CR4_shadow );
	len += sprintf( buf+len, "= control_CR4_shadow \n" );

	len += sprintf( buf+len, " 0x%016llX ", control_CR3_target0 );
	len += sprintf( buf+len, "= control_CR3_target0 \n" );

	len += sprintf( buf+len, " 0x%016llX ", control_CR3_target1 );
	len += sprintf( buf+len, "= control_CR3_target1 \n" );

	len += sprintf( buf+len, " 0x%016llX ", control_CR3_target2 );
	len += sprintf( buf+len, "= control_CR3_target2 \n" );

	len += sprintf( buf+len, " 0x%016llX ", control_CR3_target3 );
	len += sprintf( buf+len, "= control_CR3_target3 \n" );

	len += sprintf( buf+len, "\n" );
	return	len;
}

int my_info_host( char *buf, char **start, off_t off, int count,
						int *eof, void *data )
{
	int	len = 0;

	len += sprintf( buf+len, "\n\n\n\n\n VMX Host State \n\n" );

	len += sprintf( buf+len, " CR0=%016llX ", host_CR0 );
	len += sprintf( buf+len, " FS_base=%016llX ", host_FS_base );
	len += sprintf( buf+len, " GDTR_base=%016llX ", host_GDTR_base );
	len += sprintf( buf+len, "\n" );
	len += sprintf( buf+len, " CR3=%016llX ", host_CR3 );
	len += sprintf( buf+len, " GS_base=%016llX ", host_GS_base );
	len += sprintf( buf+len, " IDTR_base=%016llX ", host_IDTR_base );
	len += sprintf( buf+len, "\n" );
	len += sprintf( buf+len, " CR4=%016llX ", host_CR4 );
	len += sprintf( buf+len, " TR_base=%016llX ", host_TR_base );
	len += sprintf( buf+len, " SYSENTER_CS=%08X ", host_SYSENTER_CS );
	len += sprintf( buf+len, " TR=%04X ", host_TR_selector );
	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, " RSP=%016llX ", host_RSP );
	len += sprintf( buf+len, " SS=%04X ", host_SS_selector );
	len += sprintf( buf+len, " DS=%04X ", host_DS_selector );
	len += sprintf( buf+len, "FS=%04X ", host_FS_selector );
	len += sprintf( buf+len, " SYSENTER_ESP=%016llX ", host_SYSENTER_ESP );
	len += sprintf( buf+len, "\n" );
	len += sprintf( buf+len, " RIP=%016llX ", host_RIP );
	len += sprintf( buf+len, " CS=%04X ", host_CS_selector );
	len += sprintf( buf+len, " ES=%04X ", host_ES_selector );
	len += sprintf( buf+len, "GS=%04X ", host_GS_selector );
	len += sprintf( buf+len, " SYSENTER_EIP=%016llX ", host_SYSENTER_EIP );
	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, "\n\n" );
	len += sprintf( buf+len, " control_VM_exit_MSR_load_count =" );
	len += sprintf( buf+len, " %d \n\n", control_VM_exit_MSR_load_count );

	msr_index = MSR_STAR;
	asm(	" mov	msr_index, %%rcx	\n"\
	 	" rdmsr				\n"\
		" mov	%%eax, msr_value+0	\n"\
		" mov	%%edx, msr_value+4	\n"\
		::: "ax", "cx", "dx" );
	len += sprintf( buf+len, "    %016lX = MSR_STAR \n", msr_value ); 

	msr_index = MSR_CSTAR;
	asm(	" mov	msr_index, %%rcx	\n"\
	 	" rdmsr				\n"\
		" mov	%%eax, msr_value+0	\n"\
		" mov	%%edx, msr_value+4	\n"\
		::: "ax", "cx", "dx" );
	len += sprintf( buf+len, "    %016lX = MSR_CSTAR \n", msr_value ); 

	msr_index = MSR_LSTAR;
	asm(	" mov	msr_index, %%rcx	\n"\
	 	" rdmsr				\n"\
		" mov	%%eax, msr_value+0	\n"\
		" mov	%%edx, msr_value+4	\n"\
		::: "ax", "cx", "dx" );
	len += sprintf( buf+len, "    %016lX = MSR_LSTAR \n", msr_value ); 

	msr_index = MSR_SYSCALL_MASK;
	asm(	" mov	msr_index, %%rcx	\n"\
	 	" rdmsr				\n"\
		" mov	%%eax, msr_value+0	\n"\
		" mov	%%edx, msr_value+4	\n"\
		::: "ax", "cx", "dx" );
	len += sprintf( buf+len, "    %016lX = MSR_SYSCALL_MASK \n", 
								msr_value ); 
	msr_index = MSR_KERNEL_GS_BASE;
	asm(	" mov	msr_index, %%rcx	\n"\
	 	" rdmsr				\n"\
		" mov	%%eax, msr_value+0	\n"\
		" mov	%%edx, msr_value+4	\n"\
		::: "ax", "cx", "dx" );
	len += sprintf( buf+len, "    %016lX = MSR_KERNEL_GS_BASE \n", 
								msr_value ); 
	len += sprintf( buf+len, "\n\n\n" );
	return	len;
}

int my_info_task( char *buf, char **start, off_t off, int count, 
							int *eof, void *data )
{
	int	len = 0;

	len += sprintf( buf+len, "\n\n VMX Guest State \n\n" );

	len += sprintf( buf+len, " CR0=%016llX ", guest_CR0 );
	len += sprintf( buf+len, " CR3=%016llX ", guest_CR3 );
	len += sprintf( buf+len, " CR4=%016llX ", guest_CR4 );
	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, "\n" );
	len += sprintf( buf+len, " RSP=%016llX ", guest_RSP );
	len += sprintf( buf+len, " SYSENTER_ESP=%016llX ", host_SYSENTER_ESP );
	len += sprintf( buf+len, "\n" );
	len += sprintf( buf+len, " RIP=%016llX ", guest_RIP );
	len += sprintf( buf+len, " SYSENTER_EIP=%016llX ", guest_SYSENTER_EIP );
	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, " DR7=%016llX ", guest_DR7 );
	len += sprintf( buf+len, " SYSENTER_CS=%08X ", guest_SYSENTER_CS );
	len += sprintf( buf+len, " RFLAGS=%016llX ", guest_RFLAGS );
	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, "\n   ES=%04X ", guest_ES_selector );
	len += sprintf( buf+len, " [ base=%016llX", guest_ES_base );
	len += sprintf( buf+len, " limit=%08X", guest_ES_limit );
	len += sprintf( buf+len, " rights=%08X ] ", guest_ES_access_rights );

	len += sprintf( buf+len, "\n   CS=%04X ", guest_CS_selector );
	len += sprintf( buf+len, " [ base=%016llX", guest_CS_base );
	len += sprintf( buf+len, " limit=%08X", guest_CS_limit );
	len += sprintf( buf+len, " rights=%08X ] ", guest_CS_access_rights );

	len += sprintf( buf+len, "\n   SS=%04X ", guest_SS_selector );
	len += sprintf( buf+len, " [ base=%016llX", guest_SS_base );
	len += sprintf( buf+len, " limit=%08X", guest_SS_limit );
	len += sprintf( buf+len, " rights=%08X ] ", guest_SS_access_rights );

	len += sprintf( buf+len, "\n   DS=%04X ", guest_DS_selector );
	len += sprintf( buf+len, " [ base=%016llX", guest_DS_base );
	len += sprintf( buf+len, " limit=%08X", guest_DS_limit );
	len += sprintf( buf+len, " rights=%08X ] ", guest_DS_access_rights );

	len += sprintf( buf+len, "\n   FS=%04X ", guest_FS_selector );
	len += sprintf( buf+len, " [ base=%016llX", guest_FS_base );
	len += sprintf( buf+len, " limit=%08X", guest_FS_limit );
	len += sprintf( buf+len, " rights=%08X ] ", guest_FS_access_rights );

	len += sprintf( buf+len, "\n   GS=%04X ", guest_GS_selector );
	len += sprintf( buf+len, " [ base=%016llX", guest_GS_base );
	len += sprintf( buf+len, " limit=%08X", guest_GS_limit );
	len += sprintf( buf+len, " rights=%08X ] ", guest_GS_access_rights );

	len += sprintf( buf+len, "\n LDTR=%04X ", guest_LDTR_selector );
	len += sprintf( buf+len, " [ base=%016llX", guest_LDTR_base );
	len += sprintf( buf+len, " limit=%08X", guest_LDTR_limit );
	len += sprintf( buf+len, " rights=%08X ] ", guest_LDTR_access_rights );

	len += sprintf( buf+len, "\n   TR=%04X ", guest_TR_selector );
	len += sprintf( buf+len, " [ base=%016llX", guest_TR_base );
	len += sprintf( buf+len, " limit=%08X", guest_TR_limit );
	len += sprintf( buf+len, " rights=%08X ] ", guest_TR_access_rights );

	len += sprintf( buf+len, "\n      GDTR " );
	len += sprintf( buf+len, " [ base=%016llX", guest_GDTR_base );
	len += sprintf( buf+len, " limit=%08X ] ", guest_GDTR_limit );

	len += sprintf( buf+len, "\n      IDTR " );
	len += sprintf( buf+len, " [ base=%016llX", guest_IDTR_base );
	len += sprintf( buf+len, " limit=%08X ] ", guest_IDTR_limit );
	len += sprintf( buf+len, "\n" );
	
	len += sprintf( buf+len, "\n" );
	len += sprintf( buf+len, " EAX=%08lX ", guest_RAX );
	len += sprintf( buf+len, " ECX=%08lX ", guest_RCX );
	len += sprintf( buf+len, " ESI=%08lX ", guest_RSI );
	len += sprintf( buf+len, " ESP=%08llX ", guest_RSP );
	len += sprintf( buf+len, "  extints=%d ", extints );
	len += sprintf( buf+len, "\n" );
	len += sprintf( buf+len, " EBX=%08lX ", guest_RBX );
	len += sprintf( buf+len, " EDX=%08lX ", guest_RDX );
	len += sprintf( buf+len, " EDI=%08lX ", guest_RDI );
	len += sprintf( buf+len, " EBP=%08lX ", guest_RBP );
	len += sprintf( buf+len, "  nmiints=%d ", nmiints );
	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, "\n" );
	return	len;
}

char *error_cause[] = {	"-----",				// 0
			"VMCALL while in VMX root operation", 	// 1
			"VMCLEAR with invalid address",		// 2
			"VMCLEAR with VMXON pointer",		// 3
			"VMLAUNCH with non-clear VCMS",		// 4
			"VMRESUME with non-launched VMCS",	// 5
			"VMRESUME with corrupted VMCS",		// 6
			"VM entry with invalid controls",	// 7
			"VM entry with invalid host-state",	// 8
			"VMPTRLD with invalid address",		// 9
			"VMPTRLD with VMXON pointer",		// 10
			"VMPTRLD with incorect revision-ID",	// 11
			"VMREAD/VMWRITE unsupported item", 	// 12
			"VMWRITE to read-only component",	// 13
			"----",					// 14
			"VMXON while in VMX root operation",	// 15
			"VM entry with invalid exec-pointer",	// 16
			"VM entry with non-launched exec-ptr",	// 17
			"VM entry with exec-ptr not vmxon",	// 18
			"VMCALL with non-clear VMCS (smm)",	// 19 		
			"VMCALL with invalid VM-exit ctrls",	// 20
			"----",					// 21
			"VMCALL with incorrect MSEG rev-id",	// 22
			"VMXOFF during dual-monitor handling",	// 23
			"VMCALL with invalid SMM-monitor",	// 24
			"VM entry with invalid VM-exec ctls",	// 25
			"VM entry with events blocked",		// 26
			};

char *exit_reason[] = {	"Exception or Non-Maskable Interrupt",	// 0
			"External Interrupt",			// 1
			"Triple Fault",				// 2
			"INIT signal arrived",			// 3
			"Start-up IPI arrived",			// 4
			"I/O System-Management Interrupt",	// 5
			"Non-I/O System-Management Interrupt",	// 6
			"Interrupt Window",			// 7
			"NMI Window",				// 8
			"Task-Switch attempted",		// 9
			"CPUID-instruction encountered",	// 10
			"---",					// 11
			"HLT-instruction encountered",		// 12	
			"INVD-instruction encountered",		// 13
			"INVLPG-instruction encountered",	// 14
			"RDPMC-instruction encountered",	// 15
			"RDTSC-instruction encountered",	// 16
			"RSM-instruction encountered",		// 17	
			"VMCALL-instruction encountered",	// 18
			"VMCLEAR-instruction encountered",	// 19
			"VMLAUNCH-instruction encountered",	// 20
			"VMPTRLD-instruction encountered",	// 21
			"VMPTRST-instruction encountered",	// 22
			"VMREAD-instruction encountered",	// 23
			"VMRESUME-instruction encountered",	// 24
			"VMWRITE-instruction encountered",	// 25
			"VMXOFF-instruction encountered",	// 26
			"VMXON-instruction encountered",	// 27
			"Control-register access attempted",	// 28
			"Debug-register access attempted", 	// 29
			"I/O-instruction attempted",		// 30
			"RDMSR-instruction encountered",	// 31
			"WRMSR-instruction encountered",	// 32
			"VM-entry failure - guest state",	// 33
			"VM-entry failure - MSR loading",	// 34
			"---",					// 35
			"MWAIT-instruction encountered",	// 36
			"---",					// 37
			"---",					// 38
			"MONITOR-instruction encountered",	// 39
			"PAUSE-instruction encountered",	// 40
			"VM-entry failure - machine check",	// 41
			"---",					// 42
			"TPR below threshold",			// 43
			};


int my_info_read( char *buf, char **start, off_t off, int count,
						int *eof, void *data )
{
	int	len = 0;

	len += sprintf( buf+len, "\n\n VMX Read-Only Fields \n\n" );

	len += sprintf( buf+len, "        " );
	len += sprintf( buf+len, " 0x%08X ", info_vminstr_error );
	len += sprintf( buf+len, "= VM_instruction_error \n" );

	len += sprintf( buf+len, "        " );
	len += sprintf( buf+len, " 0x%08X ", info_vmexit_reason );
	len += sprintf( buf+len, "= VM_Exit_Reason \n" );

	len += sprintf( buf+len, "\n" );

	if ( info_vminstr_error )
		len += sprintf( buf+len, "     %s  ",
			error_cause[ (unsigned short)info_vminstr_error ] );	
	else
	{
	if ( info_vmexit_reason & (1<<31) )
		len += sprintf( buf+len, "VM-Entry Failure " );
	if ( info_vmexit_reason & (1<<29) )
		len += sprintf( buf+len, "VM-Exit from VMX root operation " );
	len += sprintf( buf+len, " %s  ", 
			exit_reason[ (unsigned short)info_vmexit_reason ] );	
	}
	len += sprintf( buf+len, "\n\n" );
	

	len += sprintf( buf+len, "\n" );
	len += sprintf( buf+len, "        " );
	len += sprintf( buf+len, " 0x%08X ", info_vmexit_interrupt_information);
	len += sprintf( buf+len, "= VM_Exit_Interrupt_Information \n" );

	len += sprintf( buf+len, "        " );
	len += sprintf( buf+len, " 0x%08X ", info_vmexit_interrupt_error_code);
	len += sprintf( buf+len, "= VM_Exit_Interrupt_Error_Code \n" );

	len += sprintf( buf+len, "        " );
	len += sprintf( buf+len, " 0x%08X ", info_IDT_vectoring_information );
	len += sprintf( buf+len, "= VM_IDT_vectoring_information \n" );

	len += sprintf( buf+len, "        " );
	len += sprintf( buf+len, " 0x%08X ", info_IDT_vectoring_error_code  );
	len += sprintf( buf+len, "= VM_IDT_vectoring_error_code \n" );

	len += sprintf( buf+len, "        " );
	len += sprintf( buf+len, " 0x%08X ", info_vmexit_instruction_length );
	len += sprintf( buf+len, "= VM_Exit_instruction_length \n" );

	len += sprintf( buf+len, "        " );
	len += sprintf( buf+len, " 0x%08X ", info_vmx_instruction_information);
	len += sprintf( buf+len, "= VMX_instruction_information \n" );

	len += sprintf( buf+len, "\n" );

	len += sprintf( buf+len, " 0x%016llX ", info_exit_qualification );
	len += sprintf( buf+len, "= Exit_Qualification \n" );

	len += sprintf( buf+len, " 0x%016llX ", info_IO_RCX );
	len += sprintf( buf+len, "= IO_RCX \n" );

	len += sprintf( buf+len, " 0x%016llX ", info_IO_RSI );
	len += sprintf( buf+len, "= IO_RSI \n" );

	len += sprintf( buf+len, " 0x%016llX ", info_IO_RDI );
	len += sprintf( buf+len, "= IO_RDI \n" );

	len += sprintf( buf+len, " 0x%016llX ", info_IO_RIP );
	len += sprintf( buf+len, "= IO_RIP \n" );

	len += sprintf( buf+len, " 0x%016llX ", info_guest_linear_address );
	len += sprintf( buf+len, "= Guest_linear_address \n" );

	len += sprintf( buf+len, "\n" );
	return	len;
}


void set_CR4_vmxe( void *dummy )
{
	asm(	" mov  %%cr4, %%rax	\n"\
		" bts  $13, %%rax	\n"\
		" mov  %%rax, %%cr4	" ::: "ax" );
}
		
void clear_CR4_vmxe( void *dummy )
{
	asm(	" mov  %%cr4, %%rax	\n"\
		" btr  $13, %%rax	\n"\
		" mov  %%rax, %%cr4	" ::: "ax" );
}


static int __init newvmm32_init( void )
{

	// confirm module installation and show device-major number
	printk( "<1>\nInstalling \'%s\' module ", modname );
	printk( "(major=%d) \n", my_major );

	// verify cpu support for Intel Virtualization Technology
	asm(	" xor	%%eax, %%eax		\n"\
		" cpuid				\n"\
		" mov	%%ebx, cpu_oem+0	\n"\
		" mov	%%edx, cpu_oem+4	\n"\
		" mov	%%ecx, cpu_oem+8	\n"\
		::: "ax", "bx", "cx", "dx" );
	printk( " processor is \'%s\' \n", cpu_oem );

	if ( strncmp( cpu_oem, "GenuineIntel", 12 ) == 0 )
		asm(	" mov	$1, %%eax		\n"\
			" cpuid				\n"\
			" mov	%%ecx, cpu_features	\n"\
			::: "ax", "bx", "cx", "dx" );
	if ( ( cpu_features & (1<<5) ) == 0 )
		{
		printk( " Virtualization Technology is unsupported \n" );
		return	-ENODEV;
		}
	else	printk( " Virtualization Technology is supported \n" );

	// read contents of the VMX-Capability Model-Specific Registers
	asm(	" xor	%%rbx, %%rbx			\n"\
		" mov	%0, %%rcx			\n"\
		"nxcap:					\n"\
		" rdmsr					\n"\
		" mov	%%eax, msr0x480+0(, %%rbx, 8 )	\n"\
		" mov	%%edx, msr0x480+4(, %%rbx, 8 )	\n"\
		" inc	%%rcx				\n"\
		" inc	%%rbx				\n"\
		" cmp	$11, %%rbx			\n"\
		" jb	nxcap				\n"\
		:: "i" (MSR_VMX_CAPS) : "ax", "bx", "cx", "dx" );

	// preserve original contents of Control Registers CR0, CR4
	asm(" mov %%cr0, %%rax \n mov %%rax, original_CR0 " ::: "ax" );
	asm(" mov %%cr4, %%rax \n mov %%rax, original_CR4 " ::: "ax" );

	// preserve original contents of Extended Feature Control Register
	asm(	" mov	%0, %%ecx			\n"\
		" rdmsr					\n"\
		" mov	%%eax, efcr+0			\n"\
		" mov	%%edx, efcr+4			\n"\
		:: "i" (EFCR_MSR) : "ax", "cx", "dx" );

	// preserve original contents of Extended Feature Enable Register
	asm(	" mov	%0, %%ecx			\n"\
		" rdmsr					\n"\
		" mov	%%eax, efer+0			\n"\
		" mov	%%edx, efer+4			\n"\
		:: "i" (EFER_MSR) : "ax", "cx", "dx" );


	// allocate page-aligned non-pageable kernel memory
////	kmem = kzalloc( KMEM_LENGTH, GFP_KERNEL );
kmem = kzalloc( KMEM_LENGTH, GFP_KERNEL | GFP_DMA ); // <-- 04 AUG 2008
	if ( !kmem ) return -ENOMEM;
	lower_region = virt_to_phys( kmem );
	himem_region = lower_region + LEGACY_VIDEO;
	reach_region = himem_region + SEGMENT_SIZE;

	vmxon_region = reach_region + VMXON_OFFSET;	
	guest_region = reach_region + GUEST_OFFSET;	
	pgdir_region = reach_region + PAGE_DIR_OFFSET;	
	pgtbl_region = reach_region + PAGE_TBL_OFFSET;	
	iomap_region = reach_region + IOBITMAP_OFFSET;	
	g_IDT_region = reach_region + IDT_KERN_OFFSET;
	g_GDT_region = reach_region + GDT_KERN_OFFSET;
	g_LDT_region = reach_region + LDT_KERN_OFFSET;
	g_TSS_region = reach_region + TSS_KERN_OFFSET;
	g_SS0_region = reach_region + SS0_KERN_OFFSET;
	g_ISR_region = reach_region + ISR_KERN_OFFSET;
	h_MSR_region = reach_region + MSR_KERN_OFFSET;

	// enable virtual-machine extensions (bit 13 in CR4)
	set_CR4_vmxe( NULL );
	smp_call_function( set_CR4_vmxe, NULL, 1, 1 );

	create_proc_read_entry( iname_mmap, 0, NULL, my_info_mmap, NULL );
	create_proc_read_entry( iname_read, 0, NULL, my_info_read, NULL );
	create_proc_read_entry( iname_task, 0, NULL, my_info_task, NULL );
	create_proc_read_entry( iname_host, 0, NULL, my_info_host, NULL );
	create_proc_read_entry( iname_ctls, 0, NULL, my_info_ctls, NULL );
	create_proc_read_entry( iname_caps, 0, NULL, my_info_caps, NULL );
	create_proc_read_entry( iname_help, 0, NULL, my_info_help, NULL );
	return	register_chrdev( my_major, devname, &my_fops );
}


static void __exit newvmm32_exit(void )
{
	unregister_chrdev( my_major, devname );
	remove_proc_entry( iname_caps, NULL );
	remove_proc_entry( iname_ctls, NULL );
	remove_proc_entry( iname_host, NULL );
	remove_proc_entry( iname_task, NULL );
	remove_proc_entry( iname_read, NULL );
	remove_proc_entry( iname_mmap, NULL );
	remove_proc_entry( iname_help, NULL );

	// disable virtual-machine extensions (bit 13 in CR4)
	smp_call_function( clear_CR4_vmxe, NULL, 1, 1 );
	clear_CR4_vmxe( NULL );

	kfree( kmem );

	printk( "<1>Removing \'%s\' module\n", modname );
}

module_init( newvmm32_init );
module_exit( newvmm32_exit );
MODULE_LICENSE("GPL"); 

int my_mmap( struct file *file, struct vm_area_struct *vma )
{
	unsigned long	user_virtaddr = vma->vm_start;
	unsigned long	region_length = vma->vm_end - vma->vm_start;
	unsigned long	physical_addr = virt_to_phys( kmem ), pfn;
	pgprot_t	pgprot = vma->vm_page_prot;

	// we require prescribed parameter-values from our client
	if ( user_virtaddr != 0x00000000L ) return -EINVAL;
	if ( region_length != LEGACY_REACH ) return -EINVAL;

	// let the kernel know not to try swapping out this region
	vma->vm_flags |= VM_RESERVED;

	//---------------------------------------------------------------
	// ask the kernel to add page-table entries to 'map' these areas
	//---------------------------------------------------------------

	// map the 640KB lower region to address-range 0x00000-0x9FFFF
	pfn = (physical_addr >> PAGE_SHIFT);
	if ( remap_pfn_range( vma, user_virtaddr, pfn, 0xA0000, pgprot ) ) 
		return -EAGAIN;
	user_virtaddr += 0xA0000;

	// map the 384KB video/rom-bios region to address-range 0xA0000-0xFFFFF
	pfn = (LEGACY_VIDEO >> PAGE_SHIFT);
	if ( remap_pfn_range( vma, user_virtaddr, pfn, 0x60000, pgprot ) ) 
		return -EAGAIN;
	user_virtaddr += 0x60000;

	// map the 64KB lower region to address-range 0x100000-0x10FFFF
	physical_addr = lower_region;
	pfn = (physical_addr >> PAGE_SHIFT);
	if ( remap_pfn_range( vma, user_virtaddr, pfn, 0x10000, pgprot ) ) 
		return -EAGAIN;
	user_virtaddr += 0x10000;

	// map the 64KB himem region to address-range 0x110000-0x11FFFF
	physical_addr = reach_region;
	pfn = (physical_addr >> PAGE_SHIFT);
	if ( remap_pfn_range( vma, user_virtaddr, pfn, 0x10000, pgprot ) ) 
		return -EAGAIN;
	user_virtaddr += 0x10000;

	//---------------------------------------------------------------
	// initialize some portions of the 640K conventional memory area
	//---------------------------------------------------------------

	// copy page-frame 0x000 to bottom of userspace (for IVT and BDA)
	memcpy( kmem, phys_to_virt( 0x00000000 ), PAGE_SIZE );

	// copy page-frames 0x090 to 0x09F to arena 0x9 (for EBDA)
	memcpy( kmem+0x90000, phys_to_virt( 0x00090000 ), 16 * PAGE_SIZE );

	return	0;
}

void isr_gpfault( void );
asm("	.type	isr_gpfault, @function		");
asm("isr_gpfault:				");
asm("	vmcall					");
asm("	.rept	32				");
asm("	nop					");
asm("	.endr					");

int my_open( struct inode *inode, struct file *file )
{
	unsigned long long	*g_idt, *g_gdt, *g_ldt, desc;
	unsigned int		*pgdir, *pgtbl, *g_tss, i;

	// reinitialize the VMCS regions
	memset( phys_to_virt( vmxon_region ), 0x00, 0x1000 );		
	memcpy( phys_to_virt( vmxon_region ), msr0x480, 4  );		
	memset( phys_to_virt( guest_region ), 0x00, 0x1000 );		
	memcpy( phys_to_virt( guest_region ), msr0x480, 4  );		

	// initialize the Guest Page-Directory and Page-Table
	pgdir = (unsigned int*)phys_to_virt( pgdir_region );
	for (i = 0; i < 1024; i++)
		pgdir[ i ] = ( i == 0 ) ? pgtbl_region | 0x007 : 0;

	pgtbl = (unsigned int*)phys_to_virt( pgtbl_region );
	for (i = 0; i < 0xA0; i++)
		{
		unsigned int	page_address = (i << PAGE_SHIFT); 
		pgtbl[ i ] = (lower_region + page_address) | 0x007;
		}
	for (i = 0xA0; i < 0x100; i++)
		{
		unsigned int	page_address = (i << PAGE_SHIFT); 
		pgtbl[ i ] = page_address | 0x007;
		}
	for (i = 0x100; i < 0x110; i++)
		{
		unsigned int	page_address = ((i - 0x100) << PAGE_SHIFT); 
		pgtbl[ i ] = (lower_region + page_address) | 0x007;
		}
	for (i = 0x110; i < 0x120; i++)
		{
		unsigned int	page_address = ((i - 0x60) << PAGE_SHIFT); 
		pgtbl[ i ] = (lower_region + page_address) | 0x007;
		}
	for (i = 0x120; i < 0x400; i++) pgtbl[ i ] = 0;


	// initialize our Guest task's interrupt-handler region
	memcpy( phys_to_virt( g_ISR_region ), isr_gpfault, 32 ); 

	// initialize our Guest task's IDT
	g_idt = (unsigned long long*)phys_to_virt( g_IDT_region );
	desc = LEGACY_REACH + ISR_KERN_OFFSET; 	// offset for GPF handler
	desc &= 0x00000000FFFFFFFFLL;
	desc |= (desc << 32);
	desc &= 0xFFFF00000000FFFFLL; 
	desc |= (__SELECTOR_CODE << 16);
	desc |= (0x8E00LL << 32);	// DPL=0, 386-INTR-gate
	g_idt[ 13 ] = desc;		// General Protection Fault		

	// initialize our Guest task's GDT
	g_gdt = (unsigned long long*)phys_to_virt( g_GDT_region );

	desc = LEGACY_REACH + TSS_KERN_OFFSET;
	desc = ((desc & 0xFF000000)<<32)|((desc & 0x00FFFFFF)<<16);
	desc |= ( 8328 ) | (0x008BLL << 40);
	g_gdt[ __SELECTOR_TASK >> 3 ] = desc;

	desc = LEGACY_REACH + LDT_KERN_OFFSET;
	desc = ((desc & 0xFF000000)<<32)|((desc & 0x00FFFFFF)<<16);
	desc |= ( 4 * 8 - 1) | (0x0082LL << 40);
	g_gdt[ __SELECTOR_LDTR >> 3 ] = desc;

	// initialize our Guest task's LDT
	g_ldt = (unsigned long long*)phys_to_virt( g_LDT_region );

	desc = 0x00CF9A000000FFFFLL;
	g_ldt[ __SELECTOR_CODE >> 3 ] = desc;

	desc = 0x00CF92000000FFFFLL;
	g_ldt[ __SELECTOR_DATA >> 3 ] = desc; 

	desc = 0x0000920B8000FFFFLL;
	g_ldt[ __SELECTOR_VRAM >> 3 ] = desc;

	desc = 0x00CF92000000FFFFLL;
	g_ldt[ __SELECTOR_FLAT >> 3 ] = desc;

	// initialize our Guest task's TSS
	g_tss = (unsigned int*)phys_to_virt( g_TSS_region );
	g_tss[0] = 0;			// back-link
	g_tss[1] = LEGACY_REACH + ISR_KERN_OFFSET; // ESP0
	g_tss[2] = __SELECTOR_FLAT;	           // SS0
	g_tss[25] = 0x00880000;		// IOBITMAP offset
	// number of bytes in TSS: 104 + 32 + 8192 = 8328
	g_tss[ 8328 >> 2 ] = 0xFF;	// end of IOBITMAP

	return	0;
}

//----------------------------------------------------------------
// Here we setup and launch our Virtual Machine (and its Manager)   
//----------------------------------------------------------------

int my_ioctl( struct inode *inode, struct file *file, 
				unsigned int len, unsigned long buf )
{
	unsigned long 	*host_gdt;	
	signed long 	desc;

	//--------------------------------------------------------
	// sanity check: we require the client-process to pass an
	// exact amount of data representing CPU's register-state
	//--------------------------------------------------------
	retval = -EINVAL;
	if ( len != sizeof( regs_ia32 ) ) return retval;

	//----------------------------------------------------
	// fetch the client's virtual-machine register-values
	//---------------------------------------------------- 
	if ( copy_from_user( &vm, (void*)buf, len ) ) return -EFAULT;
	guest_ES_selector = vm.es;
	guest_CS_selector = vm.cs;
	guest_SS_selector = vm.ss;
	guest_DS_selector = vm.ds;
	guest_FS_selector = vm.fs;
	guest_GS_selector = vm.gs;
	guest_RAX = vm.eax;
	guest_RBX = vm.ebx;
	guest_RCX = vm.ecx;
	guest_RDX = vm.edx;
	guest_RBP = vm.ebp;
	guest_RSI = vm.esi;
	guest_RDI = vm.edi;
	guest_RSP = vm.esp;
	guest_RIP = vm.eip;
	guest_RFLAGS = vm.eflags; 

	// insure the reserved RFLAGS-bits have their required values
	guest_RFLAGS &= ~((1<<3)|(1<<5)|(1<<15));	// reserved 0-bits
	guest_RFLAGS |= (1<<1);				// reserved 1-bits

	// NOTE: Here we impose some othr RFLAGS settings
	guest_RFLAGS |= (1<<17);	// for Virtual-8086 mode
	guest_RFLAGS |= (3<<12);	// for IO-privilege-level 
	guest_RFLAGS &= ~(1<<14);	// for NT (Nested Task)

	// setup the other Guest-state fields (for Virtual-8086 mode)
	guest_ES_base = (guest_ES_selector << 4);
	guest_CS_base = (guest_CS_selector << 4);
	guest_SS_base = (guest_SS_selector << 4);
	guest_DS_base = (guest_DS_selector << 4);
	guest_FS_base = (guest_FS_selector << 4);
	guest_GS_base = (guest_GS_selector << 4);
	guest_ES_limit = 0xFFFF;
	guest_CS_limit = 0xFFFF;
	guest_SS_limit = 0xFFFF;
	guest_DS_limit = 0xFFFF;
	guest_FS_limit = 0xFFFF;
	guest_GS_limit = 0xFFFF;
	guest_ES_access_rights = 0xF3;
	guest_CS_access_rights = 0xF3;
	guest_SS_access_rights = 0xF3;
	guest_DS_access_rights = 0xF3;
	guest_FS_access_rights = 0xF3;
	guest_GS_access_rights = 0xF3;

	guest_CR0 = 0x80000031;
	guest_CR4 = 0x00002001;
	guest_CR3 = pgdir_region;
	guest_VMCS_link_pointer_full = ~0L;
	guest_VMCS_link_pointer_high = ~0L;

	guest_IDTR_base = LEGACY_REACH + IDT_KERN_OFFSET;
	guest_GDTR_base = LEGACY_REACH + GDT_KERN_OFFSET;
	guest_LDTR_base = LEGACY_REACH + LDT_KERN_OFFSET;
	guest_TR_base   = LEGACY_REACH + TSS_KERN_OFFSET;

	guest_IDTR_limit = (256 * 8) - 1;	// 256 descriptors
	guest_GDTR_limit = (3 * 8) - 1;		// 3 descriptors
	guest_LDTR_limit = (4 * 8) - 1;		// 4 descriptors
	guest_TR_limit   = (26 * 4) + 0x20 + 0x2000;
	guest_LDTR_access_rights = 0x82;
	guest_TR_access_rights   = 0x8B;
	guest_LDTR_selector = __SELECTOR_LDTR;
	guest_TR_selector   = __SELECTOR_TASK;

	//------------------------------------------------------
	// initialize the global variables for our Host's state 
	//------------------------------------------------------
	asm(" mov %%cr0, %%rax \n mov %%rax, host_CR0 " ::: "ax" );	
	asm(" mov %%cr4, %%rax \n mov %%rax, host_CR4 " ::: "ax" );	
	asm(" mov %%cr3, %%rax \n mov %%rax, host_CR3 " ::: "ax" );	
	asm(" mov %es, host_ES_selector ");
	asm(" mov %cs, host_CS_selector ");
	asm(" mov %ss, host_SS_selector ");
	asm(" mov %ds, host_DS_selector ");
	asm(" mov %fs, host_FS_selector ");
	asm(" mov %gs, host_GS_selector ");
	asm(" sgdt host_gdtr \n sidt host_idtr \n sldt host_ldtr ");
	host_GDTR_base = *(unsigned long*)(host_gdtr+1);
	host_IDTR_base = *(unsigned long*)(host_idtr+1);

	asm(" str host_TR_selector ");
	host_gdt = (unsigned long*)host_GDTR_base;
	desc = host_gdt[ (host_TR_selector >> 3) + 0 ]; 
	host_TR_base = ((desc >> 32)&0xFF000000)|((desc >> 16)&0x00FFFFFF);
	desc = host_gdt[ (host_TR_selector >> 3) + 1 ]; 
	desc <<= 48;	// maneuver to insure 'canonical' addressing
	host_TR_base |= (desc >> 16)&0xFFFFFFFF00000000;

	// access the SYSENTER Model-Specific Registers	
	asm(	" mov	$0x174, %%ecx			\n"\
		" rdmsr					\n"\
		" mov	%%eax, host_SYSENTER_CS		\n"\
		" inc	%%ecx				\n"\
		" rdmsr					\n"\
		" mov	%%eax, host_SYSENTER_ESP+0	\n"\
		" mov	%%edx, host_SYSENTER_ESP+4	\n"\
		" inc	%%ecx				\n"\
		" rdmsr					\n"\
		" mov	%%eax, host_SYSENTER_EIP+0	\n"\
		" mov	%%edx, host_SYSENTER_EIP+4	\n"\
		::: "ax", "cx", "dx" );
	
	// access the base-address MSRs for FS and GS
	asm(	" mov	$0xC0000100, %%ecx		\n"\
		" rdmsr					\n"\
		" mov	%%eax, host_FS_base+0		\n"\
		" mov	%%edx, host_FS_base+4		\n"\
		" inc	%%ecx				\n"\
		" rdmsr					\n"\
		" mov	%%eax, host_GS_base+0		\n"\
		" mov	%%edx, host_GS_base+4		\n"\
		::: "ax", "cx", "dx" );

	//------------------------------------------------------
	// initialize the global variables for our VMX controls 
	//------------------------------------------------------

	control_VMX_pin_based = msr0x480[ 1 ];
	control_VMX_pin_based |= (1<<0);	// exit on interrupts
	control_VMX_pin_based |= (1<<3);	// NMI-exiting 

	control_VMX_cpu_based = msr0x480[ 2 ];
	control_VMX_cpu_based |= (1<<7);	// HLT-exiting

	control_VM_exit_controls = msr0x480[ 3 ];
	control_VM_exit_controls |= (1<<9);	// exit to 64-bit host

	control_VM_entry_controls = msr0x480[ 4 ];

	control_CR0_mask   = 0x80000021;
 	control_CR0_shadow = 0x80000021;

	control_CR4_mask   = 0x00002001;
 	control_CR4_shadow = 0x00002001;
	
	control_CR3_target_count = 2;
	control_CR3_target0 = guest_CR3;
	control_CR3_target1 = host_CR3;
	control_pagefault_errorcode_mask  = 0x00000000;
	control_pagefault_errorcode_match = 0xFFFFFFFF;

	//-----------------------------
	// setup our host's MSR region
	//-----------------------------
	control_VM_exit_MSR_load_address_full = (h_MSR_region >>  0);
	control_VM_exit_MSR_load_address_high = (h_MSR_region >> 32);
	control_VM_exit_MSR_load_count = 0;

	msr_index = MSR_KERNEL_GS_BASE;
	asm(	" mov	msr_index, %%rcx	\n"\
		" rdmsr				\n"\
		" mov	%%eax, msr_value+0	\n"\
		" mov	%%edx, msr_value+4	\n"\
		::: "ax", "cx", "dx" );
	memcpy( next_host_MSR_entry + 0, &msr_index, 4 );
	memcpy( next_host_MSR_entry + 8, &msr_value, 8 );
	control_VM_exit_MSR_load_count += 1;
	next_host_MSR_entry += 16;

	msr_index = MSR_STAR;
	asm(	" mov	msr_index, %%rcx	\n"\
		" rdmsr				\n"\
		" mov	%%eax, msr_value+0	\n"\
		" mov	%%edx, msr_value+4	\n"\
		::: "ax", "cx", "dx" );
	memcpy( next_host_MSR_entry + 0, &msr_index, 4 );
	memcpy( next_host_MSR_entry + 8, &msr_value, 8 );
	control_VM_exit_MSR_load_count += 1;
	next_host_MSR_entry += 16;

	msr_index = MSR_LSTAR;
	asm(	" mov	msr_index, %%rcx	\n"\
		" rdmsr				\n"\
		" mov	%%eax, msr_value+0	\n"\
		" mov	%%edx, msr_value+4	\n"\
		::: "ax", "cx", "dx" );
	memcpy( next_host_MSR_entry + 0, &msr_index, 4 );
	memcpy( next_host_MSR_entry + 8, &msr_value, 8 );
	control_VM_exit_MSR_load_count += 1;
	next_host_MSR_entry += 16;

	msr_index = MSR_CSTAR;
	asm(	" mov	msr_index, %%rcx	\n"\
		" rdmsr				\n"\
		" mov	%%eax, msr_value+0	\n"\
		" mov	%%edx, msr_value+4	\n"\
		::: "ax", "cx", "dx" );
	memcpy( next_host_MSR_entry + 0, &msr_index, 4 );
	memcpy( next_host_MSR_entry + 8, &msr_value, 8 );
	control_VM_exit_MSR_load_count += 1;
	next_host_MSR_entry += 16;

	msr_index = MSR_SYSCALL_MASK;
	asm(	" mov	msr_index, %%rcx	\n"\
		" rdmsr				\n"\
		" mov	%%eax, msr_value+0	\n"\
		" mov	%%edx, msr_value+4	\n"\
		::: "ax", "cx", "dx" );
	memcpy( next_host_MSR_entry + 0, &msr_index, 4 );
	memcpy( next_host_MSR_entry + 8, &msr_value, 8 );
	control_VM_exit_MSR_load_count += 1;
	next_host_MSR_entry += 16;

	// initialize our event counters
 	extints = 0;
	nmiints = 0;

	//-----------------------
	// launch the Guest task
	//----------------------
	asm volatile("	.type	my_vmm, @function	\n"\
		" pushfq				\n"\
		" push	%rax				\n"\
		" push	%rbx				\n"\
		" push	%rcx				\n"\
		" push	%rdx				\n"\
		" push	%rbp				\n"\
		" push	%rsi				\n"\
		" push	%rdi				\n"\
		" push	%r8 				\n"\
		" push	%r9 				\n"\
		" push	%r10				\n"\
		" push	%r11				\n"\
		" push	%r12				\n"\
		" push	%r13				\n"\
		" push	%r14				\n"\
		" push	%r15				\n"\
		"					\n"\
		" lea	my_vmm, %rax			\n"\
		" mov	%rax, host_RIP			\n"\
		" mov	%rsp, host_RSP			\n"\
		"					\n"\
		" vmxon	vmxon_region			\n"\
		" jbe	vmfail				\n"\
		"					\n"\
		" vmclear guest_region			\n"\
		" jbe	vmfail				\n"\
		"					\n"\
		" vmptrld guest_region			\n"\
		" jbe	vmfail				\n"\
		"					\n"\
		"  xor	%rdx, %rdx			\n"\
		"  mov	elements, %rcx			\n"\
		"nxwr:					\n"\
		"  mov	machine+0(%rdx), %rax		\n"\
		"  mov	machine+8(%rdx), %rbx		\n"\
		"  vmwrite (%rbx), %rax			\n"\
		"  jbe	vmfail				\n"\
		"  add	$16, %rdx			\n"\
		"  loop	nxwr				\n"\
		" 					\n"\
		" mov  guest_RAX, %rax			\n"\
		" mov  guest_RBX, %rbx			\n"\
		" mov  guest_RCX, %rcx			\n"\
		" mov  guest_RDX, %rdx			\n"\
		" mov  guest_RBP, %rbp			\n"\
		" mov  guest_RSI, %rsi			\n"\
		" mov  guest_RDI, %rdi			\n"\
		" vmlaunch				\n"\
		" jmp  vmfail				\n"\
		"					\n"\
		"my_vmm:				\n"\
		" movl	$0, retval			\n"\
		" mov  %rax, guest_RAX			\n"\
		" mov  %rbx, guest_RBX			\n"\
		" mov  %rcx, guest_RCX			\n"\
		" mov  %rdx, guest_RDX			\n"\
		" mov  %rbp, guest_RBP			\n"\
		" mov  %rsi, guest_RSI			\n"\
		" mov  %rdi, guest_RDI			\n"\
		"					\n"\
		"read:					\n"\
		"  xor  %rdx, %rdx			\n"\
		"  mov  rocount, %rcx			\n"\
		"nxrd:					\n"\
		"  mov  results+0(%rdx), %rax		\n"\
		"  mov  results+8(%rdx), %rbx		\n"\
		"  vmread  %rax, (%rbx)			\n"\
		"  jbe	vmfail				\n"\
		"  add  $16, %rdx			\n"\
		"  loop nxrd				\n"\
		"					\n"\
		" mov  info_vmexit_reason, %eax		\n"\
		" mov  %eax, retval			\n"\
		"					\n"\
		" cmpl	$0, info_vmexit_reason		\n"\
		" je  was_exception_or_nmi		\n"\
		"					\n"\
		" cmpl  $1, info_vmexit_reason		\n"\
		" je  was_extint			\n"\
		"					\n"\
		" jmp  gameover				\n"\
		"					\n"\
		"was_exception_or_nmi:			\n"\
		" btl  $31, info_vmexit_interrupt_information	\n"\
		" jnc  was_nmi					\n"\
		" jmp  gameover					\n"\
		"					\n"\
		"was_nmi:				\n"\
		" incl  nmiints				\n"\
		" int  $0x02				\n"\
		" jmp  resume_guest			\n"\
		"					\n"\
		"was_extint:				\n"\
		" sti					\n"\
		" movl  $8, retval			\n"\
		" incl  extints				\n"\
		" jmp  resume_guest			\n"\
		"					\n"\
		"resume_guest:				\n"\
		"  mov  guest_RAX, %rax			\n"\
		"  mov  guest_RBX, %rbx			\n"\
		"  mov  guest_RCX, %rcx			\n"\
		"  mov  guest_RDX, %rdx			\n"\
		"  mov  guest_RBP, %rbp			\n"\
		"  mov  guest_RSI, %rsi			\n"\
		"  mov  guest_RDI, %rdi			\n"\
		"  vmresume				\n"\
		"					\n"\
		"vmfail:				\n"\
		"  jc	failInvalid			\n"\
		"failValid:				\n"\
		"  mov $0x4400, %rax			\n"\
		"  lea info_vminstr_error, %rbx		\n"\
		"  vmread  %rax, (%rbx)			\n"\
		"gameover:				\n"\
		"  mov	info_vminstr_error, %eax	\n"\
		"  mov	%eax, retval			\n"\
		"  vmxoff				\n"\
		"failInvalid:				\n"\
		" pop	%r15				\n"\
		" pop	%r14				\n"\
		" pop	%r13				\n"\
		" pop	%r12				\n"\
		" pop	%r11				\n"\
		" pop	%r10				\n"\
		" pop	%r9 				\n"\
		" pop	%r8 				\n"\
		" pop	%rdi				\n"\
		" pop	%rsi				\n"\
		" pop	%rbp				\n"\
		" pop	%rdx				\n"\
		" pop	%rcx				\n"\
		" pop	%rbx				\n"\
		" pop	%rax				\n"\
		" popfq					\n"\
		);

	//-------------------------------------------------------
	// restore some system-registers that VMX left corrupted
	//-------------------------------------------------------
	asm(" lgdt host_gdtr \n lidt host_idtr ");
	asm(" lldt host_ldtr ");

	// -----------------------------------------------------
	// deliver the client's virtual-machine register-values
	// -----------------------------------------------------
	vm.eax = guest_RAX;
	vm.ebx = guest_RBX;
	vm.ecx = guest_RCX;
	vm.edx = guest_RDX;
	vm.ebp = guest_RBP;
	vm.esi = guest_RSI;
	vm.edi = guest_RDI;
	vm.eip = guest_RIP;
	vm.esp = guest_RSP;
	vm.eflags = guest_RFLAGS;
	vm.es  = guest_ES_selector;
	vm.cs  = guest_CS_selector;
	vm.ss  = guest_SS_selector;
	vm.ds  = guest_DS_selector;
	vm.fs  = guest_FS_selector;
	vm.gs  = guest_GS_selector;
	if ( copy_to_user( (void*)buf, &vm, len ) ) return -EFAULT;

	return	retval;
}

