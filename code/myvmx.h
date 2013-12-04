//----------------------------------------------------------------
//	myvmx.h
//
//	
//	programmer: ALLAN CRUSE
//	date begun: 17 JUL 2006
//	revised on: 26 JUL 2006 -- omit equates for VMX mnemonics
//----------------------------------------------------------------

typedef struct 	{
		unsigned int	eip;
		unsigned int	eflags;
		unsigned int	eax;
		unsigned int	ecx;
		unsigned int	edx;
		unsigned int	ebx;
		unsigned int	esp;
		unsigned int	ebp;
		unsigned int	esi;
		unsigned int	edi;
		unsigned int	 es;
		unsigned int	 cs;
		unsigned int	 ss;
		unsigned int	 ds;
		unsigned int	 fs;
		unsigned int	 gs;
		} regs_ia32;


