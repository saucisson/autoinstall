#!/bin/sh
# auto-apt -- on demand package installation tool
# Copyright (c) 2000 Fumitoshi UKAI <ukai@debian.or.jp>
# GPL
# 
# AUTO_APT_DEBUG=<defined?>
# AUTO_APT_VERBOSE=<defined?>
# AUTO_APT_QUIET=<defined?>
# AUTO_APT_LOG=<filename>	-- obsolate?
# AUTO_APT_ACCEPT={main,non-US,non-free,contrib,none}
# AUTO_APT_SIMULATE=<defined?>
# AUTO_APT_CACHEDIR=/var/cache/auto-apt/
# AUTO_APT_DETECT=<dbfile>
# AUTO_APT_YES=<defined?>
# AUTO_APT_DB=/var/cache/auto-apt/pkgcontents.bin
# AUTO_APT_HOOK={exec,open,access,stat}
#
# APT_CONFIG=/etc/apt/apt.conf
# SOURCES_LIST=/etc/auto-apt/sources.list (cf: apt-config -dump)

prog=`basename $0`

AUTO_APT_ID='$Id: auto-apt.sh,v 1.58 2004/03/19 17:53:25 ukai Exp $'
AUTO_APT_PKGCDB=${AUTO_APT_PKGCDB:-'/usr/lib/auto-apt/auto-apt-pkgcdb'}
AUTO_APT_SO=${AUTO_APT_SO:-/lib/auto-apt.so}
AUTO_APT_ACCEPT=${AUTO_APT_ACCEPT:-"main,non-US,non-free,contrib"}
AUTO_APT_CACHEDIR=${AUTO_APT_CACHEDIR:-"/var/cache/auto-apt"}
AUTO_APT_DB=${AUTO_APT_DB:-"${AUTO_APT_CACHEDIR}/pkgcontents.bin"}
AUTO_APT_FILEDB=${AUTO_APT_FILEDB:-"${AUTO_APT_CACHEDIR}/pkgfiles.bin"}
AUTO_APT_HOOK=${AUTO_APT_HOOK:-"all"}
AUTO_APT_SOURCES_LIST=${AUTO_APT_SOURCES_LIST:-"/etc/auto-apt/sources.list"}

export AUTO_APT_ACCEPT
export AUTO_APT_HOOK

LIBC_PATH=`ldd /bin/sh | grep libc.so | awk '{print $3}'`
if test -f $LIBC_PATH; then
   export LIBC_PATH
fi

requirepkg() {
  cmd=$1
  pkg=$2
  if test -e "$1";then
    :
  else
    echo "I: Install:$2	file:$1	by:$0" >&2
    apt-get -y install $2 >&2
  fi
}

usage() {
  echo "$AUTO_APT_ID
Usage: auto-apt [options] command [arg ...]

auto-apt is a simple command line interface for setting up auto-apt
environment and/or search packages by filename.

Commands:
    run - Enter auto-apt environment
	run [command [cmdarg]]
    update - Retrieve new lists of Contents (available file list)
	update
    updatedb - Regenerate lists of Contents (available file list, no download)
        updatedb
    update-local - Generate installed file lists
    	update-local
    merge - Merge lists of Contents
	merge
    del - Delete package list
	del package
    check - Check which package will provide the filename
        check [-v] [-f] filename
    list - List filelist in dbfile
    	list [-v] [-f]
    search - Search package by filename (grep)
        search [-v] [-f] pattern
    debuild - debuild with auto-apt
	useful to get build-depends:
    status - Report current environments (auto-apt or not)

 For some commands, command name with "-local" suffix, it will use 
 pkgfiles.db, which is created by update-local command, instead of
 pkgcontents.db

Options:
    [-s] [-y] [-q] [-i] [-x] [-X]
    [-a dists] [-p hooks]
    [-D pkgcontents.bin] [-F pkgfiles.bin] [-L detect.list] 

See the auto-apt(1) manual pages.
" >&2
    exit
}

run() {
    if test -e /usr/bin/apt-get; then
	:
    else
	echo E: You need apt-get to run auto-apt.
	exit 1
    fi
    if test -e /usr/bin/sudo; then
	:
    else
	echo W: without sudo, you can not install new packages automatically.
    fi
    if test "$1" = ""; then
	set -- $SHELL
    fi
    if test "$AUTO_APT_QUIET" = ""; then
      echo Entering auto-apt mode: "$@"
      echo Exit the command to leave auto-apt mode.
    fi
    command -v "$1" |grep -q / > /dev/null 2>&1 && LD_PRELOAD=$AUTO_APT_SO:$LD_PRELOAD exec "$@"
    echo "E: Exec $1 failed, auto-apt failed"
}

update() {
    if test "$1" = db; then
       nodownload=1
       shift
    fi
    # dirname in shellutils, which is required
    CACHEDIR=`dirname $AUTO_APT_DB`
    test -d "$CACHEDIR" || {
      echo "E: update: cache dir not found: $CACHEDIR" >&2; exit
    }
    test -w "$CACHEDIR" || {
      echo "E: You need write permission for $CACHEDIR" >&2; exit
    }
    ARCH=$(dpkg --print-architecture)

    cd "$CACHEDIR" && {
      rm -f "$AUTO_APT_DB"

      test -f $AUTO_APT_SOURCES_LIST || {
        eval `apt-config shell APT_ETC Dir::Etc/ SOURCES_LIST Dir::Etc::sourcelist`
        test -f $APT_ETC/$SOURCES_LIST || {
          echo "E: apt sources.list:$APT_ETC/$SOURCES_LIST not found" >&2; exit
        }
	ln -sf $APT_ETC/$SOURCES_LIST $AUTO_APT_SOURCES_LIST
      }
      cat $AUTO_APT_SOURCES_LIST | \
	sed -ne 's=^[[:space:]]*deb[[:space:]][[:space:]]*\([^:[:space:]]*\):\([^[:space:]]*\)[[:space:]][[:space:]]*\([^[:space:]]*\)[[:space:]][[:space:]]*.*=\1 \2/dists/\3=p' | 
      while read method url
      do
         u=`echo $url | sed -e 's,^/*,,' -e 's:/:_:g' -e 's:__*:_:g'`
	 case "$method" in
	 http|ftp)
	   if test "$nodownload" = 1; then
	      :
	   else
  	     echo "Downloading $method:$url Contents-$ARCH.gz ..." >&2
	     # proxy setting
	     if test "${method}_proxy" = ""; then
                host=`echo $url | sed -e 's=^//==' -e 's=/.*=='`
		eval `apt-config shell ${method}_proxy Acquire::${method}::Proxy`
		eval `apt-config shell ${method}_proxy Acquire::${method}::Proxy::${host}`
		if test "${method}_proxy" = "DIRECT"; then
	            unset ${method}_proxy
		else
		    export ${method}_proxy
	        fi
	     fi
	     # other options
	     wgetopt="--timestamping --continue --progress=bar:force"
	     if test "$method" = "ftp"; then
		passive_ftp="true"
		eval `apt-config shell passive_ftp Acquire::ftp::Passive`
		if test "$passive_ftp" = "true"; then
		    wgetopt="$wgetopt --passive-ftp"
		fi
	     fi
	     requirepkg /usr/bin/wget wget
	     # /usr/bin/wget -q -O ${u}_Contents-$ARCH.gz $method:$url/Contents-$ARCH.gz >&2
             wget $wgetopt -O ${u}_Contents-$ARCH.gz $method:$url/Contents-$ARCH.gz 2>&1 | tail -n +8 >&2
           fi
	   ;;
	 rsh|ssh)
	   if test "$nodownload" = 1; then
	      :
	   else
  	     echo -n "Downloading $method:$url Contents-$ARCH.gz ..." >&2
	     case "$method" in
	     rsh) requirepkg /usr/bin/rsh rsh-client; cmd=rcp;;
	     ssh) requirepkg /usr/bin/ssh ssh; cmd=scp;;
	     esac
	     path=`echo $url | sed -e 's=//\([^/]*\)/\(.*\)$=\1:/\2='`
	     $cmd $path/Contents-$ARCH.gz ${u}_Contents-$ARCH.gz > /dev/null 2>&1
	     echo "done" >&2
           fi
	   ;;
	 file)
           if test "$nodownload" = 1; then
	       :
	   else
	     ln -fs $url/Contents-$ARCH.gz ${u}_Contents-$ARCH.gz
	   fi
	   ;;
	   
	 *)
	   echo "W: Unsupported apt-line: $method, ignored" >&2
	   ;;
	 esac
	 test -s ${u}_Contents-$ARCH.gz &&
	 gunzip < ${u}_Contents-$ARCH.gz |
	 sed -e '1,/^FILE/d'
	 echo "" >&2
      done | $AUTO_APT_PKGCDB -f "$AUTO_APT_DB" put "$@"
    }
}

updatelocal() {
    test -f "$AUTO_APT_FILEDB" && rm -f "$AUTO_APT_FILEDB"
    ls -1rt /var/lib/dpkg/info/*.list | while read list
    do
      pkg=`echo $list | sed -ne 's:.*/dpkg/info/\(.*\).list:\1:p'`
      awk -v pkg=$pkg '{print $1, " ", pkg}' $list
    done | $AUTO_APT_PKGCDB -f "$AUTO_APT_FILEDB" put "$@"
}

merge() {
    $AUTO_APT_PKGCDB -f "$AUTO_APT_DB" put "$@"
}

del() {
    if test "$1" = ""; then
        echo "E: del: missing packagename" >&2
	exit
    fi
    $AUTO_APT_PKGCDB -f "$AUTO_APT_DB" del "$@"
}

check() {
    while getopts "fv" opt; do
    case "$opt" in
     f) full=yes;;
     v) verbose=yes;;
     *) echo "$0 check [-f] filename" >&2; exit;;
    esac
    done
    shift $(($OPTIND -1))
    if test "$1" = ""; then
    	echo "E: check: missing filename" >&2
	exit
    fi
    if test "$full" = "yes"; then
      pat=`echo $1 | sed -e 's:^\/::'`
      (cd `dirname $AUTO_APT_DB`
        for contents in *_Contents-*.gz
        do
          test -s $contents || continue
          gunzip < $contents | sed -e '1,/^FILE/d'
        done ) | grep -E "^/?$pat[[:space:]]" | awk '{
	    print $2;
	    if ("'$verbose'" == "yes") { print $1; } 
        }'
    else
      pkgcdbopt=
      test "$verbose" = "yes" && pkgcdbopt="-v"
      $AUTO_APT_PKGCDB -f "$AUTO_APT_DB" get $pkgcdbopt "$@"
    fi
}

install() {
    while getopts "sduyv" opt; do
     case "$opt" in
      s) simulate=yes;;
      d) download=yes;;
      u) upgraded=yes;;
      y) assumeyes=yes;; 
      v) verbose=yes;;
      *) echo "$0 install [-s] [-d] [-u] [-y] [-v] filename" >&2; exit;;
     esac
    done
    shift $(($OPTIND -1))
    filename="$1"
    test "$verbose" = "yes" && echo "N: try to install a package providing $filename"
    pkgs=$($0 check "$filename")
    IFS0="$IFS"; IFS=,; set -- $pkgs; IFS="$IFS0"
    test "$verbose" = "yes" && echo "N: $@"
    if [ $# -eq 0 ]; then
       echo "E: no candidate found for $filename" >&2; exit 1
    fi
    if [ $# -gt 1 ]; then
       echo "E: multiple candidates found for $filename" >&2
       echo "I:  $@" >&2
       exit 1
    fi
    pkgname=${1##*/}
    aptopt=
    test "$simulate" = "yes" && aptopt="$aptopt -s"
    test "$download" = "yes" && aptopt="$aptopt -d"
    test "$upgraded" = "yes" && aptopt="$aptopt -u"
    test "$assumeyes" = "yes" && aptopt="$aptopt -y"
    test "$verbose" = "yes" && echo "apt-get $aptopt intall $pkgname"
    apt-get $aptopt install $pkgname
}

list() {
    while getopts "fv" opt; do
     case "$opt" in
      f) full=yes;;
      v) verbose=yes;;
      *) echo "$0 list [-f]" >&2; exit;;
     esac
    done
    shift $(($OPTIND -1))
    if test "$verbose" = "yes"; then
       set -- -v "$@"
    fi
    if test "$full" = "yes"; then
      (cd `dirname $AUTO_APT_DB`
        founddb=false
        for contents in *_Contents-*.gz
        do
          test -s $contents || continue
          founddb=true
          gunzip < $contents | sed -e '1,/^FILE/d'
        done
	if test "$founddb" = false; then
	   echo "E: no auto-apt db, run 'auto-apt update' first"
	   exit 1
	fi
       )
    else
      if test -f "$AUTO_APT_DB"; then
        $AUTO_APT_PKGCDB -f "$AUTO_APT_DB" list
      else
	echo "E: $AUTO_APT_DB not found, run 'auto-apt update' first"
	exit 1
      fi
    fi
}

search() {
    if test "$1" = ""; then
       echo "E: search: missing search pattern" >&2
       exit
    fi
    while getopts "fv" opt; do
     case "$opt" in
      f) full=yes;;
      v) verbose=yes;;
      *) echo "$0 search [-f] pattern" >&2; exit;;
     esac
    done
    shift $(($OPTIND -1))
    pat=$1
    if test "$verbose" = "yes"; then
       set -- -v
    fi
    if test "$full" = "yes"; then
       set -- -f "$@"
    fi
    list "$@" | grep "$pat"
}

debuild() {
  test -f $AUTO_APT_FILEDB || {
    if test "$AUTO_APT_YES" = ""; then
     fdb=`basename $AUTO_APT_FILEDB`
     echo "You have no $AUTO_APT_FILEDB"
     echo "It is recommended to create $fdb to get right build-depends, "
     echo "but it takes too much time to generate $fdb."
     echo -n "Create it now ? [Y/n] "
     while read yn;
     do 
       test "$yn" = "" && yn=y
       case "$yn" in
        Y|y) auto-apt update-local; break;;
        N|n) echo "ok, run without $fdb"; break;;
        *) echo -n "Create it now ? [Y/n] "; continue;;
      esac
     done
    else
     auto-apt update-local
    fi
  }
  if test "$AUTO_APT_DETECT" = ""; then
   requirepkg /usr/bin/dpkg-parsechangelog dpkg-dev
   package=`dpkg-parsechangelog | sed -n 's/^Source: //p'`
   test "$package" = "" && {
     echo "E: badly formatted changelog file, no Source:?" >&2; exit
   }
   version=`dpkg-parsechangelog | sed -n 's/^Version: //p'`
   test "$version" = "" && {
     echo "E: badly formatted changelog file, no Version:?" >&2; exit
   }
   # dpkg-architecture is dpkg-dev
   arch=`dpkg-architecture -qDEB_HOST_ARCH 2>/dev/null` \
     && test "${arch}" != "" \
     || arch=`dpkg --print-architecture`
   sversion=`echo "$version"| perl -pe 's/^\d+://'`
   pva="${package}_${sversion}${arch:+_${arch}}"
   DDB=../${pva}.lists
   AUTO_APT_DETECT=`pwd`/$DDB
   export AUTO_APT_DETECT
  else
   DDB=$AUTO_APT_DETECT
  fi
  test -f $AUTO_APT_DETECT && {
   if test "$AUTO_APT_YES" = ""; then
    echo "detect.lists $AUTO_APT_DETECT already existed"
    echo -n "Remove it, before running debuild? [Y/n] "
    while read yn;
    do
      test "$yn" = "" && yn=y
      case "$yn" in
       Y|y) rm -f $AUTO_APT_DETECT; break;;
       N|n) echo "ok, append record to $AUTO_APT_DETECT"; break;;
       *) echo -n "Remove it, before running debuild? [Y/n]"; continue;;
      esac
    done
   else
    rm -f $AUTO_APT_DETECT
   fi
  }
  rm -f $AUTO_APT_DETECT
  echo "$prog: record file access to $DDB"
  requirepkg /usr/bin/debuild devscripts
  auto-apt -L $AUTO_APT_DETECT run /usr/bin/debuild -E "$@"
  echo "Build dependencies will be ... (in ../${pva}.build-depends)"
  rm -f ../essential-packages-list
  requirepkg /usr/share/doc/build-essential/essential-packages-list build-essential
  sed -e '1,/^$/d' /usr/share/doc/build-essential/essential-packages-list \
    > ../essential-packages-list
  cat $DDB | sed -ne '/^\//p' | awk '$2 !~ /[*!]/ {print $2}' | 
    grep -Fvf ../essential-packages-list | sort | uniq | \
    perl -e 'print "  " . join(", ", grep {chomp} <STDIN>) . "\n"' \
	> ../${pva}.build-depends
  rm -f ../essential-packages-list
  cat ../${pva}.build-depends
  echo "Note: file access record is stored $DDB"
}

status() {
    case $LD_PRELOAD in
    /lib/auto-apt.so|/lib/auto-apt.so:*|*:/lib/auto-apt.so|*:/lib/auto-apt.so:*)
     echo "auto-apt mode"; 
     if test "$AUTO_APT_QUIET" != "yes"; then
        test "$AUTO_APT_SIMULATE" = "yes" && echo -n " -s"
	test "$AUTO_APT_YES" = "yes" && echo -n " -y"
	test "$AUTO_APT_NOBG" = "yes" && echo -n " -i"
	test "$AUTO_APT_X" = "yes" && echo -n " -X"
        echo -n " -a $AUTO_APT_ACCEPT";
	echo -n " -p $AUTO_APT_HOOK";
	echo -n " -D $AUTO_APT_DB";
	echo -n " -F $AUTO_APT_FILEDB";
	test -f "$AUTO_APT_DETECT" && echo -n " -L $AUTO_APT_DETECT";
	echo "";
     fi
     exit 0;;
    *)
     echo "normal mode"; exit 1;;
    esac
}

## general command line parsing
# /usr/bin/getopt in util-linux (required)
## XXX: use getopts?

# default -X enable
case X"$AUTO_APT_X" in
Xoff|Xno) ;;
X*) if test "$DISPLAY" != "" && test -x /usr/bin/x-terminal-emulator; then
      AUTO_APT_X=yes; export AUTO_APT_X;
    fi ;;
esac

while getopts "hsyqixXa:c:p:D:F:L:" opt; do
  # echo "opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG"
  case "$opt" in
   h) usage;;
   s) AUTO_APT_SIMULATE=yes; export AUTO_APT_SIMULATE ;;
   y) AUTO_APT_YES=yes; export AUTO_APT_YES;;
   q) AUTO_APT_QUIET=yes; export AUTO_APT_QUIET;;
   i) AUTO_APT_NOBG=yes; export AUTO_APT_NOBG;;
   x) AUTO_APT_X=no; export AUTO_APT_X ;;
   X) if test "$DISPLAY" != "" && test -x /usr/bin/x-terminal-emulator; then
         AUTO_APT_X=yes; export AUTO_APT_X
      else
         echo "no \$DISPLAY or x-terminal-emulator, X support disabled" >&2
      fi;;
   a) case "$OPTARG" in
       none) AUTO_APT_ACCEPT;;
       *) AUTO_APT_ACCEPT="$AUTO_APT_ACCEPT,$OPTARG";;
      esac
      export AUTO_APT_ACCEPT;;
   p) case "$OPTARG" in
       none) AUTO_APT_HOOK;;
       *) AUTO_APT_HOOK="$AUTO_APT_HOOK,$OPTARG";;
      esac
      export AUTO_APT_HOOK;;
   D) AUTO_APT_DB="$OPTARG"; export AUTO_APT_DB;;
   F) AUTO_APT_FILEDB="$OPTARG"; export AUTO_APT_FILEDB ;;
   L) AUTO_APT_DETECT="$OPTARG"; export AUTO_APT_DETECT AUTO_APT_FILEDB ;;
   *) usage;;
  esac
done
# echo "opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG"
shift $(($OPTIND - 1))

if [ $# -lt 1 ]; then
    usage
fi

CMD=$1; shift
case "$CMD" in
 run) run "$@";;
 update) update "$@";;
 updatedb) update db "$@";;
 updatedb-local) AUTO_APT_DB="$AUTO_APT_FILEDB" update "$@" ;;
 update-local) updatelocal "$@";;
 merge) merge "$@";;
 merge-local) AUTO_APT_DB="$AUTO_APT_FILEDB" merge "$@" ;;
 check) check "$@";;
 check-local) AUTO_APT_DB="$AUTO_APT_FILEDB" check "$@" ;;
 install) install "$@";;
 list) list "$@";;
 list-local) AUTO_APT_DB="$AUTO_APT_FILEDB" list "$@" ;;
 del) del "$@";;
 del-local) AUTO_APT_DB="$AUTO_APT_FILEDB" del "$@" ;;
 search) search "$@";;
 search-local) AUTO_APT_DB="$AUTO_APT_FILEDB" search "$@" ;;
 debuild) debuild "$@";;
 status|mode) status "$@";;
 *) echo "unknown command: $CMD" >&2; usage ;;
esac
exit
