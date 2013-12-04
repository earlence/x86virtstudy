//----------------------------------------------------------------
//	machine.h
//
//	This header-file is for inclusion in a Linux Kernel Module
//	that will build a host Virtual Machine Manager and a guest 
//	Virtual Machine.  See Intel 64 Software Developer's Manual 
//	(Volume 3B), Appendix H. 
//
//	NOTE: Fields unimplemented by our Pentium-D Xeon processor
//	are commented out, but may be supported in Core-2 Duo CPU.
//
//	programmer: ALLAN CRUSE
//	written on: 26 JUL 2006
//	revised on: 29 APR 2007 -- altered our VMCS_DEF structure
//----------------------------------------------------------------

//typedef struct	{ void  *setting; int  encoding; } VMCS_DEF;

typedef struct	{ int  encoding; void *setting; } VMCS_DEF;

// Natural 32-bit Control fields
unsigned int  control_VMX_pin_based;
unsigned int  control_VMX_cpu_based;
unsigned int  control_exception_bitmap;
unsigned int  control_pagefault_errorcode_mask; 
unsigned int  control_pagefault_errorcode_match; 
unsigned int  control_CR3_target_count;
unsigned int  control_VM_exit_controls;
unsigned int  control_VM_exit_MSR_store_count;
unsigned int  control_VM_exit_MSR_load_count;
unsigned int  control_VM_entry_controls;
unsigned int  control_VM_entry_MSR_load_count;
unsigned int  control_VM_entry_interruption_information;
unsigned int  control_VM_entry_exception_errorcode;
unsigned int  control_VM_entry_instruction_length;
unsigned int  control_Task_PRivilege_Threshold;
// Natural 64-bit Control fields
unsigned long long  control_CR0_mask;
unsigned long long  control_CR4_mask;
unsigned long long  control_CR0_shadow;
unsigned long long  control_CR4_shadow;
unsigned long long  control_CR3_target0;
unsigned long long  control_CR3_target1;
unsigned long long  control_CR3_target2;
unsigned long long  control_CR3_target3;
// Full 64-bit Control fields
unsigned int  control_IO_BitmapA_address_full;
unsigned int  control_IO_BitmapA_address_high;
unsigned int  control_IO_BitmapB_address_full;
unsigned int  control_IO_BitmapB_address_high;
unsigned int  control_MSR_Bitmaps_address_full;
unsigned int  control_MSR_Bitmaps_address_high;
unsigned int  control_VM_exit_MSR_store_address_full;
unsigned int  control_VM_exit_MSR_store_address_high;
unsigned int  control_VM_exit_MSR_load_address_full;
unsigned int  control_VM_exit_MSR_load_address_high;
unsigned int  control_VM_entry_MSR_load_address_full;
unsigned int  control_VM_entry_MSR_load_address_high;
unsigned int  control_Executive_VMCS_pointer_full;
unsigned int  control_Executive_VMCS_pointer_high;
unsigned int  control_TSC_offset_full;
unsigned int  control_TSC_offset_high;
unsigned int  control_virtual_APIC_page_address_full;
unsigned int  control_virtual_APIC_page_address_high;

// Natural 64-bit Host-State fields
unsigned long long  host_CR0;
unsigned long long  host_CR3;
unsigned long long  host_CR4;
unsigned long long  host_FS_base;
unsigned long long  host_GS_base;
unsigned long long  host_TR_base;
unsigned long long  host_GDTR_base;
unsigned long long  host_IDTR_base;
unsigned long long  host_SYSENTER_ESP;
unsigned long long  host_SYSENTER_EIP;
unsigned long long  host_RSP;
unsigned long long  host_RIP;
// Natural 32-bit Host-State fields
unsigned int  host_SYSENTER_CS;
// Natural 16-bit Host-State fields
unsigned short  host_ES_selector;
unsigned short  host_CS_selector;
unsigned short  host_SS_selector;
unsigned short  host_DS_selector;
unsigned short  host_FS_selector;
unsigned short  host_GS_selector;
unsigned short  host_TR_selector;

// Natural 64-bit Guest-State fields
unsigned long long  guest_CR0;
unsigned long long  guest_CR3;
unsigned long long  guest_CR4;
unsigned long long  guest_ES_base;
unsigned long long  guest_CS_base; 
unsigned long long  guest_SS_base;
unsigned long long  guest_DS_base;
unsigned long long  guest_FS_base;
unsigned long long  guest_GS_base;
unsigned long long  guest_LDTR_base;
unsigned long long  guest_TR_base;
unsigned long long  guest_GDTR_base;
unsigned long long  guest_IDTR_base;
unsigned long long  guest_DR7;
unsigned long long  guest_RSP; 
unsigned long long  guest_RIP; 
unsigned long long  guest_RFLAGS; 
unsigned long long  guest_pending_debug_x;
unsigned long long  guest_SYSENTER_ESP;
unsigned long long  guest_SYSENTER_EIP;
// Natural 32-bit Guest-State fields
unsigned int  guest_ES_limit;
unsigned int  guest_CS_limit;
unsigned int  guest_SS_limit;
unsigned int  guest_DS_limit;
unsigned int  guest_FS_limit;
unsigned int  guest_GS_limit;
unsigned int  guest_LDTR_limit; 
unsigned int  guest_TR_limit;
unsigned int  guest_GDTR_limit;
unsigned int  guest_IDTR_limit;
unsigned int  guest_ES_access_rights; 
unsigned int  guest_CS_access_rights;
unsigned int  guest_SS_access_rights;
unsigned int  guest_DS_access_rights;
unsigned int  guest_FS_access_rights;
unsigned int  guest_GS_access_rights;
unsigned int  guest_LDTR_access_rights;
unsigned int  guest_TR_access_rights;
unsigned int  guest_interruptibility; 
unsigned int  guest_activity_state; 
unsigned int  guest_SMBASE;	// <-- Added 23 December 2006
unsigned int  guest_SYSENTER_CS; 
// Natural 16-bit Guest-State fields
unsigned short  guest_ES_selector;
unsigned short  guest_CS_selector;
unsigned short  guest_SS_selector;
unsigned short  guest_DS_selector;
unsigned short  guest_FS_selector;
unsigned short  guest_GS_selector;
unsigned short  guest_LDTR_selector;
unsigned short  guest_TR_selector;
// Full 64-bit Guest-State fields
unsigned int  guest_VMCS_link_pointer_full;
unsigned int  guest_VMCS_link_pointer_high;
unsigned int  guest_IA32_DEBUGCTL_full;
unsigned int  guest_IA32_DEBUGCTL_high;

//------------------
// Read-Only Fields
//------------------
unsigned int  info_vminstr_error;
unsigned int  info_vmexit_reason;
unsigned int  info_vmexit_interrupt_information;
unsigned int  info_vmexit_interrupt_error_code;
unsigned int  info_IDT_vectoring_information;
unsigned int  info_IDT_vectoring_error_code;
unsigned int  info_vmexit_instruction_length;
unsigned int  info_vmx_instruction_information;
unsigned long long  info_exit_qualification;
unsigned long long  info_IO_RCX;
unsigned long long  info_IO_RSI;
unsigned long long  info_IO_RDI;
unsigned long long  info_IO_RIP;
unsigned long long  info_guest_linear_address;


VMCS_DEF  machine[] =	{
	//----------------
	// Control fields
	//----------------
	// Natural 32-bit Control fields
	{ 0x4000, &control_VMX_pin_based },
	{ 0x4002, &control_VMX_cpu_based },
	{ 0x4004, &control_exception_bitmap },
	{ 0x4006, &control_pagefault_errorcode_mask },
	{ 0x4008, &control_pagefault_errorcode_match },
	{ 0x400A, &control_CR3_target_count },
	{ 0x400C, &control_VM_exit_controls },
	{ 0x400E, &control_VM_exit_MSR_store_count },
	{ 0x4010, &control_VM_exit_MSR_load_count },
	{ 0x4012, &control_VM_entry_controls },
	{ 0x4014, &control_VM_entry_MSR_load_count },
	{ 0x4016, &control_VM_entry_interruption_information },
	{ 0x4018, &control_VM_entry_exception_errorcode },
	{ 0x401A, &control_VM_entry_instruction_length },
	{ 0x401C, &control_Task_PRivilege_Threshold },
	// Natural 64-bit Control fields
	{ 0x6000, &control_CR0_mask },
	{ 0x6002, &control_CR4_mask }, 
	{ 0x6004, &control_CR0_shadow },
	{ 0x6006, &control_CR4_shadow },
	{ 0x6008, &control_CR3_target0 },
	{ 0x600A, &control_CR3_target1 },
	{ 0x600C, &control_CR3_target2 },
	{ 0x600E, &control_CR3_target3 },
	// Full 64-bit Control fields
	{ 0x2000, &control_IO_BitmapA_address_full },
	{ 0x2001, &control_IO_BitmapA_address_high },
	{ 0x2002, &control_IO_BitmapB_address_full },
	{ 0x2003, &control_IO_BitmapB_address_high },
////	{ 0x2004, &control_MSR_Bitmaps_address_full },
////	{ 0x2005, &control_MSR_Bitmaps_address_high }, 
	{ 0x2006, &control_VM_exit_MSR_store_address_full },
	{ 0x2007, &control_VM_exit_MSR_store_address_high },
	{ 0x2008, &control_VM_exit_MSR_load_address_full },
	{ 0x2009, &control_VM_exit_MSR_load_address_high },
	{ 0x200A, &control_VM_entry_MSR_load_address_full },
	{ 0x200B, &control_VM_entry_MSR_load_address_high },
	{ 0x200C, &control_Executive_VMCS_pointer_full },
	{ 0x200D, &control_Executive_VMCS_pointer_high },
	{ 0x2010, &control_TSC_offset_full },
	{ 0x2011, &control_TSC_offset_high },
////	{ 0x2012, &control_virtual_APIC_page_address_full }, 
////	{ 0x2013, &control_virtual_APIC_page_address_high },

	//-------------------
	// Host-State fields
	//-------------------
	// Natural 64-bit Host-State fields
	{ 0x6C00, &host_CR0 },
	{ 0x6C02, &host_CR3 },
	{ 0x6C04, &host_CR4 },
	{ 0x6C06, &host_FS_base },
	{ 0x6C08, &host_GS_base },
	{ 0x6C0A, &host_TR_base },
	{ 0x6C0C, &host_GDTR_base },
	{ 0x6C0E, &host_IDTR_base },
	{ 0x6C10, &host_SYSENTER_ESP },
	{ 0x6C12, &host_SYSENTER_EIP },
	{ 0x6C14, &host_RSP },
	{ 0x6C16, &host_RIP },
	// Natural 32-bit Host-State fields
	{ 0x4C00, &host_SYSENTER_CS },
	// Natural 16-bit Host-State fields
	{ 0x0C00, &host_ES_selector },
	{ 0x0C02, &host_CS_selector },
	{ 0x0C04, &host_SS_selector },
	{ 0x0C06, &host_DS_selector },
	{ 0x0C08, &host_FS_selector },
	{ 0x0C0A, &host_GS_selector },
	{ 0x0C0C, &host_TR_selector },

	//--------------------
	// Guest-State fields
	//--------------------
	// Natural 64-bit Guest-State fields
	{ 0x6800, &guest_CR0 },
	{ 0x6802, &guest_CR3 },
	{ 0x6804, &guest_CR4 },
	{ 0x6806, &guest_ES_base },
	{ 0x6808, &guest_CS_base },
	{ 0x680A, &guest_SS_base },
	{ 0x680C, &guest_DS_base },
	{ 0x680E, &guest_FS_base },
	{ 0x6810, &guest_GS_base },
	{ 0x6812, &guest_LDTR_base },
	{ 0x6814, &guest_TR_base },
	{ 0x6816, &guest_GDTR_base },
	{ 0x6818, &guest_IDTR_base },
	{ 0x681A, &guest_DR7 },
	{ 0x681C, &guest_RSP },
	{ 0x681E, &guest_RIP },
	{ 0x6820, &guest_RFLAGS },
	{ 0x6822, &guest_pending_debug_x },
	{ 0x6824, &guest_SYSENTER_ESP },
	{ 0x6826, &guest_SYSENTER_EIP },
	// Natural 32-bit Guest-State fields
	{ 0x4800, &guest_ES_limit },
	{ 0x4802, &guest_CS_limit },
	{ 0x4804, &guest_SS_limit },
	{ 0x4806, &guest_DS_limit },
	{ 0x4808, &guest_FS_limit },
	{ 0x480A, &guest_GS_limit },
	{ 0x480C, &guest_LDTR_limit },
	{ 0x480E, &guest_TR_limit },
	{ 0x4810, &guest_GDTR_limit },
	{ 0x4812, &guest_IDTR_limit },
	{ 0x4814, &guest_ES_access_rights },
	{ 0x4816, &guest_CS_access_rights },
	{ 0x4818, &guest_SS_access_rights },
	{ 0x481A, &guest_DS_access_rights },
	{ 0x481C, &guest_FS_access_rights },
	{ 0x481E, &guest_GS_access_rights },
	{ 0x4820, &guest_LDTR_access_rights },
	{ 0x4822, &guest_TR_access_rights },
	{ 0x4824, &guest_interruptibility },
	{ 0x4826, &guest_activity_state },
	{ 0x4828, &guest_SMBASE },
	{ 0x482A, &guest_SYSENTER_CS },
	// Natural 16-bit Guest-State fields
	{ 0x0800, &guest_ES_selector },
	{ 0x0802, &guest_CS_selector },
	{ 0x0804, &guest_SS_selector },
	{ 0x0806, &guest_DS_selector },
	{ 0x0808, &guest_FS_selector },
	{ 0x080A, &guest_GS_selector },
	{ 0x080C, &guest_LDTR_selector },
	{ 0x080E, &guest_TR_selector },
	// Full 64-bit Guest-State fields
	{ 0x2800, &guest_VMCS_link_pointer_full },
	{ 0x2801, &guest_VMCS_link_pointer_high },
	{ 0x2802, &guest_IA32_DEBUGCTL_full },
	{ 0x2803, &guest_IA32_DEBUGCTL_high } };

const long elements = ( sizeof( machine ) ) / sizeof( VMCS_DEF );


VMCS_DEF  results[ ] = {
	{ 0x681C, &guest_RSP },
	{ 0x681E, &guest_RIP },
	{ 0x6820, &guest_RFLAGS },
	{ 0x0800, &guest_ES_selector },
	{ 0x0802, &guest_CS_selector },
	{ 0x0804, &guest_SS_selector },
	{ 0x0806, &guest_DS_selector },
	{ 0x0808, &guest_FS_selector },
	{ 0x080A, &guest_GS_selector },
	{ 0x080C, &guest_LDTR_selector },
	{ 0x080E, &guest_TR_selector },
	{ 0x4400, &info_vminstr_error }, 
	{ 0x4402, &info_vmexit_reason },
	{ 0x4404, &info_vmexit_interrupt_information },
	{ 0x4406, &info_vmexit_interrupt_error_code },
	{ 0x4408, &info_IDT_vectoring_information },
	{ 0x440A, &info_IDT_vectoring_error_code },
	{ 0x440C, &info_vmexit_instruction_length },
	{ 0x440E, &info_vmx_instruction_information },
	{ 0x6400, &info_exit_qualification },
	{ 0x6402, &info_IO_RCX },
	{ 0x6404, &info_IO_RSI },
	{ 0x6406, &info_IO_RDI },
	{ 0x6408, &info_IO_RIP },
	{ 0x640A, &info_guest_linear_address } };

const long rocount = sizeof( results ) / sizeof( VMCS_DEF );

