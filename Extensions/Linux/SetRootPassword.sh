#!/bin/bash

echo "root:$1"  | chpasswd

# RUN USING:
# sh ChangePassword.sh <password>