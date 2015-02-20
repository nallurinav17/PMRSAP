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
function shareKeys {
for i in $newmgmt
do
echo "---------------------------- Sharing SSH keys from : ${prefix}${i} to whole SAP cluster."
$SSH ${prefix}${i} "mount -o remount,rw /"
sleep 3
  for d in $cnp $cmp $uip $ccp $sgp $mgmt $newmgmt; do
    ./sshkeytool-quiet --src=${prefix}${i} --dest=${prefix}${d}
  done
done
}
shareKeys


