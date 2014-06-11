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
clear

function configrestore {
for i in $cnp $mgmt
do
        echo "Restoring configuration at ${prefix}${i}"
        $SSH ${prefix}${i} "mount -o remount,rw /"
  	$SSH ${prefix}${i} '/opt/tms/bin/cli -t "en" "conf t" "configuration switch-to pre-snmp-config" "configuration delete initial" "wr mem"'
  	$SSH ${prefix}${i} '/opt/tms/bin/cli -t "en" "conf t" "configuration write to initial" "configuration delete pre-snmp-config" "wr mem"'
done


}

configrestore


