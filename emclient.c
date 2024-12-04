#include <stdlib.h>

// https://github.com/emacs-mirror/emacs/blob/69e1f787528eaf2f223c53a6ff518ba4f984bc17/lib-src/emacsclient.c#L896

/* In STR, insert a & before each &, each space, each newline, and
   any initial -.  Change spaces to underscores, too, so that the
   return value never contains a space.

   Does not change the string.  Outputs the result to S.  */
int
emacs_quote_argument (const char *str, char* res)
{
    char *copy = res;
  char *q = copy;
  if (*str == '-')
    *q++ = '&', *q++ = *str++;
  for (; *str; str++)
    {
      char c = *str;
      if (c == ' ')
	*q++ = '&', c = '_';
      else if (c == '\n')
	*q++ = '&', c = 'n';
      else if (c == '&')
	*q++ = '&';
      *q++ = c;
    }
  *q = 0;

  return q-copy;
}


/* The inverse of quote_argument.  Remove quoting in string STR by
   modifying the addressed string in place.  Return STR.  */

int
emacs_unquote_argument (char *str)
{
  char const *p = str;
  char *q = str;
  char c;

  do
    {
      c = *p++;
      if (c == '&')
	{
	  c = *p++;
	  if (c == '_')
	    c = ' ';
	  else if (c == 'n')
	    c = '\n';
	}
      *q++ = c;
    }
  while (c);

  return q-str;
}

