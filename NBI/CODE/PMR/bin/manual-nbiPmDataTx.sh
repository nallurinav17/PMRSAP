#!/bin/bash

# Read Configuration and quit if not Master
cd /data/scripts/PMR
. /data/scripts/PMR/etc/PMRConfig.cfg


#/usr/bin/rsync -ravz --rsh="/usr/bin/sshpass -p $PASS ssh -o StrictHostKeyChecking=no -l $USER" /data/mgmt/pmr/data/pm/VISP/SMLAB/2014/07/08 10.10.21.66:/tmp
SRSYNC="/usr/bin/rsync -avzrR" 

if [[ `am_i_master` -ne 0 ]] ; then exit 0; fi

D1=`date -d '1 day ago' +%Y/%m/%d`
D2=`date +%Y/%m/%d`

function raiseTrap {
  /usr/bin/snmptrap -v 2c -c public ${PMRMASTER} "" .1.3.6.1.4.1.37140.3.0.24 .1.3.6.1.4.1.37140.1.2.6.1 string 'PM' .1.3.6.1.4.1.37140.1.2.6.2 string "$1" .1.3.6.1.4.1.37140.1.2.6.3 string "`date`"
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

   # Measure Include/Exclude DC types (VISP/PNSA/CMDS/PNSA) - DCTYPE
   if [[ "${nbiIncludeType}" != '' ]]; then calibrateIncludeType;
   elif [[ "${nbiExcludeType}" != '' ]]; then calibrateExcludeType;
   else
      DCTYPE=`/bin/ls -ld ${SANDATA}/* | grep ^d | awk -F/ '{print $NF}'`
   fi


   for DCT in ${DCTYPE}; do
    # SAP has one level lesser of directory than other DCs, which defines type of DC (VISP/PNSA/CMDS).
    if [[ ${DCT} == 'SAP' ]]; then
       echo "--------- Transferring data for ${DCT} to NBI host : $nbiIpAddr"
       for D in $DAYS; do
       count=0
       if [[ ! -e ${SANDATA}/${DCT}/${D} ]]; then echo "--------- Source ${SANDATA}/${DCT}/${D} does not exists. Skipping...!"; continue; fi 
       while [[ ${count} -lt '3' ]]; do

	  echo "--------- Sending ${SANDATA}/${DCT}/${D} TO ${nbiUser}@${nbiIpAddr} UNDER ${nbiDestPath} "
	 
  	  # Used ./ with rsync -R option in order to create the dctype directory structure at remote server, in following rsync command. 
	  RSH='';RSH="/data/scripts/PMR/bin/sshpass -e ssh -o StrictHostKeyChecking=no -l $nbiUser"
	  $SRSYNC --rsh="${RSH}" ${SANDATA}/./${DCT}/${D} ${nbiIpAddr}:${nbiDestPath}/ 2>&1 | tr '\n' ' '

	  if [[ ${PIPESTATUS[0]} -ne '0' || $? -ne '0' ]]; then 
                count=`expr $count + 1`
 	        echo "--------- Failed to transfer data for ${DCT} ${D} to NBI host : $nbiIpAddr Transfer attempt $count."
		#raiseTrap "${nbiIpAddr}"
	  else 
		echo ""; echo "--------- Successfully transferred data for ${DCT} ${D} to NBI host : ${nbiIpAddr} Transfer attempt $count."
	        count=3
          fi
	  echo ""
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
	    echo "--------- Transferring data for ${DCT} DC : ${DC} to NBI host : $nbiIpAddr"
	    count=0

	    if [[ ! -e ${SANDATA}/${DCT}/${DC}/${D} ]]; then echo "--------- Source ${SANDATA}/${DCT}/${DC}/${D} does not exists. Skipping...!"; continue; fi
	    echo "------------------------------------------------------------------------"

            while [[ ${count} -lt '3' ]]; do

	      echo "--------- Sending ${SANDATA}/${DCT}/${DC}/${D} TO ${nbiUser}@${nbiIpAddr} UNDER ${nbiDestPath} "

  	      # Used ./ with rsync -R option in order to create the dctype directory structure at remote server, in following rsync command. 
	      RSH='';RSH="/data/scripts/PMR/bin/sshpass -e ssh -o StrictHostKeyChecking=no -l $nbiUser"
              $SRSYNC --rsh="${RSH}" ${SANDATA}/./${DCT}/${DC}/${D} ${nbiIpAddr}:${nbiDestPath}/ 2>&1 | tr '\n' ' '

              if [[ ${PIPESTATUS[0]} -ne '0' || $? -ne '0' ]]; then
                count=`expr $count + 1`
                echo "--------- Failed to transfer data for ${DCT} DC : ${DC} ${D} to NBI host : $nbiIpAddr Transfer attempt $count."
		#raiseTrap "${nbiIpAddr}"
              else
                echo ""; echo "--------- Successfully transferred data for ${DCT} DC : ${DC} ${D} to NBI host : $nbiIpAddr Transfer attempt $count."
		count=3
              fi
	      echo ""
	    done
         done
       done
    fi
   echo "------------------------------------------------------------------------"
   done
 #done

}

function usage {

echo "

Usage:
	--ip 		(Mandatory)	=>	IP address of the target NBI server. 
	--user		(Mandatory)	=>	Username to transfer PM data.
	--destPath	(Optional)	=>	Destination path to stage data in.
	--includeDC	(Optional)	=>	Comma separated list of DC names to be included, higher in precedence than excludeDC. Defaults to include all.
	--excludeDC	(Optional)	=>	Comma separated list of DC names to be excluded, lower in precedence than includeDC. Defaults to exclude none.
	--includeType	(Optional)	=>	Comma separated list of source data type to be included (PNSA/CMDS/VISP/SAP), higher in precedence than excludeType. Defaults to include all.
	--excludeType	(Optional)	=>	Comma separated list of source data type to be included (PNSA/CMDS/VISP/SAP), lower in precedence than includeType. Defaults to exclude none.

Note: 	You 'll be prompted to supply the password, incase you have password-less/key-based access to the downstream server, hit enter and leave the password blank to proceed.


Example: 
	`basename $0` --ip='10.10.21.67' --user='root' --destPath='/data/nbi' --includeDC='Bloomington,Azusa,Chantily' --excludeType='SAP'
	
	Or,

	`basename $0` --ip='10.10.21.67' --user='root' --destPath='/data/nbi' --includeType='SAP'

"
}

### MAIN
# Reset NBI properties.
DCTYPE='';nbiSyncDays='';nbiIpAddr='';nbiUser='';nbiPassword='';nbiDestPath='';nbiIncludeDc='';nbiExcludeDc='';nbiIncludeType='';nbiExcludeType='';


for option in `echo $* | awk '{print $0}'`
do
  key=`echo $option | cut -d '=' -f1 | sed 's/\s+//g'`
  case $key in
	--user)
		nbiUser=`echo $option | cut -d '=' -f2`
	;;

	--ip)
		nbiIpAddr=`echo $option | cut -d '=' -f2`
	;;

	--destPath)
		nbiDestPath=`echo $option | cut -d '=' -f2`
	;;

	--includeDC)
		nbiIncludeDc=`echo $option | cut -d '=' -f2`
	;;

	--excludeDC)
		nbiExcludeDc=`echo $option | cut -d '=' -f2`
	;;

	--includeType)
		nbiIncludeType=`echo $option | cut -d '=' -f2`
	;;

	--excludeType)
		nbiExcludeType=`echo $option | cut -d '=' -f2`
	;;

esac
done

if [[ ! ${nbiIpAddr} || ! ${nbiUser} ]]; then usage; exit; fi

#clear
clear
echo -e "\n------------------------------------------------------------------------ Execution started at : `date '+%Y-%m-%d %H:%M:%S'`"
# Get password before sanitizing.
printf "Provide password for the outbound destination server : "; /bin/stty -echo; read nbiPassword; /bin/stty echo; echo ""

# Perform sanity checks on loaded NBI properties file.
sanityFlag=0 ; sanitizeNbiFile;
if [[ $sanityFlag -ne 0 ]]; then echo "--------- Error (code:$sanityFlag) : Malformed NBI properties supplied. Skipping...!"; exit; fi

echo "--------- Synchronizing last 3 days of data including today, with properties; user:$nbiUser, ip:$nbiIpAddr, destPath:$nbiDestPath"

# Calculate days to be sync'ed.
calibrateDays

# Execute sync.
syncPMData
echo "------------------------------------------------------------------------ Execution Completed at : `date '+%Y-%m-%d %H:%M:%S'`"


