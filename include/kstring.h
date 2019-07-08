#ifndef KSTRING_H_
#define KSTRING_H_
void * memcpy(void * destination, const void * source, unsigned int size)
{
  void *ret = destination;
  asm volatile (
      "rep movsb"
      :"=c"(size), "=S"(source), "=D"(destination)
      :"0"(size), "1"(source), "2"(destination)
      : "memory");
  return ret;
}

#endif // KSTRING_H_
