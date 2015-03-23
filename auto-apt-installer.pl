#!/usr/bin/perl -- # -*- perl -*-
#
# auto-apt backend installer 
# Copyright (c) 2000 Fumitoshi UKAI <ukai@debian.or.jp>
# GPL
#
# cmdname	trigger command
# filename	trigger filename
# package	1st selected package? (override by pkgcdb output)
$rcsid = q$Id: auto-apt-installer.pl,v 1.10 2001/06/19 15:07:43 ukai Exp $;

# $ENV{'AUTO_APT_ACCEPT'}
# $ENV{'AUTO_APT_QUIET'}
# $ENV{'AUTO_APT_ACCEPT'}
# $ENV{'AUTO_APT_LOG'}
# $ENV{'AUTO_APT_SIMULATE'}
# $ENV{'AUTO_APT_NOBG'}
# $ENV{'AUTO_APT_X'}

@aptinstall = qw(sudo apt-get -y install);
$PKGCDB = '/usr/lib/auto-apt/auto-apt-pkgcdb';
$ENV{'PATH'} = '/usr/sbin:/sbin:' . $ENV{'PATH'};

$gtk = 0;
eval "use Gtk; use Gtk::Atoms;";
if ($@ eq "") {
    $gtk = 1;
} elsif ($ENV{'AUTO_APT_INSTALL'} ne 'yes') {
    my ($gtkpm);
    # install Gtk.pm
    if (open(L, "$PKGCDB list|")) {
	while (<L>) {
	    chomp;
	    if (/Gtk.pm/) {
		s/\s+.*//;
		$gtkpm = $_;
		last;
	    }
	}
	close(L);
    }
    if ($gtkpm) {
	# install now
	$ENV{'AUTO_APT_INSTALL'} = 'yes';
	system($0, $0, $gtkpm, "libgtk-perl");
	undef $ENV{'AUTO_APT_INSTALL'};
    }
    eval "use Gtk; use Gtk::Atoms;";
    if ($@ eq "") {
	$gtk = 1;
    }
}

sub conf_var {
    my ($s) = @_;
    return $ENV{$s};
}

sub conf_switch {
    my ($s) = @_;
    my ($v) = $ENV{$s};
    if ($v eq "no" || $v eq "off") {
	undef $v;
    }
    return $v;
}

sub check_accept {
    my ($p) = @_;
    my (@a) = split(',', &conf_var('AUTO_APT_ACCEPT'));
    foreach (@a) {
	return undef if (/none/);
	return $p if (/main/ && $p !~ m:^(non-US|contrib|non-free)/:);
	return $p if (/non-US/ && $p =~ m:^non-US/:);
	return $p if (/contrib/ && $p =~ m:^contrib/:);
	return $p if (/non-free/ && $p =~ m:^non-free/:);
    }
    return undef;
}

if ($#ARGV < 2) {
    print STDERR <<USAGE;
usage: $0 cmdname filename [package]
$rcsid
USAGE
    exit 1;
}

$cmdname = $ARGV[0];
$filename = $ARGV[1];
$package = $ARGV[2];
@package = ($package);

if (open(PACKAGE, "$PKGCDB get '$filename'|")) {
    $_ = <PACKAGE>;
    chomp;
    @package = split(/,/, $_);
    close(PACKAGE);
}

@package = grep {&check_accept($_)} @package;
$package = $package[0];
if ($package eq "") {
    exit;
}

if (&conf_switch('AUTO_APT_X') && $gtk) {
    if ($#package > 0 || ! &conf_switch('AUTO_APT_YES')) {
	eval "&run_gtk";
	if ($@ eq "") {
	    $ENV{'AUTO_APT_YES'} = "yes";
	}
    }
}
if ($package eq "") {
    exit;
}

if (&conf_switch('AUTO_APT_QUIET') || !-t STDOUT) {
    open(NULL, "+>/dev/null");
    close(STDIN); open(STDIN, "<&NULL");
    close(STDOUT); open(STDOUT, ">&NULL");
    close(STDERR); open(STDERR, ">&NULL");
} else {
    select(STDOUT);

    system('tput', 'smcup');
    $| = 1;
    if (! &conf_switch('AUTO_APT_YES')) {
	print "Install:@package\tfile:$filename\tby:$cmdname\n";
    }
    if ($#package > 0) {
	print "File $filename may be provided by the following packages\n";
	for ($n = 0; $n <= $#package; $n++) {
	    print " $n) $package[$n]\n";
	}
	$n = $#package;
	print "Which package do you want to install? [0-${n}n] ";
	while (<STDIN>) {
	    if (/n/i) {
		exit;
	    } elsif ($_ >= 0 && $_ <= $n) {
		$n = $_; last;
	    }
	    print "Which package do you want to install? [0-${n}n] ";
	}
	$package = $package[$n];
    } else {
	if (! &conf_switch('AUTO_APT_YES')) {
	    $yes = 0;
	    print "Do you want to install $package now? [Y/n] ";
	    while (<STDIN>) {
		chomp;
		exit if (/n/i);
		if (/y/i || /^\s*$/ || (length($_) == 0)) {
		    $yes = 1; last;
		}
		print "\nDo you want to install $package now? [Y/n] ";
	    }
	}
    }
    system('tput', 'rmcup');
}

$package =~ s:.*/::;
if (&conf_switch('AUTO_APT_X') && ! -x '/usr/bin/x-terminal-emulator'
    && $ENV{'AUTO_APT_INSTALL'} ne 'yes') {
    # xterm provides x-terminal-emulator, so install it
    $ENV{'AUTO_APT_INSTALL'} = 'yes';
    system($0, $0, '/usr/X11R6/bin/xterm', 'x11/xterm');
    undef $ENV{'AUTO_APT_INSTALL'};
}

if (&conf_switch('AUTO_APT_X') && -x "/usr/bin/x-terminal-emulator") {
    exec {'/usr/bin/x-terminal-emulator'} 
    "x-terminal-emulator", 
      "-title", "auto-apt Install:$package file:$filename by:$cmdname",
      "-geometry", "+20+30",
      "-e", "sh", "-c", qq#@aptinstall $package || (echo -n 'Failed [Z - exec shell to fix this situation]'; read yn; case \$yn in Z) echo "Type 'exit' when you're done"; \${SHELL:-/bin/sh};; esac)#;
} else {
    system('tput', 'smcup');
    system {'/usr/bin/sudo'} @aptinstall, $package;
    if ($? != 0) {
	print "Failed [Z - exec shell to fix this situation]";
	my ($yn) = <STDIN>;
        if ($yn =~ /Z/) {
	    print "Type 'exit' when you're done\n";
	    system ($ENV{'SHELL'} || '/bin/sh');
	}
    }
    system('tput', 'rmcup');
}

%pbutton = ();
%pinfo = ();

sub package_selected {
    my ($widget, $p) = @_;

    if ($pbutton{$p}->active) {
	$package = $p;
	@package = ($package);
	foreach (keys %pbutton) {
	    if ($_ ne $p && $pbutton{$_}->active) {
		$pbutton{$_}->set_active(0);
	    }
	}
    }
}

sub package_info {
    my ($widget, $p) = @_;
    my ($window) = new Gtk::Window('toplevel');
    $window->set_title("auto-apt: $p");
    $window->set_name("info: $p");

    $window->signal_connect("destroy", sub { $window->hide(); });
    $window->signal_connect("delete_event", sub { $window->hide();  });
    $window->set_usize(320, 300);
    realize $window;

    my ($text) = new Gtk::Text(undef, undef);
    $text->show();
    $window->add($text);
    $text->freeze();
    $text->realize();
    $p =~ s:.*/::;
    foreach (split(/\n/, $pinfo{$p})) {
	$text->insert(undef,$text->style->black,undef, "$_\n");
    }
    $text->thaw();
    $window->show();
}

sub package_description {
    my ($p) = @_;
    my ($d);
    $p =~ s:.*/::;
    if (open(A, "apt-cache show $p|")) {
	while (<A>) {
	    $pinfo{$p} .= $_;
	    if (s/^Description:\s+//) {
		$d = $_;
	    }
	}
	close(A);
    }
    return $d;
}

sub run_gtk {
    Gtk->init_check() || die "Gtk init error";
    set_locale Gtk;
    init Gtk;
    my ($window) = new Gtk::Window('toplevel');
    $window->set_title("auto-apt: Debian automatic installation tool");
    $window->set_name("main window");
    $window->set_uposition(20,20);
#    $window->set_usize(500,500);
    
    $window->signal_connect("destroy" => \&Gtk::main_quit);
    $window->signal_connect("delete_event" => \&Gtk::false);

    realize $window;

    my ($tooltips) = new Gtk::Tooltips;
    $window->{tooltips} = $tooltips;

    my ($vbox) = new Gtk::VBox(0,0);
    $window->add($vbox);
    $vbox->show();
    
    my ($proglabel) = new Gtk::Label("Program: $cmdname");
    $proglabel->set_alignment(0, 0.5);
    $proglabel->show();
    $vbox->pack_start($proglabel, 0, 0, 0);
    
    my ($filelabel) = new Gtk::Label("requires file: $filename");
    $filelabel->set_alignment(0, 0.5);
    $filelabel->show();
    $vbox->pack_start($filelabel, 0, 0, 0);
    
    my ($infolabel) = new Gtk::Label("This file is provided by:");
    $infolabel->set_alignment(0, 0.5);
    $infolabel->show();
    $vbox->pack_start($infolabel, 0, 0, 0);

    my ($hsep0) = new Gtk::HSeparator;
    $hsep0->show();
    $vbox->pack_start($hsep0, 0, 0, 0);

    my ($p);
    foreach $p (@package) {
	my ($pbox) = new Gtk::HBox(0,1);
	$vbox->pack_start($pbox, 0, 0, 5);
	$pbox->show();

	$pbutton{$p} = new Gtk::CheckButton($p);
	$pbutton{$p}->signal_connect("clicked", \&package_selected, $p);
	$pbox->pack_start($pbutton{$p}, 0, 0, 5);
	$tooltips->set_tip($pbutton{$p}, &package_description($p), 
			   "Package/$p");
	$pbutton{$p}->show();

	$pibutton{$p} = new Gtk::Button("info");
	$pibutton{$p}->signal_connect("clicked", \&package_info, $p);
	$pbox->pack_end($pibutton{$p}, 0, 0, 5);
	$pibutton{$p}->show();
    }

    my ($buttbox) = new Gtk::HBox(0,1);
    $vbox->pack_start($buttbox, 0, 0, 5);
    $buttbox->show();

    my ($hsep1) = new Gtk::HSeparator;
    $hsep1->show();
    $vbox->pack_start($hsep1, 0, 0, 0);

    my (@butts) = (new Gtk::Button("Install"),
		   new Gtk::Button("Cancel"));
    foreach (@butts) {
	$buttbox->pack_start($_, 0, 0, 5);
	$_->show();
    }
    $butts[0]->signal_connect("clicked", \&Gtk::main_quit);
    $butts[1]->signal_connect("clicked", sub { undef $package; &Gtk::main_quit} );

    $window->show();
    $package = $package[0];
    $pbutton{$package}->set_active(1);
    Gtk->gc;
    Gtk->main;
}
