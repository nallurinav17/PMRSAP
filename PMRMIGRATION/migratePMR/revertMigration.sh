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

SSH='ssh -q -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o UserKnownHostsFile=/dev/null -l root '
#------------------------------------------------------------------------


DEST="/data/mgmt/pmr/scripts/pm/SAP"
INSTALL_LOC="/data/scripts/PMR"
FILE="sap-pmr-v02.tgz"
SRC="/tmp"

#  MGMT
function restore {
echo "---------------------------- Restarting cron service."
for i in $mgmt
do
echo "Working on node: ${prefix}${i}"
$SSH ${prefix}${i} "mount -o remount,rw /"
sleep 3
$SSH ${prefix}${i} "cd /etc/cron.d/ ; /bin/rm -f PMR_SAP.cron ; /bin/ln -s ${INSTALL_LOC}/etc/PMR_SAP.cron ./"
$SSH ${prefix}${i} "/opt/tms/bin/cli -t 'en' 'conf t' 'pm process crond restart'"
sleep 2
$SSH ${prefix}${i} "/opt/tms/bin/cli -t 'en' 'conf t' 'cluster enable'"
sleep 1
$SSH ${prefix}${i} "/opt/tms/bin/cli -t 'en' 'conf t' 'wr mem'"
done
}

function uninstall {
echo "---------------------------- Restore PMR migration code."
for i in $newmgmt
do
echo "Working on node: ${prefix}${i}"
$SSH ${prefix}${i} "mount -o remount,rw /"
sleep 3
$SSH ${prefix}${i} "/bin/rm -rf /etc/cron.d/PMR_SAP.cron /data/mgmt/pmr /data/scripts/PMR"
$SSH ${prefix}${i} "/opt/tms/bin/cli -t 'en' 'conf t' 'pm process crond restart'"
sleep 2
$SSH ${prefix}${i} "/opt/tms/bin/cli -t 'en' 'conf t' 'no cluster enable'"
sleep 1
$SSH ${prefix}${i} "/opt/tms/bin/cli -t 'en' 'conf t' 'wr mem'"
done
}

clear
uninstall
restore
echo "---------------------------- Done!"
