#!/bin/bash

HOMEPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
read -p "Enter version of FreeBSD: " VERSION
ISO_NAME="FreeBSD-$VERSION-RELEASE-amd64-dvd1.iso"
packerConfig=freebsd_base.json
packerConfig_AUX=freebsd.json

detect_os_and_install_dependecies() {
    OS=$(hostnamectl | grep "Operating System:" )
    if [[ $(echo \"$OS\" | grep "Ubuntu") ]]; then
        $HOMEPATH/dependencies_installers/install_ubuntu_dependencies.sh
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

main() {
    #Install dependecies
    detect_os_and_install_dependecies

    #Create folder if it doesn't exist
    if [ ! -d $HOMEPATH/http ]; then
        mkdir -p $HOMEPATH/http
    fi

    #Get FreeBSD iso
    if [ ! -f $HOMEPATH/http/$ISO_NAME ]; then
        iso_freebsd_path=$(sudo find / -name "$ISO_NAME" -print | head -n 1)
        if [[ "$iso_freebsd_path" == "" ]]; then
            wget https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/$VERSION/$ISO_NAME
        else
            mv $iso_freebsd_path $HOMEPATH/http/$ISO_NAME
        fi
    fi

    #Evaluate path
    output_path=$(sudo find / -type d -name "VirtualBox VMs")

    cp $packerConfig $packerConfig_AUX
    sed -i 's|ISO_NAME|'$ISO_NAME'|g' $packerConfig_AUX
    ISOSHA2=$(sha256sum $HOMEPATH/http/$ISO_NAME | awk '{print $1}')
    sed -i 's|ISO_CHECKSUM|'$ISOSHA2'|g' $packerConfig_AUX

    #Validate and build VM with Packer
    packer validate $packerConfig_AUX
    retVal=$?
    if [ $retVal -ne 0 ]; then
        echo "Validation fails"
        exit $retVal
    fi

    packer build -var output_path="$output_path" $packerConfig_AUX

    #Clean output
    if [[ -d "$HOMEPATH/packer_cache" ]]; then
        rm -rf packer_cache
    fi

    if [[ -f "$packerConfig_AUX" ]]; then
        rm $packerConfig_AUX
    fi
}

main