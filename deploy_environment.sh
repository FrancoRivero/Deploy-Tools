#!/bin/bash
typeset -A config 
config=(
    [VERSION]="13.0"
    [ISO_NAME]="FreeBSD-${config[VERSION]}-RELEASE-amd64-dvd1.iso"
    [HOME]="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
    [PACKER_CONFIG_BASE]="freebsd_base.json"
    [PACKER_CONFIG]="freebsd.json"
)

detect_os_and_install_dependecies() {
    OS=$(hostnamectl | grep "Operating System:" )
    if [[ $(echo \"$OS\" | grep "Ubuntu") ]]; then
        ${config["HOME"]}/dependencies_installers/install_ubuntu_dependencies.sh
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
        ping -I $interface -c 1 www.google.com >/dev/null 2>&1
        cmd=$(echo $?)
        if [[ $cmd == 0 ]];then
            network_output=$interface
        fi
    done
}

main() {
    #Install dependecies
    detect_os_and_install_dependecies

    #Evaluate interfaces
    detect_network_connection

    #Create folder if it doesn't exist
    if [ ! -d ${config["HOME"]}/http ]; then
        mkdir -p ${config["HOME"]}/http
    fi

    #Get FreeBSD iso
    if [ ! -f ${config["HOME"]}/http/${config["ISO_NAME"]} ]; then
        iso_freebsd_path=$(sudo find /home -name "${config["ISO_NAME"]}" -print | head -n 1)
        if [[ "$iso_freebsd_path" == "" ]]; then
            wget https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/${config["VERSION"]}/${config["ISO_NAME"]}
        fi 
        mv $iso_freebsd_path ${config["HOME"]}/http/${config["ISO_NAME"]}
    fi

    #Evaluate path
    output_path=$(sudo find /home -type d -name "VirtualBox VMs")
    cp ${config["PACKER_CONFIG_BASE"]} ${config["PACKER_CONFIG"]}
    sed -i 's|ISO_NAME|'${config["ISO_NAME"]}'|g' ${config["PACKER_CONFIG"]}
    ISOSHA2=$(sha256sum ${config["HOME"]}/http/${config["ISO_NAME"]} | awk '{print $1}')
    sed -i 's|ISO_CHECKSUM|'$ISOSHA2'|g' ${config["PACKER_CONFIG"]}
    sed -i 's|NETWORK_INTERFACE|'$network_output'|g' ${config["PACKER_CONFIG"]}

    #Validate and build VM with Packer
    packer validate ${config["PACKER_CONFIG"]}
    retVal=$?
    if [ $retVal -ne 0 ]; then
        echo "Validation fails"
        exit $retVal
    fi

    packer build -var output_path="$output_path" ${config["PACKER_CONFIG"]}

    #Clean output
    if [[ -d "${config["HOME"]}/packer_cache" ]]; then
        rm -rf packer_cache
    fi

    if [[ -f "${config["PACKER_CONFIG"]}" ]]; then
        rm ${config["PACKER_CONFIG"]}
    fi
}

main
