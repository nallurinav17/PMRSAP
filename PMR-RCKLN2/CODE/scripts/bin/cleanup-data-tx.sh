#!/bin/bash
# Sync data for 24 hours. ALL Alarm files for last 10 days; snmptrapd.log, /var/log/snmptrapd.log.1.gz
#-------------------------------------------------------------
cd ~/; source 'guavus/scripts/etc/rckln-pm.cfg'
if [[ $? -eq '0' ]]; then
   if [[ `am_i_online` -ne '0' ]]; then exit; fi
fi
#-------------------------------------------------------------

STATUS=''
ALERT=''

# File Cleanup
/bin/find ${STAGE_TRAPS} -mindepth 1 -type f -mmin +${TRAP_RETENTION} -exec rm -rf {} \; 2>/dev/null
/bin/find ${STAGE_DATA_SAP} -mindepth 3 -type f -mmin +${PM_DATA_RETENTION} -exec rm -rf {} \; 2>/dev/null
/bin/find ${STAGE_DATA_DC} -mindepth 3 -type f -mmin +${PM_DATA_RETENTION} -exec rm -rf {} \; 2>/dev/null
/bin/find ${STAGE_ALARMS} -mindepth 3 -type f -mmin +${PM_DATA_RETENTION} -exec rm -rf {} \; 2>/dev/null

# Directory Cleanup - Older than a week.
/bin/find ${STAGE_DATA_SAP} -mindepth 3 -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null
/bin/find ${STAGE_DATA_DC} -mindepth 3 -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null
/bin/find ${STAGE_ALARMS} -mindepth 3 -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null

