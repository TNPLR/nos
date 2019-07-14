#include <memory.h>
#include <kstring.h>
#include <bitmap.h>
#include <text.h>
#include <type.h>
enum {
	PG_P = 0x1UL, // Present
	PG_RW = 0x2UL,
	PG_US = 0x4UL, // If Set, CPL=3 could access
	PG_PWT = 0x8UL, // If Set, table or physical page has a writethrough
	PG_PCD = 0x10UL, // Page-Level Cache Disable (PCD) Bit
	PG_A = 0x20UL, // Accessed
	PG_D = 0x40UL, // Dirty
	PG_PAT = 0x80UL, // Page-Attribute Table (PAT) Bit
	PG_G = 0x100UL, // Global Bit
	PG_NX = 0x8000000000000000UL, // No Execute (NX) Bit
};

static void init_loopback_pages(void)
{
	*((__u64 *)0x1C0FF0UL) = 0x1C0003;
}

static void setupPML4E(__u64 index, __u64 vaddr)
{
	*(__u64 *)(((vaddr >> 36) & 0xFF8) | 0xFFFFFF7FBFDFE000UL) = index;
}

static void setupPDPE(__u64 index, __u64 vaddr)
{
	*(__u64 *)(((vaddr >> 27) & 0x1FFFF8L) | 0xFFFFFF7FBFC00000UL) = index;
}

static void setupPDE(__u64 index, __u64 vaddr)
{
	*(__u64 *)(((vaddr >> 18) & 0x3FFFFFF8UL) | 0xFFFFFF7F80000000UL) = index;
}

static void setupPTE(__u64 index, __u64 vaddr)
{
	*(__u64 *)(((vaddr >> 9) & 0x7FFFFFFFF8UL) | 0xFFFFFF0000000000UL) = index;
}

static __u64 getPML4E(__u64 vaddr)
{
	return *(__u64 *)(((vaddr >> 36) & 0xFF8) | 0xFFFFFF7FBFDFE000UL);
}

static __u64 getPDPE(__u64 vaddr)
{
	return *(__u64 *)(((vaddr >> 27) & 0x1FFFF8L) | 0xFFFFFF7FBFC00000UL);
}

static __u64 getPDE(__u64 vaddr)
{
	return *(__u64 *)(((vaddr >> 18) & 0x3FFFFFF8UL) | 0xFFFFFF7F80000000UL);
}

static __u64 getPTE(__u64 vaddr)
{
	return *(__u64 *)(((vaddr >> 9) & 0x7FFFFFFFF8UL) | 0xFFFFFF0000000000UL);
}

static int remove_low_addr_vaddr(void)
{
	setupPML4E(0, 0);
	return 0;
}

static int remove_1mb_addr_vaddr(void)
{
	for (int i = 0; i < 0x100; ++i) {
		setupPTE(0, 0xFFFFFFFF80100000 | (i << 12));
	}
	return 0;
}

struct multiboot2_memory_map_entry {
	__u64 base_addr;
	__u64 length;
	__u32 type;
	__u32 reserved;
} __attribute__((packed));

struct multiboot2_memory_map {
	__u32 type;
	__u32 size;
	__u32 entry_size;
	__u32 entry_version;
	struct multiboot2_memory_map_entry entry[];
} __attribute__((packed));

static struct multiboot2_memory_map *memory_map;

static int find_memory_map_entry(void *boot_info)
{
	boot_info = ((__u32*)boot_info) + 2;
	while (*((__u32 *)boot_info) != 0) {
		if (*((__u32 *)boot_info) == 6) { // MM type == 6
			memory_map = boot_info;
			return 0;
		}
		boot_info = (__u8 *)boot_info + *((__u32 *)boot_info+1);
	}
	return 1;
}

static int print_mm_info(void)
{
	int index = (memory_map->size - 16) / memory_map->entry_size;
	for (int i = 0; i < index; ++i) {
		if (memory_map->entry[i].type == 1) {
			kprintf("Available\tBase = 0x%x\t\tLength = %u Bytes\n",
					memory_map->entry[i].base_addr,
					memory_map->entry[i].length);
		} else {
			kprintf("Reserved\tBase = 0x%x\t\tLength = %u Bytes\n",
					memory_map->entry[i].base_addr,
					memory_map->entry[i].length);
		}
	}
	return 0;
}

static void * const pmemory_bitmap = (void *)0xFFFFFFFF80009000UL;
static __u64 pmemory_page_count = 0;
static __u64 pmemory_page_available_count;
static void * const vmemory_bitmap = (void *)0xFFFFFFFF8000A000UL;
static void * const vmemory_start_addr = (void *)0xFFFFFFFF80000000UL;

static void *(*physical_page_alloc)(void);
static void (*free_physical_page)(void *paddr);

// TODO ALLOCATE FUNCTIONS
static void bootmem_free_physical_page(void *paddr)
{
	clear_bitmap(pmemory_bitmap, (__u64)paddr >> 12, 1);
}

static void *bootmem_physical_page_alloc(void)
{
	__u64 ppage = find_bits(pmemory_bitmap, 0x1000, 1);
	if (ppage < 0x8000) {
		set_bitmap(pmemory_bitmap, ppage, 1);
		return (void *)(ppage << 12);
	}
	return (void *)0;
}

// return 1 when cannot allocate memory
// return 0 when done correctly
static int newPDPT(__u64 vaddr, __u64 attr)
{
	if (getPML4E(vaddr) & PG_P) {
		return 0;
	}
	void *t_addr = physical_page_alloc();
	if (!t_addr) {
		return 1;
	}
	memset(t_addr, 0, 0x1000);
	setupPML4E((__u64)t_addr | attr | PG_P, vaddr);
	return 0;
}

static int newPDT(__u64 vaddr, __u64 pdpt_attr, __u64 attr)
{
	if (newPDPT(vaddr, pdpt_attr)) {
		return 1;
	}
	if (getPDPE(vaddr) & PG_P) {
		return 0;
	}
	void *t_addr = physical_page_alloc();
	if (!t_addr) {
		return 1;
	}
	memset(t_addr, 0, 0x1000);
	setupPDPE((__u64)t_addr | attr | PG_P, vaddr);
	return 0;
}

static int newPT(__u64 vaddr, __u64 pdpt_attr, __u64 pdt_attr, __u64 attr)
{
	if (newPDT(vaddr, pdpt_attr, pdt_attr)) {
		return 1;
	}
	if (getPDE(vaddr) & PG_P) {
		return 0;
	}
	void *t_addr = physical_page_alloc();
	if (!t_addr) {
		return 1;
	}
	memset(t_addr, 0, 0x1000);
	setupPDE((__u64)t_addr | attr | PG_P, vaddr);
	return 0;
}

static int newPG(__u64 vaddr, __u64 pdpt_attr, __u64 pdt_attr,
		__u64 pt_attr, __u64 attr, void *t_addr)
{
	if (newPT(vaddr, pdpt_attr, pdt_attr, pt_attr)) {
		return 1;
	}
	if (getPTE(vaddr) & PG_P) {
		return 0;
	}
	setupPTE((__u64)t_addr | attr | PG_P, vaddr);
	return 0;
}

static int removePG(__u64 vaddr)
{
	free_physical_page((void *)(getPTE(vaddr) & ~0xFFFUL));
	setupPTE(0UL, vaddr);
	return 0;
}

static void *bootmem_virtual_page_alloc(__u64 page_count)
{
	if (page_count + 3 > pmemory_page_available_count) {
		return (void *)0;
	}
	__u64 vpage = find_bits(vmemory_bitmap, 0x1000, page_count);
	set_bitmap(vmemory_bitmap, vpage, page_count);
	__u64 vaddr = (__u64)vmemory_start_addr + (vpage << 12);
	for (__u64 i = 0; i < page_count; ++i) {
		// Will not allocate failed
		newPG(vaddr + (i << 12), PG_RW, PG_RW, PG_RW, PG_RW,
				bootmem_physical_page_alloc());
	}
	return (void *)vaddr;
}

static void bootmem_free_virtual_page(void *ptr, __u64 page_count)
{
	for (__u64 i = 0; i < page_count; ++i) {
		removePG((__u64)ptr + (i << 12));
	}
}

static void setup_reserved_memory_bitmap(void)
{
	int index = (memory_map->size - 16) / memory_map->entry_size;
	for (int i = 0; i < index; ++i) {
		__u64 base = memory_map->entry[i].base_addr >> 12;
		__u64 length = memory_map->entry[i].length >> 12;
		if ((base + length < 0x1000) &&
				memory_map->entry[i].type != 1) {
			set_bitmap(pmemory_bitmap, base, length);
		}
		if (memory_map->entry[i].type == 1 &&
			       (pmemory_page_count < base + length)) {
			pmemory_page_count = base + length;
		}
	}
	if (pmemory_page_count > 32768) {
		pmemory_page_count = 32768;
	}
}
/*
 * Please Read the NOS Manual for more details
 */
static void setup_bitmap_paddr(__u32 k_pages)
{
	/*
	 * Set Bitmap for reserved memory
	 */
	setup_reserved_memory_bitmap();

	/*
	 * We don't use lower 1MiB, but we still make them in the bitmap
	 */
	set_bitmap(pmemory_bitmap, 0, 256);

	/*
	 * PML4T 0x1C0000
	 */
	set_bitmap(pmemory_bitmap, 0x1C0, 1);

	/*
	 * PDT PT
	 */
	set_bitmap(pmemory_bitmap, 0x1C2, 2);

	/*
	 * PDPT
	 */
	set_bitmap(pmemory_bitmap, 0x1C4, 1);

	/*
	 * PT of k_size
	 */
	set_bitmap(pmemory_bitmap, 0x1C5, k_pages >> 9);

	/*
	 * k_size
	 */
	set_bitmap(pmemory_bitmap, 0x200, k_pages);
}

static void setup_bitmap_vaddr(__u32 k_pages)
{
	/*
	 * lower 1MiB
	 */
	set_bitmap(vmemory_bitmap, 0, 256);

	/*
	 * Kernel
	 */
	set_bitmap(vmemory_bitmap, 0x200, k_pages);
}

void *(*page_alloc)(__u64 page_count);
void (*page_free)(void *pos, __u64 page_count);

static int init_bootmem(__u32 k_pages)
{
	// Physical Memory 128MiB (base = 0x0)
	init_bitmap(pmemory_bitmap, 0x1000);

	setup_bitmap_paddr(k_pages);

	pmemory_page_available_count = 
		available_bits(pmemory_bitmap, pmemory_page_count >> 3);

	// Virtual Memory 128MiB (base = 0xFFFFFFFF80000000)
	init_bitmap(vmemory_bitmap, 0x1000);

	setup_bitmap_vaddr(k_pages);
	return 0;
}

int init_mem(__u32 k_pages, void *boot_info)
{
	init_loopback_pages();

	remove_low_addr_vaddr();
	remove_1mb_addr_vaddr();
	
	kprintf("Kernel Page Count: %u\n", k_pages);

	if (find_memory_map_entry(boot_info)) {
		kputs("Cannot Find Memory Map Entry");
		return 1;
	}

	print_mm_info();

	if (init_bootmem(k_pages)){
		kputs("Cannot Initialize Boot Memory System");
		return 2;
	}

	physical_page_alloc = bootmem_physical_page_alloc;
	free_physical_page = bootmem_free_physical_page;
	page_free = bootmem_free_virtual_page;
	page_alloc = bootmem_virtual_page_alloc;
	kprintf("Physical Boot Memory: %u Pages\n", pmemory_page_count);
	kprintf("Available Boot Memory: %u Pages\n",
			pmemory_page_available_count);


	return 0;
}
