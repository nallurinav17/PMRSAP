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
   val="$val `$RSYNC $RSYNCOPT --rsh="${RSH}" ${STAGE_DATA_SAP}/./${D}/* ${DEST_IP}:${DEST_DATA_SAP}/ 2>&1`";
   if [[ $? -ne '0' ]]; then
      STATUS=1; if [[ ${ALERT} ]]; then ALERT="$ALERT ; Failed to upload PM data for SAP"; else ALERT="Failed to upload PM data for SAP"; fi
   fi

   # DC
   DC_MSG=''
   FLAG='0'
   for dcClli in $DCLIST; do
      val="$val `$RSYNC $RSYNCOPT --rsh="${RSH}" ${STAGE_DATA_DC}/./${dcClli}/${D}/* ${DEST_IP}:${DEST_DATA_DC}/ 2>&1`";
      if [[ $? -eq '0' ]]; then
         FLAG=`echo "$FLAG + 0" | bc`;
      else
         FLAG=`echo "$FLAG + 1" | bc`; DC_MSG="$DC_MSG $dcClli"
      fi
   done

   if [[ $FLAG -ne '0' ]]; then STATUS=1; fi

   if [[ $DC_MSG ]]; then 
      if [[ ${ALERT} ]]; then ALERT="$ALERT ; Failed to upload PM data for the following DCs${DC_MSG}"; else ALERT="Failed to upload PM data for the following DCs ${DC_MSG}"; fi 
   fi

}

# MAIN # Attempt transfer
D=''; D=`date -u +%Y/%m/%d`;

upload
echo "$val"
if [[ $STATUS -ne '0' ]]; then
   write_pm_status "PROXY_PM_STATUS : $STATUS , ALERT_DETAILS : $ALERT."
   exit 2
fi

if [[ ! $ALERT ]]; then ALERT="NIL!"; fi
write_pm_status "PROXY_PM_STATUS : $STATUS , ALERT_DETAILS : $ALERT"

#

