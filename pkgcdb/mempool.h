/*-
 * mempool.h
 * Copyright (c) 2000 Fumitoshi UKAI <ukai@debian.or.jp>
 * GPL
 *
 */

#ifndef _mempool_h_
#define _mempool_h_

static char mempool_h_rcsid[] __attribute__ ((unused)) = "$Id: mempool.h,v 1.1 2000/07/12 03:42:47 ukai Exp $";

#include "debug.h"
#include <stdio.h>
#include <sys/types.h>

PKGCDB_API void mempool_init();
PKGCDB_API struct mempool *mempool_alloc(struct mempool *mp, 
					 int count, size_t siz);
#ifndef PKGCDB_AUTOAPT
PKGCDB_API void mempool_release(struct mempool *mp);
#endif

#ifndef PKGCDB_AUTOAPT
PKGCDB_API void mempool_shrink(struct mempool *mp, int num);
#endif
PKGCDB_API void *mempool_mem(struct mempool *mp);
PKGCDB_API void *mempool_mem_avail(struct mempool *mp, int avail);
PKGCDB_API int mempool_index(struct mempool *mp, void *ptr);
PKGCDB_API void *mempool_fetch(struct mempool *mp, int idx);
#ifndef PKGCDB_AUTOAPT
PKGCDB_API int mempool_count(struct mempool *mp);
#endif

#ifndef PKGCDB_AUTOAPT
PKGCDB_API int mempool_dump(struct mempool *mp, int fd, 
			    int (*serialize)(void *buf, /* buf[count*siz] */
					     void *ptr, int count, int siz, 
					     void *arg),
			    void *arg);
#endif
PKGCDB_API struct mempool *mempool_restore(int fd,
					   void (*unserialize)(
					       struct mempool *mp,
					       void *ptr, 
					       int count, int siz,
					       void *arg),
					   void *arg,
					   int margin);

#endif /* _mempool_h_ */
