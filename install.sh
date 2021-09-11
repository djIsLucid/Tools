#!/bin/bash
## installs custom hacking environment in Ubuntu-based systems

#### Add bettercap install

USER=$1
TOOLS_DIR=/opt/tools
EXE_DIR=/usr/local/bin
PACKAGES="
nodejs screen git build-essential make jq ruby python3 python3-pip 
nmap wget wfuzz traceroute net-tools dnsutils masscan aircrack-ng 
postgresql apache2 mariadb-server php patch ruby-dev 
zlib1g-dev liblzma-dev
"

if [ -z "$1" ]; then
	echo "You must specify a user! ./install.sh <username>"
	exit 1
fi

## Getting started
#
apt update -y 
apt install $PACKAGES
apt upgrade
gem install optimist open-uri colorize httparty nokogiri json
cp /home/$USER/Tools/bash/.bash_aliases ~/
cp /home/$USER/Tools/bash/.bash_colors ~/
echo "export RESOLVERS=/home/$USER/Tools/wordlists/DNS/resolvers-small.txt" >> ~/.profile
ln -s /home/$USER/Tools/reconParse.rb ~/Tools/bin/reconParse && chmod +x ~/Tools/bin/reconParse
mkdir /home/$USER/Targets
mkdir -p /opt/tools

## Configure Golang
#
which go
if [ $? -eq 1 ]; then
	# set up golang properly	
	# So if ARM is specified: wget https://golang.org/dl/$GOARM
	cat /etc/issue |grep Raspbian
	if [ $? -eq 1]; then
		export GOFLAVOR="curl -s https://golang.org/dl/|grep tar.gz|grep amd64|head -1|awk -F "/dl/" '{print $2}'|awk -F "\">" '{print $1}'"
	else
		export GOFLAVOR="curl -s https://golang.org/dl/|grep tar.gz|grep armv6l|head -1|awk -F "/dl/" '{print $2}'|awk -F "\">" '{print $1}'"
	fi
	wget https://golang.org/dl/$GOFLAVOR
	tar -C /usr/local -xzf $GOFLAVOR
	unset GOFLAVOR
	mkdir -p /home/$USER/Development/go/src/github.com && chown -R $USER.$USER ~/Development/go
	echo "export GOPATH=/home/$USER/Development/go" >> ~/.profile
	echo "export PATH=$PATH:/usr/local/go/bin:/home/$USER/Development/go/bin:$HOME/Tools/bin" >> /home/$USER/.profile
fi

source /home/$USER/.profile

## Install Amass
#
cd $GOPATH/src/github.com
export GO111MODULE=on
go get -v github.com/OWASP/Amass/v3/...
cd $GOPATH/src/github.com/OWASP/Amass
go install ./...

## Install github tools
#
go get -v github.com/tomnomnom/httprobe
go get -v github.com/tomnomnom/waybackurls
go get -v github.com/famasoon/crtsh
go get -u github.com/ffuf/ffuf

## Install dirsearch
#
#cd /home/$USER/Tools && git clone https://github.com/maurosoria/dirsearch.git
cd $TOOLS_DIR && git clone https://github.com/maurosoria/dirsearch.git
#cd dirsearch && ln -s /home/$USER/Tools/dirsearch/dirsearch.py ~/Tools/bin/dirsearch && chmod +x ~/Tools/bin/dirsearch
cd dirsearch && ln -s $TOOLS_DIR/dirsearch/dirsearch.py $EXE_DIR/dirsearch && chmod +x $EXE_DIR/dirsearch

## Install massdns
#
#cd /home/$USER/Tools && git clone https://github.com/blechschmidt/massdns
cd $TOOLS_DIR && git clone https://github.com/blechschmidt/massdns
cd massdns && make
#ln -s /home/$USER/Tools/massdns/bin/massdns ~/Tools/bin/massdns && chmod ~/Tools/bin/massdns
ln -s $TOOLS_DIR/massdns/bin/massdns $EXE_DIR/massdns && chmod $EXE_DIR/massdns

## Configure reconApi
#
cd /home/$USER/Tools/recon-api && npm install
cp reconapi.service /etc/systemd/system/
systemctl enable reconapi.service
ln -s /home/$USER/Tools/recon-api/scripts/reconApi.rb ~/Tools/bin/reconApi && chmod +x ~/Tools/bin/reconApi

## Configure backup script
#
ln -s /home/$USER/Tools/backup ~/Tools/bin/backup && chmod +x ~/Tools/bin/backup
mkdir -p /home/$USER/.config/backup

# This only happens if you specify the -b <backup_name> flag
printf "Do you want to initiate a new scheduled backup configuration? [y/n]: "
read input

if [ $input == 'y' ]; then
	printf "Backup name: "
	read input2
	backup init $input2
	echo "export CURRENT_BACKUP=/home/$USER/.config/backup/$input2.json" >> /home/$USER/.profile
	source /home/$USER/.profile
fi

# Finishing touches
echo "Install finished. Don't forget to reboot!"

