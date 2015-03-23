/*-
 * debug.h
 * Copyright (c) 2000 Fumitoshi UKAI <ukai@debian.or.jp>
 * GPL
 *
 */

#ifndef _debug_h_
#define _debug_h_
static char debug_h_rcsid[] __attribute__ ((unused)) = "$Id: debug.h,v 1.1 2000/07/12 03:42:47 ukai Exp $";

#include <stdio.h>
#include <errno.h>
#include <unistd.h>

#ifdef PKGCDB_AUTOAPT
#define PKGCDB_API	static
#define PKGCDB_VARDECL	static
#define PKGCDB_VARDEF	static
#else
#define PKGCDB_API
#define PKGCDB_VARDECL	extern
#define PKGCDB_VARDEF	
#endif

#ifdef DEBUG
PKGCDB_VARDECL int debug;
#define DPRINT(x) if (debug) printf x
#else
#define DPRINT(x)
#endif

PKGCDB_VARDECL int verbose;
PKGCDB_VARDECL int quiet;

#define MSG(x)	if (!quiet) printf x
#define VMSG(x)	if (!quiet && verbose) printf x
#define PERROR(x)	if (!quiet) perror x


static inline int
read_data(int fd, void *buf, int siz)
{
    int r = 0;
    int n = siz;
    char *p = (char *)buf;
    while (n > 0) {
	r = read(fd, p, n);
	if (r < 0) {
	    if (errno == EINTR)
		continue;
	    return r;
	}
	if (r == 0) {
	    return siz - n;
	}
	p += r;
	n -= r;
    }
    return siz;
}


#endif /* _debug_h_ */
