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
for i in $newmgmt
do
  echo -n "---------------------------- Connecting through : ${prefix}${i} : "
  val=`/usr/bin/rsync -v -azr ${INSTALL_LOC}/* root@${prefix}${i}:${DEST}/ 2>&1 | tr '\n' ' '`
  if [[ $? -eq '0' ]]; then
     echo "SUCCESS!"
     #break
  else
     echo "FAILED!"
     sleep 5
     echo "---------------------------- LOGS ----------------------------"
     echo "$val"
     echo "---------------------------- RETRYING..."
  fi
done
}

function createPaths {
for i in $newmgmt
do
echo "---------------------------- Creating PMR architecture at new management node : ${prefix}${i}"
sleep 3
$SSH ${prefix}${i} "mount -o remount,rw /"
$SSH ${prefix}${i} "/bin/mkdir -p /data/mgmt/pmr/data/alarms /data/mgmt/pmr/data/pm/SAP /data/mgmt/pmr/scripts/pm/SAP /data/scripts"
done
}

clear
SETUP=`/bin/pwd | awk -F '/' '{print $NF}'`
createPaths
migrateRepo
echo "---------------------------- Done!"

