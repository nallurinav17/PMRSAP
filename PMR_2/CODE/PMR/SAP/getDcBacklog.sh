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

write_log "Starting DC Backlog Identifier."

STANDBY=`$SSH $NETWORK.$CNP0 "$CLI 'show cluster standby'" | grep external | awk {'print $NF'}`
if [[ -z ${STANDBY} ]] ; then write_log "Could not determine standby namenode, exiting"; exit 127 ; fi

HDFSCMD="$HADOOP dfs -ls "

# Calculate bin backlog for last 24 hours. Every hour.
# Define maximum window size to check for the lag.
window=24

# Define ideal flexibility in minutes, which is assumed to be an unavoidable lag in ideal case.
# (IPFIX = current 10mins - 2 open bins, previous 15 mins - 3 copy jobs already running, transfering data from DC = 10+15 = 25 mins).
# (PILOT = current 10mins - 2 open bins, previous 5 mins - 1 copy job already running, transfering data from DC = 10+15 = 25 mins).
# (SUBIB = current 1 hour - 1 open bin, previous 1 hour - 1 copy job already running, transfering data from DC = 1+1 = 2 hrs = 120 mins).
# We do not consider these times into a lag, anything beyond this difference is a lag.
ipfixIdealFlexibility='25'
pilotIdealFlexibility='15'
subibIdealFlexibility='120'

# Current epoch to lower 5 minute bin boundary.
curd=`date +%s`; diff=`echo "$curd % 300" | bc`; curd=`echo "$curd - $diff" | bc`;

# Window epoch to lower 5 minute boundary.
#windowd=`date -d "$window hours ago" +%s`;
#diff=`echo "$windowd % 300" | bc`; windowd=`echo "$windowd - $diff" | bc`;
windowd=`echo "$curd - ($window * 60 * 60)" | bc`
y1=`date -d @$windowd +%Y/%m/%d`

# Ideal time to start backwards in epoch
curdI=`echo "$curd - ($ipfixIdealFlexibility * 60)" | bc`
curdP=`echo "$curd - ($pilotIdealFlexibility * 60)" | bc`
curdS=`echo "$curd - ($subibIdealFlexibility * 60)" | bc`

# Ideal time adjustment in windowd to keep window time to be standard 24 hours from the time when we actually start observing the latest bin availability.
windowdI=`echo "$windowd - ($ipfixIdealFlexibility * 60)" | bc`
windowdP=`echo "$windowd - ($pilotIdealFlexibility * 60)" | bc`
windowdS=`echo "$windowd - ($subibIdealFlexibility * 60)" | bc`

# Calculate days to query from hadoop for ipfix
temp=$windowdI
while [[ $temp -le $curdI ]] ; do
Iday='';Iday=`date -d @$temp +%Y/%m/%d`
Idays="$Iday $Idays"
temp=`expr $temp + 86400`
done

# Calculate days to query from hadoop for pilot
temp=$windowdP
while [[ $temp -le $curdP ]] ; do
Pday='';Pday=`date -d @$temp +%Y/%m/%d`
Pdays="$Pday $Pdays"
temp=`expr $temp + 86400`
done

# Calculate days to query from hadoop for subib
temp=$windowdS
while [[ $temp -le $curdS ]] ; do
Sday=`date -d @$temp +%Y/%m/%d`
Sdays="$Sday $Sdays"
temp=`expr $temp + 86400`
done

# IPFIX Bin Lag
write_log "----- IPFIX Bin Lag"
for dc in $cmdsDC; do
  for chassis in 1 2 3 4; do
    str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
    if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi
    # Skip if chassis does not exist.
    if [[ `$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis 2>/dev/null"` ]]; then
      outFile="/tmp/binListForLag-ipfix-${chassis}-${dc}"
      for y in $Idays; do
      $SSH $STANDBY "$HDFSCMD /data/$dc/$chassis/ipfix/${y}/*/*/* 2>/dev/null" | awk '{print $NF}' >>$outFile
      done 2>/dev/null
      if [[ -s $outFile ]]; then
	counter=$curdI
	while [[ $counter -ge $windowdI ]] ; do
	   dt=`date -d @$counter +%Y/%m/%d/%H/%M`
	   if [[ `/bin/grep "/data/$dc/$chassis/ipfix/${dt}/_DONE" $outFile 2>/dev/null` ]]; then
	       lag=`expr $curdI - $counter`
	       lagH=`echo "$lag / 3600" | bc`; lag=`echo "$lag % 3600" | bc`
	       lagM=`echo "$lag / 60" | bc`; lagS=`echo "$lag % 60" | bc`
	       printf "%s,SAP/%s/%d,,IPFIX_data_transfer_backlog,%02d:%02d:%02d\n" "$TIMESTAMP" "$dcClli" "$chassis" $lagH $lagM $lagS
	       break;
	   else
	      counter=`expr $counter - 300` 
	   fi
	done
      else
 	lagH=24;lagM=00;lagS=00
	printf "%s,SAP/%s/%d,,IPFIX_data_transfer_backlog,%02d:%02d:%02d\n" "$TIMESTAMP" "$dcClli" "$chassis" $lagH $lagM $lagS
	write_log "Unable to generate $outFile, to calculate ipfix bin lag for DC $dc"	
      fi
      /bin/rm -f $outFile 
    fi
  done
done  


for dc in $pnsaDC; do
  for chassis in 0; do
    str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
    if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi
      outFile="/tmp/binListForLag-ipfix-${chassis}-${dc}"
      for y in $Idays; do
      $SSH $STANDBY "$HDFSCMD /data/$dc/ipfix/${y}/*/*/_DONE 2>/dev/null" | awk '{print $NF}' >>$outFile
      done 2>/dev/null
      if [[ -s $outFile ]]; then
        counter=$curdI
        while [[ $counter -ge $windowdI ]] ; do
           dt=`date -d @$counter +%Y/%m/%d/%H/%M`
           if [[ `/bin/grep "/data/$dc/ipfix/${dt}/_DONE" $outFile 2>/dev/null` ]]; then
               lag=`expr $curdI - $counter`
               lagH=`echo "$lag / 3600" | bc`; lag=`echo "$lag % 3600" | bc`
               lagM=`echo "$lag / 60" | bc`; lagS=`echo "$lag % 60" | bc`
               printf "%s,SAP/%s/%d,,IPFIX_data_transfer_backlog,%02d:%02d:%02d\n" "$TIMESTAMP" "$dcClli" "$chassis" $lagH $lagM $lagS
               break;
           else
              counter=`expr $counter - 300`
           fi
        done
      else
        lagH=24;lagM=00;lagS=00
        printf "%s,SAP/%s/%d,,IPFIX_data_transfer_backlog,%02d:%02d:%02d\n" "$TIMESTAMP" "$dcClli" "$chassis" $lagH $lagM $lagS
        write_log "Unable to generate $outFile, to calculate ipfix bin lag for DC $dc"
      fi
      /bin/rm -f $outFile
  done
done 

# PILOTPACKET
write_log "----- RADIUS Bin Lag"
for dc in $cmdsDC; do
  for chassis in 1 2 3 4; do
    str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
    if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi
    # Skip if chassis does not exist.
    if [[ `$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis 2>/dev/null"` ]]; then
      outFile="/tmp/binListForLag-pilot-${chassis}-${dc}"
      for y in $Pdays; do
      $SSH $STANDBY "$HDFSCMD /data/$dc/$chassis/pilotPacket/${y}/*/*/_DONE 2>/dev/null" | awk '{print $NF}' >>$outFile
      done 2>/dev/null
      if [[ -s $outFile ]]; then
	counter=$curdP
	while [[ $counter -ge $windowdP ]] ; do
	   dt=`date -d @$counter +%Y/%m/%d/%H/%M`
	   if [[ `/bin/grep "/data/$dc/$chassis/pilotPacket/${dt}/_DONE" $outFile 2>/dev/null` ]]; then
	       lag=`expr $curdP - $counter`
	       lagH=`echo "$lag / 3600" | bc`; lag=`echo "$lag % 3600" | bc`
	       lagM=`echo "$lag / 60" | bc`; lagS=`echo "$lag % 60" | bc`
	       printf "%s,SAP/%s/%d,,PilotPacket_data_transfer_backlog,%02d:%02d:%02d\n" "$TIMESTAMP" "$dcClli" "$chassis" $lagH $lagM $lagS
	       break;
	   else
	      counter=`expr $counter - 300`
	   fi
	done
      else
	lagH=24;lagM=00;lagS=00
	printf "%s,SAP/%s/%d,,PilotPacket_data_transfer_backlog,%02d:%02d:%02d\n" "$TIMESTAMP" "$dcClli" "$chassis" $lagH $lagM $lagS
	write_log "Unable to generate $outFile, to calculate pilotPacket bin lag for DC $dc"
      fi
      /bin/rm -f $outFile
    fi
  done
done


for dc in $pnsaDC; do
  for chassis in 0; do
    str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
    if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi
      outFile="/tmp/binListForLag-pilot-${chassis}-${dc}"
      for y in $Pdays; do
      $SSH $STANDBY "$HDFSCMD /data/$dc/pilotPacket/${y}/*/*/_DONE 2>/dev/null" | awk '{print $NF}' >>$outFile
      done 2>/dev/null
      if [[ -s $outFile ]]; then
        counter=$curdP
        while [[ $counter -ge $windowdP ]] ; do
           dt=`date -d @$counter +%Y/%m/%d/%H/%M`
           if [[ `/bin/grep "/data/$dc/pilotPacket/${dt}/_DONE" $outFile 2>/dev/null` ]]; then
               lag=`expr $curdP - $counter`
               lagH=`echo "$lag / 3600" | bc`; lag=`echo "$lag % 3600" | bc`
               lagM=`echo "$lag / 60" | bc`; lagS=`echo "$lag % 60" | bc`
               printf "%s,SAP/%s/%d,,PilotPacket_data_transfer_backlog,%02d:%02d:%02d\n" "$TIMESTAMP" "$dcClli" "$chassis" $lagH $lagM $lagS
               break;
           else
              counter=`expr $counter - 300`
           fi
        done
      else
        lagH=24;lagM=00;lagS=00
        printf "%s,SAP/%s/%d,,PilotPacket_data_transfer_backlog,%02d:%02d:%02d\n" "$TIMESTAMP" "$dcClli" "$chassis" $lagH $lagM $lagS
        write_log "Unable to generate $outFile, to calculate pilotPacket bin lag for DC $dc"
      fi
      /bin/rm -f $outFile
  done
done

# SUBSCRIBER IB 
write_log "----- SUBIB Bin Lag"

for dc in $allDC; do
  for chassis in 0; do
    str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
    if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi
      outFile="/tmp/binListForLag-subib-${chassis}-${dc}"
      for y in $Sdays; do
      $SSH $STANDBY "$HDFSCMD /data/$dc/SubscriberIB/${y}/*/distcp_DONE 2>/dev/null" | awk '{print $NF}' >>$outFile
      done 2>/dev/null
      if [[ -s $outFile ]]; then
        counter=$curdS
        while [[ $counter -ge $windowdS ]] ; do
           dt=`date -d @$counter +%Y/%m/%d/%H`
           if [[ `/bin/grep "/data/$dc/SubscriberIB/${dt}/distcp_DONE" $outFile 2>/dev/null` ]]; then
               lag=`expr $curdS - $counter`
               lagH=`echo "$lag / 3600" | bc`; lag=`echo "$lag % 3600" | bc`
               lagM=`echo "$lag / 60" | bc`; lagS=`echo "$lag % 60" | bc`
               printf "%s,SAP/%s/%d,,SubscriberIB_data_transfer_backlog,%02d:%02d:%02d\n" "$TIMESTAMP" "$dcClli" "$chassis" $lagH $lagM $lagS
               break;
           else
              counter=`expr $counter - 3600`
           fi
        done
      else
        lagH=24;lagM=00;lagS=00
	printf "%s,SAP/%s/%d,,SubscriberIB_data_transfer_backlog,%02d:%02d:%02d\n" "$TIMESTAMP" "$dcClli" "$chassis" $lagH $lagM $lagS
        write_log "Unable to generate $outFile, to calculate SubscriberIB bin lag for DC $dc"
      fi
      /bin/rm -f $outFile
  done
done 

write_log "Completed calculating DC bin lags."

exit 0

