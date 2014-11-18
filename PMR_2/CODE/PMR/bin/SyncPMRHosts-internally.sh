#!/bin/bash

# Read Configuration and quit if not Master
cd /data/scripts/PMR
. /data/scripts/PMR/etc/PMRConfig.cfg
if [[ `am_i_master` -ne 0 ]] ; then exit 0; fi

if /sbin/ifconfig -a | grep -q ${PMRHOST1} ; then REMOTEHOST=${PMRHOST2}; else REMOTEHOST=${PMRHOST1} ; fi

write_log "Syncing with ${REMOTEHOST}"
write_log "`$RSYNC -v $RSYNCOPT $BASEPATH/* root@${REMOTEHOST}:$BASEPATH/ | tail -2  | tr '\n' ' ' `"
if [[ $? -eq 0 ]] ; then write_log "Sync Complete" ; else write_log "Sync Failed" ; fi

exit 0
