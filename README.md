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

A complete example
=====

Presume we have a server with an incoming user, "disco", who has a home directory like this:

    disco@server:~$ cat rsyncd.conf
    [parameters]
    path = /home/disco/parameters
    read only = true
    comment = DISCO Parameters
    list = yes
    use chroot = false
   
    [testmodule-1.0]
    path = /home/disco/modules/testmodule-1.0
    read only = true
    comment = v1.0 of the Test module
    list = yes
    use chroot = false
   
    [othermodule-3.2]
    path = /home/disco/modules/othermodule-3.2
    read only = true
    comment = v3.2 of othermodule
    list = yes
    use chroot = false 

    disco@server:~$ find parameters
    parameters
    parameters/localhost.localdomain
    parameters/localhost.localdomain/parameters
    parameters/localhost.localdomain/parameters/something
    parameters/localhost.localdomain/modules
    parameters/localhost.localdomain/modules/othermodule-3.2
    parameters/localhost.localdomain/modules/testmodule-1.0
  
    disco@server:~$ cat parameters/localhost.localdomain/parameters/something
    LOLTHISKEYMEANSNOTHING
  
    disco@server:~$ find modules
    modules
    modules/othermodule-3.2
    modules/othermodule-3.2/requires
    modules/othermodule-3.2/parameters
    modules/othermodule-3.2/parameters/othermodule-3.2
    modules/othermodule-3.2/scripts
    modules/othermodule-3.2/templates
    modules/othermodule-3.2/templates/etc
    modules/othermodule-3.2/templates/etc/othermodule
    modules/othermodule-3.2/templates/etc/othermodule/stuff.cfg
    modules/othermodule-3.2/files
    modules/testmodule-1.0
    modules/testmodule-1.0/requires
    modules/testmodule-1.0/parameters
    modules/testmodule-1.0/parameters/testmodule-1.0
    modules/testmodule-1.0/scripts
    modules/testmodule-1.0/scripts/00-hello.sh
    modules/testmodule-1.0/scripts/10-service_stop.sh
    modules/testmodule-1.0/templates
    modules/testmodule-1.0/files
   
    disco@server:~$ cat modules/othermodule-3.2/templates/etc/othermodule/stuff.cfg
    echo HOST=$(hostname)
    echo KEY_VALUE=$(cat /var/disco/parameters/$(hostname)/parameters/something)
  
    disco@server:~$ cat modules/testmodule-1.0/scripts/00-hello.sh
    #!/bin/bash
  
    echo "Hello, disco"
  
    disco@server:~$ cat modules/testmodule-1.0/scripts/10-service_stop.sh
    #!/bin/bash
  
    service postgresql stop

... and that we have, on our client, a disco parameters tree set up like this:

    [disco@client disco]$ disco-param dump
    disco = {}
    disco/client = {}
    disco/client/cmds = {}
    disco/client/cmds/rsync = rsync -qaWHe "ssh -i /home/disco/.ssh/id_rsa_disco"
    disco/server = {}
    disco/server/uri = disco@aklabs.net

... Then we can use disco to configure our host.

First we need to mount and initialize disco's testing/noop filesystem as
root on the client.

    [root@localhost disco]$ NOOP=true disco-fs-mount
    [root@localhost disco]$ NOOP=true disco-fs-init

This will take a minute or two, the init does a lot of work. (But you only
have to run the init once at system start, no matter how many times you 
run disco.) Now we can do our noop run:

    [disco@localhost disco]$ NOOP=true disco dance
    error: othermodule-3.2: rsync: link_stat "/files/*" (in othermodule-3.2) failed: No such file or directory (2)
    error: testmodule-1.0: rsync: link_stat "/files/*" (in testmodule-1.0) failed: No such file or directory (2)
    info: Processing testmodule-1.0
    Hello, disco
    warning: Would execute : service postgresql stop
    info: Processing othermodule-3.2
    info: File: file: /etc/othermodule/stuff.cfg : Created : type=[regular file] device=[fd00] mode=[81a4] selinux=[?] md5=[77b20e4840b1be13a577e152edc6b443] perms=[root:root 644]
    0a1,2
    > HOST=localhost.localdomain
    > KEY_VALUE=LOLTHISKEYMEANSNOTHING

Here we can see the noop at work; it is preventing potentially destructive
commands like 'service' from running, while allowing other harmless commands
to operate in the noop context so that script logic is not affected. We can
also see the highly detailed statistics and diffs returned for file 
modifications. But none of the files actually wind up present on the 
system, and no running processes were affected:

    [root@client ~]$ ps ax | grep -i postgresql
    15595 pts/1    S+     0:00 grep -i postgresql
    24457 ?        S      0:12 /usr/lib/postgresql/8.4/bin/postgres -D /var/lib/postgresql/8.4/main -c config_file=/etc/postgresql/8.4/main/postgresql.conf
    [root@client ~]$ ls -l /etc/othermodule/stuff.cfg
    ls: cannot access /etc/othermodule/stuff.cfg: No such file or directory

If we were to turn the NOOP flag off, this would all happen for real:

    [root@client disco]$ disco dance
    error: othermodule-3.2: rsync: link_stat "/files/*" (in othermodule-3.2) failed: No such file or directory (2)
    error: testmodule-1.0: rsync: link_stat "/files/*" (in testmodule-1.0) failed: No such file or directory (2)
    info: Processing testmodule-1.0
    Hello, disco
    info: Processing othermodule-3.2
    info: File: file: /etc/othermodule/stuff.cfg : Created : type=[regular file] device=[fd00] mode=[81a4] selinux=[?] md5=[77b20e4840b1be13a577e152edc6b443] perms=[root:root 644]
    0a1,2
    > HOST=localhost.localdomain
    > KEY_VALUE=LOLTHISKEYMEANSNOTHING

... And we will see that the config file has been installed:

    [root@client ~]$ cat /etc/othermodule/stuff.cfg
    HOST=localhost.localdomain
    KEY_VALUE=LOLTHISKEYMEANSNOTHING

... And that postgres has been stopped:

    [root@client ~]# ps ax | grep -i postgresql
    28394 pts/1    S+     0:00 grep -i postgresql

Hooray!

Disco will report other types of file modifications, as well. If you were to 
open an interactive shell in the disco chroot, and perform some more interesting
operations, representing what a more advanced sort of script might do:

    [disco@client disco]$ NOOP=true disco-sh-shell
    [root@client /]# rm -f /etc/passwd
    [root@client /]# grep -v root /etc/shadow | tee tmpfile
    bin:*:15240:0:99999:7:::
    daemon:*:15240:0:99999:7:::
    adm:*:15240:0:99999:7:::
    lp:*:15240:0:99999:7:::
    sync:*:15240:0:99999:7:::
    shutdown:*:15240:0:99999:7:::
    halt:*:15240:0:99999:7:::
    mail:*:15240:0:99999:7:::
    uucp:*:15240:0:99999:7:::
    operator:*:15240:0:99999:7:::
    games:*:15240:0:99999:7:::
    gopher:*:15240:0:99999:7:::
    ftp:*:15240:0:99999:7:::
    nobody:*:15240:0:99999:7:::
    dbus:!!:15324::::::
    usbmuxd:!!:15324::::::
    avahi-autoipd:!!:15324::::::
    vcsa:!!:15324::::::
    rtkit:!!:15324::::::
    rpc:!!:15324:0:99999:7:::
    pulse:!!:15324::::::
    haldaemon:!!:15324::::::
    avahi:!!:15324::::::
    saslauth:!!:15324::::::
    postfix:!!:15324::::::
    apache:!!:15324::::::
    ntp:!!:15324::::::
    rpcuser:!!:15324::::::
    nfsnobody:!!:15324::::::
    gdm:!!:15324::::::
    sshd:!!:15324::::::
    tcpdump:!!:15324::::::
    disco:$6$Hv67bVi.$d/EolMfURGTMbq1hBr1QL2HdYMYxAXvruq550Qqgu2HCOKWQ1YptMghLKvOAgr3h0NwzXZwHpXQ6fVLdpYe.9.:15533:0:99999:7:::
    discostu:!!:15558:0:99999:7:::
    [root@client /]# mv tmpfile /etc/shadow
    mv: overwrite `/etc/shadow'? y
    [root@client /]# echo LOL > /var/lib/p0wnt
    bash: /var/lib/p0wnt: restricted: cannot redirect output
    [root@client /]# echo LOL | tee /var/lib/p0wnt
    LOL
    [root@client /]# echo > /bin/myhotbash
    bash: /bin/myhotbash: restricted: cannot redirect output
    [root@client /]# touch /bin/myhotbash
    [root@client /]# exit

... Since that was done inside of the noop shell (where all the scripts and 
templates run during noop), we can easily report on these activities:

    [disco@client disco]$ NOOP=true disco-fs-diff
    info: File: file: /etc/passwd : Deleted
    1,35d0
    < root:x:0:0:root:/root:/bin/bash
    < bin:x:1:1:bin:/bin:/sbin/nologin
    < daemon:x:2:2:daemon:/sbin:/sbin/nologin
    < adm:x:3:4:adm:/var/adm:/sbin/nologin
    < lp:x:4:7:lp:/var/spool/lpd:/sbin/nologin
    < sync:x:5:0:sync:/sbin:/bin/sync
    < shutdown:x:6:0:shutdown:/sbin:/sbin/shutdown
    < halt:x:7:0:halt:/sbin:/sbin/halt
    < mail:x:8:12:mail:/var/spool/mail:/sbin/nologin
    < uucp:x:10:14:uucp:/var/spool/uucp:/sbin/nologin
    < operator:x:11:0:operator:/root:/sbin/nologin
    < games:x:12:100:games:/usr/games:/sbin/nologin
    < gopher:x:13:30:gopher:/var/gopher:/sbin/nologin
    < ftp:x:14:50:FTP User:/var/ftp:/sbin/nologin
    < nobody:x:99:99:Nobody:/:/sbin/nologin
    < dbus:x:81:81:System message bus:/:/sbin/nologin
    < usbmuxd:x:113:113:usbmuxd user:/:/sbin/nologin
    < avahi-autoipd:x:170:170:Avahi IPv4LL Stack:/var/lib/avahi-autoipd:/sbin/nologin
    < vcsa:x:69:69:virtual console memory owner:/dev:/sbin/nologin
    < rtkit:x:499:496:RealtimeKit:/proc:/sbin/nologin
    < rpc:x:32:32:Rpcbind Daemon:/var/cache/rpcbind:/sbin/nologin
    < pulse:x:498:495:PulseAudio System Daemon:/var/run/pulse:/sbin/nologin
    < haldaemon:x:68:68:HAL daemon:/:/sbin/nologin
    < avahi:x:70:70:Avahi mDNS/DNS-SD Stack:/var/run/avahi-daemon:/sbin/nologin
    < saslauth:x:497:76:"Saslauthd user":/var/empty/saslauth:/sbin/nologin
    < postfix:x:89:89::/var/spool/postfix:/sbin/nologin
    < apache:x:48:48:Apache:/var/www:/sbin/nologin
    < ntp:x:38:38::/etc/ntp:/sbin/nologin
    < rpcuser:x:29:29:RPC Service User:/var/lib/nfs:/sbin/nologin
    < nfsnobody:x:65534:65534:Anonymous NFS User:/var/lib/nfs:/sbin/nologin
    < gdm:x:42:42::/var/lib/gdm:/sbin/nologin
    < sshd:x:74:74:Privilege-separated SSH:/var/empty/sshd:/sbin/nologin
    < tcpdump:x:72:72::/:/sbin/nologin
    < disco:x:500:10::/home/disco:/bin/bash
    < discostu:x:501:501::/home/discostu:/bin/bash
    info: File: file: /bin/myhotbash : Created : type=[regular empty file] device=[fd00] mode=[81a4] selinux=[?] md5=[d41d8cd98f00b204e9800998ecf8427e] perms=[root:root 644]
    info: File: file: /etc/shadow : Modified : md5=[8b02f6d00dbcd622f869216bb1dbbbf4 => 336d0b913c8f8cd029964afd00357952] perms=[root:root 0 => root:root 644] mode=[8000 => 81a4]
    1d0
    < root:$6$57kBYzwRrygFb5op$vghIbLjxmkzTznSbN4kA5fdxFsd1ye7WWe/HFtwMJSTBlDuBcOZISgLKNg/xlA4uAFIBi82yAnW/JajgwhCXY.:15517:0:99999:7:::
    info: File: file: /root/.bash_history : Modified : md5=[ead812e487da32cb99cebd09ad7f773b => cb0138b7f3c4f48639cafe9f7147413f] selinux=[unconfined_u:object_r:admin_home_t:s0 => ?]
    228a229,237
    > exit
    > rm -f /etc/passwd
    > grep -v root /etc/shadow | tee tmpfile
    > mv tmpfile /etc/shadow
    > echo LOL > /var/lib/p0wnt
    > echo LOL | tee /var/lib/p0wnt
    > echo > /bin/myhotbash
    > touch /bin/myhotbash
    > exit
    info: File: file: /var/lib/p0wnt : Created : type=[regular file] device=[fd00] mode=[81a4] selinux=[?] md5=[5732edd7e4e1240b868e15bc95d36339] perms=[root:root 644]
    0a1
    > LOL

And here we see some more of Disco's rather extensive noop reporting capabilities.

But let's say that this run took longer than we thought it should. What was taking
so much time? Disco will tell us.

    [root@disco ~]# disco report
    report: _internal: diff
    report:    time_real 0.82 : time_user 0.14 : time_sys 0.66
    report:    mem_avg 0 : mem_max 5184 : mem_faults_major 0 : mem_faults_minor 18218
    report:    io_fsin 0 : io_fsout 8 : io_sockin 0 : io_sockout 0 : io_signals 0
    report:    exit: 0
    report: _internal: fetch_params
    report:    time_real 1.26 : time_user 0.02 : time_sys 0.08
    report:    mem_avg 0 : mem_max 11136 : mem_faults_major 0 : mem_faults_minor 1728
    report:    io_fsin 0 : io_fsout 0 : io_sockin 0 : io_sockout 0 : io_signals 0
    report:    exit: 0
    report: othermodule-3.2: diff
    report:    time_real 0.80 : time_user 0.13 : time_sys 0.65
    report:    mem_avg 0 : mem_max 4816 : mem_faults_major 0 : mem_faults_minor 16448
    report:    io_fsin 0 : io_fsout 8 : io_sockin 0 : io_sockout 0 : io_signals 0
    report:    exit: 0
    report: othermodule-3.2: fetch
    report:    time_real 2.28 : time_user 0.05 : time_sys 0.14
    report:    mem_avg 0 : mem_max 11152 : mem_faults_major 0 : mem_faults_minor 2843
    report:    io_fsin 0 : io_fsout 24 : io_sockin 0 : io_sockout 0 : io_signals 0
    report:    exit: 0
    report: othermodule-3.2: template
    report:    etc/othermodule/stuff.cfg :
    report:        time_real 0.56 : time_user 0.04 : time_sys 0.37
    report:        mem_avg 0 : mem_max 4592 : mem_faults_major 122 : mem_faults_minor 4885
    report:        io_fsin 25536 : io_fsout 16 : io_sockin 0 : io_sockout 0 : io_signals 0
    report:        exit: 0
    report: testmodule-1.0: diff
    report:    time_real 2.56 : time_user 0.42 : time_sys 2.10
    report:    mem_avg 0 : mem_max 5184 : mem_faults_major 0 : mem_faults_minor 57661
    report:    io_fsin 0 : io_fsout 32 : io_sockin 0 : io_sockout 0 : io_signals 0
    report:    exit: 0
    report: testmodule-1.0: exec
    report:    00-hello.sh :
    report:        time_real 0.27 : time_user 0.03 : time_sys 0.18
    report:        mem_avg 0 : mem_max 4672 : mem_faults_major 32 : mem_faults_minor 3783
    report:        io_fsin 6640 : io_fsout 8 : io_sockin 0 : io_sockout 0 : io_signals 0
    report:        exit: 0
    report:    10-service_stop.sh :
    report:        time_real 0.58 : time_user 0.03 : time_sys 0.41
    report:        mem_avg 0 : mem_max 4960 : mem_faults_major 122 : mem_faults_minor 5462
    report:        io_fsin 25656 : io_fsout 8 : io_sockin 0 : io_sockout 0 : io_signals 0
    report:        exit: 1
    report: testmodule-1.0: fetch
    report:    time_real 2.72 : time_user 0.06 : time_sys 0.15
    report:    mem_avg 0 : mem_max 11152 : mem_faults_major 0 : mem_faults_minor 2996
    report:    io_fsin 0 : io_fsout 24 : io_sockin 0 : io_sockout 0 : io_signals 0
    report:    exit: 0

Happy dancing!