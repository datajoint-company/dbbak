
SHELL := /bin/bash
ROOTUSER?=root
ROOTGROUP?=root

default:
	@echo "usage: make install"

install-xtrabackup:
	@echo "Install percona-xtrabackup"
	apt-get install -y curl wget lsb-release
	wget -P /tmp https://repo.percona.com/apt/percona-release_latest.$$(lsb_release -sc)_all.deb
	dpkg -i /tmp/percona-release_latest.$$(lsb_release -sc)_all.deb
	percona-release enable-only tools release
	apt update
	apt install -y percona-xtrabackup-80 qpress
	rm /tmp/percona-release_latest.$$(lsb_release -sc)_all.deb

install-xtrabackup-generic:
	@echo "Install percona-xtrabackup for Ubuntu 22.04 Jammy"
	apt-get install -y wget
	wget -P /tmp https://downloads.percona.com/downloads/Percona-XtraBackup-LATEST/Percona-XtraBackup-8.0.28-21/binary/tarball/percona-xtrabackup-8.0.28-21-Linux-x86_64.glibc2.17.tar.gz
	tar -xvf /tmp/percona-xtrabackup-8.0.28-21-Linux-x86_64.glibc2.17.tar.gz -C /opt
	echo "export PATH=$$PATH:/opt/percona-xtrabackup-8.0.28-21-Linux-x86_64.glibc2.17/bin" >> ~/.bashrc

install-dbbak:
	@echo "installing dbbak..."
	@[ ! -f "/etc/dbbak.cfg" ] \
	&& install -o $(ROOTUSER) -g $(ROOTGROUP) -m 640 \
		dbbak.cfg.in /etc/dbbak.cfg \
	|| ( \
		echo "note: merge /etc/dbbak.cfg.upgrade if needed!"; \
		install -o $(ROOTUSER) -g $(ROOTGROUP) -m 644 \
			dbbak.cfg.in /etc/dbbak.cfg.upgrade \
	)
	@install -o $(ROOTUSER) -g $(ROOTGROUP) -m 755 \
		dbbak /usr/local/bin/dbbak
	@install -o $(ROOTUSER) -g $(ROOTGROUP) -m 755 \
		dbbak.cron /usr/local/bin/dbbak.cron
	@echo "done."

install:
	make install-xtrabackup
	make install-dbbak

install-generic:
	make install-xtrabackup-generic
	make install-dbbak