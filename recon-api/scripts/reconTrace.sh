#!/bin/bash
# 	utility which passes all IPs in traceroute output to the Recon API
# 	Author: DJ Nelson

source ~/.bash_colors

HOST=$1

if [ $# -ne 1 ]; then
	echo "Usage: $0 <domain_or_ip_to_traceroute_to>"
	exit 1
fi

# run host against each hop on the way to the target
for ip in $(traceroute $HOST |awk '{ print $2 }' |grep -v 'to\|*'); do
	echo -e "Hostname: $BLUE $HOST $OFF"
	curl -s http://localhost:6301/ipv4/$ip |python -m json.tool
done
