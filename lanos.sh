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

GITDIR=$(pwd)
export PATH=$PATH":/usr/sbin/:/sbin/:/usr/local/sbin"
localip=""
funcInit() {
    # dir prepiar
    mkdir -p /wujios/dockerapp
    mkdir -p /wujios/appdata
    mkdir -p /wujios/sysapp
}

funcUpdateSource() {
    cat >/etc/apt/sources.list <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ buster main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-updates main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-updates main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-backports main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-backports main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security buster/updates main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security buster/updates main contrib non-free
EOF
    apt update && apt upgrade -y
    apt install -y zip unzip
}

funcInstallDocker() {
    # docker ce
    apt-get -y install apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/debian/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/debian  buster stable"
    sudo apt-get -y update
    sudo apt-get -y install docker-ce
    cat >/etc/docker/daemon.json <<EOF
{
    "registry-mirrors": [
        "https://registry.docker-cn.com"
    ]
}
EOF
    systemctl restart docker
    # portainer ok
    docker pull portainer/portainer
    mkdir -p /wujios/appdata/portainer/data
    sudo docker run -d -p 9000:9000 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v /wujios/appdata/portainer/data:/data portainer/portainer
    docker pull wallabag/wallabag &
}
funcGenCa() { #  ok
    # ssl ca 下载证书
    mkdir -p /wujios/config/cacrt/
    cp $GITDIR/ca/* /wujios/config/cacrt/
}

# lnmp ok
funcInstallLnmp() {
    lnmpStatusNum=$(lnmp status | grep "is run" | grep "ing" | wc -l)
    if [ $lnmpStatusNum -eq 2 ]; then
        echo "install lnmp done and success..."
        return
    fi
    cd /wujios/sysapp
    wget http://soft.vpser.net/lnmp/lnmp1.7.tar.gz -cO lnmp1.7.tar.gz && tar zxf lnmp1.7.tar.gz && cd lnmp1.7
    sed -i "s/'n'/'y'/g" lnmp.conf
    #sed -i "s/Nginx_Modules_Options=''/Nginx_Modules_Options='--with-http_dav_module --with-http_realip_module'/g" lnmp.conf
    #sed -i "s/PHP_Modules_Options=''/Nginx_Modules_Options='--with-http_dav_module --with-http_realip_module'/g" lnmp.conf

    echo 'export PATH=$PATH":/usr/sbin/:/sbin/:/usr/local/sbin"' >backinstall.sh
    echo 'LNMP_Auto="y" DBSelect="10" DB_Root_Password="12345678" InstallInnodb="y" PHPSelect="10" SelectMalloc="2" ./install.sh lnmp' >>backinstall.sh
    nohup sh backinstall.sh &
    #sh backinstall.sh >>lnmpinstall.log
    # lnmp status | grep "is run" | grep "ing" | wc -l
    while true; do
        installNum=$(ps aux | grep backinstall | grep -v "grep" | wc -l)
        if [ $installNum -eq 1 ]; then
            echo "install lnmp ing..."
            sleep 20s
        fi
        if [ $installNum -eq 0 ]; then
            lnmpStatusNum=$(lnmp status | grep "is run" | grep "ing" | wc -l)
            if [ $lnmpStatusNum -eq 2 ]; then
                echo "install lnmp done and success..."
                break
            else
                echo "install lnmp done and sim not success..."
                exit 1
            fi
        fi
    done
}

funcUpdatesshd() {
    # sshd ok
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    service sshd restart
}

funcInstallWordPress() {
    # wordpress ok  port 81 todo sqlite
    cd /wujios/appdata
    mkdir -p /home/wwwlogs/
    wget https://wordpress.org/latest.zip
    unzip latest.zip -d /home/wwwroot/
    chmod -Rf 777 /home/wwwroot/
    cp $GITDIR/configfile/wp_nginx.conf /usr/local/nginx/conf/vhost/wordpress.conf
    lnmp nginx restart
}

funcInstallTransmission() {
    # transmission ok
    apt-get install -y transmission-daemon
    service transmission-daemon stop
    cp $GITDIR/configfile/transmission_config.json /etc/transmission-daemon/settings.json
    service transmission-daemon start
}

funcInstallJellyfin() {
    # jellyfin ok
    sudo apt install -y apt-transport-https
    wget -O - https://repo.jellyfin.org/jellyfin_team.gpg.key | sudo apt-key add -
    echo "deb [arch=$(dpkg --print-architecture)] https://repo.jellyfin.org/$(awk -F'=' '/^ID=/{ print $NF }' /etc/os-release) $(awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release) main" | sudo tee /etc/apt/sources.list.d/jellyfin.list
    sudo apt update
    sudo apt install -y jellyfin
    sudo service jellyfin restart
}

funcInstallkode() {
    # kedocloud port 82 ok
    wget http://static.kodcloud.com/update/download/kodbox.1.09.zip
    unzip kodbox.1.09.zip -d /home/wwwroot/kode/
    chmod -Rf 777 /home/wwwroot/kode/
    sed -i 's/shell_exec,//g' /usr/local/php/etc/php.ini
    sed -i 's/exec,//g' /usr/local/php/etc/php.ini
    sed -i 's/fix_pathinfo=0/fix_pathinfo=1/g' /usr/local/php/etc/php.ini
    cp $GITDIR/configfile/kode_nginx.conf /usr/local/nginx/conf/vhost/kode_nginx.conf
    echo "open_basedir=/home/wwwroot/:/tmp/:/proc/" >/home/wwwroot/kode/.user.ini
    chattr +i /home/wwwroot/kode/.user.ini
    lnmp php-fpm restart
    lnmp nginx restart
}
funcInstallRss() {
    # tinyrss + fever api + theme
    wget -O ttrss.zip https://git.tt-rss.org/fox/tt-rss/archive/master.zip
    unzip ttrss.zip -d /home/wwwroot/
    chmod -Rf 777 /home/wwwroot/
    cp $GITDIR/configfile/ttrss.conf /usr/local/nginx/conf/vhost/ttrss.conf
    lnmp nginx restart
    #  add crontab
    crontab -l | {
        cat
        echo "*/30 * * * * cd /home/wwwroot/tt-rss;sudo -u www php update.php --feeds > /dev/null 2>&1"
    } | crontab -
    # rsshub : use docker  ok todo restart always
    docker run -d --name rsshub --restart=always -p 1200:1200 diygod/rsshub
    docker run -d --name mercury --restart=always -p 3000:3000 -d wangqiru/mercury-parser-api
}
funcInstallBitwardenrs() {
    # bitwardenrs
    mkdir -p /wujios/appdata/bitwardenrs
    docker run -d --name bitwarden --restart=always -e SIGNUPS_ALLOWED=false -v /wujios/appdata/bitwardenrs/:/data/ -p 10085:80 bitwardenrs/server:latest
    cp $GITDIR/configfile/bitwarden.conf /usr/local/nginx/conf/vhost/bitwarden.conf
    lnmp nginx restart
}

funcInstallCalibre() {
    # bitwardenrs
    mkdir -p /wujios/appdata/Calibre
    docker run -d --name=calibre --restart=always -p 83:8083 -v /wujios/appdata/Calibre/config:/config -v /wujios/appdata/Calibre/books:/books technosoft2000/calibre-web
    # todo nginx 转发
}

funcInstallWallabag() {
    if [ $localip"x" == "x" ]; then
        echo "ip get error not install "
        return
    fi
    mkdir -p /wujios/appdata/wallabag/data
    mkdir -p /wujios/appdata/wallabag/images
    # docker run --restart=always -d -v /wujios/appdata/wallabag/data:/var/www/wallabag/data -v /wujios/appdata/wallabag/images:/var/www/wallabag/web/assets/images -p 88:80 -e SYMFONY__ENV__DOMAIN_NAME=http://my.domain:88 wallabag/wallabag
    # add https
    #cp $GITDIR/configfile/wallabag.conf /usr/local/nginx/conf/vhost/wallabag.conf
    #lnmp nginx restart
}

funcInstallWizNote() {
    mkdir -p /wujios/appdata/wizdata/
    docker run --restart=always --name wiz -it -d -e SEARCH=false -v /wujios/appdata/wizdata/:/wiz/storage -v /etc/localtime:/etc/localtime -p 89:80 -p 9269:9269/udp wiznote/wizserver
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
}

funcPrepairWeb() {
    funcGenCa
    # init page
    rm -r /home/wwwroot/initpage
    rm -r /home/wwwroot/index
    cp $GITDIR/configfile/daohang.conf /usr/local/nginx/conf/vhost/
    cp -r $GITDIR/ui/initpage /home/wwwroot/
    cp -r $GITDIR/ui/index /home/wwwroot/
    chmod -R 777 /home/wwwroot/
    lnmp nginx restart
}

funcInit
funcUpdateSource
funcInstallDocker
funcInstallLnmp
funcPrepairWeb
funcUpdatesshd
funcInstallWordPress
funcInstallTransmission
#funcInstallJellyfin
funcInstallkode
funcInstallRss
funcInstallBitwardenrs
funcInstallCalibre
funcInstallWizNote
# need domain
funcInitSys
#funcInstallWallabag
