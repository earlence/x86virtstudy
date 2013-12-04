//----------------------------------------------------------------
//	newapp64.cpp	
//
//	This utility will create 'boilerplate' assembly language 
//	code for a new 64bit protected-mode application program,
//	with a fault-handler for General Protection Exceptions.
//
//		to compile:  $ g++ newapp64.cpp -o newapp64
//		to execute:  $ ./newapp64 <appname>
//
//	programmer: ALLAN CRUSE
//	date begun: 13 MAR 2007 
//	completion: 19 MAR 2007 
//----------------------------------------------------------------

#include <stdio.h>	// for fprintf(), fopen(), etc
#include <string.h>	// for strncpy(), strncat()
#include <time.h>	// for time(), localtime()

char authorname[] = "ALLAN CRUSE";
char monthlist[] = "JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC";

int main( int argc, char *argv[] )
{
	// check for program-name as command-line argument
	if ( argc == 1 ) 
		{
		fprintf( stderr, "Must specify program-name\n" );
		return	-1;
		}

	// prepare program name 
	char	appname[33] = "";
	strncpy( appname, argv[1], 28 );

	// prepare code-file name
	char	srcname[33] = "";
	char	objname[33] = "";
	char	binname[33] = "";
	strncpy( srcname, argv[1], 28 );
	strncpy( objname, argv[1], 28 );
	strncpy( binname, argv[1], 28 );
	strncat( srcname, ".s", 4 );
	strncat( objname, ".o", 4 );
	strncat( binname, ".b", 4 );

	// announce this program's purpose 
	printf( "\nCreating skeleton for program " );
	printf( "named \'%s\' \n", srcname );

	// insure source-file doesn't already exist
	FILE	*fp = fopen( srcname, "rb" );
	if ( fp != NULL )
		{
		fclose( fp );
		fprintf( stderr, "File \'%s\' already exists\n", srcname );
		return	-1;
		}

	// create the new source-file
	fp = fopen( srcname, "wb" );
	if ( fp == NULL )
		{
		fprintf( stderr, "Cannot create source-file\n" );
		return	-1;
		}

	// obtain today's date (in DD MMM YYYY format)
	time_t		now = time( (time_t *)NULL );
	struct tm	*t = localtime( &now );
	char	month[4] = "";
	strncpy( month, monthlist+3*t->tm_mon, 3 );
	month[3] = '\0';

	char	when[16] = "";
	sprintf( when, "%02d %3s %04d", t->tm_mday, month, 1900+t->tm_year );	

	char	border[68] = "";
	memset( border, '-', 67 );

	fprintf( fp, "//%s\n", border );
	fprintf( fp, "//\t%s\n", srcname );
	fprintf( fp, "//\n" );
	fprintf( fp, "//\n" );
	fprintf( fp, "//\t to assemble: $ as %s ", srcname );
	fprintf( fp, "-o %s \n", objname );
	fprintf( fp, "//\t and to link: $ ld %s ", objname );
	fprintf( fp, "-T ldscript " );
	fprintf( fp, "-o %s \n", binname );
	fprintf( fp, "//\t and install: $ dd if=%s ", binname );
	fprintf( fp, "of=%s seek=%d \n", "/dev/sda4", 1 );
	fprintf( fp, "//\n" );
	fprintf( fp, "//\tNOTE: This program begins executing " );
	fprintf( fp, "with CS:IP = 1000:0002. \n" );
	fprintf( fp, "//\n" );
	fprintf( fp, "//\tprogrammer: %s\n", authorname );
	fprintf( fp, "//\tdate begun: %s\n", when );
	fprintf( fp, "//%s\n", border );

	fprintf( fp, "\n\t.equ\tARENA, 0x10000 \t\t" );
	fprintf( fp, "# program's load-address \n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\t.section\t.text\n" );
	fprintf( fp, "#%s\n", border );
	fprintf( fp, "\t.word\t0xABCD\t\t\t# our application signature\n" );
	fprintf( fp, "#%s\n", border );
	fprintf( fp, "main:" );
	fprintf( fp, "\t.code16\t\t\t\t# for x86 'real-mode' \n" );
	fprintf( fp, "\tmov\t%%sp, %%cs:exit_pointer+0\t" );
	fprintf( fp, "# preserve the loader's SP" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ss, %%cs:exit_pointer+2\t" );
	fprintf( fp, "# preserve the loader's SS" );
	fprintf( fp, "\n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%cs, %%ax\t\t" );
	fprintf( fp, "# address program's data " );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%ds\t\t" );
	fprintf( fp, "#   with DS register     " );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%es\t\t" );
	fprintf( fp, "#   also ES register     " );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%ss\t\t" );
	fprintf( fp, "#   also SS register     " );
	fprintf( fp, "\n" );
	fprintf( fp, "\tlea\ttos, %%sp\t\t" );
	fprintf( fp, "# and setup new stacktop " );
	fprintf( fp, "\n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tcall\tenter_ia32e_mode\t" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tcall\texecute_our_demo\t" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tcall\tleave_ia32e_mode\t" );
	fprintf( fp, "\n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tlss\t%%cs:exit_pointer, %%sp\t" );
	fprintf( fp, "# recover saved SS and SP" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tlret\t\t\t\t" );
	fprintf( fp, "# exit back to the loader" );
	fprintf( fp, "\n" );
	fprintf( fp, "#%s\n", border );
	fprintf( fp, "exit_pointer:\t.word\t0, 0 \t\t" );
	fprintf( fp, "# for loader's SS and SP " );
	fprintf( fp, "\n" );
	fprintf( fp, "#%s\n", border );

	fprintf( fp, "theGDT:\t" );
	fprintf( fp, ".quad\t0x0000000000000000\t" );
	fprintf( fp, "# required null descriptor \n" );
	
	fprintf( fp, "\n\t.equ\tsel_cs, (.-theGDT)+0\t" );
	fprintf( fp, "# selector for code-segment \n" );
	fprintf( fp, "\t.quad\t0x00009A010000FFFF\t" );
	fprintf( fp, "# 16-bit code-descriptor \n" );

	fprintf( fp, "\n\t.equ\tsel_CS, (.-theGDT)+0\t" );
	fprintf( fp, "# selector for code-segment \n" );
	fprintf( fp, "\t.quad\t0x00209A0000000000\t" );
	fprintf( fp, "# 64-bit code-descriptor \n" );

	fprintf( fp, "\n\t.equ\tsel_ds, (.-theGDT)+0\t" );
	fprintf( fp, "# selector for data-segment \n" );
	fprintf( fp, "\t.quad\t0x000092010000FFFF\t" );
	fprintf( fp, "# 16-bit data-descriptor \n" );

	fprintf( fp, "\n\t.equ\tgate64, (.-theGDT)+0\t" );
	fprintf( fp, "# selector for call-gate \n" );
	fprintf( fp, "\t.word\tprog64, sel_CS, 0x8C00, 0x0000 \n" );
	fprintf( fp, "\t.word\t0x0000, 0x0000, 0x0000, 0x0000 \n" );

	fprintf( fp, "\n\t.equ\tlimGDT, (.-theGDT)-1\t" );
	fprintf( fp, "# our GDT-segment's limit \n" );
	fprintf( fp, "#%s\n", border );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "theIDT:\t.space\t13 * 16\t\t\t" );
	fprintf( fp, "# first 13 gate-descriptors \n" );
	fprintf( fp, "\n" );

	fprintf( fp, "\t# interrupt-gate for General Protection Faults \n" );
	fprintf( fp, "\t.word\tisrGPF, sel_CS, 0x8E00, 0x0000 \t" );
	fprintf( fp, " \n" );
	fprintf( fp, "\t.word\t0x0000, 0x0000, 0x0000, 0x0000 \t" );
	fprintf( fp, " \n" );

	fprintf( fp, "\n\t.equ\tlimIDT, (.-theIDT)-1\t" );
	fprintf( fp, "# our IDT-segment's limit \n" );
	fprintf( fp, "#%s\n", border );

	fprintf( fp, "regCR3:\t.long\tlevel4 + ARENA \t\t" );
	fprintf( fp, "# register-image for CR3 \n" );
	fprintf( fp, "regGDT:\t.word\tlimGDT, theGDT, 0x0001\t" );
	fprintf( fp, "# register-image for GDTR \n" );
	fprintf( fp, "regIDT:\t.word\tlimIDT, theIDT, 0x0001\t" );
	fprintf( fp, "# register-image for IDTR \n" );
	fprintf( fp, "regIVT:\t.word\t0x03FF, 0x0000, 0x0000\t" );
	fprintf( fp, "# register-image for IDTR \n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "enter_ia32e_mode:\n" );
	fprintf( fp, "\n" );

	fprintf( fp, "\t# setup the Extended Feature Enable Register \n" );
	fprintf( fp, "\tmov\t$0xC0000080, %%ecx \n" );
	fprintf( fp, "\trdmsr \n" );
	fprintf( fp, "\tbts\t$8, %%eax \t\t" );
	fprintf( fp, "# set LME-bit in EFER \n" );
	fprintf( fp, "\twrmsr \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\t# setup system control register CR4  \n" );
	fprintf( fp, "\tmov\t%%cr4, %%eax \n" );
	fprintf( fp, "\tbts\t$5, %%eax \t\t" );
	fprintf( fp, "# set PAE-bit in CR4 \n" );
	fprintf( fp, "\tmov\t%%eax, %%cr4 \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\t# setup system control register CR3  \n" );
	fprintf( fp, "\tmov\tregCR3, %%eax \n" );
	fprintf( fp, "\tmov\t%%eax, %%cr3 \t\t" );
	fprintf( fp, "# setup page-mapping \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\t# setup system control register CR0  \n" );
	fprintf( fp, "\tcli\t\t\t\t" );
	fprintf( fp, "# no device interrupts" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%cr0, %%eax \n" );
	fprintf( fp, "\tbts\t$0, %%eax \t\t" );
	fprintf( fp, "# set PE-bit in CR0 \n" );
	fprintf( fp, "\tbts\t$31, %%eax \t\t" );
	fprintf( fp, "# set PG-bit in CR0 \n" );
	fprintf( fp, "\tmov\t%%eax, %%cr0 \t\t" );
	fprintf( fp, "# turn on protection \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\t# setup the system descriptor-table registers \n" );
	fprintf( fp, "\tlgdt\tregGDT\t\t\t" );
	fprintf( fp, "# setup GDTR register \n" );
	fprintf( fp, "\tlidt\tregIDT\t\t\t" );
	fprintf( fp, "# setup IDTR register \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\t# load segment-registers with suitable selectors \n" );
	fprintf( fp, "\tljmp\t$sel_cs, $pm\t\t" );
	fprintf( fp, "# reload register CS" );
	fprintf( fp, "\npm:" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t$sel_ds, %%ax\t\t" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%ss\t\t" );
	fprintf( fp, "# reload register SS" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%ds\t\t" );
	fprintf( fp, "# reload register DS" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%es\t\t" );
	fprintf( fp, "# reload register ES" );
	fprintf( fp, "\n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\txor\t%%ax, %%ax\t\t" );
	fprintf( fp, "# use \"null\" selector" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%fs\t\t" );
	fprintf( fp, "# to purge invalid FS" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%gs\t\t" );
	fprintf( fp, "# to purge invalid GS" );
	fprintf( fp, "\n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\tret\t" );
	fprintf( fp, "\n" );
	fprintf( fp, "#%s\n", border );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "leave_ia32e_mode:\n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\t# insure segment-register caches " );
	fprintf( fp, "have 'real' attributes \n" );
	fprintf( fp, "\tmov\t$sel_ds, %%ax\t\t" );
	fprintf( fp, "# address 64K r/w segment \n" );
	fprintf( fp, "\tmov\t%%ax, %%ds\t\t" );
	fprintf( fp, "#   using DS register \n" );
	fprintf( fp, "\tmov\t%%ax, %%es\t\t" );
	fprintf( fp, "#    and ES register \n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\t# modify system control register CR0 \n" );
	fprintf( fp, "\tmov\t%%cr0, %%eax\t\t" );
	fprintf( fp, "# get machine status" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tbtr\t$0, %%eax\t\t" );
	fprintf( fp, "# reset PE-bit to 0 " );
	fprintf( fp, "\n" );
	fprintf( fp, "\tbtr\t$31, %%eax\t\t" );
	fprintf( fp, "# reset PG-bit to 0 " );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%eax, %%cr0\t\t" );
	fprintf( fp, "# disable protection" );
	fprintf( fp, "\n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\t# reload segment-registers with " );
	fprintf( fp, "real-mode addresses \n" );
	fprintf( fp, "\tljmp\t$0x1000, $rm\t\t" );
	fprintf( fp, "# reload register CS" );
	fprintf( fp, "\nrm:" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%cs, %%ax\t\t" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%ss\t\t" );
	fprintf( fp, "# reload register SS" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%ds\t\t" );
	fprintf( fp, "# reload register DS" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%es\t\t" );
	fprintf( fp, "# reload register ES" );
	fprintf( fp, "\n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\t# restore real-mode interrupt-vectors \n" );
	fprintf( fp, "\tlidt\tregIVT\t\t\t" );
	fprintf( fp, "# restore vector table" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tsti\t\t\t\t" );
	fprintf( fp, "# and allow interrupts" );
	fprintf( fp, "\n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\tret\t" );
	fprintf( fp, "\n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "execute_our_demo: \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\t# preserve the stack-address \n" );
	fprintf( fp, "\tmov\t%%esp, tossave+0\t\t" );
	fprintf( fp, "# preserve 32-bit offset \n" );
	fprintf( fp, "\tmov\t%%ss,  tossave+4\t\t" );
	fprintf( fp, "#  plus 16-bit selector \n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\t# transfer via call-gate to 64-bit code-segment \n" );
	fprintf( fp, "\tlcall\t$gate64, $0   \t\t" );
	fprintf( fp, "# transfer to 64-bit code \n" );
	fprintf( fp, "\n" );

	fprintf( fp, "\t# restore saved stack-address \n" );
	fprintf( fp, "fin:\tlss\t%%cs:tossave, %%esp \t" );
	fprintf( fp, "# reload our saved SS:ESP \n" );
	fprintf( fp, "\tret\t\t\t\t" );
	fprintf( fp, "# return to main function " );
	fprintf( fp, "\n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "tossave:  .long\t0, 0 \t\t\t" );
	fprintf( fp, "# stores a 48-bit pointer \n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "msg1:\t.ascii\t\" Now executing 64-bit code \" \n" );
	fprintf( fp, "len1:\t.quad\t. - msg1 \n" );
	fprintf( fp, "att1:\t.byte\t0x50     \n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "prog64:\t.code64 \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\t# display confirmation-message \n" );
	fprintf( fp, "\tmov\t$3, %%rax \n" );
	fprintf( fp, "\timul\t$160, %%rax, %%rdi \n" );
	fprintf( fp, "\tadd\t$0xB8000, %%rdi \n" );
	fprintf( fp, "\tcld \n" );
	fprintf( fp, "\tlea\tmsg1, %%rsi \n" );
	fprintf( fp, "\tmov\tlen1, %%rcx \n" );
	fprintf( fp, "\tmov\tatt1, %%ah  \n" );
	fprintf( fp, ".M0: " );
	fprintf( fp, "\tlodsb \n" );
	fprintf( fp, "\tstosw \n" );
	fprintf( fp, "\tloop\t.M0 \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tlretq \n" );
	
	fprintf( fp, "#%s\n", border );
	fprintf( fp, "isrGPF:\t.code64 \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\t# our fault-handler for " );
	fprintf( fp, "General Protection Exceptions \n" );
	fprintf( fp, "\tpush\t%%rax\t\n" );
	fprintf( fp, "\tpush\t%%rbx\t\n" );
	fprintf( fp, "\tpush\t%%rcx\t\n" );
	fprintf( fp, "\tpush\t%%rdx\t\n" );
	fprintf( fp, "\tpush\t%%rsp\t\n" );
	fprintf( fp, "\taddq\t$40, (%%rsp)\t\n" );
	fprintf( fp, "\tpush\t%%rbp\t\n" );
	fprintf( fp, "\tpush\t%%rsi\t\n" );
	fprintf( fp, "\tpush\t%%rdi\t\n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tpushq\t$0\t\t\t\t\n" );
	fprintf( fp, "\tmov\t%%ds, (%%rsp)\t\t# store DS \n" ); 
	fprintf( fp, "\tpushq\t$0\t\t\t\t\n" );
	fprintf( fp, "\tmov\t%%es, (%%rsp)\t\t# store ES \n" ); 
	fprintf( fp, "\tpushq\t$0\t\t\t\t\n" );
	fprintf( fp, "\tmov\t%%fs, (%%rsp)\t\t# store FS \n" ); 
	fprintf( fp, "\tpushq\t$0\t\t\t\t\n" );
	fprintf( fp, "\tmov\t%%gs, (%%rsp)\t\t# store GS \n" ); 
	fprintf( fp, "\tpushq\t$0\t\t\t\t\n" );
	fprintf( fp, "\tmov\t%%ss, (%%rsp)\t\t# store SS \n" ); 
	fprintf( fp, "\tpushq\t$0\t\t\t\t\n" );
	fprintf( fp, "\tmov\t%%cs, (%%rsp)\t\t# store CS \n" ); 
	fprintf( fp, "\n" );

	fprintf( fp, "\txor\t%%rbx, %%rbx \t\t" );
	fprintf( fp, "# initialize element-index \n" );
	fprintf( fp, "nxelt: \n" );
	fprintf( fp, "\t# place element-name in buffer \n" );
	fprintf( fp, "\tmov\tnames(, %%rbx, 4), %%eax \t\n" );
	fprintf( fp, "\tmov\t%%eax, buf \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\t# place element-value in buffer \n" );
	fprintf( fp, "\tmov\t(%%rsp, %%rbx, 8), %%rax \n" );
	fprintf( fp, "\tlea\tbuf+5, %%rdi \n" );
	fprintf( fp, "\tcall\trax2hex \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\t# compute element-location in RDI \n" );
	fprintf( fp, "\tmov\t$23, %%rax \n" );
	fprintf( fp, "\tsub\t%%rbx, %%rax \n" );
	fprintf( fp, "\timul\t$160, %%rax, %%rdi \n" );
	fprintf( fp, "\tadd\t$0xB8000, %%rdi \n" );
	fprintf( fp, "\tadd\t$110, %%rdi \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\t# draw buffer-contents to screen-location \n" );
	fprintf( fp, "\tcld \n" );
	fprintf( fp, "\tlea\tbuf, %%rsi \n" );
	fprintf( fp, "\tmov\tlen, %%rcx \n" );
	fprintf( fp, "\tmov\tatt, %%ah  \n" );
	fprintf( fp, "nxpel:" );
	fprintf( fp, "\tlodsb \n" );
	fprintf( fp, "\tstosw \n" );
	fprintf( fp, "\tloop\tnxpel \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\t# advance the element-index \n" );
	fprintf( fp, "\tinc\t%%rbx \n" );
	fprintf( fp, "\tcmp\t$N_ELTS, %%rbx \n" );
	fprintf( fp, "\tjb\tnxelt \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\t# now transfer to demo finish \n" );
	fprintf( fp, "\tljmp\t*depart	\t\t" );
	fprintf( fp, "# indirect long jump \n" );
	fprintf( fp, "#%s\n", border );
	fprintf( fp, "depart:\t.long\tfin, sel_cs \t\t" );
	fprintf( fp, "# target for indirect jump \n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "hex:\t.ascii\t\"0123456789ABCDEF\"\t" );
	fprintf( fp, "# array of hex digits\n" );
	fprintf( fp, "names:" );
	fprintf( fp, "\t.ascii\t\"  CS  SS  GS  FS  ES  DS\" \n" );
	fprintf( fp, "\t.ascii\t\" RDI RSI RBP RSP RDX RCX RBX RAX\" \n" );
	fprintf( fp, "\t.ascii\t\" err RIP  CS RFL RSP  SS\" \n" );
	fprintf( fp, "\t.equ\tN_ELTS, (. - names)/4 \t" );
	fprintf( fp, "# number of elements \n" );
	fprintf( fp, "buf:\t.ascii\t\" nnn=xxxxxxxxxxxxxxxx \"\t" );
	fprintf( fp, "# buffer for output \n" );
	fprintf( fp, "len:\t.quad\t. - buf \t\t" );
	fprintf( fp, "# length of output \n" );
	fprintf( fp, "att:\t.byte\t0x70\t\t\t" );
	fprintf( fp, "# color attributes \n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "rax2hex: .code64 \n" );
	fprintf( fp, "\t# converts value in EAX " );
	fprintf( fp, "to hexadecimal string at DS:EDI \n" );
	fprintf( fp, "\tpush\t%%rax \n" );
	fprintf( fp, "\tpush\t%%rbx \n" );
	fprintf( fp, "\tpush\t%%rcx \n" );
	fprintf( fp, "\tpush\t%%rdx \n" );
	fprintf( fp, "\tpush\t%%rdi \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t$16, %%rcx \t\t" );
	fprintf( fp, "# setup digit counter \n" );
	fprintf( fp, "nxnyb:" );
	fprintf( fp, "\trol\t$4, %%rax \t\t" );
	fprintf( fp, "# next nybble into AL \n" );
	fprintf( fp, "\tmov\t%%al, %%bl \t\t" );
	fprintf( fp, "# copy nybble into BL \n" );
	fprintf( fp, "\tand\t$0xF, %%rbx\t\t" );
	fprintf( fp, "# isolate nybble's bits \n" );
	fprintf( fp, "\tmov\thex(%%rbx), %%dl\t\t" );
	fprintf( fp, "# lookup ascii-numeral \n" );
	fprintf( fp, "\tmov\t%%dl, (%%rdi) \t\t" );
	fprintf( fp, "# put numeral into buf \n" );
	fprintf( fp, "\tinc\t%%rdi\t\t\t" );
	fprintf( fp, "# advance buffer index \n" );
	fprintf( fp, "\tloop\tnxnyb\t\t\t" );
	fprintf( fp, "# back for next nybble\n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tpop\t%%rdi \n" );
	fprintf( fp, "\tpop\t%%rdx \n" );
	fprintf( fp, "\tpop\t%%rcx \n" );
	fprintf( fp, "\tpop\t%%rbx \n" );
	fprintf( fp, "\tpop\t%%rax \n" );
	fprintf( fp, "\tret \n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "\t.align\t16 \t\t\t" );
	fprintf( fp, "# insure stack alignment \n" );
	fprintf( fp, "\t.space\t512 \t\t\t" );
	fprintf( fp, "# reserved for stack use \n" );
	fprintf( fp, "tos:\t\t\t\t\t" );
	fprintf( fp, "# label for top-of-stack \n" );
	fprintf( fp, "#%s\n", border );

	fprintf( fp, "\n\n\n\n" );
	
	fprintf( fp, "\n" );
	fprintf( fp, "\n\t.section\t.data \n" );
	fprintf( fp, "#%s\n", border );

	fprintf( fp, "# NOTE: Here we create the 4-level " );
	fprintf( fp, "page-mapping tables, needed for \n" );
	fprintf( fp, "# execution in protected-mode with " );
	fprintf( fp, "64-bit Page-Address Extensions. \n" );
	fprintf( fp, "# The lowest 64-KB of the virtual-" );
	fprintf( fp, "address space is linearly mapped \n" );
	fprintf( fp, "# upward to the load-address at 0x10000, " );
	fprintf( fp, "which facilitates our use \n" );
	fprintf( fp, "# of symbolic addresses when a segment's " );
	fprintf( fp, "base-address equals zero. \n" );
	fprintf( fp, "# Otherwise, the rest of the bottom " );
	fprintf( fp, "megabyte is \"identity-mapper\". \n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "level1:" );

	fprintf( fp, "\tentry = ARENA \t\t\t" );
	fprintf( fp, "# initial physical address \n" );
	fprintf( fp, "\t.rept\t16 \t\t\t" );
	fprintf( fp, "# sixteen 4-KB page-frames \n" );
	fprintf( fp, "\t.quad\tentry + 3 \t\t" );
	fprintf( fp, "# 'present' and 'writable' \n" );
	fprintf( fp, "\tentry = entry + 0x1000 \t\t" );
	fprintf( fp, "# next page-frame address \n" );
	fprintf( fp, "\t.endr \t\t\t\t" );
	fprintf( fp, "# end of this repeat-macro \n" );

	fprintf( fp, "\tentry = ARENA \t\t\t" );
	fprintf( fp, "# initial physical address \n" );
	fprintf( fp, "\t.rept\t240 \t\t\t" );
	fprintf( fp, "# remainder of bottom 1-MB \n" );
	fprintf( fp, "\t.quad\tentry + 3 \t\t" );
	fprintf( fp, "# 'present' and 'writable' \n" );
	fprintf( fp, "\tentry = entry + 0x1000 \t\t" );
	fprintf( fp, "# next page-frame address \n" );
	fprintf( fp, "\t.endr \t\t\t\t" );
	fprintf( fp, "# end of this repeat-macro \n" );

	fprintf( fp, "\t.align\t0x1000 \t\t\t" );
	fprintf( fp, "# rest of table has zeros \n" );
	fprintf( fp, "#%s\n", border );
	fprintf( fp, "level2:" );
	fprintf( fp, "\t.quad\tlevel1 + ARENA + 3 \t" );
	fprintf( fp, "# initial directory entry \n" );
	fprintf( fp, "\t.align\t0x1000 \t\t\t" );
	fprintf( fp, "# rest of table has zeros \n" );
	fprintf( fp, "#%s\n", border );
	fprintf( fp, "level3:" );
	fprintf( fp, "\t.quad\tlevel2 + ARENA + 3 \t" );
	fprintf( fp, "# initial 'pointer' entry \n" );
	fprintf( fp, "\t.align\t0x1000 \t\t\t" );
	fprintf( fp, "# rest of table has zeros \n" );
	fprintf( fp, "#%s\n", border );
	fprintf( fp, "level4:" );
	fprintf( fp, "\t.quad\tlevel3 + ARENA + 3 \t" );
	fprintf( fp, "# initial 'level-4' entry \n" );
	fprintf( fp, "\t.align\t0x1000 \t\t\t" );
	fprintf( fp, "# rest of table has zeros \n" );
	fprintf( fp, "#%s\n", border );
	fprintf( fp, "\t.end\t\t\t\t" );
	fprintf( fp, "# no more to be assembled " );
	fprintf( fp, "\n" );

	printf( "\n" );
}
