#!/bin/bash
# Sync data for 24 hours. ALL Alarm files for last 10 days; snmptrapd.log, /var/log/snmptrapd.log.1.gz
#-------------------------------------------------------------
source "/opt/guavus/scripts/etc/rckln-pm.cfg"
if [[ $? -eq '0' ]]; then
   if [[ `am_i_master` -ne '0' ]]; then exit; fi
fi
#-------------------------------------------------------------

STATUS=''
ALERT=''

if [[ -e ${LOGF_PM} ]]; then
  /bin/cat ${LOGF_PM} 2>/dev/null
else 
  echo "`date` , PROXY_PM_STATUS : NA , ALERT_DETAILS : NA"
fi

if [[ -e ${LOGF_ALARM} ]]; then
  /bin/cat ${LOGF_ALARM} 2>/dev/null
else
  echo "`date` , PROXY_TRAPS_STATUS : NA , ALERT_DETAILS : NA"
fi

