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
INSTALL_LOC="/data/scripts"
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
$SSH ${prefix}${i} "if [[ -e ${DEST}/PMR/etc/PMR_SAP.cron.b4pmrv2.bkp ]]; then /bin/mv ${DEST}/PMR/etc/PMR_SAP.cron.b4pmrv2.bkp ${DEST}/PMR/etc/PMR_SAP.cron; fi"
sleep 2
if [[ "${SETUP}" == 'STAGING' ]]; then
$SSH ${prefix}${i} "/bin/rm -rf /data/mgmt/pmr 2>/dev/null"
fi
done

for i in $mgmt
do
echo "Working on node: ${prefix}${i}"
$SSH ${prefix}${i} "mount -o remount,rw /"
sleep 2
if [[ "${SETUP}" == 'STAGING' ]]; then
$SSH ${prefix}${i} "/bin/rm -rf /data/scripts/PMR /etc/cron.d/PMR_SAP.cron 2>/dev/null "
else
$SSH ${prefix}${i} "if [[ -e ${INSTALL_LOC}/PMR/etc/PMR_SAP.cron.b4pmrv2.bkp ]]; then /bin/mv ${INSTALL_LOC}/PMR/etc/PMR_SAP.cron.b4pmrv2.bkp ${INSTALL_LOC}/PMR/etc/PMR_SAP.cron; fi"
fi
done
}

function syncPMR {
echo "---------------------------- Synchronize PMR v2 uninstall with repository."
for i in $mgmt
do
echo "Working on node: ${prefix}${i}"
sleep 3
$SSH ${prefix}${i} "mount -o remount,rw /"
$SSH ${prefix}${i} "/data/scripts/PMR/bin/SyncPMRHosts.sh 2>/dev/null"
done
}

clear
SETUP=`/bin/pwd | awk -F '/' '{print $NF}'`
uninstallPMRv2
syncPMR
restartCron
echo "---------------------------- Done!"
