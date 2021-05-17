#!/bin/bash
LOG_FOLDER=$1
LOG_FILE="$LOG_FOLDER/installation_dependencies.log"

sudo apt update &>> $LOG_FILE
cat $LOG_FILE | grep "Failed" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "\e[31m\e[1m\tRepository update failed\e[0m"
    echo "LOGS: $LOG_FOLDER"
    exit 1
fi
echo "------------------------------------------------------------------------------------------------------" >> $LOG_FILE
echo "Repositories updated" >> $LOG_FILE
echo -e "\e[32m\tRepositories updated\t\t\e[1m[X]\e \e[0m"

sudo apt upgrade -y &>> $LOG_FILE
cat $LOG_FILE | grep "Failed" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "\e[31m\e[1m\tPackages update failed\e[0m"
    echo "LOGS: $LOG_FOLDER"
    exit 1
fi
echo "------------------------------------------------------------------------------------------------------" >> $LOG_FILE
echo "Packages updated" >> $LOG_FILE
echo -e "\e[32m\tPackages updated\t\t\e[1m[X]\e \e[0m"

sudo apt-get install -y linux-headers-$(uname -r)\
                        build-essential\
                        perl\
                        gcc\
                        make\
                        dkms\
                        sed\
                        wget\
                        virtualbox\
                        network-manager &>> $LOG_FILE

cat $LOG_FILE | grep "Failed" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "\e[31m\e[1m\tInstall dependencies failed\e[0m"
    echo "LOGS: $LOG_FOLDER"
    exit 1
fi
echo "------------------------------------------------------------------------------------------------------" >> $LOG_FILE
echo "Dependencies were installed" >> $LOG_FILE
echo -e "\e[32m\tDependencies\t\t\t\e[1m[X]\e \e[0m"

#Update Virtualbox
if [[ -z $(sudo apt list -a virtualbox 2>/dev/null | grep "installed") ]];then
    VB_CURRENT_VERSION=$(VBoxManage --version)
    if [[ $? != 0 ]];then
        VB_CURRENT_VERSION=6.0
    else
        VB_CURRENT_VERSION=${VB_CURRENT_VERSION:0:3}
    fi
    VERSION_VB=6.1
    if (( ${VB_CURRENT_VERSION%%.*} < ${VERSION_VB%%.*} || ( ${VB_CURRENT_VERSION%%.*} == ${VERSION_VB%%.*} && ${VB_CURRENT_VERSION##*.} < ${VERSION_VB##*.} ) )) ; then    
        sudo apt remove virtualbox
        wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
        wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] http://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib"
        sudo apt update
        sudo apt-get install virtualbox-6.1
        wget https://download.virtualbox.org/virtualbox/6.1.22/Oracle_VM_VirtualBox_Extension_Pack-6.1.22.vbox-extpack
        VBoxManage extpack install Oracle_VM_VirtualBox_Extension_Pack-6.1.22.vbox-extpack
    fi
    if [[ -z $(sudo apt list -a virtualbox 2>/dev/null | grep "installed") ]];then
        echo -e "\e[31m\e[1m\tInstall VirtualBox failed\e[0m"
        echo "LOGS: $LOG_FOLDER"
        exit 1
    fi
    echo "------------------------------------------------------------------------------------------------------" >> $LOG_FILE
    echo "Virtualbox was installed" >> $LOG_FILE
fi
echo -e "\e[32m\tVirtualbox\t\t\t\e[1m[X]\e \e[0m"

#Install Packer
if [[ -z $(sudo apt list -a packer 2>/dev/null | grep "installed") ]]; then
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add - &>> $LOG_FILE
    sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"  >> $LOG_FILE
    sudo apt-get update &>>$LOG_FILE
    sudo apt-get install packer &>> $LOG_FILE
fi
if [[ -z $(sudo apt list -a packer 2>/dev/null | grep "installed") ]]; then
    echo -e "\e[31m\e[1m\tInstall packer failed\e[0m"
    echo "LOGS: $LOG_FOLDER"
    exit 1
fi
echo "------------------------------------------------------------------------------------------------------" >> $LOG_FILE
echo "Packer was installed" >> $LOG_FILE
echo -e "\e[32m\tPacker\t\t\t\t\e[1m[X]\e \e[0m"
