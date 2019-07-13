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
	*(__u64 *)(((vaddr >> 27) & 0xFF8) | 0xFFFFFF7FBFDFE000) = index;
}

static void setupPDE(__u64 index, __u64 vaddr)
{
	*(__u64 *)(((vaddr >> 18) & 0x1FFFF8) | 0xFFFFFF7FBFC00000) = index;
}

static void setupPTE(__u64 index, __u64 vaddr)
{
	*(__u64 *)(((vaddr >> 9) & 0x3FFFFFF8) | 0xFFFFFF7F80000000) = index;
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

static int init_bootmem(void)
{
	// 
	init_bitmap((void *)0x9000, 0x1000);
	return 0;
}

int init_mem(__u32 k_size, void *boot_info)
{
	// Loop back our page tables at 0xFFFFFF0000000000
	setupPML4E(((__u64)PML4T) | 3, 0xFFFFFF0000000000);

	if (find_memory_map_entry(boot_info)) {
		return 1;
	}

	print_mm_info();

	if (init_bootmem()) {
		return 2;
	}

	return 0;
}
