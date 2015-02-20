#!/bin/bash

# -------------------------------------------------------------------------------------------------------
BASEPATH=/data/scripts/PMR
HOSTNAME=`hostname`

# Read Configuration and quit if not Master
# Read main configuration file
cd /data/scripts/PMR
. /data/scripts/PMR/etc/PMRConfig.cfg
if [[ `am_i_master` -ne 0 ]] ; then exit 0; fi

# Read SAP Configuration file
. /data/scripts/PMR/etc/SAPConfig.cfg
# Source variables in dc-config.cfg
. /data/scripts/PMR/etc/dc-config.cfg
# -------------------------------------------------------------------------------------------------------

YY=`date +%Y`
PMR_STATUS=0
ALERT=''

function validateSnmp {
  SNMP_processCount=''; SNMP_processCount=`ps -ef | grep -v grep | grep snmp | wc -l`
  if [[ $? -ne '0' ]]; then SNMP_processCount='0'; fi
  if [[ $SNMP_processCount -lt 4 ]]; then
     PMR_STATUS=`echo "$PMR_STATUS + 1" | bc`
     ALERT="$ALERT : SNMP Server Status Critical."
  else
     PMR_STATUS=`echo "$PMR_STATUS + 0" | bc`
  fi
}

function validateSapDataCollection {
  
SAP_FILES='0'; SAP_FILES=`/bin/find ${SANDATA}/SAP/${YY}/ -mindepth 2 -type f -mmin -60 2>/dev/null | wc -l`
if [[ $SAP_FILES -eq '0' ]]; then 
  PMR_STATUS=`echo "$PMR_STATUS + 2" | bc`
  ALERT="$ALERT : SAP PM Data Collection Status Critical."
else 
  PMR_STATUS=`echo "$PMR_STATUS + 0" | bc`
fi  

}

function validateDcDataCollection {
FLAG=0

for DC in `/bin/cat ${BASEPATH}/etc/DCCLLI.txt | egrep -v ^\# | awk -F '/' '{print $3}'`; do
  DC_FILES='0'; DC_FILES=`/bin/find ${SANDATA}/VISP/${DC}/${YY}/ -mindepth 2 -type f -mmin -60 2>/dev/null | wc -l`
  if [[ $DC_FILES -eq '0' ]]; then
    FLAG=1 
    DCNAME=`grep $DC ${BASEPATH}/etc/DCCLLI.txt | awk -F '/' '{print $2}'`
    LIST="$LIST $DCNAME"
  fi
done

if [[ $FLAG -eq '1' ]]; then
     ALERT="$ALERT : Not receiving PM data from following DCs $LIST."
     PMR_STATUS=`echo "$PMR_STATUS + 4" | bc`
fi

}

#function validateNbiPush {
#}

#function validateLocalHealth {
#}

validateSnmp
validateSapDataCollection
validateDcDataCollection
validateNbiPush
validateLocalHealth

if [[ $PMR_STATUS -eq '0' ]]; then
  echo "SUCCESS"
else 
  echo "FAILED : PMR status : $PMR_STATUS : Alert details $ALERT"
fi

