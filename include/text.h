#ifndef TEXT_H_
#define TEXT_H_
#include <stdarg.h>
int init_text(void);
int kfflush(void);
int kputc(char ch);
int kputs(const char *s);
int kprintf(const char *format, ...);
#endif // TEXT_H_
