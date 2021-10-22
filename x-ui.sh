#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Cannot run: ${plain} This script must be run as a root user！\n" && exit 1

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

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Do you want to restart the panel，restart the panel will also restart xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Press enter to return to the main menu: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/nxlong1103/x-ui-eng/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "This function will force reinstall the current latest version, the data will not be lost, you want to continue?" "n"
    if [[ $? != 0 ]]; then
        echo -e "${red}Canceled${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/nxlong1103/x-ui-eng/master/install.sh)
    if [[ $? == 0 ]]; then
        echo -e "${green}The update is complete and the panel has been automatically restarted${plain}"
        exit 0
    fi
}

uninstall() {
    confirm "Are you sure you want to uninstall the panel，xray will also uninstall?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf

    echo ""
    echo -e "The uninstallation was successful. If you want to delete this script, exit the script and run ${green}rm /usr/bin/x-ui -f${plain} 进行删除"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Are you sure you want to reset the admin username and password ?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo -e "Username and password have been reset to ${green}admin${plain}，please restart the panel"
    confirm_restart
}

reset_config() {
    confirm "Are you sure you want to reset all panel settings，account data will not be lost，username and password will not change" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "All console settings have been reset to default values, now please restart panel and use default values ${green}54321${plain} port access control panel"
    confirm_restart
}

set_port() {
    echo && echo -n -e "Enter the port number[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        echo -e "${yellow}Canceled${plain}"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "After setting up the port, please restart the panel and use the new port ${green}${port}${plain} 访问面板"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}The panel is already running, no need to reboot, if need to restart, please choose restart${plain}"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}x-ui started success${plain}"
        else
            echo -e "${red}Panel failed to start. Possibly due to the boot time exceeding two seconds. Please check the following log information.${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        echo -e "${green}Panel has stopped, no need to stop again${plain}"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            echo -e "${green}x-ui & xray stopped success${plain}"
        else
            echo -e "${red}Panel does not stop. Possibly due to the dwell time exceeding two seconds. Please check the following log information.${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}x-ui & xray restarted success${plain}"
    else
        echo -e "${red}Panel restart failed, possibly due to the boot time exceeding two seconds, please check the following log information${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}x-ui set auto power on successfully${plain}"
    else
        echo -e "${red}x-ui unable to set auto-start after power on${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}x-ui cancel auto power on success${plain}"
    else
        echo -e "${red}x-ui cancel auto power on failed${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/x-ui/x-ui v2-ui

    before_show_menu
}

install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://github.com/nxlong1103/x-ui-eng/raw/master/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Script could not be downloaded, please check if the machine can connect Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        echo -e "${green}Script upgrade success, please run the script again${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}The panel is already installed, please do not install it too many times${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Please install the panel first${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Panel status: ${green}Started${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Panel status: ${yellow}Not running${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Panel status: ${red}Not installed${plain}"
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Start after boot: ${green}Yes${plain}"
    else
        echo -e "Start after boot: ${red}No${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray status: ${green}Running${plain}"
    else
        echo -e "xray status: ${red}Not started${plain}"
    fi
}

show_usage() {
    echo "How to use x-ui management scripts: "
    echo "------------------------------------------"
    echo  "x-ui              - Display management menu (More functions)"
    echo  "x-ui start        - Launch the x-ui panel"
    echo  "x-ui stop         - Stop the x-ui panel"
    echo  "x-ui restart      - Restart the x-ui panel"
    echo  "x-ui status       - x-ui status"
    echo  "x-ui enable       - Set x-ui to start automatically after boot"
    echo  "x-ui disable      - Set x-ui to not start automatically after boot"
    echo  "x-ui log          - View x-ui log"
    echo  "x-ui v2-ui        - Migrate this machine's v2-ui account data to x-ui"
    echo  "x-ui update       - Update x-ui panel"
    echo  "x-ui install      - Install x-ui panel"
    echo  "x-ui uninstall    - Uninstall x-ui panel"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}x-ui Panel management script${plain}
  ${green}0.${plain} Exit script
————————————————
  ${green}1.${plain} Install x-ui
  ${green}2.${plain} Renew x-ui
  ${green}3.${plain} Uninstall x-ui
————————————————
  ${green}4.${plain} Reset username and password
  ${green}5.${plain} Reset the panel
  ${green}6.${plain} Reset the port
————————————————
  ${green}7.${plain} Start x-ui
  ${green}8.${plain} Stop x-ui
  ${green}9.${plain} Restart x-ui
 ${green}10.${plain} x-ui status
 ${green}11.${plain} x-ui log
————————————————
 ${green}12.${plain} Set x-ui to start automatically after boot
 ${green}13.${plain} Set x-ui to not start automatically after boot
————————————————
 ${green}14.${plain} One click install of bbr (new core)
 "
    show_status
    echo && read -p "Please enter options [0-14]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && reset_user
        ;;
        5) check_install && reset_config
        ;;
        6) check_install && set_port
        ;;
        7) check_install && start
        ;;
        8) check_install && stop
        ;;
        9) check_install && restart
        ;;
        10) check_install && status
        ;;
        11) check_install && show_log
        ;;
        12) check_install && enable
        ;;
        13) check_install && disable
        ;;
        14) install_bbr
        ;;
        *) echo -e "${red}Please enter the correct number [0-14]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "v2-ui") check_install 0 && migrate_v2_ui 0
        ;;
        "update") check_install 0 && update 0
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        *) show_usage
    esac
else
    show_menu
fi
