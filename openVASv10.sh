#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
echo "[+] Preparing for openVAS v10 install"
cd ~
mkdir gvm10
chown $USER:$USER gvm10
cd gvm10
echo "[+] Update and Upgrade"
sudo apt update
sudo apt upgrade -y
echo "[+] Installing Latest nmap"
sudo snap install nmap 
echo "[+] Installing Requirements"
sudo apt install -y bison cmake gcc gcc-mingw-w64 heimdal-dev libgcrypt20-dev libglib2.0-dev libgnutls28-dev libgpgme-dev libhiredis-dev libksba-dev libmicrohttpd-dev git libpcap-dev libpopt-dev libsnmp-dev libsqlite3-dev libssh-gcrypt-dev xmltoman libxml2-dev perl-base pkg-config python3-paramiko python3-setuptools uuid-dev curl redis doxygen libical-dev python-polib gnutls-bin
echo "[+] Installing Yarn Javascript"
sudo curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
sudo echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt update
sudo apt install yarn -y
echo "[+] Downloading All GreenBone openVAS Source"
wget https://github.com/greenbone/gvm-libs/archive/v10.0.1.tar.gz -O gvm-libs-v10.0.1.tar.gz
wget https://github.com/greenbone/openvas/archive/v6.0.1.tar.gz -O openvas-scanner-v6.0.1.tar.gz
wget https://github.com/greenbone/gvmd/archive/v8.0.1.tar.gz -O gvm-v8.0.1.tar.gz
wget https://github.com/greenbone/gsa/archive/v8.0.1.tar.gz -O gsa-v8.0.1.tar.gz
wget https://github.com/greenbone/ospd/archive/v1.3.2.tar.gz -O ospd-v1.3.2.tar.gz
wget https://github.com/greenbone/openvas-smb/archive/v1.0.5.tar.gz -O openvas-smb-v1.0.5.tar.gz
echo "[+] Unpacking"
for i in *.tar.gz; do tar xzf $i; done
echo "[+] Build and Install GVM Libraries"
cd ~/gvm10/gvm-libs-10.0.1/
mkdir build
cd build/
cmake ..
make
sudo make install
echo "[+] Build and Install OpenVAS SMB"
cd ~/gvm10/openvas-smb-1.0.5
mkdir build
cd build
cmake ..
make
sudo make install
echo "[+] Build and Install OSPd"
cd ~/gvm10/ospd-1.3.2
sudo python3 setup.py install
echo "[+] Build and Install OpenVAS Scanner"
cd ~/gvm10/openvas-6.0.1/
mkdir build
cd build
cmake ..
make
sudo make install
echo "[+] Configure Redis Server"
echo "net.core.somaxconn = 1024" | sudo tee -a /etc/sysctl.conf
echo "vm.overcommit_memory = 1" | sudo tee -a /etc/sysctl.conf
echo "[+] Disabling Transparent Huge Pages (THP)"
sudo tee -a /etc/systemd/system/disable-thp.service > /dev/null << EOL
[Unit]
Description=Disable Transparent Huge Pages (THP)

[Service]
Type=simple
ExecStart=/bin/sh -c "echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled && echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag"

[Install]
WantedBy=multi-user.target
EOL
echo "[+] Reload systemd configurations"
sudo systemctl daemon-reload
echo "[+] Start and enable THP service to run on system boot"
sudo systemctl start disable-thp
sudo systemctl enable disable-thp
echo "[+] Backup and copy Redis config"
sudo mv /etc/redis/redis.conf /etc/redis/redis.conf.bak
sudo cp ~/gvm10/openvas-6.0.1/build/doc/redis_config_examples/redis_4_0.conf  /etc/redis/redis.conf
echo "[+] Adjust Redis Config"
sudo tee -a /etc/redis/redis.conf > /dev/null << EOF
dir /var/lib/redis
unixsocket /var/run/redis/redis-server.sock
pidfile /var/run/redis/redis-server.pid
EOF
echo "[+] Adjust openVAS Config"
echo "db_address = /var/run/redis/redis-server.sock" | sudo tee -a /usr/local/etc/openvas/openvassd.conf
echo "[+] Reload sysctl variables created above"
sudo ysctl -p
echo "[+] Restart Redis Server"
sudo systemctl restart redis-server
echo "[+] Update openVAS NVTs"
sudo greenbone-nvt-sync
echo "[+] Reload kernel Modules & Start openVAS v10"
sudo ldconfig && sudo openvassd
echo "[+] Checking openVAS is running"
if [[ $(ps -aux | grep 'openvas'| wc -l) = *2* ]]
then
    echo -e "${GREEN}[+] openVAS Running!${NC}"
else
    echo -e "${RED}[-] FAIL openVAS not Running check errors above...${NC}"
    exit
fi
echo "[+] Build and Install GVM"
cd ~/gvm10/gvmd-8.0.1/
mkdir build
cd build
cmake ..
make
sudo make install
echo "[+] Build and Install GSA"
cd ~/gvm10/gsa-8.0.1
mkdir build
cd build
cmake ..
make
sudo make install
echo "[+] Update Feed"
sudo greenbone-certdata-sync
sudo greenbone-scapdata-sync
echo "[+] Create Certs"
sudo gvm-manage-certs -a
echo "[+] Create Admin User"
sudo gvmd --create-user openvasadmin #User created with password 'e3b43b14-4a22-446f-a90a-e2731be36f72'
echo "[+] Start OpenVAS Scanner GSA and GVM"
openvassd && gvmd && gsad
echo "[+] Checking openVAS, Scanner, GSA and GSM are running"
if [[ $(ps aux | grep -E "openvassd|gsad|gvmd" | grep -v grep | wc -l) > *4* ]]
then
    echo -e "${GREEN}[+] Everything now Running!${NC}"
else
    echo -e "${RED}[-] FAIL somethign is not Running correctly please check errors above...${NC}"
    exit
fi
echo -e "${GREEN}[+] Installation is Complete!!!${NC}"
IP=`curl ifconfig.co`
echo -e "${YELLOW}[INFO] Please login at @ https://" + $IP + "${NC} with openvasadmin and the password generated above."
