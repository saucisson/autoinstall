/*-
 * pathnode.h
 * Copyright (c) 2000 Fumitoshi UKAI <ukai@debian.or.jp>
 * GPL
 *
 */

#ifndef _pathnode_h_
#define _pathnode_h_
static char pathnode_h_rcsid[] __attribute__ ((unused)) = "$Id: pathnode.h,v 1.1 2000/07/12 03:42:47 ukai Exp $";

#include "debug.h"
#include "strtab.h"
#include "pkgtab.h"

typedef struct __pathnode_tree *PathNodeTree;

#ifndef PKGCDB_AUTOAPT
PKGCDB_API PathNodeTree pathnode_alloc(StrTable st);
#endif
#ifndef PKGCDB_AUTOAPT
PKGCDB_API void pathnode_release(PathNodeTree pnt);
#endif

#ifndef PKGCDB_AUTOAPT
PKGCDB_API void pathnode_ignore_package(PathNodeTree pnt, char *pkg);
#endif

#ifndef PKGCDB_AUTOAPT
PKGCDB_API struct path_node *pathnode_insert(PathNodeTree pnt,
					     struct path_node *pn,
					     char *path, pkg_id pkgid);
#endif
#ifndef PKGCDB_AUTOAPT
PKGCDB_API struct path_node *pathnode_chain(PathNodeTree pnt,
					    struct path_node *pn,
					    pkg_id pkgid);
#endif
PKGCDB_API struct path_node *pathnode_retrieve(PathNodeTree pnt,
					       struct path_node *pn,
					       char *path);
PKGCDB_API void pathnode_traverse(PathNodeTree pnt,
				  char *path, struct path_node *pn,
				  void (*func)(PathNodeTree pnt,
					       char *path, 
					       struct path_node *pn, 
					       void *arg),
				  void *arg);

#ifndef PKGCDB_AUTOAPT
PKGCDB_API StrTable pathnode_strtab(PathNodeTree pnt);
#endif
PKGCDB_API struct path_node *pathnode_top(PathNodeTree pnt);
#ifndef PKGCDB_AUTOAPT
PKGCDB_API str_id pathnode_path(PathNodeTree pnt, struct path_node *pn);
#endif
PKGCDB_API char *pathnode_pathname(PathNodeTree pnt, struct path_node *pn);
#ifndef PKGCDB_AUTOAPT
PKGCDB_API pkg_id pathnode_package(PathNodeTree pnt, struct path_node *pn);
#endif
PKGCDB_API char *pathnode_packagename(PathNodeTree pnt, 
				      struct path_node *pkg_id);
#ifndef PKGCDB_AUTOAPT
PKGCDB_API struct path_node *pathnode_next(PathNodeTree pnt, 
					   struct path_node *pn);
#endif
#ifndef PKGCDB_AUTOAPT
PKGCDB_API void pathnode_delete(PathNodeTree pnt, struct path_node *pn);
#endif

#ifndef PKGCDB_AUTOAPT
PKGCDB_API int pathnode_dump(int fd, PathNodeTree pnt, int shrink);
#endif
PKGCDB_API PathNodeTree pathnode_restore(int fd, StrTable st, int margin);

#endif /* _pathnode_h_ */
