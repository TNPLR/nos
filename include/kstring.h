#ifndef KSTRING_H_
#define KSTRING_H_
static inline void *memcpy(void * destination, const void * source, unsigned int size)
{
  void *ret = destination;
  asm volatile (
      "rep movsb"
      :"=c"(size), "=S"(source), "=D"(destination)
      :"0"(size), "1"(source), "2"(destination)
      : "memory");
  return ret;
}

static inline void *memset(void *str, int c, unsigned int size)
{
  void *ret = str;
  asm volatile (
      "rep stosb"
      :"=c"(size), "=S"(str)
      :"0"(size), "1"(str), "a"(c) 
      : "memory");
  return ret;
}

#endif // KSTRING_H_
