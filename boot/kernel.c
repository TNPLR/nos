void bootEntry(void)
{
  *(int *)0xB8000 = 0x0F5A0F59;
  for (;;) ;
}
