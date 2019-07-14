#include <memory.h>
#include <bitmap.h>
#include <text.h>
#include <type.h>

#define PML4T ((void **)0xFFFFFFFF801C0000)

static void setupPML4E(__u64 index, __u64 vaddr)
{
	vaddr >>= 39;
	vaddr &= 0x1FF;
	*(PML4T+vaddr) = (void *)index;
}

static void setupPDPE(__u64 index, __u64 vaddr)
{
	*(__u64 *)(((vaddr >> 27) & 0xFF8) | 0xFFFFFF7FBFDFE000UL) = index;
}

static void setupPDE(__u64 index, __u64 vaddr)
{
	*(__u64 *)(((vaddr >> 18) & 0x1FFFF8) | 0xFFFFFF7FBFC00000UL) = index;
}

static void setupPTE(__u64 index, __u64 vaddr)
{
	*(__u64 *)(((vaddr >> 9) & 0x3FFFFFF8U) | 0xFFFFFF7F80000000UL) = index;
}

static int remove_low_addr_vaddr(void)
{
	setupPML4E(0, 0);
	return 0;
}

static __u32 bootmem_paddr_page_count;
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

static __u32 get_kernel_pg_size(__u32 k_size)
{
	return (k_size >> 12) + ((k_size & 0xFFF) && 1);
}

static int print_mm_info(void)
{
	int index = (memory_map->size - 16) / memory_map->entry_size;
	for (int i = 0; i < index; ++i) {
		if (memory_map->entry[i].type == 1) {
			kprintf("Avalible\tBase = 0x%x\t\tLength = %u Bytes\n",
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

static void *pmemory_bitmap = (void *)0xFFFFFFFF80009000;
static __u64 pmemory_page_count;
static void *vmemory_bitmap = (void *)0xFFFFFFFF8000A000;

static void setup_reserved_memory_bitmap(void)
{
	int index = (memory_map->size - 16) / memory_map->entry_size;
	for (int i = 0; i < index; ++i) {
		// TODO
		int base = memory_map->entry[i].base_addr >> 12;
		int length = memory_map->entry[i].length >> 12;
		if (base + length < 0x1000) {
			set_bitmap(pmemory_bitmap, base, length);
		}
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
	//setup_reserved_memory_bitmap();

	/*
	 * We don't use lower 1MiB
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
	set_bitmap(pmemory_bitmap, 0x1C5, k_pages);
}

static int init_bootmem(__u32 k_pages)
{
	// Physical Memory 128MiB (base = 0x0)
	init_bitmap(pmemory_bitmap, 0x1000);

	setup_bitmap_paddr(k_pages);

	// Virtual Memory 128MiB (base = 0xFFFFFFFF80000000)
	init_bitmap(vmemory_bitmap, 0x1000);
	return 0;
}

int init_mem(__u32 k_size, void *boot_info)
{
	// Loop back our page tables at 0xFFFFFF0000000000
	setupPML4E(((__u64)PML4T) | 3, 0xFFFFFF0000000000);

	remove_low_addr_vaddr();
	
	kprintf("Kernel Page Count: %x\n", k_size);

	if (find_memory_map_entry(boot_info)) {
		kputs("Cannot Find Memory Map Entry");
		return 1;
	}

	print_mm_info();

	if (init_bootmem(get_kernel_pg_size(k_size))) {
		kputs("Cannot Initialize Boot Memory System");
		return 2;
	}


	return 0;
}
