#include <stdio.h>

void __cyg_profile_func_enter (void *this_fn, void *call_site);
void __cyg_profile_func_exit (void *this_fn, void *call_site);

void __cyg_profile_func_enter (void *this_fn, void *call_site)
{
                printf ("enter %p\n", this_fn);
}
void __cyg_profile_func_exit (void *this_fn, void *call_site)
{
                printf ("exit %p\n", this_fn);
}
