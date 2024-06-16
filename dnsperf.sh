#!/usr/bin/env bash

# Check for required commands
command -v bc > /dev/null || { echo "error: bc was not found. Please install bc."; exit 1; }
{ command -v drill > /dev/null && dig=drill; } || { command -v dig > /dev/null && dig=dig; } || { echo "error: dig was not found. Please install dnsutils."; exit 1; }

# Get nameservers from resolv.conf
NAMESERVERS=$(cat /etc/resolv.conf | grep ^nameserver | cut -d " " -f 2 | sed 's/\(.*\)/&#&/')

PROVIDERSV4="
127.0.0.1#pihole
1.1.1.1#cloudflare 
4.2.2.1#level3 
8.8.8.8#google 
9.9.9.9#quad9 
80.80.80.80#freenom 
208.67.222.123#opendns 
199.85.126.20#norton 
185.228.168.168#cleanbrowsing 
8.26.56.26#comodo
45.90.28.202#nextdns
"

PROVIDERSV6="
2606:4700:4700::1111#cloudflare-v6
2001:4860:4860::8888#google-v6
2620:fe::fe#quad9-v6
2620:119:35::35#opendns-v6
2a0d:2a00:1::1#cleanbrowsing-v6
2a02:6b8::feed:0ff#yandex-v6
2a00:5a60::ad1:0ff#adguard-v6
2610:a1:1018::3#neustar-v6
"

# Check for IPv6 support
$dig +short +tries=1 +time=2 +stats @2a0d:2a00:1::1 www.google.com |grep 216.239.38.120 >/dev/null 2>&1
if [ $? = 0 ]; then
    hasipv6="true"
fi

providerstotest=$PROVIDERSV4

if [ "x$1" = "xipv6" ]; then
    if [ "x$hasipv6" = "x" ]; then
        echo "error: IPv6 support not found. Unable to do the ipv6 test."; exit 1;
    fi
    providerstotest=$PROVIDERSV6

elif [ "x$1" = "xipv4" ]; then
    providerstotest=$PROVIDERSV4

elif [ "x$1" = "xall" ]; then
    if [ "x$hasipv6" = "x" ]; then
        providerstotest=$PROVIDERSV4
    else
        providerstotest="$PROVIDERSV4 $PROVIDERSV6"
    fi
else
    providerstotest=$PROVIDERSV4
fi

# Domains to test. Duplicated domains are ok
DOMAINS2TEST="www.google.com amazon.com facebook.com www.youtube.com www.reddit.com wikipedia.org twitter.com gmail.com www.google.com whatsapp.com"

# Color codes
dark_magenta='\033[0;35m'
light_magenta='\033[1;35m'
white='\033[1;37m'
light_red='\033[1;31m'
light_green='\033[1;32m'
no_color='\033[0m'

totaldomains=0
printf "${dark_magenta}%-21s${no_color}" ""
for d in $DOMAINS2TEST; do
    totaldomains=$((totaldomains + 1))
    printf "${dark_magenta}%-8s${no_color}" "test$totaldomains"
done
printf "${dark_magenta}%-8s${no_color}" "Average"
echo ""

for p in $NAMESERVERS $providerstotest; do
    pip=${p%%#*}
    pname=${p##*#}
    ftime=0

    printf "${light_magenta}%-21s${no_color}" "$pname"
    for d in $DOMAINS2TEST; do
        ttime=$($dig +tries=1 +time=2 +stats @$pip $d | grep "Query time:" | cut -d : -f 2- | cut -d " " -f 2)
        if [ -z "$ttime" ]; then
            ttime=1000
        elif [ "x$ttime" = "x0" ]; then
            ttime=1
        fi

        if [ $ttime -gt 500 ]; then
            printf "${light_red}%-8s${no_color}" "$ttime ms"
        elif [ $ttime -lt 100 ]; then
            printf "${light_green}%-8s${no_color}" "$ttime ms"
        else
            printf "${white}%-8s${no_color}" "$ttime ms"
        fi

        ftime=$((ftime + ttime))
    done
    avg=$(bc -l <<< "scale=2; $ftime/$totaldomains")

    echo "  $avg"
done

exit 0
