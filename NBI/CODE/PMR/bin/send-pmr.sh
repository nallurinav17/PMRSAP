#!/bin/bash

# Read Configuration and quit if not Master
cd /data/scripts/PMR
. /data/scripts/PMR/etc/PMRConfig.cfg

#/data/mgmt/pmr/data/pm/SAP/ guavusv@10.194.103.254:/u06/apps/ehealth565/publishStats/guavus_visp/SAP/
SRSYNC="/usr/bin/rsync -avzre ssh" 

if [[ `am_i_master` -ne 0 ]] ; then exit 0; fi

D1=`date -d '1 day ago' +%Y/%m/%d`
D2=`date +%Y/%m/%d`

function write_nbi_event {
  printf "%s [%s] %s\n" "`date`" "`basename $0`" "$*" >> ${NBIEVENTLOGF}
}

function write_nbi_log {
  printf "%s [%s] %s\n" "`date`" "`basename $0`" "$*" >> ${NBITRXLOGF}
}

function rotateEventLog {
/bin/find ${VLOG}/ -type f -mtime +${NBIEVENTLOGROTATE} -name NBIEvents* -exec rm -rf {} \;
DATE=`date +%Y%m%d`
if [[ ! -e ${NBIEVENTLOGF}.${DATE}.gz ]]; then
  if [[ -e ${NBIEVENTLOGF} ]]; then
  /bin/gzip -cf ${NBIEVENTLOGF} > ${NBIEVENTLOGF}.${DATE}.gz
  if [[ $? -eq '0' ]]; then echo > ${NBIEVENTLOGF}; fi
  fi
fi
}

function rotateTrxLog {
/bin/find ${VLOG}/ -type f -mtime +${NBITRXLOGROTATE} -name NBIDataTransfer* -exec rm -rf {} \;
DATE=`date +%Y%m%d`
if [[ ! -e ${NBITRXLOGF}.${DATE}.gz ]]; then
  if [[ -e ${NBITRXLOGF} ]]; then
  /bin/gzip -cf ${NBITRXLOGF} > ${NBITRXLOGF}.${DATE}.gz
  if [[ $? -eq '0' ]]; then echo > ${NBITRXLOGF}; fi
  fi
fi
}

function raiseTrap {
  /usr/bin/snmptrap -v 2c -c public ${PMRMASTER} "" .1.3.6.1.4.1.37140.3.0.24 .1.3.6.1.4.1.37140.1.2.6.1 string 'PM' .1.3.6.1.4.1.37140.1.2.6.2 string "$*" .1.3.6.1.4.1.37140.1.2.6.3 string "`date`"
}

function calibrateDays {
 DAYS='';DT=''
 while [[ $nbiSyncDays -ne '-1' ]]; do
  DT=`date -d "$nbiSyncDays day ago" +%Y%m%d`
  DAYS="$DAYS $DT"
  nbiSyncDays=`expr $sync - 1`
 done
}

function sanitizeNbiFile {

 # Sync Days (Default:2)
 if [[ $nbiSyncDays == '' ]]; then nbiSyncDays=2; sanityFlag=`expr $sanityFlag + 0`; fi

 # IP Address (MUST)
 if [[ $nbiIpAddr == '' || $nbiIpAddr !~ /\d+.\d+.\d+.\d+/ ]]; then sanityFlag=`expr $sanityFlag + 1`; fi

 # User (MUST)
 if [[ $nbiUser == '' ]]; then sanityFlag=`expr $sanityFlag + 2`; fi

 # Password (Default:KeysBased/PasswordLess)
 if [[ $nbiPassword == '' ]]; then ; sanityFlag=`expr $sanityFlag + 0`; fi

 # DestPath (Default:/tmp/nbi)
 if [[ $nbiDestPath == '' ]]; then nbiDestPath="/tmp/nbi"; sanityFlag=`expr $sanityFlag + 0`; fi

 # nbiSwitch (MUST)
 if [[ $nbiSwitch == '' ]]; then sanityFlag=`expr $sanityFlag + 4` fi 

 # nbiName (MUST)
 if [[ $nbiName == '' ]]; then sanityFlag=`expr $sanityFlag + 8`; fi

 # nbiHostname 
 if [[ $nbiHostname ]]; then sanityFlag=`expr $sanityFlag + 0`; fi

}

function calibrateIncludeDc {
 nbiIncludeDc=`echo $nbiIncludeDc | sed 's/\s/|/g'`
 DCLIST=`/bin/ls -ld ${SANDATA}/${DCT}/* | grep ^d | egrep "$nbiIncludeDc" | awk -F/ '{print $NF}'`
}

function calibrateExcludeDc {
 nbiExcludeDc=`echo $nbiExcludeDc | sed 's/\s/|/g'`
 DCLIST=`/bin/ls -ld ${SANDATA}/${DCT}/* | grep ^d | egrep "$nbiExcludeDc" | awk -F/ '{print $NF}'`
}

function syncPMData {
 DCTYPE=''; 
 DCTYPE=`/bin/ls -ld ${SANDATA}/* | grep ^d | awk -F/ '{print $NF}'`
 for file in `/bin/ls $BASEPATH/etc/NBI/nbi.*.prop`; do

   # Reset NBI properties before loading next file.
   nbiSyncDays='';nbiIpAddr='';nbiName='';nbiSwitch='';nbiHostname='';nbiUser='';nbiPassword='';nbiDestPath='';nbiIncludeDc='';nbiExcludeDc='';

   source ${file}
   if [[ $? -ne 0 ]]; then write_nbi_event "Error: Unable to load source : $file Skipping...!"; continue; fi

   # Perform sanity checks on loaded NBI properties file.
   sanityFlag=0 ; sanitizeNbiFile;
   if [[ $sanityFlag -ne 0 ]]; then write_nbi_event "Error (code:$sanityFlag) : Malformed NBI property file : $file Skipping...!"; continue; fi

   # Calculate days to be sync'ed
   calibrateDays

   for DCT in ${DCTYPE}; do
    count=0;flag=0;
    # SAP has one level lesser of directory than other DCs, which defines type of DC (VISP/PNSA/CMDS).
    if [[ ${DCT} == 'SAP' ]]; then
       write_nbi_event "Transferring data for ${DCT} to NBI host : $nbiIpAddr"
       for D in $DAYS; do
       while [[ ${count} -lt '3' ]]; do
          write_nbi_log "`$SRSYNC ${SANDATA}/${DCT}/${D} ${nbiUser}@${nbiIpAddr}:${nbiDestPath}/`"  
	  if [[ $? -ne '0' ]]; then 
                count=`expr $count + 1`
 	        write_nbi_event "Failed to transfer data for ${DCT} ${D} to NBI host : $nbiIpAddr Transfer attempt $count."
		raiseTrap "${nbiIpAddr}"
	  else 
		write_nbi_event "Successfully transferred data for ${DCT} ${D} to NBI host : ${nbiIpAddr} Transfer attempt $count."
	        count=0
          fi
       done
       done
    else
       for D in $DAYS; do

         # Measure Include/Exclude DC List among DC types (VISP/PNSA/CMDS)
         DCLIST=''; 
         if [[ $nbiIncludeDc -ne '' ]]; then calibrateIncludeDc;
         elif [[ $nbiExcludeDc -ne '' ]]; then calibrateExcludeDc;
         else 
           DCLIST=`/bin/ls -ld ${SANDATA}/${DCT}/* | grep ^d | awk -F/ '{print $NF}'`
         fi       

         for DC in $DCLIST; do 
	    write_nbi_event "Transferring data for ${DCT} DC : ${DC} to NBI host : $nbiIpAddr"
            while [[ ${count} -lt '3' ]]; do
              write_nbi_log "`$SRSYNC ${SANDATA}/${DCT}/${DC}/${D} ${nbiUser}@${nbiIpAddr}:${nbiDestPath}/`"
  	      if [[ $? -ne '0' ]]; then
                count=`expr $count + 1`
                write_nbi_event "Failed to transfer data for ${DCT} DC : ${DC} ${D} to NBI host : $nbiIpAddr Transfer attempt $count."
		raiseTrap "${nbiIpAddr}"
              else
                write_nbi_event "Successfully transferred data for ${DCT} DC : ${DC} ${D} to NBI host : $nbiIpAddr Transfer attempt $count."
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



