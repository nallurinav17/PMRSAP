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


DEST="/data/mgmt/pmr/scripts/pm/SAP"
FILE="sap-pmr-v02.tgz"
SRC="/tmp"

#  MGMT
function restartCron {
echo "---------------------------- Restarting cron service."
for i in $mgmt
do
echo "Working on node: ${prefix}${i}"
sleep 3
$SSH ${prefix}${i} "mount -o remount,rw /"
$SSH ${prefix}${i} "/opt/tms/bin/cli -t 'en' 'conf t' 'pm process crond restart'"
done
}

function uninstallPMRv2 {
echo "---------------------------- Uninstalling PMR v2 code."
for i in $mgmt0
do
echo "Working on node: ${prefix}${i}"
sleep 3
$SSH ${prefix}${i} "mount -o remount,rw /"
$SSH ${prefix}${i} "if [[ -e ${DEST}/PMR/etc/PMR_SAP.cron.b4pmrv2.bkp ]]; then /bin/mv ${DEST}/PMR/etc/PMR_SAP.cron.b4pmrv2.bkp ${DEST}/PMR/etc/PMR_SAP.cron"
done
}

function syncPMR {
echo "---------------------------- Synchronize PMR v2 uninstall with repository."
for i in $mgmt
do
echo "Working on node: ${prefix}${i}"
sleep 3
$SSH ${prefix}${i} "mount -o remount,rw /"
$SSH ${prefix}${i} "/data/scripts/PMR/bin/SyncPMRHosts.sh"
done
}

uninstallPMRv2
syncPMR
restartCron
echo "---------------------------- Done!"
