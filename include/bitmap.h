#ifndef BITMAP_H_
#define BITMAP_H_
#include <type.h>
int init_bitmap(void *pos, __u64 size);
int set_bitmap(void *pos, __u64 num, __u64 count);
int clear_bitmap(void *pos, __u64 num, __u64 count);

// When the bit is clear, return 0
// Else return non-0 value
int get_bit_bitmap(void *pos, __u64 num);

__u64 find_bits(void * const pos, const __u64 map_size, const __u64 find_size);

__u64 available_bits(void *pos, __u64 size);
#endif // BITMAP_H_
