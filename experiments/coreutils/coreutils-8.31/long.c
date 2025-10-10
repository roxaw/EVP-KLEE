#include <features.h>
#if defined __GNU_LIBRARY__ && __GLIBC__ >= 2
int foo[sizeof (long double) - sizeof (double) - 1];
#else
"run this test only with glibc"
#endif
