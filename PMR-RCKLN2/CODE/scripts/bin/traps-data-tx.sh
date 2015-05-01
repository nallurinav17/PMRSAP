#!/bin/bash
# Sync data for 24 hours. ALL Alarm files for last 10 days; snmptrapd.log, /var/log/snmptrapd.log.1.gz
#-------------------------------------------------------------
cd ~/; source 'guavus/scripts/etc/rckln-pm.cfg'
if [[ $? -eq '0' ]]; then
   if [[ `am_i_online` -ne '0' ]]; then exit; fi
fi
#-------------------------------------------------------------

STATUS='0'
ALERT=''

function upload {
   # TRAPS Logs
   val="$val `$RSYNC $RSYNCOPT --rsh="${RSH}" ${STAGE_TRAPS}/./* ${DEST_IP}:${DEST_TRAPS}/ 2>&1`";
   if [[ $? -ne '0' ]]; then
      STATUS=1; if [[ ${ALERT} ]]; then ALERT="$ALERT ; Failed to upload traps log files"; else ALERT="Failed to upload traps log files"; fi
   fi

   # PM Alarm Files.
   val="$val `$RSYNC $RSYNCOPT --rsh="${RSH}" ${STAGE_ALARMS}/./${Y}/${M}/*$Y$M$D*.csv ${DEST_IP}:${DEST_ALARMS}/ 2>&1`";
   if [[ $? -ne '0' ]]; then
      STATUS=1; if [[ ${ALERT} ]]; then ALERT="$ALERT ; Failed to upload PM alarms file"; else ALERT="Failed to upload PM alarms file"; fi
   fi

}

# Attempt transfer
D=''; D=`date +%d`;
M=''; M=`date +%m`;
Y=''; Y=`date +%Y`;

upload
echo "$val"
if [[ $STATUS -ne '0' ]]; then
   write_alarm_status "PROXY_TRAPS_STATUS : $STATUS , ALERT_DETAILS : $ALERT."
   exit 2
fi

if [[ ! $ALERT ]]; then ALERT="NIL!"; fi
write_alarm_status "PROXY_TRAPS_STATUS : $STATUS , ALERT_DETAILS : $ALERT"


