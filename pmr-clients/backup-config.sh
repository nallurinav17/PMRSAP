#!/bin/bash

IPS="$PWD/IP.sh"
function getHosts()
{
  source ${IPS}
  if [[ $? -ne 0 ]]
  then
    printf "Unable to read source for IP Address List\nCannot continue"
    exit 255
  fi
}
# Get Hosts
getHosts
SSH='ssh -q -o ConnectTimeout=5 -o UserKnownHostsFile=/dev/null -l root ';
##########################################################################

function saveconfig {

clear
for i in $cnp $mgmt
do
	echo "Backing up configuration at ${prefix}${i}"
    	$SSH ${prefix}${i} "mount -o remount,rw /"
	$SSH ${prefix}${i} "/opt/tms/bin/cli -t 'en' 'conf t' 'configuration delete pre-mnp-config' 'wr mem'" > /dev/null
  	$SSH ${prefix}${i} "/opt/tms/bin/cli -t 'en' 'conf t' 'configuration write to pre-mnp-config no-switch' 'wr mem'"
done


}

saveconfig

