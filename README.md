disco
=====

Dead Simple COnfiguration management and continuous integration for linux like systems

DISCO is just now beginning development. Expect what you find here to do irreparable damage
to any system you run it on. I ONLY run disco on a throwaway VM at current.

Why disco?
=====

Because puppet, chef, cfengine, etc, are all great tools, but they all fall
short of the mark, in terms of simplicity, ease of use, and reliability.
None of them really follow the UNIX philosophy of "do one thing, do it well,
and don't reinvent the wheel".

No, really, why did you name it "disco"?
=====
I wanted an acronym based off of "Dead Simple Continuous Integration", and this was
the closest I found.

Requirements
=====

DISCO assumes that you:

    - have at least one server capable of running rsyncd, sshd and bash 4+
    - have one or more clients capable of running bash 4+, ssh, rsync, and fuse-unionfs

While that's a very simple requirements list, it currently restricts it to recent Linux
systems. You may or may not be able to use this tool on FreeBSD or Mac OS X, I haven't
tried. Due to the way it executes, this tool will probably never, ever execute properly
on Windows.

Why focus so much on linux?
=====

Because if we try to do everything and the kitchen sink, for every OS out there, we run
the risk of falling short in the same ways the other CI tools have. By limiting our scope
and problem space to recent GNU/Linux systems, we can write a much simpler tool in a
much shorter amount of time that is much simpler to understand.