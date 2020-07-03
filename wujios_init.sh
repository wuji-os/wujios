#qm importdisk 107 faime-SAC4RT6E.qcow2
# 端口分配：
# 81 导航
# 82 rss
# 83 calibre
# 84 kode
# 85 bitwarden https
# 86 wordpress
# 88 wallabag https
# 89 wiznote
# transmission 9091
# funcInstallJellyfin 8096
# put into /etc/profile.d/

GITDIR=$(pwd)
export PATH=$PATH":/usr/sbin/:/sbin/:/usr/local/sbin"
localip=""
funcInit() {
    # dir prepiar
    mkdir -p /wujios/dockerapp
    mkdir -p /wujios/appdata
    mkdir -p /wujios/sysapp
}
funcCheckOsInit() {
    initDoneFile="/home/wwwroot/initpage/initDone"
    if [ ! -f "$initDoneFile" ]; then
        echo "Os not Init Done, begein init"
    else
        echo "Os  Init Done, begein init"
        exit 0
    fi
}

funcGenCa() { #  ok
    # ssl ca 下载证书
    mkdir -p /wujios/config/cacrt/
    cp $GITDIR/ca/* /wujios/config/cacrt/
}

fail_if_error() {
    [ $1 != 0 ] && {
        unset PASSPHRASE
        exit 10
    }
}

funcGenMyCa() {
    cd /wujios/config/cacrt/
    # Script accepts a single argument, the fqdn for the cert
    DOMAIN=$1
    if [ -z "$DOMAIN" ]; then
        echo "Usage: $(basename $0) <domain>"
        exit 11
    fi
    rm "$DOMAIN"*

    # Generate a passphrase
    export PASSPHRASE=$(
        head -c 500 /dev/urandom | tr -dc a-z0-9A-Z | head -c 128
        echo
    )
    # Certificate details; replace items in angle brackets with your own info
    subj="
C=CN
ST=Hubei
O=Wuji
localityName=YiChang
commonName=$DOMAIN
organizationalUnitName=WujiOs
emailAddress=wuji@jinyong.com
"

    # Generate the server private key
    openssl genrsa -des3 -out $DOMAIN.key -passout env:PASSPHRASE 2048
    fail_if_error $?

    # Generate the CSR
    openssl req \
        -new \
        -batch \
        -subj "$(echo -n "$subj" | tr "\n" "/")" \
        -key $DOMAIN.key \
        -out $DOMAIN.csr \
        -passin env:PASSPHRASE
    fail_if_error $?
    cp $DOMAIN.key $DOMAIN.key.org
    fail_if_error $?

    # Strip the password so we don't have to type it every time we restart Apache
    openssl rsa -in $DOMAIN.key.org -out $DOMAIN.key -passin env:PASSPHRASE
    fail_if_error $?

    # Generate the cert (good for 10 years)
    openssl x509 -req -days 3650 -in $DOMAIN.csr -signkey $DOMAIN.key -out $DOMAIN.crt
    fail_if_error $?

    #openssl dhparam -out dhparam.pem 2048
    mv $DOMAIN.crt clientpub.crt
    mv $DOMAIN.key server.key
    lnmp nginx restart
}
# 81 port daohang
# todo add daohang
funcInitSys() {
    # 提供设置页面
    chmod -R 777 /home/wwwroot/initpage
    # 读取配置信息
    localip=""
    initFile="/home/wwwroot/initpage/initInfo"
    while true; do
        if [ ! -f "$initFile" ]; then
            echo "wait user set password..."
            sleep 2s
        else
            # 开始更新密码
            newpass=$(cat $initFile | grep "password" | tail -n1 | awk -F '=' '{print $2}')
            echo -e "${newpass}\n${newpass}" | passwd yzz
            echo -e "${newpass}\n${newpass}" | passwd root
            # transimisson
            service transmission-daemon stop
            cp $GITDIR/configfile/transmission_config.json /etc/transmission-daemon/settings.json
            sed -i "s/123456/$newpass/g" /etc/transmission-daemon/settings.json
            service transmission-daemon start

            localip=$(cat $initFile | grep "host" | tail -n1 | awk -F '=' '{print $2}')
            break
        fi
    done
    # 配置系统 1、导航 2、证书 3、wallabag 4、nginx
    cd /home/wwwroot/index/
    sed -i "s/my.domain/$localip/g" index.html
    sed -i "s/initpage/index/g" /usr/local/nginx/conf/vhost/daohang.conf
    # 证书：
    funcGenMyCa $localip
    # 3、wallabag
    # 完成配置
    lnmp nginx restart
    mkdir -p /wujios/appdata/wallabag/data
    mkdir -p /wujios/appdata/wallabag/images
    docker run --name wallabag --restart=always -d -v /wujios/appdata/wallabag/data:/var/www/wallabag/data -v /wujios/appdata/wallabag/images:/var/www/wallabag/web/assets/images -p 88:80 -e SYMFONY__ENV__DOMAIN_NAME=http://$localip:88 wallabag/wallabag
    echo "1" >/home/wwwroot/initpage/initDone
}

funcInit
funcCheckOsInit
# need domain
funcInitSys
