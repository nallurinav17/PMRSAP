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

SSH='ssh -q -o ConnectTimeout=5 -o UserKnownHostsFile=/dev/null -l root '
#------------------------------------------------------------------------

#  MGMT
echo "Pushing Management node filters."
sleep 3
for i in $mgmt
do
echo "Working on node: ${prefix}${i}"
$SSH ${prefix}${i} "mount -o remount,rw /"
echo "Pushing IP filter updates"
/usr/bin/scp -q ./newsvcgw.cli root@${prefix}${i}:/tmp
$SSH ${prefix}${i} "/opt/tms/bin/cli -x -h /tmp/newsvcgw.cli"
done

