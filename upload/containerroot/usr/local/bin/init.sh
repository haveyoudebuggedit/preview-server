#!/bin/bash -e

mkdir -p /var/www/.ssh
chmod 0755 /var/www/.ssh
echo "${SSH_KEY}" >/etc/ssh/authorized_keys

exec /usr/sbin/sshd -D
