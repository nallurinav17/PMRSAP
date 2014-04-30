#!/bin/bash

# Read Configuration and quit if not Master
cd /data/scripts/PMR
. /data/scripts/PMR/etc/PMRConfig.cfg

YYYY=`/bin/date -d '1 hour ago' +%Y`
mm=`/bin/date -d '1 hour ago' +%m`
dd=`/bin/date -d '1 hour ago' +%d`
HH=`/bin/date -d '1 hour ago' +%H`

if [[ `am_i_master` -ne 0 ]] ; then exit 0; fi

for VZWIT in ${PMDEST}; do

write_log "Pushing data files from SAN repository to ${VZWIT}"
write_log "`$RSYNC -v $RSYNCOPT ${PMDESTU}@${VZWIT}:${DATAPATH}/${YYYY}/${mm}/${dd}/${HH} ${PMDESTPATH}/ | tail -2  | tr '\n' ' ' `"
if [[ $? -eq 0 ]] ; then write_log "Sync Complete!" ; exit 0; else write_log "Sync Failed, Retrying..." ; 
fi

done

write_log "Push failed for all PM destinations!"

