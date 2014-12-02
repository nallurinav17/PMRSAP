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

STANDBY=`$SSH $NETWORK.$CNP0 "$CLI 'show cluster standby'" | grep external | awk {'print $NF'}`
if [[ -z ${STANDBY} ]] ; then write_log "Could not determine standby namenode, exiting"; exit 127 ; fi

HDFSCMD="$HADOOP dfs -ls "

# Software Version and patches.
write_log "Starting software patches, version collection, Configured FD Limit."
for node in $CNP $UIP $CMP $SGW $CCP; do
  #-----
  hostn='';hostn=`/bin/grep -w "$NETWORK.$node" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
  if [[ ! ${hostn} ]]; then hostn=`$SSH $NETWORK.$node "hostname"`; fi
  if [[ ! ${hostn} ]]; then hostn="$NETWORK.$node"; fi
  #-----

  #----- version
  val='';
  val=`$SSH $NETWORK.$node "${CLI} 'show version' 2>/dev/null | grep 'Product release'" 2>/dev/null | $AWK '{print $NF}' | sed 's/ //g'`
    if [[ $val && $? -eq '0' ]]; then
     echo "$TIMESTAMP,SAP/$hostn,,SW_version,${val:0:50}"
    else
     echo "$TIMESTAMP,SAP/$hostn,,SW_version,${val:0:50}"
    fi

  #----- patch
  val='';
  patches=''
  val=`$SSH $NETWORK.$node "${PMX} subshell patch show all patches 2>/dev/null | egrep -vi 'Already|No' | sort | grep [^A-Za-z] | sed 's/ //g'" 2>/dev/null`
  if [[ $val && $? -eq '0' ]]; then 
  for pat in $val; do
    patches="$pat $patches"
  done
  fi
  echo "$TIMESTAMP,SAP/$hostn,,SW_patches,${patches:0:200}"

  #----- FD Limit Counter

  val='';
  patches=''
  val=`$SSH $NETWORK.$node "/bin/cat /proc/sys/fs/file-max" 2>/dev/null`
  if [[ $val && $? -eq '0' ]]; then
   echo "$TIMESTAMP,SAP/$hostn,,file_descriptors_max,$val"
  else
   echo "$TIMESTAMP,SAP/$hostn,,file_descriptors_max,0"
   write_log "----- Unable to calculate configured FD limit for node $hostn"
  fi


done 2>/dev/null

write_log "Completed software patches, version collection, Configured FD Limit."
write_log "Calculating missing DC bins."

# Calculate missing bins. Once a day for 2 days ago.

y=`date -d "2 days ago" +%Y/%m/%d`
yMissedKpi=`date -d "2 days ago" +%Y%m%d`

# IPFIX Bins
write_log "----- IPFIX Bins"
maxBinsInDay='288'
for dc in $cmdsDC; do
  for chassis in 1 2 3 4; do
    str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed`
    if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi
    # Skip if chassis does not exist.
    if [[ `$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis 2>/dev/null"` ]]; then
      outFile="/tmp/binList-ipfix-${chassis}-${dc}"
      $SSH $STANDBY "$HDFSCMD /data/$dc/$chassis/ipfix/${y}/*/*/_DONE 2>/dev/null" | awk '{print $NF}' >$outFile
      if [[ -s $outFile && $? -eq '0' ]]; then
         cmdsIpfixCount=`wc -l $outFile 2>/dev/null | awk '{print $1}' | sed 's/ //g'`
      else
	 cmdsIpfixCount='0';
      fi
      cmdsIpfixMissedBinCount='-1';cmdsIpfixMissedBinCount=`echo "$maxBinsInDay - $cmdsIpfixCount" | bc`
      echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_IPFIX_DC_bin_count,$cmdsIpfixMissedBinCount"
      # Practically, following condition will never meet. If the magic happens, keep the KPI value empty since it is a string.
      if [[ `echo "$cmdsIpfixMissedBinCount == -1" | bc` -eq '1' ]]; then 
         echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_IPFIX_DC_bins,"
      elif [[ `echo "$cmdsIpfixMissedBinCount == $maxBinsInDay" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_IPFIX_DC_bins,ALL"
      elif [[ `echo "$cmdsIpfixMissedBinCount == 0" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_IPFIX_DC_bins,NONE"
      elif [[ `echo "$cmdsIpfixMissedBinCount > 12" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_IPFIX_DC_bins,SET"
      else 
      # Iterate through all the bins in a day to find misng bins until the count of misng bins being recorded matches $cmdsIpfixMissedBinCount. 
         binCount='0';binList='';
	 for hour in `seq -w 00 24`; do
	    for minute in `seq -w 00 05 55`; do
		if [[ `/bin/grep "/data/$dc/$chassis/ipfix/${y}/$hour/$minute/_DONE" $outFile 2>/dev/null` ]]; then
		   continue
		else
		   missedBin='';missedBin="${yMissedKpi}-${hour}:${minute}"
		   if [[ $binList ]]; then
			# PIPE separated, we can change to [][,][,] ... etc., here.
			binList="${binList}|${missedBin}"
		   else
			binList="${missedBin}"
		   fi
		   binCount=`expr $binCount + 1`
		fi
		if [[ $binCount -eq "$cmdsIpfixMissedBinCount" ]]; then break 2; fi
	    done
	 done
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_IPFIX_DC_bins,$binList"
      fi
      /bin/rm -f $outFile 
    fi
  done
done  


maxBinsInDay='288'
for dc in $pnsaDC; do
  for chassis in 0; do
    str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed`
    if [[ $str ]]; then dcClli=`echo $dc | sed $str`;  else dcClli=$dc; fi
    #Skip if chassis does not exist.	- skipped as it is PNSA/VISP
    #if [[ `$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis 2>/dev/null"` ]]; then
      outFile="/tmp/binList-ipfix-${chassis}-${dc}"
      $SSH $STANDBY "$HDFSCMD /data/$dc/ipfix/${y}/*/*/_DONE 2>/dev/null" | awk '{print $NF}' >$outFile
      if [[ -s $outFile && $? -eq '0' ]]; then
         cmdsIpfixCount=`wc -l $outFile 2>/dev/null | awk '{print $1}' | sed 's/ //g'`
      else
	 cmdsIpfixCount='0';
      fi
      cmdsIpfixMissedBinCount='-1';cmdsIpfixMissedBinCount=`echo "$maxBinsInDay - $cmdsIpfixCount" | bc`
      echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_IPFIX_DC_bin_count,$cmdsIpfixMissedBinCount"
      # Practically, following condition will never meet. If the magic happens, keep the KPI value empty since it is a string.
      if [[ `echo "$cmdsIpfixMissedBinCount == -1" | bc` -eq '1' ]]; then
         echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_IPFIX_DC_bins,"
      elif [[ `echo "$cmdsIpfixMissedBinCount == $maxBinsInDay" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_IPFIX_DC_bins,ALL"
      elif [[ `echo "$cmdsIpfixMissedBinCount == 0" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_IPFIX_DC_bins,NONE"
      elif [[ `echo "$cmdsIpfixMissedBinCount > 12" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_IPFIX_DC_bins,SET"
      else
      # Iterate through all the bins in a day to find misng bins until the count of misng bins being recorded matches $cmdsIpfixMissedBinCount.
         binCount='0';binList='';
	 for hour in `seq -w 00 24`; do
	    for minute in `seq -w 00 05 55`; do
		if [[ `/bin/grep "/data/$dc/ipfix/${y}/$hour/$minute/_DONE" $outFile 2>/dev/null` ]]; then
		   continue
		else
		   missedBin='';missedBin="${yMissedKpi}-${hour}:${minute}"
		   if [[ $binList ]]; then
			# PIPE separated, we can change to [][,][,] ... etc., here.
			binList="${binList}|${missedBin}"
		   else
			binList="${missedBin}"
		   fi
		   binCount=`expr $binCount + 1`
		fi
		if [[ $binCount -eq "$cmdsIpfixMissedBinCount" ]]; then break 2; fi
	    done
	 done
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_IPFIX_DC_bins,$binList"
      fi
      /bin/rm -f $outFile
    #fi
  done
done 

# PILOTPACKET
write_log "----- RADIUS Bins"

maxBinsInDay='288'
for dc in $cmdsDC; do
  for chassis in 1 2 3 4; do
    str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed`
    if [[ $str ]]; then dcClli=`echo $dc | sed $str`;  else dcClli=$dc; fi
    # Skip if chassis does not exist.
    if [[ `$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis 2>/dev/null"` ]]; then
      outFile="/tmp/binList-pilot-${chassis}-${dc}"
      $SSH $STANDBY "$HDFSCMD /data/$dc/$chassis/pilotPacket/${y}/*/*/_DONE 2>/dev/null" | awk '{print $NF}' >$outFile
      if [[ -s $outFile && $? -eq '0' ]]; then
         cmdsIpfixCount=`wc -l $outFile 2>/dev/null | awk '{print $1}' | sed 's/ //g'` 
      else
	 cmdsIpfixCount='0';
      fi
      cmdsIpfixMissedBinCount='-1';cmdsIpfixMissedBinCount=`echo "$maxBinsInDay - $cmdsIpfixCount" | bc`
      echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_PilotPacket_DC_bin_count,$cmdsIpfixMissedBinCount"
      # Practically, following condition will never meet. If the magic happens, keep the KPI value empty since it is a string.
      if [[ `echo "$cmdsIpfixMissedBinCount == -1" | bc` -eq '1' ]]; then
         echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_PilotPacket_DC_bins,"
      elif [[ `echo "$cmdsIpfixMissedBinCount == $maxBinsInDay" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_PilotPacket_DC_bins,ALL"
      elif [[ `echo "$cmdsIpfixMissedBinCount == 0" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_PilotPacket_DC_bins,NONE"
      elif [[ `echo "$cmdsIpfixMissedBinCount > 12" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_PilotPacket_DC_bins,SET"
      else
      # Iterate through all the bins in a day to find misng bins until the count of misng bins being recorded matches $cmdsIpfixMissedBinCount.
         binCount='0';binList='';
	 for hour in `seq -w 00 24`; do
	    for minute in `seq -w 00 05 55`; do
		if [[ `/bin/grep "/data/$dc/$chassis/pilotPacket/${y}/$hour/$minute/_DONE" $outFile 2>/dev/null` ]]; then
		   continue
		else
		   missedBin='';missedBin="${yMissedKpi}-${hour}:${minute}"
		   if [[ $binList ]]; then
			# PIPE separated, we can change to [][,][,] ... etc., here.
			binList="${binList}|${missedBin}"
		   else
			binList="${missedBin}"
		   fi
		   binCount=`expr $binCount + 1`
		fi
		if [[ $binCount -eq "$cmdsIpfixMissedBinCount" ]]; then break 2; fi
	    done
	 done
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_PilotPacket_DC_bins,$binList"
      fi
      /bin/rm -f $outFile
    fi
  done
done


maxBinsInDay='288'
for dc in $pnsaDC; do
  for chassis in 0; do
    str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed`
    if [[ $str ]]; then dcClli=`echo $dc | sed $str`;  else dcClli=$dc; fi
    #Skip if chassis does not exist.	- skipped as it is PNSA/VISP
    #if [[ `$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis 2>/dev/null"` ]]; then
      outFile="/tmp/binList-pilot-${chassis}-${dc}"
      $SSH $STANDBY "$HDFSCMD /data/$dc/pilotPacket/${y}/*/*/_DONE 2>/dev/null" | awk '{print $NF}' >$outFile
      if [[ -s $outFile && $? -eq '0' ]]; then
         cmdsIpfixCount=`wc -l $outFile 2>/dev/null | awk '{print $1}' | sed 's/ //g'`
      else
	 cmdsIpfixCount='0';
      fi
      cmdsIpfixMissedBinCount='-1';cmdsIpfixMissedBinCount=`echo "$maxBinsInDay - $cmdsIpfixCount" | bc`
      echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_PilotPacket_DC_bin_count,$cmdsIpfixMissedBinCount"
      # Practically, following condition will never meet. If the magic happens, keep the KPI value empty since it is a string.
      if [[ `echo "$cmdsIpfixMissedBinCount == -1" | bc` -eq '1' ]]; then
         echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_PilotPacket_DC_bins,"
      elif [[ `echo "$cmdsIpfixMissedBinCount == $maxBinsInDay" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_PilotPacket_DC_bins,ALL"
      elif [[ `echo "$cmdsIpfixMissedBinCount == 0" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_PilotPacket_DC_bins,NONE"
      elif [[ `echo "$cmdsIpfixMissedBinCount > 12" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_PilotPacket_DC_bins,SET"
      else
      # Iterate through all the bins in a day to find misng bins until the count of misng bins being recorded matches $cmdsIpfixMissedBinCount.
         binCount='0';binList='';
	 for hour in `seq -w 00 24`; do
	    for minute in `seq -w 00 05 55`; do
		if [[ `/bin/grep "/data/$dc/pilotPacket/${y}/$hour/$minute/_DONE" $outFile 2>/dev/null` ]]; then
		   continue
		else
		   missedBin='';missedBin="${yMissedKpi}-${hour}:${minute}"
		   if [[ $binList ]]; then
			# PIPE separated, we can change to [][,][,] ... etc., here.
			binList="${binList}|${missedBin}"
		   else
			binList="${missedBin}"
		   fi
		   binCount=`expr $binCount + 1`
		fi
		if [[ $binCount -eq "$cmdsIpfixMissedBinCount" ]]; then break 2; fi
	    done
	 done
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_PilotPacket_DC_bins,$binList"
      fi
      /bin/rm -f $outFile
    #fi
  done
done

# SUBSCRIBER IB 
write_log "----- SUBIB Bins"

maxBinsInDay='24'
for dc in $allDC; do
  for chassis in 0; do
    str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed`
    if [[ $str ]]; then dcClli=`echo $dc | sed $str`;  else dcClli=$dc; fi
    #Skip if chassis does not exist.	- skipped as it is PNSA/VISP
    #if [[ `$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis 2>/dev/null"` ]]; then
      outFile="/tmp/binList-subib-${chassis}-${dc}"
      $SSH $STANDBY "$HDFSCMD /data/$dc/SubscriberIB/${y}/*/distcp_DONE 2>/dev/null" | awk '{print $NF}' >$outFile
      if [[ -s $outFile && $? -eq '0' ]]; then
         cmdsIpfixCount=`wc -l $outFile 2>/dev/null | awk '{print $1}' | sed 's/ //g'`
      else
	 cmdsIpfixCount='0';
      fi
      cmdsIpfixMissedBinCount='-1';cmdsIpfixMissedBinCount=`echo "$maxBinsInDay - $cmdsIpfixCount" | bc`
      echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_SubscriberIB_DC_bin_count,$cmdsIpfixMissedBinCount"
      # Practically, following condition will never meet. If the magic happens, keep the KPI value empty since it is a string.
      if [[ `echo "$cmdsIpfixMissedBinCount == -1" | bc` -eq '1' ]]; then
         echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_SubscriberIB_DC_bins,"
      elif [[ `echo "$cmdsIpfixMissedBinCount == $maxBinsInDay" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_SubscriberIB_DC_bins,ALL"
      elif [[ `echo "$cmdsIpfixMissedBinCount == 0" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_SubscriberIB_DC_bins,NONE"
      elif [[ `echo "$cmdsIpfixMissedBinCount > 12" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_SubscriberIB_DC_bins,SET"
      else
      # Iterate through all the bins in a day to find misng bins until the count of misng bins being recorded matches $cmdsIpfixMissedBinCount.
         binCount='0';binList='';
	 for hour in `seq -w 00 24`; do
		if [[ `/bin/grep "/data/$dc/SubscriberIB/${y}/$hour/distcp_DONE" $outFile 2>/dev/null` ]]; then
		   continue
		else
		   missedBin='';missedBin="${yMissedKpi}-${hour}:00"
		   if [[ $binList ]]; then
			# PIPE separated, we can change to [][,][,] ... etc., here.
			binList="${binList}|${missedBin}"
		   else
			binList="${missedBin}"
		   fi
		   binCount=`expr $binCount + 1`
		fi
		if [[ $binCount -eq "$cmdsIpfixMissedBinCount" ]]; then break; fi
	 done
	 echo "$TIMESTAMP,SAP/$dcClli/$chassis,,SAP_missing_SubscriberIB_DC_bins,$binList"
      fi
      /bin/rm -f $outFile
    #fi
  done
done 

write_log "Done calculating missing DC bins."

exit 0

