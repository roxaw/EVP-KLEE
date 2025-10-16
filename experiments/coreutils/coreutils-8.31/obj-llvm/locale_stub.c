// Minimal locale stubs for KLEE-friendly sort
#include <string.h>

// Force "C" locale
char *setlocale(int category, const char *locale) {
    return "C";
}

// Replace strcoll with strcmp (byte-wise compare)
int strcoll(const char *a, const char *b) {
    return strcmp(a, b);
}

// Replace strxfrm with simple string copy
size_t strxfrm(char *dest, const char *src, size_t n) {
    size_t len = strlen(src);
    if (n > 0 && dest) {
        strncpy(dest, src, n);
    }
    return len;
}
