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

# COMPUTE NODES

echo "Pushing COMPUTE filters."
sleep 3
for i in $cmp
do
if [[ ${i} -eq '10' || ${i} -eq '11' ]]; then prefix="10.10.36."; else prefix="10.10.35."; fi
echo "Working on node: ${prefix}${i}"
echo "Pushing IP filter updates"
$SSH ${prefix}${i} "mount -o remount,rw /"
/usr/bin/scp -q ./compute-filter.cli root@${prefix}${i}:/tmp
$SSH ${prefix}${i} "/opt/tms/bin/cli -x -h /tmp/compute-filter.cli"
done

# SERVICE GATEWAYS NEW
echo "Pushing NEW SERVICE GATEWAY filters."
sleep 3
for i in $mgmt
do
if [[ ${i} -eq '10' || ${i} -eq '11' ]]; then prefix="10.10.36."; else prefix="10.10.35."; fi
echo "Working on node: ${prefix}${i}"
$SSH ${prefix}${i} "mount -o remount,rw /"
echo "Pushing IP filter updates"
/usr/bin/scp -q ./newsvcgw.cli root@${prefix}${i}:/tmp
$SSH ${prefix}${i} "/opt/tms/bin/cli -x -h /tmp/newsvcgw.cli"
done

