#include <stdio.h>
#include <selinux/selinux.h>
#include <errno.h>

int getfilecon (const char *path, char **con)
{
  /* Leave a marker so we can identify if the function was intercepted.  */
  fclose(fopen("preloaded", "w"));

  errno=ENODATA;
  return -1;
}

int getfilecon_raw (const char *path, char **con)
{ return getfilecon (path, con); }

int lgetfilecon (const char *path, char **con)
{ return getfilecon (path, con); }

int lgetfilecon_raw (const char *path, char **con)
{ return getfilecon (path, con); }
