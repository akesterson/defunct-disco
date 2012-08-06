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

Is DISCO noop friendly (report all incoming changes)?
=====

Yes, DISCO is noop friendly, with a caveat: The way we implement noop is through restricted bash
shells. This is generally sufficient, and already proven and simple. 

There are some questions around "is the NOOP really secure then?" Well, yes and no.

Unlike puppet's noop, which is implemented via a guaranteed safe DSL, DISCO assumes an
existing trust network between your disco server and disco client; the goal of DISCO noop is to
prevent well-meaning trusted sysadmins from doing really stupid things. It does not try
to secure your systems from malicious code. That security layer is moved up, onto the maintainer,
who must verify the sanity of all code they are sending to client machines.

How do you establish the trust relationship?
=====

DISCO uses rsync(+ssh) with SSH keys, so the answer is, "we don't establish it" - SSH handles
that for us by the server allowing or denying the key.

How do you handle parameters (like puppet ENC, etc)?
=====

DISCO uses a section of the filesystem to layout a tree of pathable, walkable parameters.
This part of the filesystem is available to the client at execution time, so these variables
can be used in scripts, templates, and definition files, to further customize execution based
off of parameters. This lives on the SERVER, not the client.

From the server perspective, the parameters tree looks like:

    /var/disco/parameters
    ___ ___ disco
    ___ ___ ___ client
    ___ ___ ___ ___ cmds
    ___ ___ ___ ___ ___ rsync
    ___ ___ server
    ___ ___ ___ uri
    ___ ___ NODE_NAME
    ___ ___ ___ modules
    ___ ___ ___ ___ ...
    ___ ___ ___ parameters
    ___ ___ ___ ___ ...

Think of it like a large JSON document expressed as a filesystem, with the document keys the
filenames, and the values being their contents. This format was chosen because it can be easily
created from any number of other existing datasources, and doesn't tie DISCO to any one particular
tool (cobbler, etc). The admin is free to create this structure on the server however they please.

Given this, disco does not use a config file, all configuration parameters are present in this
tree.

There are only two possible toplevel paths, /disco and /NODE_NAME. NODE_NAME is equal to the
FQDN of the client making a request, and /disco is the internal client/server configuration.
The parameter tree is transmitted from the server to the client via (yet another) rsync
operation, and is accessible as a filesystem tree (or the disco-param command which is just a
bash wrapper). These parameters appear in /var/disco/parameters on the client and server, and 
default values can be found there in the client/server install before the first run of the client.

    /disco/client/cmds/rsync : The rsync command to use when synching
        files.
    /disco/server/uri : The rsync URI from which to fetch module definitions.
    /disco/NODE_NAME/modules : This list defines the modules to install 
        on a given node. 
    /disco/NODE_NAME/parameters : This tree defines all configuration 
        parameters for the node not related to any module in particular.

Some special parameters are provided to the client, that do not exist on the paramters tree until
runtime:

    /disco/NODE_NAME/current_module : This parameter defines the full 
        name of the current module, such that a module definition file 
        can access its personal parameters via without knowing its name, e.g.:
        $(disco-param get /classes/$(disco-param get /current_module)/some/module/specific/path)

How to deploy stuff
=====

DISCO uses rsync(+ssh) to distribute files, and bash to execute supporting scripts. It has a
rudimentary dependency mechanism implemented via a topological sort. 

Essentially, to deploy something, you need 3 things:

    - some files and templates on an rsync server
    - some scripts that may or may not do something with those files and templates
    - a definition file saying where to get those files, templates and scripts, and which
      order to apply them in, as well as what other things you need deployed before this thing

Scripts
=====

DISCO uses bash for a scripting and templating engine. Instead of writing a custom DSL that lets
you specify operations (like Puppet did) or utilize a higher level language (like Chef did with
ruby), DISCO just uses the proven bash shell. 

Files vs Templates
=====

Files and Templates are delivered exactly the same way - via rsync.

Files are static files who are delivered on to the disk, and no more operations are done to them.

Templates are bash scripts who are delivered on to the disk, and then they are executed, with their
file contents replaced by their output. Templates are subject to all the same restrictions as scripts
(be mindful of the constraints of $NOOP), and in addition, they are ALWAYS interpolated in the safe
NOOP execution environment (file modifications will be discarded, and only rudimentary bash builtins
are enabled). Templates have access to all client parameters via the disco-param command.

Definition Files
=====

Definition files are just a series of files that say what files on the disk should be templated,
or executed as scripts, for this module; as well as defining module-level parameters, and dependency
requirements, for this module.

Definition files can use node parameters via the $(disco-param /path/to/node/parameter) syntax.
This interpolation is done on the client side, so the server does not execute any code for this.
This is useful for when a module needs to pull different files or whatever depending on its branch,
release name, whatever.

Module Layout
=====

A disco module (also called a "disco ball" for fun) looks like this:

    MODULE
    ├__ defs
    ___ ___ requires
    │__ ├── scripts
    │__ └── templates
    ___ ___ parameters
    ├── files
    ├── scripts
    └── templates

Your module can theoretically pull files, scripts, and templates from any location that can be
reached via rsync; however, it is generally considerd good form to include all things relevant
to your module, inside its disco ball. The disco ball is then placed in an accessible location
on the rsync server, and the disco client will pull all modules, files, scripts, and templates
relevant to its execution, and run them.

ALL MODULE FILES, SCRIPTS, AND TEMPLATES ARE DELIVERED RELATIVE TO / ON THE CLIENT.

MODULE/defs/requires
=====

This file lists, one name per line, the names of other modules that must be installed on this
node in order for this module to install correctly. This is used to create a dependency graph,
and thereby determine execution order.

MODULE/defs/files
=====

Consists of a number of rsync locations to pull files from. For each line of the file, the format is:

    SOURCE_PATH[:DEST_ROOT]

... SOURCE_PATH is a rsync+ssh URI passed directly to the rsync command (as defined in parameter 
disco/client/cmds/rsync). DEST_ROOT is optional; if not present, all files retrieved are rooted into /.
You can use this to change this behavior to root incoming files to a different LOCAL PATH; remote paths
are not supported!

MODULE/defs/templates
=====

This file has an identical syntax to MODULE/defs/files, except that it lists templates, not files.
These files are fetched exactly like the others, but once fetched, they are templated and replaced with
the template output.

MODULE/defs/scripts
=====

This file simply lists the (local) location of commands to execute, for this module, once all scripts have
been fetched, and all templates have been interpolated. The scripts cannot accept arguments. They are 
executed, in order. One script failing will not stop other scripts from failing unless told to do so in the
/MODULE_NAME/halt_on_failure parameter. Otherwise, errors are reported, but all scripts will be executed 
regardless.

MODULE/defs/parameters
=====

Each module can define default parameters which will be made available to all clients using the module.
These parameters will be merged together on the client at module fetch time, and any node-specific
parameters will override any default parameters specified here (they are rsync'ed over the top of each
other). These parameters will be rooted at /MODULE_NAME/... .

Server Side Setup
=====

The only server side setup required for DISCO is to setup an rsyncd and sshd server. This is outside
the purview of this README. 

We would recommend setting up the rsync server to allow your DISCO clients (which MUST run as root),
to come in on a non-priveleged, non-root account. You can still use rsync's module definitions with
non-root users by setting up ~/.rsyncd in that user's home directory, and adding
"--rsh 'ssh -l USER_NAME'" to your /disco/client/cmds/rsync parameter on the clients. This will
allow you to specify your rsync locations in your module definitions as USER@HOST::MODULE_NAME instead
of having to specify a filesystem path, will give you all the benefits of an SSH key trust relationship,
and no concern of incoming root access to the server. (Note that this also prevents the often mysterious
and troublesome SSL certificate issues associated with other CI systems.)

The Gory Details ("how does it work?")
=====

DISCO is a work in progress so not all of it is complete, but the general idea is this:

    - DISCO client rsyncs its node configuration parameters from the server
    - DISCO client performs topological sort of required modules, and for each one:
        - fetch all files
        - fetch all templates
            - resolve all templates
        - execute all scripts
        - report all differences
    - report overall success or failure (any piece of any module failing indicates failure)

DISCO is able to easily report all differences by executing all scripts and templates inside a 
restricted bash execution environment, and on top of a read-only unionfs with a scratchpad on 
the top. If the NOOP flag is set, then all the same operations are performed, but the restricted
environment stops all potentially dangerous commands at the reporting level, and the fetched files
are not merged out of the scratchpad onto the live filesystem.

See the client disco-fs-* and disco-exec-* scripts for more information on how this is done.