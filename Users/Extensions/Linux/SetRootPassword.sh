#!/bin/bash

sudo sed -i -e "s/PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config
sudo service sshd restart
echo "root:$1" | chpasswd

# RUN USING:
# sh ChangePassword.sh <Password>
