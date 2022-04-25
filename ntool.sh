#!/bin/bash


# 判断是否是CentOS 还是Ubuntu
release="unknown"

if [ -f /etc/redhat-release ]; then
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
    release="unknown"
fi
# 检查是否已经安装了letsencrypt


if [ "$release" == "centos" ]; then
    if [ -f "/usr/bin/certbot" ]; then
        echo "已经安装了letsencrypt"
        exit 0
    fi
    yum install -y certbot
elif [ "$release" == "debian" ]; then
    if [ -f "/usr/bin/certbot" ]; then
        echo "已经安装了letsencrypt"
        exit 0
    fi
    apt-get install -y certbot
elif [ "$release" == "ubuntu" ]; then
    if [ -f "/usr/bin/certbot" ]; then
        echo "已经安装了letsencrypt"
        exit 0
    fi
    apt-get install -y certbot
else
    echo "不支持的系统"
    exit 1
fi

# 如果是CentOS 则使用CentOS 安装letsencrypt
if [ "$release" == "centos" ]; then
    yum install -y epel-release
    yum install -y python-certbot-nginx
    certbot --nginx
else
    apt-get update
    apt-get install -y python-certbot-nginx
    certbot --nginx
fi

# 检查是否安装了nginx
if [ -f "/usr/sbin/nginx" ]; then
    echo "已经安装了nginx"
    exit 0
fi
# 如果没有安装nginx 则安装nginx
if [ "$release" == "centos" ]; then
    yum install deltarpm -y
    yum install -y redhat-lsb
    osrelease=$(lsb_release -rs|awk -F'.' '{print $1}')
    cat >/etc/yum.repos.d/nginx.repo<<EOF
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/$osrelease/\$basearch/
gpgcheck=0
enabled=1
EOF
    yum install -y nginx
elif [ "$release" == "debian" ]; then
    sudo apt install curl gnupg2 ca-certificates lsb-release -y
    echo "deb http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
    echo "deb http://nginx.org/packages/mainline/ubuntu `lsb_release -cs` nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
    curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo apt-key add -
    sudo apt-key fingerprint ABF5BD827BD9BF62
    sudo apt update
    apt-get install -y nginx
elif [ "$release" == "ubuntu" ]; then
    sudo apt install curl gnupg2 ca-certificates lsb-release -y
    echo "deb http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
    echo "deb http://nginx.org/packages/mainline/ubuntu `lsb_release -cs` nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
    curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo apt-key add -
    sudo apt-key fingerprint ABF5BD827BD9BF62
    sudo apt update
    apt-get install -y nginx
else
    echo "不支持的系统"
    exit 1
fi

# 开始读取输入的域名
echo "请输入域名"
read domain

echo "请输入附加域名，如果没有则留空"
read add_domain

# 开始读取域名对应的文件路径
echo "请输入域名对应的文件路径"
read filepath

# 检查目录是否存在，如果不存在则创建
if [ ! -d "/home/www/$filepath" ]; then
    mkdir -p /home/www/$filepath
fi


# 将前面输入的域名写入nginx配置文件中，配置文件以域名的第一个域名为文件名
echo "server {
    listen 80;
    server_name $domain $add_domain;
    location / {
        root /home/www/$filepath;
        index index.html index.htm index.nginx-debian.html index.php default.php;
    }
}" > /etc/nginx/conf.d/$domain.conf

# 开始使用letsencrypt生成证书
certbot certonly --webroot -w /home/www/$domain --agree-tos -m admin@rffan.com -d $domain -d $add_domain

# 将生成好的证书形成新的配置文件写入到此前的域名配置文件中
echo "server {
    listen 80;
    listen 443;
    server_name $domain $add_domain;
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    ssl_session_timeout 5m;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers \"TLS13-AES-256-GCM-SHA384:TLS13-CHACHA20-POLY1305-SHA256:TLS13-AES-128-GCM-SHA256:TLS13-AES-128-CCM-8-SHA256:TLS13-AES-128-CCM-SHA256:EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+AES128:RSA+AES128:EECDH+AES256:RSA+AES256:EECDH+3DES:RSA+3DES:!MD5\";
    ssl_session_cache builtin:1000 shared:SSL:10m;
    location / {
        root $filepath;
        index index.html index.htm index.nginx-debian.html index.php default.php;
    }
}" > /etc/nginx/conf.d/$domain.conf

nginx -t
nginx -s relod










