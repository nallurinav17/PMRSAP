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

DEST="/data/mgmt/pmr"
INSTALL_LOC="/data/mgmt/pmr"
SRC="/tmp"

#  MGMT
function migrateRepo {
echo "---------------------------- Migrate Repository."
for i in $mgmt0
do
  echo -n "---------------------------- Connecting through : ${prefix}${i} : "
  val=`/usr/bin/rsync -v -azr ${INSTALL_LOC}/* root@${prefix}${i}:${DEST}/ 2>&1 | tr '\n' ' '`
  if [[ $? -eq '0' ]]; then
     echo "SUCCESS!"
     #break
  else
     echo "FAILED!"
     echo "---------------------------- LOGS ----------------------------"
     echo "$val"
     echo "---------------------------- RE-RUN THE SCRIPT TO RETRY..."
  fi
done
}

function createPaths {
for i in $newmgmt
do
echo "---------------------------- Creating PMR architecture at new management node : ${prefix}${i}"
$SSH ${prefix}${i} "mount -o remount,rw /"
sleep 3
$SSH ${prefix}${i} "/bin/mkdir -p /data/mgmt/pmr 2>/dev/null"
done

for i in $mgmt0; do
echo "---------------------------- Creating PMR Repository at master management node : ${prefix}${i}"
$SSH ${prefix}${i} "/bin/mkdir -p /data/mgmt/pmr/data/alarms /data/mgmt/pmr/data/pm/SAP /data/mgmt/pmr/scripts/pm/SAP /data/scripts 2>/dev/null"
sleep 3
done
}

function pushHealthMonitor {

for i in $newmgmt; do
echo "---------------------------- Push PMR health monitoring utility to new management node : ${prefix}${i}"
/usr/bin/scp -q ../CLI/HEALTH/DCCLLI.txt root@${prefix}${i}:/data/scripts/PMR/etc/
sleep 2
/usr/bin/scp -q ../CLI/HEALTH/checkPmrHealth.sh root@${prefix}${i}:/data/scripts/PMR/bin/
done

for i in $mgmt0; do
echo "---------------------------- Push PMR health monitoring utility to new repository : ${prefix}${i}"
/usr/bin/scp -q ../CLI/HEALTH/DCCLLI.txt root@${prefix}${i}:/data/mgmt/pmr/scripts/pm/SAP/PMR/etc/
sleep 2
/usr/bin/scp -q ../CLI/HEALTH/checkPmrHealth.sh root@${prefix}${i}:/data/mgmt/pmr/scripts/pm/SAP/PMR/bin/
done

}

clear
SETUP=`/bin/pwd | awk -F '/' '{print $NF}'`
createPaths
migrateRepo
pushHealthMonitor
echo "---------------------------- Done!"

