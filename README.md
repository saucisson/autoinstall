autoinstall -- on demand package installation tool
==================================================

This software is heavily base on auto-apt, the on demand package installation
tool for Debian-based systems. This version differs on its handling of
missing packages installation. It provides a way to script in Lua the actions
to perform when a file is missing.

Install
-------

    apt-get install lua5.1 luarocks
    luarocks install --local autoinstall

Use
---

First, set the correct paths:

    export PATH=$HOME/.luarocks/bin:$PATH
    $(luarocks path)

Then, run your command:

    autoinstall ls /usr/bin/lsb_release

Warning
-------

Make sure the `sudo` command is available, and that you are in the `sudoers`.
