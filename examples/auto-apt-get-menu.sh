#!/bin/bash -e
#  Retrieve debian menu files
#   Copyright (C) 2000 Masato Taruishi. All rights reserved.
# 
# You can redistribute it and/or modify it under the terms of the
# GNU General Public License as published by the Free Software
# Foundation; either version 2, or (at your option) any later version

if [ -z "$TMP" ]; then
  tmpdir=/tmp
else
  tmpdir=$TMP
fi

tmpdir=$tmpdir/auto-apt-get-menu.$$
install -d $tmpdir
pwd=`pwd`

function copy_debian_menus()
{
 \ls -1 debian/*.menu | while read f
  do
    cp $f ../`basename $f .menu` 2> /dev/null
    basename $f .menu
  done
}

function copy_debian_menu()
{
 if cp debian/menu ../$p 2> /dev/null; then
   pkg="$p"
   return 0
 fi

 \ls debian/*.menu > /dev/null 2> /dev/null || return 1
 pkg=`copy_debian_menus`

 return 0
}

## lookup packages that have debian menu file.
echo -n "Fetching package info... "
auto-apt search usr/lib/menu | awk -F' ' '{print $2;}' | sed 's/.*\///' | sort | uniq > $tmpdir/menu
echo done.

## calculates the number of the packages.
pnum=`cat $tmpdir/menu |wc -l`
pnum=`expr $pnum`
tail -n `expr $pnum - 1` $tmpdir/menu > $tmpdir/menu.new
mv $tmpdir/menu.new $tmpdir/menu

## for all the packages, creates a local menu file for auto-apt.
for p in `cat $tmpdir/menu`
do

 echo -n "($pnum) Fetching $p... "
 mkdir $tmpdir/$p.d
 cd $tmpdir/$p.d

 if apt-get --download-only source $p > /dev/null; then
  zcat *.diff.gz 2> /dev/null | patch -p1 -f > /dev/null || tar zxf *.orig.tar.gz
  if copy_debian_menu ; then
    export IFS=" "
    echo $pkg | while read eachpkg
    do
      echo -n "[$eachpkg] "
      sed -e '/command="/s/command="\([^"]*\)"/command="auto-apt run sh -c \1"/' -e '/ command=[^"]/s/command=\([^ \\]*\)/command="auto-apt run sh -c \1"/' -e 's/package([^)]*)/package(local.auto-apt)/' ../$eachpkg > ../$eachpkg.new
      mv ../$eachpkg.new $pwd/$eachpkg
    done
  else
    echo -n "menu not found "
  fi
  echo done.
 else
  echo failed.
 fi

 pnum=`expr $pnum - 1`
 cd ..
 rm -rf $p.d
done

rm -rf $tmpdir
