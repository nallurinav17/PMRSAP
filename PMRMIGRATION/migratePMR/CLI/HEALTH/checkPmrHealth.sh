#!/bin/bash

# -------------------------------------------------------------------------------------------------------
BASEPATH=/data/scripts/PMR
HOSTNAME=`hostname`

# Read Configuration and quit if not Master
# Read main configuration file
cd /data/scripts/PMR
. /data/scripts/PMR/etc/PMRConfig.cfg

# Read SAP Configuration file
. /data/scripts/PMR/etc/SAPConfig.cfg
# Source variables in dc-config.cfg
. /data/scripts/PMR/etc/dc-config.cfg
# -------------------------------------------------------------------------------------------------------

YY=`date +%Y`
PMR_STATUS=0
ALERT=''

# Thresholds.
CPU_THRESH=90
MEM_USED_THRESH=90
UPTIME=4000

function validateSnmp {
  SNMP_processCount=''; SNMP_processCount=`ps -ef | grep -v grep | grep snmp | wc -l`
  if [[ $? -ne '0' ]]; then SNMP_processCount='0'; fi
  if [[ $SNMP_processCount -lt 4 ]]; then
     PMR_STATUS=`echo "$PMR_STATUS + 1" | bc`
     if [[ $ALERT ]]; then ALERT="$ALERT ; SNMP Server Status Critical."; else ALERT="SNMP Server Status Critical."; fi
  else
     PMR_STATUS=`echo "$PMR_STATUS + 0" | bc`
  fi
}

function validateSapDataCollection {
  
SAP_FILES='0'; SAP_FILES=`/bin/find ${SANDATA}/SAP/${YY}/ -mindepth 2 -type f -mmin -60 2>/dev/null | wc -l`
if [[ $SAP_FILES -eq '0' ]]; then 
  PMR_STATUS=`echo "$PMR_STATUS + 2" | bc`
  if [[ $ALERT ]]; then ALERT="$ALERT ; SAP PM Data Collection Status Critical."; else ALERT="SAP PM Data Collection Status Critical."; fi
else 
  PMR_STATUS=`echo "$PMR_STATUS + 0" | bc`
fi  

}

function validateDcDataCollection {
FLAG=0
LIST=''

for DC in `/bin/cat ${BASEPATH}/etc/DCCLLI.txt 2>/dev/null | egrep -v ^\# | awk -F '/' '{print $3}'`; do
  DC_FILES='0'; DC_FILES=`/bin/find ${SANDATA}/VISP/${DC}/${YY}/ -mindepth 2 -type f -mmin -60 2>/dev/null | wc -l`
  if [[ $DC_FILES -eq '0' ]]; then
    FLAG=1 
    DCNAME=`grep -w $DC ${BASEPATH}/etc/DCCLLI.txt | awk -F '/' '{print $2}'`
    if [[ ! $LIST ]]; then LIST="$DCNAME"; 
    else
    LIST="$LIST $DCNAME"
    fi
  fi
done

if [[ $FLAG -eq '1' ]]; then
     if [[ $ALERT ]]; then ALERT="$ALERT ; Not receiving PM data from the following DCs $LIST."; else ALERT="Not receiving PM data from the following DCs $LIST."; fi
     PMR_STATUS=`echo "$PMR_STATUS + 4" | bc`
fi

}

function validatePmrStorage {

val=''; val=`mount 2>/dev/null | grep '/data/mgmt/pmr' 2>/dev/null`
mode=''
if [[ $? -eq '0' ]]; then 
   mode=`echo "$val" | awk '{print $NF}' | sed 's/(//g' | sed 's/)//g' | cut -d ',' -f1`
   if [[ ! ${mode} ]]; then mode="NA"; fi
else 
   mode="NA"
fi

if [[ $mode != 'rw' ]]; then
   if [[ $ALERT ]]; then ALERT="$ALERT ; PMR storage availability critical."; else ALERT="PMR storage availability critical."; fi
   PMR_STATUS=`echo "$PMR_STATUS + 16" | bc`
fi


}


function validateNbiPush {

#TARGET_LIST='';TARGET_LIST="`grep --after-context=$(wc -l 2>/dev/null < ${NBIEVENTLOGF}) "\`date -d "1 hour ago" +"%a %b %d %H"\`" ${NBIEVENTLOGF} 2>/dev/null | grep 'Failed to transfer data' | awk -F ':' '{print $NF}' | awk '{print $1}' | sort -u | column -x`"
#TARGET_LIST='';TARGET_LIST="`grep --after-context=$(wc -l 2>/dev/null < ${NBIEVENTLOGF}) "\`date +"%a %b %d %H"\`" ${NBIEVENTLOGF} 2>/dev/null | grep 'Failed to transfer data' | awk -F ':' '{print $NF}' | awk '{print $1}' | sort -u | column -x`"
TARGET_LIST='';TARGET_LIST="`grep --after-context=$(wc -l 2>/dev/null < ${NBIEVENTLOGF}) "\`date | cut -d ':' -f1\`" ${NBIEVENTLOGF} 2>/dev/null | grep 'Failed to transfer data' | awk -F ':' '{print $NF}' | awk '{print $1}' | sort -u | column -x`"

if [[ $TARGET_LIST ]]; then
    formt=''
    for target in $TARGET_LIST; do
      if [[ $formt ]]; then
        formt="$formt $target"
      else 
        formt="$target"
      fi
    done
    if [[ $ALERT ]]; then ALERT="$ALERT ; NBI Push failed for the following target(s) in last hour $formt"; else ALERT="NBI Push failed for the following target(s) in last hour $formt"; fi
    PMR_STATUS=`echo "$PMR_STATUS + 8" | bc`
fi

}

function validateLocalHealth {
SYSTEM_STATUS='0'
SYS_ALERT=''
STAT=''

# CPU
val1='';val1=`/usr/bin/iostat -c 2>/dev/null | egrep -A1 avg-cpu 2>/dev/null | tail -1 2>/dev/null | awk '{print $6}' 2>/dev/null`
if [[ $val1 ]]; then
  #count=`echo "$count + 1" | bc`
  val1=`echo "scale=2;(100 - $val1)" | bc`
  if [[ $STAT ]]; then STAT="$STAT , CPU_USED : $val1%"; else STAT="CPU_USED : $val1%"; fi
  if [ `echo "${val1} >= ${CPU_THRESH}" | bc 2>/dev/null` -eq '1' ]; then
    SYSTEM_STATUS=`echo "$SYSTEM_STATUS + 1" | bc`
    if [[ $SYS_ALERT ]]; then SYS_ALERT="$SYS_ALERT ; CPU Utilization above threshold of ${CPU_THRESH}"; else SYS_ALERT="CPU Utilization above threshold of ${CPU_THRESH}"; fi
  fi
else 
  SYSTEM_STATUS=`echo "$SYSTEM_STATUS + 1" | bc`
  if [[ $SYS_ALERT ]]; then SYS_ALERT="$SYS_ALERT ; Unable to calculate CPU utilization."; else SYS_ALERT="Unable to calculate CPU utilization."; fi
fi

# MEMORY
val1=''; val1=`/usr/bin/free -o 2>/dev/null | tail -n+2 | egrep ^'Mem' 2>/dev/null | awk '{printf "%.2f\n", $3*100/$2}'`;
if [[ $val1 ]]; then 
   if [[ $STAT ]]; then STAT="$STAT , MEM_USED : ${val1}%"; else STAT="MEM_USED : ${val1}%"; fi
   if [ `echo "${val1} >= ${MEM_USED_THRESH}" | bc 2>/dev/null` -eq '1' ]; then
     SYSTEM_STATUS=`echo "$SYSTEM_STATUS + 2" | bc`
     if [[ $SYS_ALERT ]]; then SYS_ALERT="$SYS_ALERT ; MEM Utilization above threshold of ${MEM_USED_THRESH}"; else SYS_ALERT="MEM Utilization above threshold of ${MEM_USED_THRESH}"; fi
   fi
else 
   SYSTEM_STATUS=`echo "$SYSTEM_STATUS + 2" | bc`
   if [[ $SYS_ALERT ]]; then SYS_ALERT="$SYS_ALERT ; Unable to calculate Memory utilization."; else SYS_ALERT="Unable to calculate Memory utilization."; fi
fi

# UPTIME

val1=''; val1=`/bin/cat /proc/uptime | awk -F "." '{print $1}'`
if [[ $val1 ]]; then
   if [[ $STAT ]]; then STAT="$STAT , UPTIME : ${val1}"; else STAT="UPTIME : ${val1}"; fi
   if [ `echo "${val1} < ${UPTIME}" | bc 2>/dev/null` -eq '1' ]; then
     SYSTEM_STATUS=`echo "$SYSTEM_STATUS + 4" | bc`
     if [[ $SYS_ALERT ]]; then SYS_ALERT="$SYS_ALERT ; System reboot suspected! Uptime found lesser than limit of ${UPTIME}"; else SYS_ALERT="System reboot suspected! Uptime found lesser than limit of ${UPTIME}"; fi
   fi
else
   SYSTEM_STATUS=`echo "$SYSTEM_STATUS + 4" | bc`
   if [[ $SYS_ALERT ]]; then SYS_ALERT="$SYS_ALERT ; Unable to calculate system uptime."; else SYS_ALERT="Unable to calculate system uptime."; fi
fi

if [[ ! $SYS_ALERT ]]; then SYS_ALERT="NIL!"; fi
}

# MAIN

if [[ `am_i_master` -ne 0 ]] ; then
   validateLocalHealth
# SPIT OUT THE SUMMARY
   echo "System status : $SYSTEM_STATUS , Alert details : $SYS_ALERT , $STAT"
else
   validateSnmp
   validateSapDataCollection
   validateDcDataCollection
   validateNbiPush
   validateLocalHealth
   validatePmrStorage
# SPIT OUT THE SUMMARY
if [[ ! $ALERT ]]; then ALERT="NIL!"; fi
   echo "PMR status : $PMR_STATUS , Alert details : ${ALERT} , PMR_STORAGE_STATUS : ${mode}"
   echo "System status : $SYSTEM_STATUS , Alert details : $SYS_ALERT , $STAT"
fi



# SUCCESS/FAIL Format - in case required.
#if [[ $PMR_STATUS -eq '0' ]]; then
#  echo "SUCCESS : PMR status : 0"
#else 
#  echo "FAILED : PMR status : $PMR_STATUS : Alert details $ALERT"
#fi

