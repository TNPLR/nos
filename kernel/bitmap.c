#include <type.h>
#include <bitmap.h>
#include <kstring.h>

int init_bitmap(void *pos, __u64 size)
{
	memset(pos, 0, size);
	return 0;
}

static inline void setBit(void *pos, __u64 num)
{
	*((__u8 *)pos + (num >> 3)) |= 1 << (num & 0x7);
}

static inline void clearBit(void *pos, __u64 num)
{
	*((__u8 *)pos + (num >> 3)) &= ~(1 << (num & 0x7));
}

int set_bitmap(void *pos, __u64 num, __u64 count)
{
	for (__u64 i = 0; i < count; ++i) {
		setBit(pos, num + i);
	}
	return 0;
}

int clear_bitmap(void *pos, __u64 num, __u64 count)
{
	for (__u64 i = 0; i < count; ++i) {
		clearBit(pos, num + i);
	}
	return 0;
}

int get_bit_bitmap(void *pos, __u64 num)
{
	return *((__u8 *)pos + (num >> 3)) & (1 << (num & 0x7));
}
__u64 find_bits(void * const pos, const __u64 map_size, const __u64 find_size)
{
	__u64 retval;
	__u64 now_size = 0;
	bool cont = false;
	for (__u64 i = 0; i < (map_size << 3); ++i) {
		if (!cont && !get_bit_bitmap(pos, i)) {
			retval = i;
			++now_size;
			cont = true;
			if (now_size == find_size) {
				return retval;
			}
		} else if (cont) {
			if (!get_bit_bitmap(pos, i)) {
				++now_size;
				if (now_size == find_size) {
					return retval;
				}
			} else {
				cont = false;
				now_size = 0;
			}
		}
	}
	return map_size << 3;
}

__u64 available_bits(void * pos, __u64 size)
{
	__u64 cnt = 0;
	for (__u64 i = 0; i < (size << 3); ++i) {
		if (!get_bit_bitmap(pos, i)) {
			++cnt;
		}
	}
	return cnt;
}
