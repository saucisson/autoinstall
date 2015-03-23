/*-
 * strtab.h
 * Copyright (c) 2000 Fumitoshi UKAI <ukai@debian.or.jp>
 * GPL
 */

#ifndef _strtab_h_
#define _strtab_h_
static char strtab_h_rcsid[] __attribute__ ((unused)) = "$Id: strtab.h,v 1.1 2000/07/12 03:42:47 ukai Exp $";

#include "debug.h"
#include <stdio.h>

typedef int str_id;
#define str_null	0

typedef struct __strtab *StrTable;

#ifndef PKGCDB_AUTOAPT
PKGCDB_API StrTable strtab_alloc();
#endif
#ifndef PKGCDB_AUTOAPT
PKGCDB_API void strtab_release(StrTable st);
#endif

PKGCDB_API str_id str_intern(StrTable st, char *string, int add);
PKGCDB_API char *str_symbol(StrTable st, str_id sid);

/* dump/restore */
#ifndef PKGCDB_AUTOAPT
PKGCDB_API int strtab_dump(int fd, StrTable st, int shrink);
#endif
PKGCDB_API StrTable strtab_restore(int fd, int str_margin);

#endif /* _strtab_h_ */
 
