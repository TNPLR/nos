#include <memory.h>

#define PML4T ((void **)0xFFFFFFFF801C0000)

static void setupPML4E(unsigned long long int index, unsigned long long int vaddr)
{
  vaddr >>= 39;
  vaddr &= 0x1FF;
  *(PML4T+vaddr) = (void *)index;
}

static void setupPDPE(unsigned long long int index, unsigned long long int vaddr)
{
  *(unsigned long long int *)(((vaddr >> 27) & 0xFF8) | 0xFFFFFF7FBFDFE000) = index;
}

static void setupPDE(unsigned long long int index, unsigned long long int vaddr)
{
  *(unsigned long long int *)(((vaddr >> 18) & 0x1FFFF8) | 0xFFFFFF7FBFC00000) = index;
}

static void setupPTE(unsigned long long int index, unsigned long long int vaddr)
{
  *(unsigned long long int *)(((vaddr >> 9) & 0x3FFFFFF8) | 0xFFFFFF7F80000000) = index;
}
void initRam(void)
{
  // Loop back our page tables at 0xFFFFFF0000000000
  setupPML4E(((unsigned long long int)PML4T) | 3, 0xFFFFFF0000000000);
}

