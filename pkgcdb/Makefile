#
# Makefile
# $Id: Makefile,v 1.1 2000/07/12 03:42:47 ukai Exp $
#

DEFS=
CC=gcc
AR=ar
CFLAGS=-g -Wall $(DEFS)
OBJS=pkgcdb2.o pathnode.o pkgtab.o strtab.o mempool.o

pkgcdb2.a: $(OBJS)
	$(AR) rc pkgcdb2.a $(OBJS)

clean:
	-rm -f $(OBJS) pkgcdb2.a

distclean: clean
	-rm -f *~ *.bak *.orig *.o

