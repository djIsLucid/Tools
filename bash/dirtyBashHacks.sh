#!/bin/bash
# A quick and dirty script for figuring out where live URLs point to 
# I used this to see how many domain names discovered from amass intel -asn 714,6185,2709 -config ~/.config/amass/config.ini -o horizontal-domains.txt
# pointed back to apple.com (it was a lot)
# Once I ran that amass command I then passed the output to httprobe: cat horizontal-domains.txt |httprobe > live-urls.txt
# then ran this script against that file
# This could potentially be filled with a bunch of dirty bash hacks that get reused, so if you run in to more that you know you've done before
# add them here and implement some command-line argument handling

for url in $(cat $1); do
        echo "$url ->" $(curl -I -k --silent $url |grep "Location"| cut -d' ' -f2) &
done

