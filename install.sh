#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Cannot run：${plain} This script must be run as a root user！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}System version not detected, please contact script author！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64"
else
  arch="amd64"
  echo -e "${red}No architecture detected, use default architecture: ${arch}${plain}"
fi

echo "Construct: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ] ; then
    echo "This software does not support 32-bit (x86) systems，please use 64 bit system (x86_64)，if found wrong, please contact the author"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or higher system！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or higher system！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or higher system！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/nxlong1103/x-ui-eng/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}x-ui version not detected，it may exceed the Github API limit，Please try again later or specify the x-ui version to install manually${plain}"
            exit 1
        fi
        echo -e "Detected the latest version of x-ui：${last_version}，start installation"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/nxlong1103/x-ui-eng/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}x-ui download failed，Make sure your server can download the Github file${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/nxlong1103/x-ui-eng/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "Start installing x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Downloading x-ui v$1 failed，make sure this version exists${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/nxlong1103/x-ui-eng/master/x-ui.sh
    chmod +x /usr/bin/x-ui
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} The installation is complete and the control panel has started，"
    echo -e ""
    echo -e "If it's a first installation, the default web port is: ${green}54321${plain}，the default username and password are: ${green}admin${plain}"
    echo -e "Make sure this port is not used by other programs，${yellow}and make sure port 54321 is opened${plain}"
#    echo -e "If you want to change 54321 to another port， use command x-ui to change，also make sure the port you change to is also opened"
    echo -e ""
    echo -e "If it's an update board, access the dashboard as you did before"
    echo -e ""
    echo -e "How to use x-ui management scripts: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Display management menu (More functions)"
    echo -e "x-ui start        - Launch the x-ui panel"
    echo -e "x-ui stop         - Stop the x-ui panel"
    echo -e "x-ui restart      - Restart the x-ui panel"
    echo -e "x-ui status       - x-ui status"
    echo -e "x-ui enable       - Set x-ui to start automatically after boot"
    echo -e "x-ui disable      - Set x-ui to not start automatically after boot"
    echo -e "x-ui log          - View x-ui log"
    echo -e "x-ui v2-ui        - Migrate this machine's v2-ui account data to x-ui"
    echo -e "x-ui update       - Update x-ui panel"
    echo -e "x-ui install      - Install x-ui panel"
    echo -e "x-ui uninstall    - Uninstall x-ui panel"
    echo -e "----------------------------------------------"
}

echo -e "${green}Start installation${plain}"
install_base
install_x-ui $1
