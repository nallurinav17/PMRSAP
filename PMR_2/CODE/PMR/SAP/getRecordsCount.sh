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

STANDBY=`$SSH $NETWORK.$CNP0 "$CLI 'show cluster standby'" | grep internal | awk '{print $4}' | sed 's/,//g'`
if [[ -z ${STANDBY} ]] ; then write_log "Could not determine standby namenode, exiting"; exit 127 ; fi

HDFSCMD="$HADOOP dfs -text "
HDFSLS="$HADOOP dfs -ls "
write_log "Calculating DC records count being received at SAP."

# Calculate received records. Once a day for 2 days ago.

y=`date -d "1 day ago" +%Y/%m/%d`

# IPFIX Bins
write_log "----- IPFIX Records"
for dc in $cmdsDC; do
  str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
  if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi
  for chassis in 1 2 3 4; do
    # Skip if chassis does not exist.
    if [[ `$SSH $STANDBY "$HDFSLS /data/$dc/$chassis 2>/dev/null"` ]]; then
      for hr in `seq -w 00 23`; do
      hourlyCount=''; hourlyCount=`$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis/ipfix/${y}/${hr}/*/$dc.IPFIX.*._DONE 2>/dev/null | cut -f2 |  sed 's/^[[:digit:]]//g' | sed 's/\s[[:digit:]]//g' " 2>/dev/null | awk -v "sum=0" '{sum+=$1} END{print sum}' 2>/dev/null `
      if [[ ! $hourlyCount || $? -ne '0' ]]; then
	 hourlyCount='0'
         write_log "----- Unable to calculate IPFIX records for DC $dc Chassis ${chassis}, hour ${y} ${hr}:00."
      fi
      stamp=`date -d "${y} ${hr}:00" +"%Y%m%d-%H%M"`
      echo "$stamp,SAP/$dcClli/$chassis,,SAP_IPFIX_DC_record_volume,$hourlyCount"
      done 
    fi
  done
done  

for dc in $pnsaDC; do
  str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
  if [[ $str ]]; then dcClli=`echo $dc | sed $str`;  else dcClli=$dc; fi
  for chassis in 0; do
    #Skip if chassis does not exist.	- skipped as it is PNSA/VISP
    #if [[ `$SSH $STANDBY "$HDFSLS /data/$dc/$chassis 2>/dev/null"` ]]; then
      for hr in `seq -w 00 23`; do
      hourlyCount=''; hourlyCount=`$SSH $STANDBY "$HDFSCMD /data/$dc/ipfix/${y}/${hr}/*/$dc.IPFIX.*._DONE 2>/dev/null | cut -f2 |  sed 's/^[[:digit:]]//g' | sed 's/\s[[:digit:]]//g' " 2>/dev/null | awk -v "sum=0" '{sum+=$1} END{print sum}' 2>/dev/null `
      if [[ ! $hourlyCount ]]; then
         hourlyCount='0'
         write_log "----- Unable to calculate IPFIX records for DC ${dc}, hour ${y} ${hr}:00."
      fi
      stamp=`date -d "${y} ${hr}:00" +"%Y%m%d-%H%M"`
      echo "$stamp,SAP/$dcClli/$chassis,,SAP_IPFIX_DC_record_volume,$hourlyCount"
      done
    #fi
  done
done 

# PILOTPACKET
write_log "----- Pilot Packet Records"

for dc in $cmdsDC; do
  str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
  if [[ $str ]]; then dcClli=`echo $dc | sed $str`;  else dcClli=$dc; fi
  for chassis in 1 2 3 4; do
    # Skip if chassis does not exist.
    if [[ `$SSH $STANDBY "$HDFSLS /data/$dc/$chassis 2>/dev/null"` ]]; then
      for hr in `seq -w 00 23`; do
      hourlyCount=''; hourlyCount=`$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis/pilotPacket/${y}/${hr}/*/$dc.RADIUS.*._DONE 2>/dev/null | cut -f2 |  sed 's/^[[:digit:]]//g' | sed 's/\s[[:digit:]]//g' " 2>/dev/null | awk -v "sum=0" '{sum+=$1} END{print sum}' 2>/dev/null `
      if [[ ! $hourlyCount ]]; then
         hourlyCount='0'
         write_log "----- Unable to calculate Pilot Packet records for DC $dc Chassis ${chassis}, hour ${y} ${hr}:00."
      fi
      stamp=`date -d "${y} ${hr}:00" +"%Y%m%d-%H%M"`
      echo "$stamp,SAP/$dcClli/$chassis,,SAP_PilotPacket_DC_record_volume,$hourlyCount"
      done        
    fi
  done
done

for dc in $pnsaDC; do
  str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
  if [[ $str ]]; then dcClli=`echo $dc | sed $str`;  else dcClli=$dc; fi
  for chassis in 0; do
    #Skip if chassis does not exist.	- skipped as it is PNSA/VISP
    #if [[ `$SSH $STANDBY "$HDFSLS /data/$dc/$chassis 2>/dev/null"` ]]; then
      for hr in `seq -w 00 23`; do
      hourlyCount=''; hourlyCount=`$SSH $STANDBY "$HDFSCMD /data/$dc/pilotPacket/${y}/${hr}/*/$dc.RADIUS.*._DONE 2>/dev/null | cut -f2 |  sed 's/^[[:digit:]]//g' | sed 's/\s[[:digit:]]//g' " 2>/dev/null | awk -v "sum=0" '{sum+=$1} END{print sum}' 2>/dev/null `
      if [[ ! $hourlyCount ]]; then
         hourlyCount='0'
         write_log "----- Unable to calculate Pilot Packet records for DC ${dc}, hour ${y} ${hr}:00."
      fi
      stamp=`date -d "${y} ${hr}:00" +"%Y%m%d-%H%M"`
      echo "$stamp,SAP/$dcClli/$chassis,,SAP_PilotPacket_DC_record_volume,$hourlyCount"
      done
    #fi
  done
done

# SUBSCRIBER IB 
#write_log "----- SUBIB Bins"

#maxBinsInDay='24'
#for dc in $allDC; do
#  str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
#  if [[ $str ]]; then dcClli=`echo $dc | sed $str`;  else dcClli=$dc; fi
#  for chassis in 0; do
#  done
#done 

write_log "Done calculating hourly records count for DCs."

exit 0

