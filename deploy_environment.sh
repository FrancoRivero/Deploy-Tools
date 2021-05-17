#!/bin/bash
typeset -A config 
config=(
    [VERSION]="13.0"
    [ISO_NAME]="FreeBSD-${config[VERSION]}-RELEASE-amd64-dvd1.iso"
    [HOME]="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
    [PACKER_CONFIG_BASE]="freebsd_base.json"
    [PACKER_CONFIG]="freebsd.json"
    [OUTPUT_PATH]=$(sudo find /home -type d -name "VirtualBox VMs")
    [GIT_USER]="FrancoRivero"
    [LOG_FOLDER]="/tmp/logs/log_$(date +%Y%m%d%H%M%s)"
    [GIT_FOLDER]="~/repository"
)

detect_os_and_install_dependecies() {
    OS=$(hostnamectl | grep "Operating System:" )
    if [[ $(echo \"$OS\" | grep "Ubuntu") ]]; then
        ${config["HOME"]}/dependencies_installers/install_ubuntu_dependencies.sh ${config["LOG_FOLDER"]}
    elif [[ $(echo \"$OS\" | grep "Red Hat") ]]; then
        echo "$OS"
    elif [[ $(echo \"$OS\" | grep "Debian") ]]; then
        echo "$OS"
    elif [[ $(echo \"$OS\" | grep "openSUSE") ]]; then
        echo "$OS"
    else
        echo "Unknown"
    fi
}

detect_network_connection() {
    interfaces=$(nmcli device status | awk '{print $1}' | sed -n '1!p')
    for interface in $interfaces
    do
        echo $interface >> ${config["LOG_FOLDER"]}/detect_network.log
        echo "------------------------------------------------------------------------------------------------------" >> ${config["LOG_FOLDER"]}/detect_network.log
        ping -I $interface -c 1 www.google.com >> ${config["LOG_FOLDER"]}/detect_network.log
        if [[ $? == 0 ]];then
            network_output=$interface
            return 0
        fi
    done
    echo -e "\e[31m\e[1mNetwork detection failed\e[0m"
    echo "LOGS: ${config["LOG_FOLDER"]}"
    exit 1
}

main() {
    echo -e "\e[32m\e[1mCreating development environment...\e[0m"
    echo -e "\e[33m\e[1m--> Installing dependencies...\e[0m"
    #Create log's folder
    if [ ! -d /tmp/logs ]; then
        mkdir -p /tmp/logs
    fi
    mkdir ${config["LOG_FOLDER"]}

    #Install dependecies
    detect_os_and_install_dependecies
    if [ $? -ne 0 ]; then
        echo -e "\e[31m\e[1mInstall dependencies failed\e[0m"
        echo "LOGS: ${config["LOG_FOLDER"]}"
        exit 1
    fi

    #Evaluate interfaces
    echo -e "\e[33m\e[1m--> Network detection...\e[0m"
    detect_network_connection
    if [ $? -ne 0 ]; then
        echo -e "\e[31m\e[1mNetwork detection failed\e[0m"
        echo "LOGS: ${config["LOG_FOLDER"]}"
        exit 1
    fi
    echo -e "\e[32m\tNetwork interface\t\t\e[1m[X]\e \e[0m"

    #Create folder if it doesn't exist
    echo -e "\e[33m\e[1m--> Create environment to create a virtual machine...\e[0m"
    if [ ! -d ${config["HOME"]}/http ]; then
        mkdir -p ${config["HOME"]}/http
    fi
    if [ $? -ne 0 ]; then
        echo -e "\e[31m\e[1mhttp folder to create failed\e[0m"
        echo "LOGS: ${config["LOG_FOLDER"]}"
        exit 1
    fi
    echo -e "\e[32m\tHTTP folder\t\t\t\e[1m[X]\e \e[0m"

    #Get FreeBSD iso
    if [ ! -f ${config["HOME"]}/http/${config["ISO_NAME"]} ]; then
        iso_freebsd_path=$(sudo find /home -name "${config["ISO_NAME"]}" -print | head -n 1)
        if [[ "$iso_freebsd_path" == "" ]]; then
            wget https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/${config["VERSION"]}/${config["ISO_NAME"]} >> ${config["LOG_FOLDER"]}/create_environment.log
        fi 
        mv $iso_freebsd_path ${config["HOME"]}/http/${config["ISO_NAME"]}
    fi
    if [ ! -f ${config["HOME"]}/http/${config["ISO_NAME"]} ]; then
        echo -e "\e[31m\e[1mFreeBSD image download failed\e[0m"
        echo "LOGS: ${config["LOG_FOLDER"]}"
        exit 1
    fi
    echo -e "\e[32m\tFreeBSD image\t\t\t\e[1m[X]\e \e[0m"

    #Modify configuration file
    cd ${config["HOME"]}
    cp ${config["PACKER_CONFIG_BASE"]} ${config["PACKER_CONFIG"]}
    sed -i 's|ISO_NAME|'${config["ISO_NAME"]}'|g' ${config["PACKER_CONFIG"]}
    ISOSHA2=$(sha256sum ${config["HOME"]}/http/${config["ISO_NAME"]} | awk '{print $1}')
    sed -i 's|ISO_CHECKSUM|'$ISOSHA2'|g' ${config["PACKER_CONFIG"]}
    sed -i 's|NETWORK_INTERFACE|'$network_output'|g' ${config["PACKER_CONFIG"]}

    #Validate configuration file
    packer validate ${config["PACKER_CONFIG"]} >> ${config["LOG_FOLDER"]}/create_environment.log
    if [ $? -ne 0 ]; then
        echo -e "\e[31m\e[JSON validation failed\e[0m"
        echo "LOGS: ${config["LOG_FOLDER"]}"
        exit 1
    fi
    echo -e "\e[32m\tConfiguration file\t\t\e[1m[X]\e \e[0m"
    
    #build VM with Packer
    echo -e "\e[33m\e[1m--> Building virtual machine...\e[0m"
    if [[ ! -d ${config["OUTPUT_PATH"]}/FreeBSD_for_testing ]];then
        packer build -var output_path="${config["OUTPUT_PATH"]}" ${config["PACKER_CONFIG"]} >> ${config["LOG_FOLDER"]}/building_vm.log
        if [ $? -ne 0 ]; then
            echo -e "\e[31m\e[Build virtual machine failed\e[0m"
            echo "LOGS: ${config["LOG_FOLDER"]}"
            exit 1
        fi
    fi
    echo -e "\e[32m\tBuild virtual machine\t\t\e[1m[X]\e \e[0m"

    #Download repository
    echo -e "\e[33m\e[1m--> Cloning freebsd repository and creating a branch since the last commit in the version ${config[VERSION]}...\e[0m"
    if [ ! -d ~/repository ]; then
        mkdir ~/repository
    fi
    cd ~/repository
    if [ ! -d ~/repository/freebsd-src ]; then
        git clone git@github.com:${config["GIT_USER"]}/freebsd-src.git &>> ${config["LOG_FOLDER"]}/freebsd_repository.log
        if [ $? -ne 0 ]; then
            echo -e "\e[31m\e[Clone freebsd repository failed\e[0m"
            echo "LOGS: ${config["LOG_FOLDER"]}"
            exit 1
        fi
    fi
    echo -e "\e[32m\tRepository\t\t\t\e[1m[X]\e \e[0m"
    
    #Move to release tag
    cd freebsd-src
    if [[ -z $(git status | grep "freebsd_scheduler_develop") ]];then
        git checkout freebsd_scheduler_develop &>> ${config["LOG_FOLDER"]}/freebsd_repository.log
        if [ $? -ne 0 ]; then
            git checkout release/${config["VERSION"]}.0 &>> ${config["LOG_FOLDER"]}/freebsd_repository.log
            if [ $? -ne 0 ]; then
                echo -e "\e[31m\e[Move to release tag failed\e[0m"
                echo "LOGS: ${config["LOG_FOLDER"]}"
                exit 1
            fi
            git switch -c freebsd_scheduler_develop &>> ${config["LOG_FOLDER"]}/freebsd_repository.log
            if [ $? -ne 0 ]; then
                echo -e "\e[31m\e[Create develop branch failed\e[0m"
                echo "LOGS: ${config["LOG_FOLDER"]}"
                exit 1
            fi
        fi
    fi
    echo -e "\e[32m\tBranch to develop\t\t\e[1m[X]\e \e[0m"

    #Clean output
    if [[ -d "${config["HOME"]}/packer_cache" ]]; then
        rm -rf packer_cache
    fi
    if [[ -f "${config["HOME"]}/${config["PACKER_CONFIG"]}" ]]; then
        rm ${config["HOME"]}/${config["PACKER_CONFIG"]}
    fi
    echo -e "\e[32m\e[1mDevelopment environment ready to work!\e[0m"
}

main
