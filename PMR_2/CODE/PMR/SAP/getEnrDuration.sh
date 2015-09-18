#!/bin/bash

# -------------------------------------------------------------------------------------------------------
BASEPATH=/data/scripts/PMR

# Read main configuration file
source ${BASEPATH}/etc/PMRConfig.cfg

# Read SAP Configuration file
source ${BASEPATH}/etc/SAPConfig.cfg

# Source variables in dc-config.cfg
source ${BASEPATH}/etc/dc-config.cfg
# -------------------------------------------------------------------------------------------------------

TIMESTAMP=`date "+%Y%m%d-%H%M"`

TMPFILE=/tmp/pmr_tmp_$TIMESTAMP

ENTITY='SAP'

write_log "Starting Enrduration check"

NAMENODE="$NETWORK.$CNP0"
OOZIECMD="/opt/oozie/bin/oozie jobs -oozie http://localhost:8080/oozie -jobtype wf -len 30000"
HDFSCMD="$HADOOP dfs -ls "
OOZIEADMI="/data/oozie-admi"
mydate=`date "+%Y-%m-%d" --date="1 days ago"`

#GET OOZIE JOB LIST
$SSH $NAMENODE "${OOZIECMD}" 2>/dev/null | sed -e 's/\s*SUCCEEDED/SUCCEEDED/g' -e 's/\s*KILLED/KILLED/g' -e 's/\s*RUNNING/RUNNING/g' > $TMPFILE.oozie

#if [[ -s $TMPFILE.oozie && $? -eq '0' ]] ; then 

     # get enrjobs
     cat ${TMPFILE}.oozie | awk -v d1="${mydate}" '{if (($5 ~d1) && ($2 ~ /MidmEnr_/)) print $2 "\t" $5 "\t" $6 "\t" $7 "\t" $8 "\t" $1}'|sed -e 's/RUNNING/\tRUNNING/g' -e 's/SUCCEEDED/\tSUCCEEDED/g' -e 's/KILLED/\tKILLED/g' -e 's/_/\t/g'|awk -F "\t" '{printf "%-17s %-8s %-9s %s %s %s %s %s\n", $2, $1, $3, $4, $5, $6, $7, $8}' |sort -k 7 >$TMPFILE.enrjobs

     # get CFI data jobs # Replaced second occurence of underscore.
     cat ${TMPFILE}.oozie | awk -v d1="${mydate}" '{if (($5 ~d1) && ($2 ~ /MidmData_CFI_/)) print $2 "\t" $5 "\t" $6 "\t" $7 "\t" $8 "\t" $1}'| sed -e 's/RUNNING/\tRUNNING/g' -e 's/SUCCEEDED/\tSUCCEEDED/g' -e 's/KILLED/\tKILLED/g' -e 's/_/\t/2'| awk -F "\t" '{printf "%-17s %-8s %-9s %s %s %s %s %s\n", $2, $1, $3, $4, $5, $6, $7, $8}' |sort -k 7 >$TMPFILE.cfi.datajobs

     # get BDA data jobs # Replaced all occurences of underscore.
     cat ${TMPFILE}.oozie | awk -v d1="${mydate}" '{if (($5 ~d1) && ($2 ~ /MidmData_/) && ($2 !~ /CFI/)) print $2 "\t" $5 "\t" $6 "\t" $7 "\t" $8 "\t" $1}'| sed -e 's/RUNNING/\tRUNNING/g' -e 's/SUCCEEDED/\tSUCCEEDED/g' -e 's/KILLED/\tKILLED/g' -e 's/_/\t/g'| awk -F "\t" '{printf "%-17s %-8s %-9s %s %s %s %s %s\n", $2, $1, $3, $4, $5, $6, $7, $8}' |sort -k 7 >$TMPFILE.bda.datajobs

#fi

#
# midmEnrDuration
# 
#if [[ -s $TMPFILE.enrjobs ]]; then
subtot=0;
for dc in ${midmDC}; do
  jobid=`grep $dc $TMPFILE.enrjobs | tail -1 | awk '{print $NF'}`

  str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
  if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi
 
  $SSH $NAMENODE "grep 'map 0% reduce 0%' $OOZIEADMI/$jobid/mapredAction--ssh/*stderr"  2>/dev/null | awk '{print $1" "$2}' | head -1 | sed 's/\//-/g' > $TMPFILE.startTime
  $SSH $NAMENODE "grep 'map 100%' $OOZIEADMI/$jobid/mapredAction--ssh/*stderr" 2>/dev/null | grep 'reduce 100%' | awk '{print $1" "$2}' | head -1 | sed 's/\//-/g' > ${TMPFILE}.endTime;

  startTime=`cat $TMPFILE.startTime 2>/dev/null`;
  endTime=`cat ${TMPFILE}.endTime 2>/dev/null`;

  if [[ -n $startTime && -n $endTime ]] ; then
    start=`date -d "$startTime" +%s`;
    end=`date -d "${endTime}" +%s`;
    elapsed=`expr $end - $start`;
    let "subtot += $elapsed";
    ((sec=elapsed%60, elapsed/=60, min=elapsed%60, hrs=elapsed/60))
    timestring=$(printf "%02d%02d%02d" $hrs $min $sec)
  else 
    timestring="000000"
  fi

  echo "$TIMESTAMP,MIDM,$dcClli,MIDM_data_processing_DC_duration,$timestring" 
  rm -f ${TMPFILE}.endTime $TMPFILE.startTime
done
#fi

#
# midmEnrTotalDuration
#
((sec=subtot%60, subtot/=60, min=subtot%60, hrs=subtot/60))
tottimestring=$(printf "%02d%02d%02d" $hrs $min $sec)
echo "$TIMESTAMP,MIDM,ALL_DC,MIDM_data_processing_total_duration,$tottimestring"

#
# midmDataTransferDuration  - CFI Data Transfers
# 
subtot=0;
for dc in ${midmCFIDC}; do

  jobid=`grep $dc $TMPFILE.cfi.datajobs | tail -1 | awk '{print $8'}`

  str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
  if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi

  $SSH $NAMENODE "grep 'DataTransferActionTime Taken' $OOZIEADMI/$jobid/invokeDataTransferScripts--ssh/*0.stdout" 2>/dev/null | awk '{print $NF}' > ${TMPFILE}.dataTime

  dataTime=`cat ${TMPFILE}.dataTime 2>/dev/null | awk -F "." '{print $1}'`;
  if [[ -n $dataTime ]] ; then
    let "subtot += $dataTime";
    ((sec=dataTime%60, dataTime/=60, min=dataTime%60, hrs=dataTime/60))
    xfertimestring=$(printf "%02d%02d%02d" $hrs $min $sec)
  else 
    xfertimestring="000000"
  fi

  echo "$TIMESTAMP,MIDM,$dcClli,MIDM_data_transfer_DC_duration,$xfertimestring"
  rm -f ${TMPFILE}.dataTime

done

#
# midmDataTotalTransferDuration - CFI Transfers. 
#
((sec=subtot%60, subtot/=60, min=subtot%60, hrs=subtot/60))
xfertottimestring=$(printf "%02d%02d%02d" $hrs $min $sec)
echo "$TIMESTAMP,MIDM,ALL_DC,MIDM_data_transfer_total_duration,$xfertottimestring" 

#
# midmData BDA transfer duration.
#
subtot=0;
for dc in ${midmDC}; do

  jobid=`grep $dc $TMPFILE.bda.datajobs | tail -1 | awk '{print $8'}`

  str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
  if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi

  $SSH $NAMENODE "grep 'DataTransferActionTime Taken' $OOZIEADMI/$jobid/invokeDataTransferScripts--ssh/*0.stdout" 2>/dev/null | awk '{print $NF}' > ${TMPFILE}.dataTime

  dataTime=`cat ${TMPFILE}.dataTime 2>/dev/null | awk -F "." '{print $1}'`;
  if [[ -n $dataTime ]] ; then
    let "subtot += $dataTime";
    ((sec=dataTime%60, dataTime/=60, min=dataTime%60, hrs=dataTime/60))
    xfertimestring=$(printf "%02d%02d%02d" $hrs $min $sec)
  else
    xfertimestring="000000"
  fi

  echo "$TIMESTAMP,MIDM/BDA/$dcClli,,MIDM_data_transfer_DC_duration,$xfertimestring"
  rm -f ${TMPFILE}.dataTime

done

#
# midmDataTotalTransferDuration - BDA Transfers.
#
((sec=subtot%60, subtot/=60, min=subtot%60, hrs=subtot/60))
xfertottimestring=$(printf "%02d%02d%02d" $hrs $min $sec)
echo "$TIMESTAMP,MIDM/BDA/ALL_DC,,MIDM_data_transfer_total_duration,$xfertottimestring"

#
# midmTotalDuration - Enr Start TO BDA End time.
# 
startjobid=`grep $MIDMSTARTDC $TMPFILE.enrjobs | tail -1 | awk '{print $NF'}`
endjobid=`grep $MIDMENDDC $TMPFILE.bda.datajobs | tail -1 | awk '{print $NF'}`

if [[ -n $startjobid && -n $endjobid ]]; then

  $SSH $NAMENODE "grep 'Setting output dir' $OOZIEADMI/$startjobid/mapredAction--ssh/*stderr" 2>/dev/null | awk '{print $1" "$2}' | sed 's/\//-/g' > ${TMPFILE}.midmtotalstartTime;

  $SSH $NAMENODE "tail -1 $OOZIEADMI/$endjobid/invokeDataTransferScripts--ssh/*stdout" 2>/dev/null | awk -F "[" '{print $3}' | cut -c 1-17  > ${TMPFILE}.midmtotalendTime;

  startTime=`cat ${TMPFILE}.midmtotalstartTime 2>/dev/null`
  endTime=`cat ${TMPFILE}.midmtotalendTime 2>/dev/null`

  if [[ -n $startTime && -n $endTime ]] ; then
    start=`date -d "$startTime" +%s`;
    end=`date -d "$endTime" +%s`;
    elapsed=`expr $end - $start`;
    ((sec=elapsed%60, elapsed/=60, min=elapsed%60, hrs=elapsed/60))
    totalmidmtimestring=$(printf "%02d%02d%02d" $hrs $min $sec)
  else
    totalmidmtimestring="000000" 
  fi
else 
  totalmidmtimestring="000000"
fi

echo "$TIMESTAMP,MIDM,ALL_DC,MIDM_total_duration,$totalmidmtimestring"

# Clean up temporary files 
rm -f $TMPFILE.*

exit 0

