Read the Wiki
=====

This README is only a bare introduction. Please read the wiki at https://github.com/akesterson/disco/wiki
for more complete documentation.

disco
=====

Dead Simple COnfiguration management and continuous integration for linux like systems

DISCO uses simple, proven technologies to achieve the goal of configuration management.

* rsync for data transfer from master to client
* bash for scripts and templating
* unionfs and restricted bash for noop operations
* plaintext files in a structured directory tree for node classification and configuration

DISCO is in the very early alpha stages of development. At this point, I am fairly confident
that it won't destroy the system you run it on, but I still only run it on disposable virtual
machines until it reaches a higher level of maturity.

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

Performance Metrics
=====

DISCO stores performance metrics for pretty much everything it does. Use 'disco report' to see them. 
The report generated will represent the times and statistics for the most recent disco dance.

The Gory Details ("how does it work?")
=====

DISCO is a work in progress so not all of it is complete, but the general idea is this:

    - DISCO client rsyncs its node configuration parameters from the server
    - DISCO client performs topological sort of required modules, and for each one:
        - fetch all files, templates and scripts
        - resolve all templates
            - resolve all templates
        - execute all scripts
        - report all differences
    - report overall success or failure (any piece of any module failing indicates failure)

DISCO is able to easily report all differences by executing all scripts and templates inside a 
restricted bash chroot, and on top of a read-only unionfs with a scratchpad on the top,
some custom twiddly bits in the middle, and the existing running filesystem at the bottom (read-only). 
The scratchpad is not merged if there is a failure during live (non-NOOP) execution, to prevent
from locking the system in a non-functioning state.

If the NOOP flag is set, then all the same operations are performed, but the restricted
environment stops all potentially dangerous commands at the reporting level (presumably), and
the fetched files are not merged out of the scratchpad onto the live filesystem. 

See the client disco-fs-* and disco-exec-* scripts for more information on how this is done.
