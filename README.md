# x-ui
Multi-protocol and multi-user xray console support

# Featured
- System status monitoring
- Support multi-user and multi-protocol, website visualization operation
- Protocols supported: vmess, vless, trojan, shadowsocks, dokodemo-door, socks, http
- Support to configure more transmission profiles
- Traffic statistics, traffic limit, expiration time limit
- Customizable xray configuration template
- Support https access control panel (bring your own domain name + ssl certificate)
- More advanced configuration items, see control panel for details

# Install & Upgrade
```
bash <(curl -Ls https://raw.githubusercontent.com/nxlong1103/x-ui-eng/master/install.sh)
```

## Manually install and upgrade
1. First download the latest zipped package from https://github.com/nxlong1103/x-ui-eng/releases, usually choose `amd64` architecture
2. Then upload the zipped package to the `/root/` directory of the server and use the user `root` to login to the server

> If your server cpu architecture is not `amd64`, replace `amd64` in the command with another architecture

```
cd /root/
rm x-ui/ /usr/local/x-ui/ /usr/bin/x-ui -rf
tar zxvf x-ui-linux-amd64.tar.gz
chmod +x x-ui/x-ui x-ui/bin/xray-linux-* x-ui/x-ui.sh
cp x-ui/x-ui.sh /usr/bin/x-ui
cp -f x-ui/x-ui.service /etc/systemd/system/
mv x-ui/ /usr/local/
systemctl daemon-reload
systemctl enable x-ui
systemctl restart x-ui
```

## Supported operating system:
- CentOS 7+
- Ubuntu 16+
- Debian 8+

# Common problems

## Migrate from v2-ui
First install the latest version of x-ui on the server where v2-ui is installed then use the following command to migrate which will move `all inbound account data` of the machine's v2-ui to x-ui, 'control panel settings and username and password Won't migrate`
> After successful migration, please `close v2-ui` and `restart x-ui`, otherwise v2-ui's inbound and x-ui's input will cause `port conflict' '
```
x-ui v2-ui
```
