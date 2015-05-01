#!/bin/bash

# Read Configuration and quit if not Master
cd /data/scripts/PMR
. /data/scripts/PMR/etc/PMRConfig.cfg
#if [[ `am_i_master` -ne 0 ]] ; then exit 0; fi

#if /sbin/ifconfig -a | grep -q ${PMRMASTER} ; then REMOTEHOST=${PMRHOST2}; else REMOTEHOST=${PMRHOST1} ; fi

write_log "Syncing scripts from SAN repository through ${PMRHOST1}"
#val=`$RSYNC -v $RSYNCOPT root@${PMRHOST1}:${SAPREPO}/* $BASEPATH/ 2>&1 | tr '\n' ' '`; 
val=`$RSYNC -v $RSYNCOPT root@${PMRHOST1}:${SAPREPO}/* $BASEPATH/ 2>&1`
if [[ $? -ne '0' ]]; then
   write_log "$val"; write_log "Sync Failed, Retrying..."
   write_log "Syncing scripts from SAN repository through ${PMRHOST2}"
   val='';val=`$RSYNC -v $RSYNCOPT root@${PMRHOST2}:${SAPREPO}/* $BASEPATH/ 2>&1`
  if [[ $? -eq 0 ]] ; then write_log "$val"; write_log "Sync Complete!" ; else write_log "$val"; write_log "Sync Failed, Exit!" ; fi
else
write_log "$val"
write_log "Sync Complete!"
fi

exit 0
