#!/bin/bash

# Read Configuration and quit if not Master
cd /data/scripts/PMR
. /data/scripts/PMR/etc/PMRConfig.cfg

#/usr/bin/rsync -ravz --rsh="/usr/bin/sshpass -p $PASS ssh -o StrictHostKeyChecking=no -l $USER" /data/mgmt/pmr/data/pm/VISP/SMLAB/2014/07/08 10.10.21.66:/tmp
SRSYNC="/usr/bin/rsync -avzrR" 

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
  #/usr/bin/snmptrap -v 2c -c public ${PMRMASTER} "" .1.3.6.1.4.1.37140.3.0.24 .1.3.6.1.4.1.37140.1.2.6.1 string 'PM' .1.3.6.1.4.1.37140.1.2.6.2 string "$1" .1.3.6.1.4.1.37140.1.2.6.3 string "`date`"
  /usr/bin/snmptrap -v 2c -c 2Y2LHTZP31 ${PMRMASTER} "" .1.3.6.1.4.1.37140.3.0.24 .1.3.6.1.4.1.37140.1.2.6.1 string 'PM' .1.3.6.1.4.1.37140.1.2.6.2 string "$1" .1.3.6.1.4.1.37140.1.2.6.3 string "`date`"
}

function calibrateDays {
 DAYS='';DT=''
 while [[ $nbiSyncDays -ne '-1' ]]; do
  DT=`date -d "$nbiSyncDays day ago" +%Y/%m/%d`
  DAYS="$DAYS $DT"
  nbiSyncDays=`expr $nbiSyncDays - 1`
 done
}

function sanitizeNbiFile {

 # Sync Days (Default:2)
 if [[ $nbiSyncDays == '' ]]; then nbiSyncDays=2; sanityFlag=`expr $sanityFlag + 0`; fi

 # IP Address (MUST)
 if [[ $nbiIpAddr == '' ]] ; then sanityFlag=`expr $sanityFlag + 1`; fi
 #$nbiIpAddr ]]; then sanityFlag=`expr $sanityFlag + 1`; fi

 # User (MUST)
 if [[ $nbiUser == '' ]]; then sanityFlag=`expr $sanityFlag + 2`; fi

 # Password (Default:KeysBased/PasswordLess). Exported the password variable for RSYNC using SSHPASS utility.
 if [[ $nbiPassword == '' ]]; then sanityFlag=`expr $sanityFlag + 0`; nbiPassword="NULL"; fi
 export SSHPASS="${nbiPassword}"

 # DestPath (Default:/tmp/nbi)
 if [[ $nbiDestPath == '' ]]; then nbiDestPath="/tmp/nbi"; sanityFlag=`expr $sanityFlag + 0`; fi

 # nbiSwitch (MUST)
 if [[ $nbiSwitch == '' ]]; then sanityFlag=`expr $sanityFlag + 4`; fi 

 # nbiName (MUST)
 if [[ $nbiName == '' ]]; then sanityFlag=`expr $sanityFlag + 8`; fi

 # nbiHostname 
 if [[ $nbiHostname == '' ]]; then sanityFlag=`expr $sanityFlag + 0`; fi
}

function calibrateIncludeDc {
 nbiIncludeDc=`echo $nbiIncludeDc | sed 's/,/|/g' | sed 's/\s//g'`
 DCLIST=`/bin/ls -ld ${SANDATA}/${DCT}/* | grep ^d | awk -F/ '{print $NF}' | egrep -w "$nbiIncludeDc"`
}

function calibrateExcludeDc {
 nbiExcludeDc=`echo $nbiExcludeDc | sed 's/,/|/g' | sed 's/\s//g'`
 DCLIST=`/bin/ls -ld ${SANDATA}/${DCT}/* | grep ^d | awk -F/ '{print $NF}' | egrep -vw "$nbiExcludeDc"`
}

function calibrateIncludeType {
 nbiIncludeType=`echo $nbiIncludeType | sed 's/,/|/g' | sed 's/\s//g'`
 DCTYPE=`/bin/ls -ld ${SANDATA}/* | grep ^d | awk -F/ '{print $NF}' | egrep -w "$nbiIncludeType"`
}

function calibrateExcludeType {
 nbiExcludeType=`echo $nbiExcludeType | sed 's/,/|/g' | sed 's/\s//g'`
 DCTYPE=`/bin/ls -ld ${SANDATA}/* | grep ^d | awk -F/ '{print $NF}' | egrep -vw "$nbiExcludeType"`
}

function syncPMData {

 for file in `/bin/ls $BASEPATH/etc/NBI/nbi.*.prop`; do
 
   # Reset NBI properties before loading next file.
   DCTYPE='';nbiSyncDays='';nbiIpAddr='';nbiName='';nbiSwitch='';nbiHostname='';nbiUser='';nbiPassword='';nbiDestPath='';nbiIncludeDc='';nbiExcludeDc='';nbiIncludeType='';nbiExcludeType='';

   source ${file}
   if [[ $? -ne 0 ]]; then write_nbi_event "Error: Unable to load source : $file Skipping...!"; continue; fi
   
   # Perform sanity checks on loaded NBI properties file.
   sanityFlag=0 ; sanitizeNbiFile;
   if [[ $sanityFlag -ne 0 ]]; then write_nbi_event "Error (code:$sanityFlag) : Malformed NBI property file : $file Skipping...!"; continue; fi

   # Switch to skip NBI target data send
   if [[ $nbiSwitch == 'off' ]]; then write_nbi_event "NBI host : $nbiName : $nbiIpAddr transfer turned OFF. Skipping...!"; continue; fi

   # Measure Include/Exclude DC types (VISP/PNSA/CMDS/PNSA) - DCTYPE
   if [[ "${nbiIncludeType}" != '' ]]; then calibrateIncludeType;
   elif [[ "${nbiExcludeType}" != '' ]]; then calibrateExcludeType;
   else
      DCTYPE=`/bin/ls -ld ${SANDATA}/* | grep ^d | awk -F/ '{print $NF}'`
   fi


   # Calculate days to be sync'ed
   calibrateDays

   for DCT in ${DCTYPE}; do
    # SAP has one level lesser of directory than other DCs, which defines type of DC (VISP/PNSA/CMDS).
    if [[ ${DCT} == 'SAP' ]]; then
       write_nbi_event "Transferring data for ${DCT} to NBI host : $nbiIpAddr"
       for D in $DAYS; do
       count=0
       if [[ ! -e ${SANDATA}/${DCT}/${D} ]]; then write_nbi_event "Source ${SANDATA}/${DCT}/${D} does not exists. Skipping...!"; continue; fi 
       while [[ ${count} -lt '3' ]]; do

	  write_nbi_log "Sending ${SANDATA}/${DCT}/${D} TO ${nbiUser}@${nbiIpAddr} UNDER ${nbiDestPath} "
          #$SRSYNC ${SANDATA}/${DCT}/${D} ${nbiUser}@${nbiIpAddr}:${nbiDestPath}/ 2>&1 | tr '\n' ' ' >> ${NBITRXLOGF} 
	  #RSH='';RSH="/data/scripts/PMR/bin/sshpass -p $nbiPassword ssh -o StrictHostKeyChecking=no -l $nbiUser"
	 
  	  # Used ./ with rsync -R option in order to create the dctype directory structure at remote server, in following rsync command. 
	  RSH='';RSH="/data/scripts/PMR/bin/sshpass -e ssh -o StrictHostKeyChecking=no -l $nbiUser"
	  $SRSYNC --rsh="${RSH}" ${SANDATA}/./${DCT}/${D} ${nbiIpAddr}:${nbiDestPath}/ 2>&1 | tr '\n' ' ' >> ${NBITRXLOGF}

	  if [[ ${PIPESTATUS[0]} -ne '0' || $? -ne '0' ]]; then 
                count=`expr $count + 1`
 	        write_nbi_event "Failed to transfer data for ${DCT} ${D} to NBI host : $nbiIpAddr Transfer attempt $count."
		raiseTrap "${nbiIpAddr}"
	  else 
		write_nbi_event "Successfully transferred data for ${DCT} ${D} to NBI host : ${nbiIpAddr} Transfer attempt $count."
	        count=3
          fi
	  echo "" >> ${NBITRXLOGF}
       done
       done
    else
       for D in $DAYS; do

         # Measure Include/Exclude DC List among DC types (VISP/PNSA/CMDS)
         DCLIST=''; 
         if [[ "${nbiIncludeDc}" != '' ]]; then calibrateIncludeDc;
         elif [[ "${nbiExcludeDc}" != '' ]]; then calibrateExcludeDc;
         else 
           DCLIST=`/bin/ls -ld ${SANDATA}/${DCT}/* | grep ^d | awk -F/ '{print $NF}'`
         fi       

         for DC in $DCLIST; do 
	    write_nbi_event "Transferring data for ${DCT} DC : ${DC} to NBI host : $nbiIpAddr"
	    count=0

	    if [[ ! -e ${SANDATA}/${DCT}/${DC}/${D} ]]; then write_nbi_event "Source ${SANDATA}/${DCT}/${DC}/${D} does not exists. Skipping...!"; continue; fi
	    write_nbi_log "------------------------------------------------------------------------"

            while [[ ${count} -lt '3' ]]; do

	      write_nbi_log "Sending ${SANDATA}/${DCT}/${DC}/${D} TO ${nbiUser}@${nbiIpAddr} UNDER ${nbiDestPath} "
              #$SRSYNC ${SANDATA}/${DCT}/${DC}/${D} ${nbiUser}@${nbiIpAddr}:${nbiDestPath}/ 2>&1 | tr '\n' ' ' >> ${NBITRXLOGF}
	      #RSH='';RSH="/data/scripts/PMR/bin/sshpass -p $nbiPassword ssh -o StrictHostKeyChecking=no -l $nbiUser"

  	      # Used ./ with rsync -R option in order to create the dctype directory structure at remote server, in following rsync command. 
	      RSH='';RSH="/data/scripts/PMR/bin/sshpass -e ssh -o StrictHostKeyChecking=no -l $nbiUser"
              $SRSYNC --rsh="${RSH}" ${SANDATA}/./${DCT}/${DC}/${D} ${nbiIpAddr}:${nbiDestPath}/ 2>&1 | tr '\n' ' ' >> ${NBITRXLOGF}

              if [[ ${PIPESTATUS[0]} -ne '0' || $? -ne '0' ]]; then
                count=`expr $count + 1`
                write_nbi_event "Failed to transfer data for ${DCT} DC : ${DC} ${D} to NBI host : $nbiIpAddr Transfer attempt $count."
		raiseTrap "${nbiIpAddr}"
              else
                write_nbi_event "Successfully transferred data for ${DCT} DC : ${DC} ${D} to NBI host : $nbiIpAddr Transfer attempt $count."
		count=3
              fi
	      echo "" >> ${NBITRXLOGF}
	    done
         done
       done
    fi
   write_nbi_log "------------------------------------------------------------------------"
   done
 done
write_nbi_event "------------------------------------------------------------------------ Execution Completed!"

}


### MAIN

rotateEventLog
rotateTrxLog
syncPMData


