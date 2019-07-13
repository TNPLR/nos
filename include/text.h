#ifndef TEXT_H_
#define TEXT_H_
#include <stdarg.h>
void bufferScroll(void);
void initText(void);
void kfflush(void);
void bufferPutc(char ch);
void kputc(char ch);
void kputs(const char *s);
void kprintf(const char *format, ...);
#endif // TEXT_H_
