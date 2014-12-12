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
INSTALL_LOC="/data/scripts"
FILE="sap-pmr-v02.tgz"
SRC="/tmp"

#  MGMT
function restartCron {
echo "---------------------------- Refresh schedules."
for i in $mgmt
do
echo "Working on node: ${prefix}${i}"
if [[ ! `${SSH} ${prefix}${i} "ls /etc/cron.d/PMR_SAP.cron 2>/dev/null"` ]]; then 
	${SSH} ${prefix}${i} "/bin/ln -s /data/scripts/PMR/etc/PMR_SAP.cron /etc/cron.d/"
fi
done

echo "---------------------------- Restarting cron service."
for i in $mgmt
do
echo "Working on node: ${prefix}${i}"
sleep 3
$SSH ${prefix}${i} "mount -o remount,rw /"
/usr/bin/scp -q ../restart.cli root@${prefix}${i}:/tmp
$SSH ${prefix}${i} "/opt/tms/bin/cli -x -h /tmp/restart.cli"
done

}

# install PMRv2 into repository.
function installPMRv2 {
echo "---------------------------- Installing PMR v2 code to repository."
for i in $mgmt0
do
echo "Working on node: ${prefix}${i}"
sleep 3
$SSH ${prefix}${i} "mount -o remount,rw /"
val=`$SSH ${prefix}${i} "ls -l ${DEST}/PMR/etc/PMR_SAP.cron 2>/dev/null"`
if [[ $? -eq '0' ]]; then
$SSH ${prefix}${i} "if [[ ! -e ${DEST}/PMR/etc/PMR_SAP.cron.b4pmrv2.bkp ]]; then /bin/cp ${DEST}/PMR/etc/PMR_SAP.cron ${DEST}/PMR/etc/PMR_SAP.cron.b4pmrv2.bkp; fi"
fi
/usr/bin/scp -q ../${FILE} root@${prefix}${i}:${SRC}/
$SSH ${prefix}${i} "/bin/tar zxvf ${SRC}/${FILE} -C ${DEST}/" 
done

echo "---------------------------- Installing PMR v2 code to management nodes."
for i in $mgmt
do
echo "Working on node: ${prefix}${i}"
sleep 3
$SSH ${prefix}${i} "mount -o remount,rw /"
val=`$SSH ${prefix}${i} "ls -l ${INSTALL_LOC}/PMR/etc/PMR_SAP.cron 2>/dev/null"`
if [[ $? -eq '0' ]]; then
$SSH ${prefix}${i} "if [[ ! -e ${INSTALL_LOC}/PMR/etc/PMR_SAP.cron.b4pmrv2.bkp ]]; then /bin/cp ${INSTALL_LOC}/PMR/etc/PMR_SAP.cron ${INSTALL_LOC}/PMR/etc/PMR_SAP.cron.b4pmrv2.bkp; fi"
fi
/usr/bin/scp -q ../${FILE} root@${prefix}${i}:${SRC}/
$SSH ${prefix}${i} "/bin/tar zxvf ${SRC}/${FILE} -C ${INSTALL_LOC}/" 
done

}

function syncPMR {
echo "---------------------------- Synchronize PMR install with repository."
for i in $mgmt
do
echo "Working on node: ${prefix}${i}"
sleep 3
$SSH ${prefix}${i} "mount -o remount,rw /"
$SSH ${prefix}${i} "/data/scripts/PMR/bin/SyncPMRHosts.sh"
done
}

function createPaths {
echo "---------------------------- Creating PMR Install Architecture."
for i in $mgmt
do
echo "Working on node: ${prefix}${i}"
sleep 3
$SSH ${prefix}${i} "mount -o remount,rw /"
$SSH ${prefix}${i} "/bin/mkdir -p /data/mgmt/pmr/data/alarms /data/mgmt/pmr/data/pm/SAP /data/mgmt/pmr/scripts/pm/SAP /data/scripts"
done
}

function modifyLinks {
echo "---------------------------- Update install type."

# Update in Repository install.
for i in $mgmt0
do
echo "Working on node: ${prefix}${i}"
$SSH ${prefix}${i} "mount -o remount,rw /"
sleep 3

	if [[ ${SETUP} == 'SMLAB' ]]; then
	echo "---------------------------- Performing SMLAB specific operations."
 	post="smlab"
 	elif [[ ${SETUP} == 'STAGING' ]]; then
	echo "---------------------------- Performing STAGING specific operations."
	post="staging"
	${SSH} ${prefix}${i} "/usr/bin/perl -pi -e 's/^(.*\/nbiPmDataTx.sh)$/#\$1/' ${DEST}/PMR/etc/PMR_SAP.cron"
	elif [[ ${SETUP} == 'COLSP' ]]; then
	echo "---------------------------- Performing PROD specific operations."
	post="prod"
	fi
	${SSH} ${prefix}${i} "/bin/rm -rf ${DEST}/PMR/etc/PMRConfig.cfg ${DEST}/PMR/etc/SAPConfig.cfg ${DEST}/PMR/etc/dc-config.cfg 2>/dev/null"
	sleep 1
	${SSH} ${prefix}${i} "cd ${DEST}/PMR/etc/ ; /bin/ln -s PMRConfig.${post} ./PMRConfig.cfg"
	${SSH} ${prefix}${i} "cd ${DEST}/PMR/etc/ ; /bin/ln -s SAPConfig.${post} ./SAPConfig.cfg"
	${SSH} ${prefix}${i} "cd ${DEST}/PMR/etc/ ; /bin/ln -s dc-config.${post} ./dc-config.cfg"
done

# Update in Mgmt nodes install.

for i in $mgmt
do
echo "Working on node: ${prefix}${i}"
$SSH ${prefix}${i} "mount -o remount,rw /"
sleep 3

        if [[ ${SETUP} == 'SMLAB' ]]; then
        echo "---------------------------- Performing SMLAB specific operations."
        post="smlab"
        elif [[ ${SETUP} == 'STAGING' ]]; then
        echo "---------------------------- Performing STAGING specific operations."
        post="staging"
        ${SSH} ${prefix}${i} "/usr/bin/perl -pi -e 's/^(.*\/nbiPmDataTx.sh)$/#\$1/' ${INSTALL_LOC}/PMR/etc/PMR_SAP.cron"
        elif [[ ${SETUP} == 'COLSP' ]]; then
        echo "---------------------------- Performing PROD specific operations."
        post="prod"
        fi
        ${SSH} ${prefix}${i} "/bin/rm -rf ${INSTALL_LOC}/PMR/etc/PMRConfig.cfg ${INSTALL_LOC}/PMR/etc/SAPConfig.cfg ${INSTALL_LOC}/PMR/etc/dc-config.cfg 2>/dev/null"
        sleep 1
        ${SSH} ${prefix}${i} "cd ${INSTALL_LOC}/PMR/etc/ ; /bin/ln -s PMRConfig.${post} ./PMRConfig.cfg"
        ${SSH} ${prefix}${i} "cd ${INSTALL_LOC}/PMR/etc/ ; /bin/ln -s SAPConfig.${post} ./SAPConfig.cfg"
        ${SSH} ${prefix}${i} "cd ${INSTALL_LOC}/PMR/etc/ ; /bin/ln -s dc-config.${post} ./dc-config.cfg"
done

}

clear
SETUP=`/bin/pwd | awk -F '/' '{print $NF}'`
createPaths
installPMRv2
modifyLinks
syncPMR
restartCron
echo "---------------------------- Done!"

