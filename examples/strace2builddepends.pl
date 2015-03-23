#!/usr/bin/perl -w

#use strict comes after prototyping!

# a list of files that do not belong to a Debian package but are known
# to never create a dependency
@known_files = ("/etc/ld.so.cache");

# generate a list of the versions of all Debian packages and 
# all Essential as well as all Build-Essential packages 
open(F,"/var/lib/dpkg/status") || die $!;
$/="\n\n";
while (defined ($block=<F>)) {
	$block =~ /Package: (.*)\n/;
	$package=$1;
	$block =~ /Version: (.*)\n/;
	$version=$1;
	$dpkg_package_versions{$package}=$version;
	if ($block =~ /Essential: yes\n/) {;
		$dpkg_build_essential_packages{$package}=1 
	}
}	
close(F);
$/="\n";
open(F,"/usr/share/doc/build-essential/essential-packages-list") || die $!;
while (defined ($line=<F>)) {
	$dpkg_build_essential_packages{$package}=1;
}
close(F);

# generate a list of all known installed Debian files
foreach $filename (</var/lib/dpkg/info/*.list>) {
	open(F,$filename) || die $!;
	$filename =~ m#^.*/(.*)\.list$#;
	$file = $1;
	while (defined ($line=<F>)) {
		chomp($line);
		$dpkg_files{$line} = $file;
	}
	close(F);
}

# extrace filenames from open and exec calls and add them if their
# system call was successfull (e.g. files that didn't exists at build time
# won't give a dependency entry!)
while (defined ($line=<>)) {
	next if $line !~ /^[0-9]+  (open|exec)/;
	if ($line =~ m/^[0-9]+  open\(\"(\/[^\"]+)\", \S+ = ([-\d]+)$/) {
		$files{$1}=1 if $2 >= 0;
	} elsif ($line =~ m/^[0-9]+  execve\(\"(\/[^\"]+)\", .* ([-\d]+)([a-zA-Z\(\) ]+)?$/) {
		$files{$1}=1 if $2 >= 0;
	}
}


# filter directories that are known to never be dependency-worth
foreach $key (keys %files) { 
	if (($key =~ m#^(/dev/|/tmp/|/proc/|/var/lib/dpkg/|/usr/share/locale/)#) ||
	    (-d $key) ||
		(-l $key)) {
		delete $files{$key};
	}
}
# filter files that are known to never be dependency-worth
foreach $key (@known_files) {
	delete $files{$key};
}

# now get those files that belong to a Debian package
foreach $key (keys %files) {
	if ($dpkg_files{$key}) {
		$packages{ $dpkg_files{$key} }++;
		delete $files{$key};
	} else {
		print "UNKNOWN: $key\n";
	}
}

# filter files that belong to (build-)essential packages
foreach $key (keys %dpkg_build_essential_packages) {
	delete $packages{$key};
}

#####################################

# print all dependend packages
foreach $key (sort keys %packages) {
	print "$key (>= ".$dpkg_package_versions{$key}.")\n";
}

