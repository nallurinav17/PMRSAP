#!/bin/bash

#------------------------------------------------------------------------
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
clear

SSH='ssh -q -o ConnectTimeout=5 -o UserKnownHostsFile=/dev/null -l root '
#------------------------------------------------------------------------

# install PMRv2 into repository.
function enableScr {
for i in $newmgmt
do
echo "---------------------------- Enabling security on : ${prefix}${i}"
$SSH ${prefix}${i} "mount -o remount,rw /"
sleep 3
$SSH ${prefix}${i} "/opt/tms/bin/cli -t 'en' 'conf t' 'ssh server security-feature enable'"
$SSH ${prefix}${i} "/opt/tms/bin/cli -t 'en' 'conf t' 'wr mem'"
done
}

enableScr


