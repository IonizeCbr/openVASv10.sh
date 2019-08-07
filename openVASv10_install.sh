#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
echo "[+] Preparing for openVAS v10 install"
cd /usr/local/src
sudo mkdir gvm10
sudo chown $USER:$USER gvm10
cd gvm10
echo "[+] Downloading"
wget -O gvm-libs-10.0.0.tar.gz https://github.com/greenbone/gvm-libs/archive/v10.0.0.tar.gz
wget -O openvas-scanner-6.0.0.tar.gz https://github.com/greenbone/openvas-scanner/archive/v6.0.0.tar.gz
wget -O gvmd-8.0.0.tar.gz https://github.com/greenbone/gvmd/archive/v8.0.0.tar.gz
wget -O gsa-8.0.0.tar.gz https://github.com/greenbone/gsa/archive/v8.0.0.tar.gz
wget -O openvas-smb-1.0.5.tar.gz https://github.com/greenbone/openvas-smb/archive/v1.0.5.tar.gz
wget -O ospd-1.3.2.tar.gz https://github.com/greenbone/ospd/archive/v1.3.2.tar.gz
echo "[+] Unpacking"
find . -name \*.gz -exec tar zxvfp {} \;
echo "[+] Becoming Root"
sudo apt install software-properties-common
echo "[+] Installing Requirements"
sudo add-apt-repository universe
sudo apt update
sudo apt install -y make cmake pkg-config libglib2.0-dev libgpgme11-dev uuid-dev libssh-gcrypt-dev libhiredis-dev \
gcc libgnutls28-dev libpcap-dev libgpgme-dev bison libksba-dev libsnmp-dev libgcrypt20-dev redis-server \
libsqlite3-dev libical-dev gnutls-bin doxygen nmap libmicrohttpd-dev libxml2-dev apt-transport-https curl \
xmltoman xsltproc gcc-mingw-w64 perl-base heimdal-dev libpopt-dev graphviz nodejs rpm nsis wget sshpass \
socat snmp gettext python-polib git
echo "[+] Installing gvm-libs"
cd gvm-libs-10.0.0
sudo mkdir build
cd build
sudo cmake ..
sudo make
sudo make doc-full
sudo make install
cd /usr/local/src/gvm10/openvas-smb-1.0.5
echo "[+] Configuring and building openvas-smb"
sudo mkdir build
cd build/
sudo cmake ..
sudo make
sudo make install
echo "[+] Configuring and building scanner"
cd /usr/local/src/gvm10/openvas-6.0.0
sudo mkdir build
cd build/
sudo cmake ..
sudo make
sudo make doc-full
sudo make install
cd /usr/local/src/gvm10
echo "[+] Configuring openvas v10"
sudo cp /etc/redis/redis.conf /etc/redis/redis.orig
sudo cp /usr/local/src/gvm10/openvas-scanner-6.0.0/build/doc/redis_config_examples/redis_4_0.conf /etc/redis/redis.conf
sudo sed -i 's|/usr/local/var/run/openvas-redis.pid|/var/run/redis/redis-server.pid|g' /etc/redis/redis.conf
sudo sed -i 's|/tmp/redis.sock|/var/run/redis/redis-server.sock|g' /etc/redis/redis.conf
sudo sed -i 's|dir ./|dir /var/lib/redis|g' /etc/redis/redis.conf
sudo sysctl -w net.core.somaxconn=1024
sudo sysctl vm.overcommit_memory=1
echo "[+] Disabling Transparent Huge Pages (THP)"
sudo cat << EOF > /etc/systemd/system/disable-thp.service
[Unit]
Description=Disable Transparent Huge Pages (THP)

[Service]
Type=simple
ExecStart=/bin/sh -c "echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled && echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag"

[Install]
WantedBy=multi-user.target
EOF
echo "[+] Starting services"
sudo systemctl daemon-reload
sudo systemctl start disable-thp
sudo systemctl enable disable-thp
sudo systemctl restart redis-server
echo "[+] Setting up Networking"
sudo cat << EOF > /usr/local/etc/openvas/openvassd.conf
db_address = /var/run/redis/redis-server.sock
EOF
echo "[+] Updating Signatures"
sudo greenbone-nvt-sync
echo "[+] Reloading Modules"
sudo ldconfig
echo "[+] Starting openvas daemon"
sudo openvassd
echo "[+] Configure and build openVAS Manager"
cd /usr/local/src/gvm10/gvmd-8.0.0
sudo mkdir build
cd build/
sudo cmake ..
sudo make
sudo make doc-full
sudo make install
cd /usr/local/src/gvm10/gsa-8.0.0
echo "[+] Configure and install gsa"
sudo curl --silent --show-error https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo sudo apt-get update
sudo sudo apt-get install yarn
sudo sed -i 's/#ifdef GIT_REV_AVAILABLE/#ifdef GIT_REVISION/g' ./gsad/src/gsad.c
sudo sed -i 's/return root.get_result.commands_response.get_results_response.result/return root.get_result.get_results_response.result/g' ./gsa/src/gmp/commands/results.js
sudo mkdir build
cd build/
sudo cmake ..
sudo make
sudo make doc-full
sudo make install
cd /usr/local/src/gvm10
echo "[+] Setup Certs"
sudo gvm-manage-certs -a
echo "[+] Create Admin User"
sudo gvmd --create-user=admin
echo "[+] Start openVAS v10"
sudo gvmd
sudo openvassd
sudo gsad
echo "[+] Checking openVAS is running"
if [[ $(ps -aux | grep 'openvas'| wc -l) = *4* ]]
then
    echo -e "${GREEN}[+] openVAS Running!${NC}"
else
    echo -e "${RED}[-] FAIL openVAS not Running check errors above...${NC}"
    exit
fi
echo -e "${GREEN}[+] Installation is Complete!!!${NC}"
echo -e "${YELLOW}[INFO] Please change default username:password admin:admin @ https://" + $IP + ":4000${NC}"