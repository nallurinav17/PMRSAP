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

function upload {
   val="$val `$RSYNC $RSYNCOPT ${STAGE_DATA_SAP}/./${D}/* ${DEST_USER}@${DEST_IP}:${DEST_DATA_SAP}/ 2>&1`";
   if [[ $? -eq '0' ]]; then
      STATUS=0;
   else
      STATUS=2; if [[ ${ALERT} ]]; then ALERT="$ALERT ; Failed to upload PM data for SAP"; else ALERT="Failed to upload PM data for SAP"; fi
   fi

   # DC
   DC_MSG=''
   for dcClli in $DCLIST; do
      val="$val `$RSYNC $RSYNCOPT ${STAGE_DATA_DC}/./${dcClli}/${D}/* ${DEST_USER}@${DEST_IP}:${DEST_DATA_DC}/ 2>&1`";
      if [[ $? -eq '0' ]]; then
         STATUS=0;
      else
         STATUS=2; DC_MSG="$DC_MSG $dcClli"
      fi
   done

   if [[ $DC_MSG ]]; then 
      if [[ ${ALERT} ]]; then ALERT="$ALERT ; Failed to upload PM data for the following DCs${DC_MSG}"; else ALERT="Failed to upload PM data for the following DCs ${DC_MSG}"; fi 
   fi

   # TRAPS
   #val="$val `$RSYNC $RSYNCOPT ${STAGE_TRAPS}/./* ${DEST_USER}@${DEST_IP}:${DEST_TRAPS}/ 2>&1`";
   #if [[ $? -eq '0' ]]; then
   #   STATUS=0;
   #else
   #   STATUS=2; if [[ ${ALERT} ]]; then ALERT="$ALERT ; Failed to upload traps log files."; else ALERT="Failed to upload traps log files."; fi
   #fi

}

function download {
   val="$val `$RSYNC $RSYNCOPT ${SRC_USER}@${SRC_IP}:${SRC_DATA_SAP}/./${D}/* ${STAGE_DATA_SAP}/ 2>&1`";
   if [[ $? -eq '0' ]]; then
      STATUS=0 
   else 
      STATUS=1; if [[ ${ALERT} ]]; then ALERT="$ALERT ; Failed to download PM data for SAP"; else ALERT="Failed to download PM data for SAP"; fi
   fi

   # DC
   DC_MSG=''
   for dcClli in $DCLIST; do
      val="$val `$RSYNC $RSYNCOPT ${SRC_USER}@${SRC_IP}:${SRC_DATA_DC}/./${dcClli}/${D}/* ${STAGE_DATA_DC}/ 2>&1`";
      if [[ $? -eq '0' ]]; then
         STATUS=0;
      else
         STATUS=1; DC_MSG="$DC_MSG $dcClli"
      fi
   done

   if [[ $DC_MSG ]]; then
      if [[ ${ALERT} ]]; then ALERT="$ALERT ; Failed to download PM data for the following DCs${DC_MSG}"; else ALERT="Failed to download PM data for the following DCs${DC_MSG}"; fi
   fi

   # TRAPS
   #val="$val `$RSYNC $RSYNCOPT ${SRC_USER}@${SRC_IP}:${SRC_TRAPS}/./snmptrapd.log* ${STAGE_TRAPS}/ 2>&1`";
   #if [[ $? -eq '0' ]]; then
   #   STATUS=0
   #else
   #   STATUS=1; if [[ ${ALERT} ]]; then ALERT="$ALERT ; Failed to download traps log files."; else ALERT="Failed to download traps log files."; fi
   #fi

}


# Attempt transfer
D=''; D=`date +%Y/%m/%d`;

download
echo "$val"
if [[ $STATUS -ne '0' ]]; then 
   write_pm_status "PROXY_PM_STATUS : $STATUS , ALERT_DETAILS : $ALERT"
   exit 1
fi 

upload
echo "$val"
if [[ $STATUS -ne '0' ]]; then
   write_pm_status "PROXY_PM_STATUS : $STATUS , ALERT_DETAILS : $ALERT"
   exit 2
fi

if [[ ! $ALERT ]]; then ALERT="NIL!"; fi
write_pm_status "PROXY_PM_STATUS : $STATUS , ALERT_DETAILS : $ALERT"

