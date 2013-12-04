//-----------------------------------------------------------------
//	vmxstep3.s
//
//	This is the 'Control' component of our planned VMX demo.
//	This source-file includes 'vmxstep1.s' and 'vmxstep2.s'.
//
//		to assemble:  $ as vmxstep3.s -o vmxstep3.o
//
//	programmer: ALLAN CRUSE
//	written on: 21 APR 2007
//-----------------------------------------------------------------

	# list of imported symbols
	.extern	guest_selLDT, guest_selTSS
	.extern	guest_limLDT, guest_limTSS
	.extern	guest_limGDT, guest_limIDT
	.extern	guest_PGDIR, guest_TOS3, guest_task, theVMM
	.extern	guest_LDT, guest_TSS, guest_GDT, guest_IDT
	.extern	host_selCS0, host_selDS0, host_selTSS
	.extern	host_level4, host_TOS0, ARENA
	.extern	host_TSS, host_GDT, host_IDT

	# list of exported symbols
	.global	machine, ELEMENTS
	.global	results, ROCOUNT


	.include	"intstep1.s"
	.include	"intstep2.s"

	.section	.data
#------------------------------------------------------------------
machine:
# Natural 16-bit Guest State fields
	.int	0x0800, guest_ES_selector
	.int	0x0802, guest_CS_selector
	.int	0x0804, guest_SS_selector
	.int	0x0806, guest_DS_selector
	.int	0x0808, guest_FS_selector
	.int	0x080A, guest_GS_selector
	.int	0x080C, guest_LDTR_selector
	.int	0x080E, guest_TR_selector
# Natural 32-bit Guest State fields
	.int	0x4800, guest_ES_limit
	.int	0x4802, guest_CS_limit
	.int	0x4804, guest_SS_limit
	.int	0x4806, guest_DS_limit
	.int	0x4808, guest_FS_limit
	.int	0x480A, guest_GS_limit
	.int	0x480C, guest_LDTR_limit
	.int	0x480E, guest_TR_limit
	.int	0x4810, guest_GDTR_limit
	.int	0x4812, guest_IDTR_limit
	.int	0x4814, guest_ES_access_rights
	.int	0x4816, guest_CS_access_rights
	.int	0x4818, guest_SS_access_rights
	.int	0x481A, guest_DS_access_rights
	.int	0x481C, guest_FS_access_rights
	.int	0x481E, guest_GS_access_rights
	.int	0x4820, guest_LDTR_access_rights
	.int	0x4822, guest_TR_access_rights
	.int	0x4824, guest_interruptibility
	.int	0x4826, guest_activity_state
	.int	0x4828, guest_SMBASE
	.int	0x482A, guest_SYSENTER_CS
# Natural 64-bit Guest State fields
	.int	0x6800, guest_CR0
	.int	0x6802, guest_CR3
	.int	0x6804, guest_CR4
	.int	0x6806, guest_ES_base
	.int	0x6808, guest_CS_base
	.int	0x680A, guest_SS_base
	.int	0x680C, guest_DS_base
	.int	0x680E, guest_FS_base
	.int	0x6810, guest_GS_base
	.int	0x6812, guest_LDTR_base
	.int	0x6814, guest_TR_base
	.int	0x6816, guest_GDTR_base
	.int	0x6818, guest_IDTR_base
	.int	0x681A, guest_DR7
	.int	0x681C, guest_RSP
	.int	0x681E, guest_RIP
	.int	0x6820, guest_RFLAGS
	.int	0x6822, guest_pending_debug_x
	.int	0x6824, guest_SYSENTER_ESP
	.int	0x6826, guest_SYSENTER_EIP
# Full 64-bit Guest State fields
	.int	0x2800, guest_VMCS_link_pointer_full
	.int	0x2801, guest_VMCS_link_pointer_high
	.int	0x2802, guest_IA32_DEBUGCTL_full
	.int	0x2803, guest_IA32_DEBUGCTL_high
#
# Natural 16-bit Host State fields
	.int	0x0C00, host_ES_selector
	.int	0x0C02, host_CS_selector
	.int	0x0C04, host_SS_selector
	.int	0x0C06, host_DS_selector
	.int	0x0C08, host_FS_selector
	.int	0x0C0A, host_GS_selector
	.int	0x0C0C, host_TR_selector
# Natural 32-bit Host State fields
	.int	0x4C00, host_SYSENTER_CS
# Natural 64-bit Host State fields
	.int	0x6C00, host_CR0
	.int	0x6C02,	host_CR3
	.int	0x6C04, host_CR4
	.int	0x6C06, host_FS_base
	.int	0x6C08, host_GS_base
	.int	0x6C0A, host_TR_base
	.int	0x6C0C, host_GDTR_base
	.int	0x6C0E, host_IDTR_base
	.int	0x6C10, host_SYSENTER_ESP
	.int	0x6C12, host_SYSENTER_EIP
	.int	0x6C14, host_RSP
	.int	0x6C16, host_RIP
#
# Natural 32-bit Control fields
	.int	0x4000, control_VMX_pin_based
	.int	0x4002, control_VMX_cpu_based
	.int	0x4004, control_exception_bitmap
	.int	0x4006, control_pagefault_errorcode_mask
	.int	0x4008, control_pagefault_errorcode_match
	.int	0x400A, control_CR3_target_count
	.int	0x400C, control_VM_exit_controls
	.int	0x400E, control_VM_exit_MSR_store_count
	.int	0x4010, control_VM_exit_MSR_load_count
	.int	0x4012, control_VM_entry_controls
	.int	0x4014, control_VM_entry_MSR_load_count
	.int	0x4016, control_VM_entry_interruption_info
	.int	0x4018, control_VM_entry_exception_errorcode
	.int	0x401A, control_VM_entry_instruction_length
	.int	0x401C, control_Task_PRivilege_Threshold
# Natural 64-bit Control fields
	.int	0x6000, control_CR0_mask
	.int	0x6002, control_CR4_mask
	.int	0x6004, control_CR0_shadow
	.int	0x6006, control_CR4_shadow
	.int	0x6008, control_CR3_target0
	.int	0x600A, control_CR3_target1
	.int	0x600C, control_CR3_target2
	.int	0x600E, control_CR3_target3
# Full 64-bit Control fields
	.int	0x2000, control_IO_BitmapA_address_full	
	.int	0x2001, control_IO_BitmapA_address_high	
	.int	0x2002, control_IO_BitmapB_address_full	
	.int	0x2003, control_IO_BitmapB_address_high	
	# next two field-encodings unsupported on Xeon
#	.int	0x2004, control_MSR_Bitmaps_address_full
#	.int	0x2005, control_MSR_Bitmaps_address_high
	.int	0x2006, control_VMexit_MSR_store_address_full
	.int	0x2007, control_VMexit_MSR_store_address_high
	.int	0x2008, control_VMexit_MSR_load_address_full
	.int	0x2009, control_VMexit_MSR_load_address_high
	.int	0x200A, control_VMentry_MSR_load_address_full
	.int	0x200B, control_VMentry_MSR_load_address_high
	.int	0x200C, control_Executive_VMCS_pointer_full
	.int	0x200D, control_Executive_VMCS_pointer_high
	# next two field-encodings unsupported on Xeon/Core2
#	.int	0x200E, 0
#	.int	0x200F, 0
	.int	0x2010, control_TSC_offset_full
	.int	0x2011, control_TSC_offset_high
	# next two field-encodings unsupported on Xeon
#	.int	0x2012, control_virtual_APIC_page_address_full
#	.int	0x2013, control_virtual_APIC_page_address_high

	.equ	ELEMENTS, (. - machine)/8
#------------------------------------------------------------------
#------------------------------------------------------------------
results:
# Natural 32-bit Read-Only Data fields
	.int	0x4400,	info_vmxinstr_error
	.int	0x4402,	info_vmexit_reason
	.int	0x4404, info_vmexit_interrupt_information
	.int	0x4406, info_vmexit_interrupt_error_code
	.int	0x4408, info_IDT_vectoring_information
	.int	0x440A, info_IDT_vectoring_error_code
	.int	0x440C, info_vmexit_instruction_length
	.int	0x441E, info_vmx_instruction_information
# Natural 64-bit Read-Only Data fields
	.int	0x6400, info_exit_qualification
	.int	0x6402, info_IO_RCX
	.int	0x6404, info_IO_RSI
	.int	0x6406, info_IO_RDI
	.int	0x6408, info_IO_RIP
	.int	0x640A, info_guest_linear_address

	.equ	ROCOUNT, (. - results)/8
#------------------------------------------------------------------
# Natural 16-bit Guest State fields
guest_ES_selector:			.short	0x0000	
guest_CS_selector:			.short	ARENA >> 4
guest_SS_selector:			.short	ARENA >> 4
guest_DS_selector:			.short	0x0000
guest_FS_selector:			.short	0x0000
guest_GS_selector:			.short	0x0000
guest_LDTR_selector:			.short	guest_selLDT
guest_TR_selector:			.short	guest_selTSS
# Natural 32-bit Guest State fields
guest_ES_limit:				.int	0x0000FFFF
guest_CS_limit:				.int	0x0000FFFF
guest_SS_limit:				.int	0x0000FFFF
guest_DS_limit:				.int	0x0000FFFF
guest_FS_limit:				.int	0x0000FFFF
guest_GS_limit:				.int	0x0000FFFF
guest_LDTR_limit:			.int	guest_limLDT
guest_TR_limit:				.int	guest_limTSS
guest_GDTR_limit:			.int	guest_limGDT
guest_IDTR_limit:			.int	guest_limIDT
guest_ES_access_rights:			.int	0x000000F3
guest_CS_access_rights:			.int	0x000000F3
guest_SS_access_rights:			.int	0x000000F3
guest_DS_access_rights:			.int	0x000000F3
guest_FS_access_rights:			.int	0x000000F3
guest_GS_access_rights:			.int	0x000000F3
guest_LDTR_access_rights:		.int	0x00000082
guest_TR_access_rights:			.int	0x0000008B
guest_interruptibility:			.int	0x00000000
guest_activity_state:			.int	0x00000000
guest_SMBASE:				.int	0x000A0000
guest_SYSENTER_CS:			.int	0x00000000
# Natural 64-bit Guest State fields
guest_CR0:				.quad	0x80000031
guest_CR3:				.quad	guest_PGDIR + ARENA
guest_CR4:				.quad	0x00002011
guest_ES_base:				.quad	0x00000000
guest_CS_base:				.quad	ARENA
guest_SS_base:				.quad	ARENA
guest_DS_base:				.quad	0x00000000
guest_FS_base:				.quad	0x00000000
guest_GS_base:				.quad	0x00000000
guest_LDTR_base:			.quad	guest_LDT + ARENA
guest_TR_base:				.quad	guest_TSS + ARENA
guest_GDTR_base:			.quad	guest_GDT + ARENA
guest_IDTR_base:			.quad	guest_IDT + ARENA
guest_DR7:				.quad	0x00000000
guest_RSP:				.quad	guest_TOS3
guest_RIP:				.quad	guest_task
guest_RFLAGS:				.quad	0x00023202 # IOPL=3, IF=1
guest_pending_debug_x:			.quad	0x00000000
guest_SYSENTER_ESP:			.quad	0x00000000
guest_SYSENTER_EIP:			.quad	0x00000000
# Full 64-bit Guest State fields
guest_VMCS_link_pointer_full:		.int	0xFFFFFFFF
guest_VMCS_link_pointer_high:		.int	0xFFFFFFFF
guest_IA32_DEBUGCTL_full:		.int	0x00000000
guest_IA32_DEBUGCTL_high:		.int	0x00000000
#------------------------------------------------------------------
# Natural 16-bit Host State fields
host_ES_selector:			.short	0x0000
host_CS_selector:			.short	host_selCS0
host_SS_selector:			.short	host_selDS0
host_DS_selector:			.short	0x0000
host_FS_selector:			.short	0x0000
host_GS_selector:			.short	0x0000
host_TR_selector:			.short	host_selTSS
# Natural 32-bit Host State fields
host_SYSENTER_CS:			.int	0x00000000
# Natural 64-bit Host State fields
host_CR0:				.quad	0x80000021	
host_CR3:				.quad	host_level4 + ARENA
host_CR4:				.quad	0x00002020	
host_FS_base:				.quad	0x00000000
host_GS_base:				.quad	0x00000000
host_TR_base:				.quad	host_TSS
host_GDTR_base:				.quad	host_GDT
host_IDTR_base:				.quad	host_IDT
host_SYSENTER_ESP:			.quad	0x00000000
host_SYSENTER_EIP:			.quad	0x00000000
host_RSP:				.quad	host_TOS0
host_RIP:				.quad	theVMM
#------------------------------------------------------------------
# Natural 32-bit Control fields
control_VMX_pin_based:			.int	0x00000016	
control_VMX_cpu_based:			.int	0x0401E172
control_exception_bitmap:		.int	0x00000000
control_pagefault_errorcode_mask:	.int	0x00000000
control_pagefault_errorcode_match:	.int	0xFFFFFFFF
control_CR3_target_count:		.int	0x00000002
control_VM_exit_controls:		.int	0x00036FFF
control_VM_exit_MSR_store_count:	.int	0x00000000
control_VM_exit_MSR_load_count:		.int	0x00000000
control_VM_entry_controls:		.int	0x000011FF
control_VM_entry_MSR_load_count:	.int	0x00000000
control_VM_entry_interruption_info:	.int	0x00000000
control_VM_entry_exception_errorcode:	.int	0x00000000
control_VM_entry_instruction_length:	.int	0x00000000
control_Task_PRivilege_Threshold:	.int	0x00000000
# Natural 64-bit Control fields	
control_CR0_mask:			.int	0x80000021			
control_CR4_mask:			.int	0x00002000
control_CR0_shadow:			.int	0x80000021
control_CR4_shadow:			.int	0x00002000
control_CR3_target0:			.int	guest_PGDIR + ARENA	
control_CR3_target1:			.int	host_level4 + ARENA
control_CR3_target2:			.int	0x00000000
control_CR3_target3:			.int	0x00000000
# Full 64-bit Control fields
control_IO_BitmapA_address_full:	.int	0x00000000	
control_IO_BitmapA_address_high:	.int	0x00000000
control_IO_BitmapB_address_full:	.int	0x00000000
control_IO_BitmapB_address_high:	.int	0x00000000
control_MSR_Bitmaps_address_full:	.int	0x00000000
control_MSR_Bitmaps_address_high:	.int	0x00000000
control_VMexit_MSR_store_address_full:	.int	0x00000000
control_VMexit_MSR_store_address_high:	.int	0x00000000
control_VMexit_MSR_load_address_full:	.int	0x00000000
control_VMexit_MSR_load_address_high:	.int	0x00000000
control_VMentry_MSR_load_address_full:	.int	0x00000000
control_VMentry_MSR_load_address_high:	.int	0x00000000
control_Executive_VMCS_pointer_full:	.int	0x00000000
control_Executive_VMCS_pointer_high:	.int	0x00000000
control_TSC_offset_full:		.int	0x00000000
control_TSC_offset_high:		.int	0x00000000
control_virtual_APIC_page_address_full:	.int	0x00000000
control_virtual_APIC_page_address_high:	.int	0x00000000
#------------------------------------------------------------------
# Natural 32-bit Read-Only fields
info_vmxinstr_error:			.int	0
info_vmexit_reason:			.int	0
info_vmexit_interrupt_information:	.int	0
info_vmexit_interrupt_error_code:	.int	0
info_IDT_vectoring_information:		.int	0
info_IDT_vectoring_error_code:		.int	0
info_vmexit_instruction_length:		.int	0
info_vmx_instruction_information:	.int	0
# Natural 64-bit Read-Only fields
info_exit_qualification:		.quad	0
info_IO_RCX:				.quad	0
info_IO_RSI:				.quad	0
info_IO_RDI:				.quad	0
info_IO_RIP:				.quad	0
info_guest_linear_address:		.quad	0
#------------------------------------------------------------------

