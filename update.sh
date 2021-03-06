#!/bin/bash -x
#export IFS=$'\n'

if [ $(whoami) != "root" ]; then
        echo "This script must be run as root"
        exit 1
fi

IPSET=/sbin/ipset
IPTABLES=/sbin/iptables

curl -O 'http://nami.jp/ipv4bycc/cidr.txt.gz' || exit 1
gunzip -f cidr.txt.gz || exit 1

## blacklist

${IPSET} create -exist BLACKLIST hash:net  || exit 1
${IPSET} flush BLACKLIST || exit 1

# block country codes
array=("CH" "HK" "KR" "BR");
#

i=0
for COUNTRY_CODE in ${array[@]}
do
	grep ${COUNTRY_CODE} cidr.txt| sed -e "s/^${COUNTRY_CODE}\t//" | xargs -i ${IPSET} -q add BLACKLIST {} || exit 1
	i=i++
done

${IPSET} list BLACKLIST || exit 1

firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 1 -m set --match-set BLACKLIST src -j REJECT || exit 1
firewall-cmd --direct --add-rule ipv4 filter INPUT 1 -m set --match-set BLACKLIST src -j REJECT || exit 1

${IPTABLES}  -I INPUT -m state --state NEW -p tcp --dport 22 -m set --match-set BLACKLIST src -j REJECT || exit 1

## whitelist

${IPSET} create -exist WHITELIST hash:net || exit 1
${IPSET} flush WHITELIST || exit 1

array=("JP");
i=0
for COUNTRY_CODE in ${array[@]}
do
        grep ${COUNTRY_CODE} cidr.txt| sed -e "s/^${COUNTRY_CODE}\t//" | xargs -i ${IPSET} -q add WHITELIST {} || exit 1 || exit 1
        i=i++
done

firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -m set --match-set WHITELIST src -j ACCEPT || exit 1
firewall-cmd --direct --add-rule ipv4 filter INPUT 0 -m set --match-set WHITELIST src -j ACCEPT || exit 1

${IPTABLES} -I INPUT -m state --state NEW -p tcp --dport 22 -m set --match-set WHITELIST src -j ACCEPT || exit 1

rm -f cidr.txt || exit 1

firewall-cmd --reload
