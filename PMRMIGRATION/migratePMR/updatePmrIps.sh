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

DEST="/data/mgmt/pmr/scripts/pm/SAP/PMR"
INSTALL_LOC="/data/scripts/PMR"
SRC=""

#  MGMT

function generateKeysCli {

$SSH ${prefix}${mgmt0} "mount -o remount,rw /"
sleep 3

# KEYS
echo "---------------------------- Generate keys from CLI configurations."
printf "\n\n   en\n   conf t\n" > ../CLI/keys.cli
$SSH ${prefix}${mgmt0} "/opt/tms/bin/cli -t 'en' 'conf t' 'show run full' | grep 'ssh client user admin authorized'" >> ../CLI/keys.cli
printf "\n\n   write memory\n\n" >> ../CLI/keys.cli

# CLUSTER
echo "---------------------------- Generate cluster from CLI configurations."
printf "\n\n   en\n   conf t\n" > ../CLI/cluster.cli
$SSH ${prefix}${mgmt0} "/opt/tms/bin/cli -t 'en' 'conf t' 'show run full' | grep 'cluster' | egrep -w 'interface|master interface|id|address|expected|cluster name'" >> ../CLI/cluster.cli

# CLUSTER FILTERS
echo "---------------------------- Generate cluster IP filters."
for ip in $newmgmt; do
printf "   ip filter chain INPUT rule append tail target ACCEPT dup-delete source-addr ${prefix}${ip} /32 dest-port 5353 protocol udp\n" >> ../CLI/cluster.cli
done
#printf "   ip filter chain INPUT rule append tail target DROP dup-delete dest-port 5353 protocol udp\n" >> ../CLI/cluster.cli
printf "\n\n   no cluster enable\n\n   write memory\n\n" >> ../CLI/cluster.cli
}

function migrateCli {
for i in $newmgmt
do
echo "---------------------------- Migrating CLI configurations to : ${prefix}${i}"
$SSH ${prefix}${i} "mount -o remount,rw /"
sleep 3
/usr/bin/scp -q ../CLI/keys.cli root@${prefix}${i}:/tmp
/usr/bin/scp -q ../CLI/cluster.cli root@${prefix}${i}:/tmp
sleep 2
$SSH ${prefix}${i} "/opt/tms/bin/cli -x -h /tmp/keys.cli"
$SSH ${prefix}${i} "/opt/tms/bin/cli -x -h /tmp/cluster.cli"
done
}

function disableCluster {
echo "---------------------------- Disable cluster, PMR and VIP at current mgmt nodes."
for i in $mgmt
do
echo "Working on node : ${prefix}${i}"
$SSH ${prefix}${i} "/opt/tms/bin/cli -t 'en' 'conf t' 'no cluster enable'"
sleep 2
$SSH ${prefix}${i} "/opt/tms/bin/cli -t 'en' 'conf t' 'wr mem'"
$SSH ${prefix}${i} "/bin/rm -rf /etc/cron.d/PMR_SAP.cron"
$SSH ${prefix}${i} "/opt/tms/bin/cli -t 'en' 'conf t' 'pm process crond restart'"
sleep 2
$SSH ${prefix}${i} "/opt/tms/bin/cli -t 'en' 'conf t' 'wr mem'"
done
}

function enableCluster {
echo "---------------------------- Restart cron and enable cluster at new mgmt nodes."
for i in $newmgmt
do
echo "Working on node : ${prefix}${i}"
sleep 3
/usr/bin/scp -q ../CLI/restart.cli root@${prefix}${i}:/tmp
sleep 2
$SSH ${prefix}${i} "/opt/tms/bin/cli -x -h /tmp/restart.cli"
done
}

function editPmrConfigs {
if [[ ${SETUP} == "COLSP" ]]; then post="prod"; 
elif [[ ${SETUP} == "SMLAB" ]]; then post="smlab";
elif [[ ${SETUP} == "STAGING" ]]; then post="staging";
else post="cfg"
fi

for i in $newmgmt
do
echo "---------------------------- Updating PMR configurations with new mgmt node IPs : ${prefix}${i}"
$SSH ${prefix}${i} "mount -o remount,rw /"
sleep 3
count=1
  for IP in $newmgmt; do
   #${SSH} ${prefix}${i} "/usr/bin/perl -pi -e s/^PMRHOST${count}=.*/PMRHOST${count}=\'${prefix}${IP}\'/g ${DEST}/etc/PMRConfig.${post}"
   ${SSH} ${prefix}${i} "/usr/bin/perl -pi -e s/^PMRHOST${count}=.*/PMRHOST${count}=\'${prefix}${IP}\'/g ${INSTALL_LOC}/etc/PMRConfig.${post}"
   sleep 1
   count=`echo "$count + 1" | bc`
  done
done

for i in $mgmt0
do
echo "---------------------------- Updating PMR configurations with new repository via : ${prefix}${i}"
$SSH ${prefix}${i} "mount -o remount,rw /"
sleep 3
count=1
  for IP in $newmgmt; do
   ${SSH} ${prefix}${i} "/usr/bin/perl -pi -e s/^PMRHOST${count}=.*/PMRHOST${count}=\'${prefix}${IP}\'/g ${DEST}/etc/PMRConfig.${post}"
   #${SSH} ${prefix}${i} "/usr/bin/perl -pi -e s/^PMRHOST${count}=.*/PMRHOST${count}=\'${prefix}${IP}\'/g ${INSTALL_LOC}/etc/PMRConfig.${post}"
   sleep 1
   count=`echo "$count + 1" | bc`
  done
done



}

function syncPmr {
for i in $newmgmt
do
echo "---------------------------- Synchronize PMR install with repository at new mgmt node : ${prefix}${i}"
$SSH ${prefix}${i} "mount -o remount,rw /"
sleep 3
$SSH ${prefix}${i} "/data/scripts/PMR/bin/SyncPMRHosts.sh"
done
}

clear
SETUP=`/bin/pwd | awk -F '/' '{print $NF}'`
#generateKeysCli
editPmrConfigs
#migrateCli
#disableCluster
#enableCluster
#echo "Sleeping for 5 seconds to get cluster enabled successfully!"
#sleep 5
syncPmr
echo "---------------------------- Done!"

