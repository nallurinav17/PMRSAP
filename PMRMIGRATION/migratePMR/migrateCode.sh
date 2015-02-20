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

DEST="/data/scripts/PMR"
INSTALL_LOC="/data/scripts/PMR"
FILE=""
SRC="/tmp"
CRONDIR="/etc/cron.d"

#  MGMT

function populateCron {

for i in $newmgmt; do
  echo -n "---------------------------- Populate cron at ${prefix}${i} : "
  $SSH ${prefix}${i} "cd ${CRONDIR} ; /bin/ln -s $DEST/etc/PMR_SAP.cron ./ 2>/dev/null"
  sleep 1
  $SSH ${prefix}${i} "if [[ -e ${CRONDIR}/PMR_SAP.cron ]]; then echo 'SUCCESS!'; else echo 'FAILED!'; fi" 2>/dev/null
  if [[ $? -ne '0' ]]; then echo "FAILED!"; fi
done
}

function migrateCode {
for i in $newmgmt; do
  echo -n "---------------------------- Transferring code to ${prefix}${i} : "
  $SSH ${prefix}${i} "mount -o remount,rw /"
  $SSH ${prefix}${i} "/bin/mkdir -p ${DEST}"
  sleep 1
  val=`/usr/bin/rsync -v -azr ${INSTALL_LOC}/* root@${prefix}${i}:${DEST}/ 2>&1 | tr '\n' ' '`
  if [[ $? -eq '0' ]]; then
     echo "SUCCESS!"
  else 
     echo "FAILED!"
     sleep 5
     echo "---------------------------- LOGS ----------------------------"
     echo "$val"
  fi
done
}

# ADD MIBS
function transferMibs {
echo "---------------------------- Transfering MIB files."
for i in $newmgmt
do
   echo "Working on node: ${prefix}${i}"
   $SSH ${prefix}${i} "mount -o remount,rw /"
   sleep 3
   /usr/bin/scp -q ../CLI/MIBS/* root@${prefix}${i}:/usr/share/snmp/mibs/
   /usr/bin/scp -q ../CLI/MIBS/* root@${prefix}${i}:/usr/share/mibs/ietf/
done
}

clear
SETUP=`/bin/pwd | awk -F '/' '{print $NF}'`
migrateCode
populateCron
transferMibs
echo "---------------------------- Done!"

