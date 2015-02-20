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
function verifyPmrMount {
for i in $mgmt $newmgmt
do
echo -n "---------------------------- Verifying PMR mount point on : ${prefix}${i} : "
$SSH ${prefix}${i} "mount -o remount,rw /"
sleep 3
val=`$SSH ${prefix}${i} "mount | grep pmr 2>/dev/null"`
if [[ $? -eq '0' ]]; then
echo "Mounted : $val"
else 
echo "Not mounted : Error!"
fi
done
}
verifyPmrMount
