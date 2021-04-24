#!/bin/bash

#Declare constants
HOMEPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"

#Install dependencies
sudo apt update
sudo apt upgrade -y
sudo apt-get install -y linux-headers-$(uname -r)\
                        build-essential\
                        perl\
                        dkms\
                        sed\
                        wget\
                        virtualbox

#Install Packer
if [[ -z $(sudo apt list -a packer 2>/dev/null | grep "installed") ]]; then
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
    sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
    sudo apt-get update && sudo apt-get install packer
fi
