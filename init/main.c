#include <type.h>
#include <text.h>
#include <memory.h>

static void error_halt(void)
{
	asm (
			"cli\n"
			"hlt"
	    );
}
void kmain(__u32 k_size, void *boot_info)
{
	// Our stack is at 0x7000
	// init text system
	init_text();

	// init our pages
	if ((__u64)boot_info < 0x100000U) {
		boot_info += 0xFFFFFFFF80000000ULL;
		init_mem(k_size, boot_info);
	} else {
		kputs("Boot Info Not at Address Below 1MiB");
		error_halt();
	}
	
	// Print A Msg
	kputs("This is a 64 bits kernel");
	for (;;) ;
}
