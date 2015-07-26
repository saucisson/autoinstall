#!/bin/sh
# auto-apt -- on demand package installation tool
# Copyright (c) 2000 Fumitoshi UKAI <ukai@debian.or.jp>
# GPL

script=$(realpath $0)
prefix=$(dirname ${script})/..
so=${prefix}/lib/lua/5.1/autoinstall.so

LIBC_PATH=$(ldd /bin/sh | grep libc.so | awk '{print $3}')
if test -f "${LIBC_PATH}"; then
  export LIBC_PATH
fi

usage() {
  echo "Usage: autoinstall command [arg ...]" >&2
  exit 1
}

rm -f "autoinstall.port" "autoinstall.log"
exec lua5.1 -e "require 'autoinstall.server'" > autoinstall.log 2>&1 &
while [ true ]
do
  if [ -f "autoinstall.port" ]
  then
    export AUTOINSTALL_PORT=$(cat "autoinstall.port")
    command -v "$1" && LD_PRELOAD=${so}:${LD_PRELOAD} exec "$@"
    exit 0
  fi
  sleep 0.1
done
