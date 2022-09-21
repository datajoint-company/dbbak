FROM ubuntu:jammy

RUN apt update && \
    apt upgrade -y
    
RUN apt-get install -y wget xz-utils libaio1 libncurses5 libnuma1 && \
    wget -P /tmp https://downloads.mysql.com/archives/get/p/23/file/mysql-8.0.28-linux-glibc2.17-x86_64-minimal.tar.xz && \
    tar -xvf /tmp/mysql-8.0.28-linux-glibc2.17-x86_64-minimal.tar.xz -C /tmp && \
    mv /tmp/mysql-8.0.28-linux-glibc2.17-x86_64-minimal /usr/local/mysql && \
    rm /tmp/mysql-8.0.28-linux-glibc2.17-x86_64-minimal.tar.xz
ENV PATH=${PATH}:/usr/local/mysql/bin

WORKDIR /usr/local/mysql
RUN groupadd mysql && \
    useradd -r -g mysql -s /bin/false mysql && \
    mkdir mysql-files && \
    chown mysql:mysql mysql-files && \
    chmod 750 mysql-files && \
    bin/mysqld --initialize-insecure --user=mysql && \
    bin/mysql_ssl_rsa_setup && \
    cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysql.server

WORKDIR /