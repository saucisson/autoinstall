/*
 * auto-apt.so
 * on demand package installation tool
 * Copyright (c) 2000 Fumitoshi UKAI <ukai@debian.or.jp>
 * GPL
 *
 */
#define LARGEFILE_SOURCE
#define LARGEFILE64_SOURCE
#define __USE_LARGEFILE64 1
#define __USE_FILE_OFFSET64 1
//#define DPRINT(x) printf x
#define DPRINT(x)

#include <unistd.h>
#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <string.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>

#include <lua5.1/lua.h>
#include <lua5.1/lauxlib.h>
#include <lua5.1/lualib.h>

static lua_State *L;

#define APT_HOOK_EXEC  0
#define APT_HOOK_OPEN  1
#define APT_HOOK_ACCESS  2
#define APT_HOOK_STAT  3
#define NUM_APT_HOOK  4

static int apt_hook[NUM_APT_HOOK];

#ifdef __alpha__
#define LIBCPATH "/lib/libc.so.6.1"
#else
#define LIBCPATH "/lib/libc.so.6"
#endif

typedef int (*funcptr)();

static struct realfunctab {
  char *name;
  funcptr fptr;
} rftab[] = {
  {"execve", NULL},  /* execve(2) */
  /* XXX: execl(3), execle(3) */
  /* execlp(3)->execvp(3) */
  /* execvp(3)->execv(3) */
  {"execv", NULL},
  {"open", NULL},
  {"open64", NULL},
  {"__libc_open", NULL},
  {"__libc_open64", NULL},
  {"access", NULL},
  {"euidaccess", NULL},
  {"__xstat", NULL},
  {"__xstat64", NULL},
  {"__lxstat", NULL},
  {"__lxstat64", NULL},
  {NULL, NULL}
};

static funcptr
load_library_symbol(char *name)
{
  void *handle;
  const char *error;
  struct realfunctab *ft;
  char *libcpath = NULL;
  for (ft = rftab; ft->name; ft++) {
    if (strcmp(name, ft->name) == 0) {
      if (ft->fptr != NULL) {
        return ft->fptr;
      }
      break;
    }
  }
  if (ft->name == NULL) {
    DPRINT(("func:%s not found\n", name));
    return NULL;
  }
  if ((libcpath = getenv("LIBC_PATH")) == NULL)
    libcpath = LIBCPATH;
  handle = dlopen (libcpath, RTLD_LAZY);
  if (!handle) {
    DPRINT((dlerror()));
    return NULL;
  }
  ft->fptr = dlsym(handle, ft->name);
  if ((error = dlerror()) != NULL)  {
    DPRINT(("dysym(%s)=%s\n", ft->name, error));
    ft->fptr = NULL;
  }
  dlclose(handle);
  return ft->fptr;
}

/*
static int
open_internal(const char *filename, int flag, int mode)
{
  funcptr __open = load_library_symbol("__libc_open64");
  if (__open == NULL) __open = load_library_symbol("__libc_open");
  if (__open == NULL) __open = load_library_symbol("open64");
  if (__open == NULL) __open = load_library_symbol("open");
  if (__open == NULL)
    return -1;
  return __open(filename, flag, mode);
}
*/

/* _init() ? */
static void
auto_apt_setup()
{
  static int inited = 0;
  if (!inited) {
    int i;
    inited = 1;
    L = luaL_newstate ();
    luaL_openlibs (L);
    luaL_dostring (L, "require \"autoinstall\"");
    for (i = 0; i < NUM_APT_HOOK; i++) {
      apt_hook[i] = 0;
    }
    apt_hook[APT_HOOK_EXEC] = 1;
    apt_hook[APT_HOOK_OPEN] = 1;
    apt_hook[APT_HOOK_ACCESS] = 1;
    apt_hook[APT_HOOK_STAT] = 1;
  }
}

static int
apt_get_install_for_file(const char *filename)
{
  auto_apt_setup();
  lua_getglobal (L, "install");
  assert (lua_isfunction (L, -1));
  lua_pushstring (L, filename);
  assert (lua_pcall (L, 1, 1, 0) == 0);
  assert (lua_isboolean (L, -1));
  bool result = lua_toboolean (L, -1);
  lua_pop (L, 1);
  return result;
}

int
execl(const char *path, const char *arg, ...)
{
  size_t argv_max = 1024;
  const char **argv = alloca(argv_max * sizeof(const char *));
  unsigned int i;
  va_list args;
  auto_apt_setup();
  argv[0] = arg;
  va_start(args, arg);
  i = 0;
  while (argv[i++] != NULL) {
    if (i == argv_max) {
      const char **nptr = alloca ((argv_max *= 2) * sizeof(const char *));
      argv = (const char **)memmove(nptr, argv, i);
      argv_max += i;
    }
    argv[i] = va_arg(args, const char *);
  }
  va_end(args);
  return execv(path, (char *const *)argv);
}

int
execle(const char *path, const char *arg, ...)
{
  size_t argv_max = 1024;
  const char **argv = alloca(argv_max * sizeof(const char *));
  const char *const *envp;
  unsigned int i;
  va_list args;
  argv[0] = arg;
  auto_apt_setup();
  va_start(args, arg);
  i = 0;
  while (argv[i++] != NULL) {
    if (i == argv_max) {
      const char **nptr = alloca((argv_max *= 2) * sizeof(const char *));
      argv = (const char **)memmove(nptr, argv, i);
      argv_max += i;
    }
    argv[i] = va_arg (args, const char *);
  }
  envp = va_arg (args, const char *const *);
  va_end (args);
  return execve(path, (char *const *)argv, (char *const *)envp);
}

int
execve(const  char  *filename, char *const argv [], char *const envp[])
{
  int e;
  int apt = 0;
  funcptr  __execve;
  auto_apt_setup();
again:
  DPRINT(("execve: filename=%s \n", filename));
//  if (!apt && detectdb_file) { detect_package(filename, __FUNCTION__); }
  __execve = load_library_symbol("execve");
  if (__execve == NULL) {
    errno = EINVAL;
    return -1;
  }
  DPRINT(("execve = %p\n", __execve));
  e = __execve(filename, argv, envp);
  DPRINT(("execve: filename=%s, e=%d\n", filename, e));
  if (apt_hook[APT_HOOK_EXEC] && e < 0) {
    switch (errno) {
      case ENOENT:
        DPRINT(("execve: filename=%s not found\n", filename));
        if (!apt && apt_get_install_for_file(filename)) {
          apt = 1;
          goto again;
        }
        break;
      default:
        break;
    }
  }
  return e;
}

int
execv(const  char  *filename, char *const argv [])
{
  int e;
  int apt = 0;
  funcptr  __execv;
  auto_apt_setup();
again:
  DPRINT(("execv: filename=%s \n", filename));
//  if (!apt && detectdb_file) { detect_package(filename, __FUNCTION__); }
  __execv = load_library_symbol("execv");
  if (__execv == NULL) {
    errno = EINVAL;
    return -1;
  }
//  DPRINT(("execv = %p :filename=%s %d,%s\n", __execv, filename, apt, detectdb_file));
  e = __execv(filename, argv);
  DPRINT(("execvp: filename=%s, e=%d\n", filename, e));
  if (apt_hook[APT_HOOK_EXEC] && e < 0) {
    switch (errno) {
      case ENOENT:
        DPRINT(("execv: filename=%s not found\n", filename));
        if (!apt && apt_get_install_for_file(filename)) {
          apt = 1;
          goto again;
        }
        break;
      default:
        break;
    }
  }
  return e;
}

#undef open
int
open(const char *filename, int flags, ...)
{
  int apt = 0;
  int e;
  funcptr __open;
  mode_t mode;
  va_list ap;
//  static int o = 0; /* XXX: guard for open() in detect_pacage? */
  auto_apt_setup();
again:
  DPRINT(("open: filename=%s \n", filename));
//  if (!apt && detectdb_file && !o) {
//    o = 1; detect_package(filename, __FUNCTION__); o = 0;
//  }
  __open = load_library_symbol("open");
  if (__open == NULL) {
    errno = ENOENT;
    return -1;
  }
  DPRINT(("open = %p\n", __open));
  va_start(ap, flags);
  mode = va_arg(ap, mode_t);
  va_end(ap);
  e = __open(filename, flags, mode);
  DPRINT(("open: filename=%s e=%d\n", filename, e));
  if (apt_hook[APT_HOOK_OPEN] && e < 0) {
    switch (errno) {
      case ENOENT:
        if (*filename == '/') {
          if (!apt && apt_get_install_for_file(filename)) {
            apt = 1;
            goto again;
          }
        }
        break;
      default:
        break;
    }
  }
  return e;
}

#undef __libc_open
int
__libc_open(const char *filename, int flags, ...)
{
  int apt = 0;
  int e;
  funcptr __open;
  mode_t mode;
  va_list ap;
//  static int o = 0; /* XXX */
  auto_apt_setup();
again:
  DPRINT(("__libc_open: filename=%s \n", filename));
//  if (!apt && detectdb_file && !o) {
//    o = 1; detect_package(filename, __FUNCTION__); o = 0;
//  }
  __open = load_library_symbol("__libc_open");
  if (__open == NULL) {
    errno = ENOENT;
    return -1;
  }
  DPRINT(("__libc_open = %p\n", __open));
  va_start(ap, flags);
  mode = va_arg(ap, mode_t);
  va_end(ap);
  e = __open(filename, flags, mode);
  DPRINT(("__libc_open: filename=%s e=%d\n", filename, e));
  if (apt_hook[APT_HOOK_OPEN] && e < 0) {
    switch (errno) {
      case ENOENT:
        if (*filename == '/') {
          if (!apt && apt_get_install_for_file(filename)) {
            apt = 1;
            goto again;
          }
        }
        break;
      default:
        break;
    }
  }
  return e;
}

#undef open64
int
open64(const char *filename, int flags, ...)
{
  int apt = 0;
  int e;
  funcptr __open;
  mode_t mode;
  va_list ap;
//  static int o = 0; /* XXX */
  auto_apt_setup();
again:
  DPRINT(("open64: filename=%s \n", filename));
//  if (!apt && detectdb_file && !o) {
//    o = 1; detect_package(filename, __FUNCTION__); o = 0;
//  }
  __open = load_library_symbol("open64");
  if (__open == NULL) {
    errno = ENOENT;
    return -1;
  }
  DPRINT(("open64 = %p\n", __open));
  va_start(ap, flags);
  mode = va_arg(ap, mode_t);
  va_end(ap);
  e = __open(filename, flags, mode);
  DPRINT(("open64: filename=%s e=%d\n", filename, e));
  if (apt_hook[APT_HOOK_OPEN] && e < 0) {
    switch (errno) {
      case ENOENT:
        if (*filename == '/') {
          if (!apt && apt_get_install_for_file(filename)) {
            apt = 1;
            goto again;
          }
        }
        break;
      default:
        break;
    }
  }
  return e;
}

#undef __libc_open64
int
__libc_open64(const char *filename, int flags, ...)
{
  int apt = 0;
  int e;
  funcptr __open;
  mode_t mode;
  va_list ap;
//  static int o = 0; /* XXX */
  auto_apt_setup();
again:
  DPRINT(("__libc_open64: filename=%s \n", filename));
//  if (!apt && detectdb_file && !o) {
//    o = 1; detect_package(filename, __FUNCTION__); o = 0;
//  }
  __open = load_library_symbol("__libc_open64");
  if (__open == NULL) {
    errno = ENOENT;
    return -1;
  }
  DPRINT(("__libc_open64 = %p\n", __open));
  va_start(ap, flags);
  mode = va_arg(ap, mode_t);
  va_end(ap);
  e = __open(filename, flags, mode);
  DPRINT(("__libc_open64: filename=%s e=%d\n", filename, e));
  if (apt_hook[APT_HOOK_OPEN] && e < 0) {
    switch (errno) {
      case ENOENT:
        if (*filename == '/') {
          if (!apt && apt_get_install_for_file(filename)) {
            apt = 1;
            goto again;
          }
        }
        break;
      default:
        break;
    }
  }
  return e;
}

int
access(const char *filename, int type)
{
  int apt = 0;
  int e;
  funcptr __access;
  auto_apt_setup();
again:
  DPRINT(("access: filename=%s \n", filename));
//  if (!apt && detectdb_file) detect_package(filename, __FUNCTION__);
  __access = load_library_symbol("access");
  if (__access == NULL) {
    errno = ENOENT;
    return -1;
  }
  DPRINT(("access = %p\n", __access));
  e = __access(filename, type);
  DPRINT(("access: filename=%s e=%d\n", filename, e));
  if (apt_hook[APT_HOOK_ACCESS] && e < 0) {
    switch (errno) {
      case ENOENT:
        if (*filename == '/') {
          if (!apt && apt_get_install_for_file(filename)) {
            apt = 1;
            goto again;
          }
        }
        break;
      default:
        break;
    }
  }
  return e;
}

int
euidaccess(const char *filename, int type)
{
  int apt = 0;
  int e;
  funcptr __euidaccess;
  auto_apt_setup();
again:
  DPRINT(("euidaccess: filename=%s \n", filename));
//  if (!apt && detectdb_file) detect_package(filename, __FUNCTION__);
  __euidaccess = load_library_symbol("euidaccess");
  if (__euidaccess == NULL) {
    errno = ENOENT;
    return -1;
  }
  DPRINT(("euidaccess = %p\n", __euidaccess));
  e = __euidaccess(filename, type);
  DPRINT(("euidaccess: filename=%s e=%d\n", filename, e));
  if (apt_hook[APT_HOOK_ACCESS] && e < 0) {
    switch (errno) {
      case ENOENT:
        if (*filename == '/') {
          if (!apt && apt_get_install_for_file(filename)) {
            apt = 1;
            goto again;
          }
        }
        break;
      default:
        break;
    }
  }
  return e;
}


#undef __xstat
int
__xstat(int ver, const char *filename, struct stat *buf)
{
  int apt = 0;
  int e;
  funcptr __stat;
  auto_apt_setup();
again:
  DPRINT(("stat: filename=%s \n", filename));
//  if (!apt && detectdb_file) detect_package(filename, __FUNCTION__);
  __stat = load_library_symbol("__xstat");
  if (__stat == NULL) {
    errno = ENOENT;
    return -1;
  }
  DPRINT(("stat = %p\n", __stat));
  e = __stat(ver, filename, buf);
  DPRINT(("stat: filename=%s e=%d\n", filename, e));
  if (apt_hook[APT_HOOK_STAT] && e < 0) {
    switch (errno) {
      case ENOENT:
        if (*filename == '/') {
          if (!apt && apt_get_install_for_file(filename)) {
            apt = 1;
            goto again;
          }
        }
        break;
      default:
        break;
    }
  }
  DPRINT(("result e=%d\n", e));
  return e;
}

#undef __xstat64
struct stat64; /* XXX */
int
__xstat64(int ver, const char *filename, struct stat64 *buf)
{
  int apt = 0;
  int e;
  funcptr __stat;
  auto_apt_setup();
again:
  DPRINT(("stat64: filename=%s \n", filename));
//  if (!apt && detectdb_file) detect_package(filename, __FUNCTION__);
  __stat = load_library_symbol("__xstat64");
  if (__stat == NULL) {
    errno = ENOENT;
    return -1;
  }
  DPRINT(("stat64 = %p\n", __stat));
  e = __stat(ver, filename, buf);
  DPRINT(("stat64: filename=%s e=%d\n", filename, e));
  if (apt_hook[APT_HOOK_STAT] && e < 0) {
    switch (errno) {
      case ENOENT:
        if (*filename == '/') {
          if (!apt && apt_get_install_for_file(filename)) {
            apt = 1;
            goto again;
          }
        }
        break;
      default:
        break;
    }
  }
  return e;
}


#undef __lxstat
int
__lxstat(int ver, const char *filename, struct stat *buf)
{
  int apt = 0;
  int e;
  funcptr __stat;
  auto_apt_setup();
again:
  DPRINT(("lstat: filename=%s \n", filename));
//  if (!apt && detectdb_file) detect_package(filename, __FUNCTION__);
  __stat = load_library_symbol("__lxstat");
  if (__stat == NULL) {
    errno = ENOENT;
    return -1;
  }
  DPRINT(("lstat = %p\n", __stat));
  e = __stat(ver, filename, buf);
  DPRINT(("lstat: filename=%s e=%d\n", filename, e));
  if (apt_hook[APT_HOOK_STAT] && e < 0) {
    switch (errno) {
      case ENOENT:
        if (*filename == '/') {
          if (!apt && apt_get_install_for_file(filename)) {
            apt = 1;
            goto again;
          }
        }
        break;
      default:
        break;
    }
  }
  return e;
}

#undef __lxstat64
int
__lxstat64(int ver, const char *filename, struct stat64 *buf)
{
  int apt = 0;
  int e;
  funcptr __stat;
  auto_apt_setup();
again:
  DPRINT(("lstat64: filename=%s \n", filename));
//  if (!apt && detectdb_file) detect_package(filename, __FUNCTION__);
  __stat = load_library_symbol("__lxstat64");
  if (__stat == NULL) {
    errno = ENOENT;
    return -1;
  }
  DPRINT(("lstat64 = %p\n", __stat));
  e = __stat(ver, filename, buf);
  DPRINT(("lstat64: filename=%s e=%d\n", filename, e));
  if (apt_hook[APT_HOOK_STAT] && e < 0) {
    switch (errno) {
      case ENOENT:
        if (*filename == '/') {
          if (!apt && apt_get_install_for_file(filename)) {
            apt = 1;
            goto again;
          }
        }
        break;
      default:
        break;
    }
  }
  return e;
}
