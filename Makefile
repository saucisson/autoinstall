PREFIX=/usr/
CFLAGS=-Wall -Wextra -O3

all: autoinstall.so

autoinstall.so: autoinstall.o
	$(CC) -shared -o autoinstall.so autoinstall.o -lc -ldl -llua5.1

autoinstall.o: src/autoinstall.c
	$(CC) $(CFLAGS) -fPIC -o autoinstall.o -c src/autoinstall.c

install: all
	install -m 755 -D src/autoinstall.sh 					$(PREFIX)/bin/autoinstall
	install -m 644 -D autoinstall.so 							$(PREFIX)/lib/lua/5.1/autoinstall.so
	install -m 644 -D src/autoinstall/client.lua	$(PREFIX)/share/lua5.1/autoinstall/client.lua
	install -m 644 -D src/autoinstall/server.lua	$(PREFIX)/share/lua5.1/autoinstall/server.lua

clean:
	-rm -f autoinstall.so autoinstall.o
	-rm -f autoinstall.log autoinstall.port
	-rm -rf cache

distclean: clean
	-rm -f *~ *.bak *.orig *.db *.o *.so
