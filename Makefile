INSTALL_CMD=install -g root -o root -m 755
ifeq "$(EXEC_PREFIX)" ""
	EXEC_PREFIX=/usr/sbin
endif

install:
	groupadd disco
	mkdir -p /var/disco
	mkdir -p /var/disco/parameters
	mkdir -p /var/disco/ssh
	$(INSTALL_CMD) ./client/bin/disco-fs-unmount $(EXEC_PREFIX)/disco-fs-unmount
	$(INSTALL_CMD) ./client/bin/disco-fs-mount $(EXEC_PREFIX)/disco-fs-mount
	$(INSTALL_CMD) ./client/bin/disco-fs-init $(EXEC_PREFIX)/disco-fs-init
	$(INSTALL_CMD) ./client/bin/disco-fs-diff $(EXEC_PREFIX)/disco-fs-diff
	$(INSTALL_CMD) ./client/bin/disco-sh-exec $(EXEC_PREFIX)/disco-sh-exec
	$(INSTALL_CMD) ./client/bin/disco-sh-shell $(EXEC_PREFIX)/disco-sh-shell
	$(INSTALL_CMD) ./client/bin/disco $(EXEC_PREFIX)/disco
	$(INSTALL_CMD) ./universe/bin/disco-ball $(EXEC_PREFIX)/disco-ball
	$(INSTALL_CMD) ./universe/bin/disco-param $(EXEC_PREFIX)/disco-param
	cp -vR client/etc/disco /etc/
	chown -R root:disco /etc/disco
	rm -f /var/disco/ssh/*
	ssh-keygen -f /var/disco/ssh/id_rsa -N ''
	mkdir -p /var/disco/parameters/disco/client/cmds
	mkdir -p /var/disco/parameters/disco/server
	echo 'rsync -qaWHe "ssh -i /var/disco/ssh/id_rsa"'
	echo > /var/disco/parameters/disco/server/uri
	chown root:disco /var/disco
	chmod -R 750 /var/disco/parameters
	chown -R root:root /var/disco/ssh
	chmod 700 /var/disco/ssh
	chmod 600 /var/disco/ssh/id_rsa

