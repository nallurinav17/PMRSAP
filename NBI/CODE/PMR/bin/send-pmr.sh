#!/bin/bash

# Read Configuration and quit if not Master
cd /data/scripts/PMR
. /data/scripts/PMR/etc/PMRConfig.cfg

SRSYNC="/usr/bin/rsync -avzre ssh" /data/mgmt/pmr/data/pm/SAP/ guavusv@10.194.103.254:/u06/apps/ehealth565/publishStats/guavus_visp/SAP/

if [[ `am_i_master` -ne 0 ]] ; then exit 0; fi

D1=`date -d '1 day ago' +%Y/%m/%d`
D2=`date +%Y/%m/%d`

function write_nbi_event {
  printf "%s [%s] %s\n" "`date`" "`basename $0`" "$*" >> ${NBIEVENTLOGF}
}

function write_nbi_log {
  printf "%s [%s] %s\n" "`date`" "`basename $0`" "$*" >> ${NBITRXLOGF}
}

function raiseTrap {

/usr/bin/snmptrap -v 2c -c public ${PMRMASTER} "" .1.3.6.1.4.1.37140.3.0.24 .1.3.6.1.4.1.37140.1.2.6.1 string 'PM' .1.3.6.1.4.1.37140.1.2.6.2 string "$*" .1.3.6.1.4.1.37140.1.2.6.3 string "`date`"

}

function syncPMData {
 DCTYPE=`/bin/ls -d ${SANDATA}/* | awk -F/ '{print $NF}'`
 for DCT in ${DCTYPE}; do
   for NBIHOST in ${NBIDESTIPS}; do
    # SAP has one level lesser of directory than other DCs, which defines type of DC (VISP/PNSA/CMDS).
    count=0;flag=0;
    if [[ ${DC} == 'SAP' ]]; then
       write_nbi_event "Transferring data for ${DCT} to NBI host : $NBIHOST"
       for D in $D1 $D2; do
       while [[ ${count} -lt '3' ]]; do
          write_nbi_log "`$SRSYNC ${SANDATA}/${DCT}/${D} ${NBIDESTUSER}@${NBIHOST}:${NBIDESTPATH}/`"  
	  if [[ $? -ne '0' ]]; then 
                count=`expr $count + 1`
 	        write_nbi_event "Failed to transfer data for ${DCT} ${D} to NBI host : $NBIHOST Transfer Failure $count."
		raiseTrap "${NBIHOST}"
	  else 
		write_nbi_event "Successfully transferred data for ${DCT} ${D} to NBI host : $NBIHOST Transfer attempt $count."
	        count=0
          fi
       done
       done
    else
       for D in $D1 $D2; do
       DCLIST=`/bin/ls -d ${SANDATA}/${DCT}/* | awk -F/ '{print $NF}'`
       for DC in $DCLIST; do 
	  write_nbi_event "Transferring data for ${DCT} DC : ${DC} to NBI host : $NBIHOST"
          while [[ ${count} -lt '3' ]]; do
            write_nbi_log "`$SRSYNC ${SANDATA}/${DCT}/${DC}/${D} ${NBIDESTUSER}@${NBIHOST}:${NBIDESTPATH}/`"
  	    if [[ $? -ne '0' ]]; then
                count=`expr $count + 1`
                write_nbi_event "Failed to transfer data for ${DCT} DC : ${DC} ${D} to NBI host : $NBIHOST Transfer Failure $count."
		raiseTrap "${NBIHOST}"
          else
                write_nbi_event "Successfully transferred data for ${DCT} DC : ${DC} ${D} to NBI host : $NBIHOST Transfer attempt $count."
		count=0
          fi
	  done
       done
       done
    fi
   write_nbi_log "------------------------------------------------------------------------"
   done
 done
}



function rotate {

/bin/find ${VLOG}/ -type f -mtime +${TRANSFEREVENTLOGROTATE} -name PMRDataTransferEvent* -exec rm -rf {} \;
DATE=`date +%Y%m%d`
if [[ ! -e ${EVENTLOGF}.${DATE}.gz ]]; then
  if [[ -e ${EVENTLOGF} ]]; then
  /bin/gzip -cf ${EVENTLOGF} > ${EVENTLOGF}.${DATE}.gz
  if [[ $? -eq '0' ]]; then echo > ${EVENTLOGF}; fi
  fi
fi

}





write_log "Syncing scripts from SAN repository through ${PMRHOST1}"
write_log "`$RSYNC -v $RSYNCOPT root@${PMRHOST1}:${SAPREPO}/* $BASEPATH/ | tail -2  | tr '\n' ' ' `"
if [[ $? -eq 0 ]] ; then write_log "Sync Complete!" ; else write_log "Sync Failed, Retrying..." ;
  write_log "Syncing scripts from SAN repository through ${PMRHOST2}"
  write_log "`$RSYNC -v $RSYNCOPT root@${PMRHOST2}:${SAPREPO}/* $BASEPATH/ | tail -2  | tr '\n' ' ' `"
  if [[ $? -eq 0 ]] ; then write_log "Sync Complete!" ; else write_log "Sync Failed, Exit!" ; fi
fi

exit 0
