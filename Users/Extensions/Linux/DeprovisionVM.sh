#!/bin/bash

sudo waagent -deprovision+user -force && sudo poweroff

# RUN USING:
# sh DeprovisionVM.sh
