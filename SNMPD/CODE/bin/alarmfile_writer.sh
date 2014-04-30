#!/bin/bash

BASEPATH="/data/scripts/PMR"
source ${BASEPATH}/etc/PMRConfig.cfg
ALARMPATH="/data/mgmt/pmr/data/alarms/snmp"
MGMT=''; MGMT=`$CLI 'show cluster global brief' | grep \* | awk '{print $NF}'`

if [[ ! $MGMT ]]; then MGMT=${PMRHOST1}; fi

if [[ $# -eq 0 ]] ; then TYPE='05m' ; else TYPE=$1; fi

CURR=`date +%s`
myY=`date +%Y`
myM=`date +%m`
myD=`date +%d`

# Round off to next 5 minute
ROUNDOFF=$(echo "(${CURR}-(${CURR}%300))+300" | bc)

PMDIR="$ALARMPATH/$myY/$myM"
PMFILE=`date -d @${ROUNDOFF} +"alarm-MGMT-${MGMT}-%Y%m%d_%H%M-0.csv"`
PMPATH="$PMDIR/$PMFILE"

if [[ ! -e $PMDIR ]] ; then mkdir -p $PMDIR ; fi

if [[ ! -f ${PMPATH} ]] ; then echo "#Timestamp, IP source, trap name, GMSassignedSeverity, [ <varbindName | varbindOid> = \"<value>\" ]   [, <varbindName | varbindOid> = \"<value>\" ]\*" > ${PMPATH} ; fi
#if [[ ! -f ${PMPATH} ]] ; then echo "#timestamp, source, trapname, severity, properties" > ${PMPATH} ; fi

while IFS= read -r line; do
  printf '%s\n' "$line" >> ${PMPATH}
done 

write_log "Wrote alarms to $PMPATH"

exit 0 
