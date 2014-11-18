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

write_log "Starting ByteVolumeCounters"

STANDBY=`$SSH $NETWORK.$CNP0 "$CLI 'show cluster standby'" | grep external | awk {'print $NF'}`
if [[ -z ${STANDBY} ]] ; then write_log "Could not determine standby namenode, exiting"; exit 127 ; fi

HDFSCMD="$HADOOP dfs -ls "

#
# MidmAgg file size - total bytes for each DC MidmAgg files which are sent to VIT
#
myda=`date "+%d" --date="2 days ago"`;
mymo=`date "+%m" --date="2 days ago"`;
myyr=`date "+%Y" --date="2 days ago"`;
#
write_log "  -- MIDM Aggregate"
for dc in ${midmDC};
do 
str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed`
if [[ $str ]]; then dcClli=`echo $dc | sed $str`; fi
$SSH $STANDBY "$HDFSCMD  /data/output/$dc/Midm/$myyr/$mymo/$myda/GVS.MIDM_Aggregate* 2>/dev/null" | awk '{print $5$8}'| awk -v "t1=$TIMESTAMP" -v "dc=$dcClli" -F "/" 'BEGIN{sum1=0} {sum1+= $1} END{printf "%s,MIDM,%s,MIDM_aggregated_data_DC_volume,%s\n", t1, dc, sum1}';
done 2>/dev/null | tee -a ${TMPFILE}.midmagg

# MIDM_aggregated_data_total_volume
awk -v "t1=$TIMESTAMP" -F "," 'BEGIN{sum1=0} {sum+= $NF} END{printf "%s,MIDM,ALL_DC,MIDM_aggregated_data_total_volume,%s\n", t1, sum}' ${TMPFILE}.midmagg 
# Cleanup
rm -f ${TMPFILE}.midmagg

write_log "  -- MIDM Enriched"
#
# MidmEnr File Size -total bytes for each DC MidmEnr files which are sent to VIT
for dc in ${midmDC};
do
str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed`
if [[ $str ]]; then dcClli=`echo $dc | sed $str`; fi
$SSH $STANDBY "$HDFSCMD  /data/output/$dc/Midm/$myyr/$mymo/$myda/GVS.MIDM_Enriched* 2>/dev/null" | awk '{print $5$8}'| awk -v "t1=$TIMESTAMP" -v "dc=$dcClli" -F "/" 'BEGIN{sum1=0} {sum1+= $1} END{printf "%s,MIDM,%s,MIDM_enriched_data_DC_volume,%s\n", t1, dc, sum1}';
done 2>/dev/null | tee -a ${TMPFILE}.midmenr

# MIDM_enriched_data_total_volume
awk -v "t1=$TIMESTAMP" -F "," 'BEGIN{sum1=0} {sum+= $NF} END{printf "%s,MIDM,ALL_DC,MIDM_enriched_data_total_volume,%s\n", t1, sum}' ${TMPFILE}.midmenr 
# Cleanup
rm -f ${TMPFILE}.midmenr

# FILE SIZE STATS
#
# 7am to end of day yesterday plus 12am to 6:55 am today

myda1=`date "+%d" --date="2 days ago"`;
myda2=`date "+%d" --date="1 days ago"`;
mymo1=`date "+%m" --date="2 days ago"`;
mymo2=`date "+%m" --date="1 days ago"`;
myyr1=`date "+%Y" --date="2 days ago"`;
myyr2=`date "+%Y" --date="1 days ago"`;

write_log "  -- IPFIX Records"
# IPFIX
for dc in $cmdsDC
do
str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed`
if [[ $str ]]; then dcClli=`echo $dc | sed $str`; fi
$SSH $STANDBY "$HDFSCMD /data/$dc/{1,2,3,4}/ipfix/$myyr1/$mymo1/$myda1/*/*/*IPFIX*.? 2>/dev/null" | awk '{print $5$8}'| awk -v "dc=$dcClli" -F "/" '{if ($9>6) subtot1 += $1} END {printf "%s;%13d",dc, subtot1}';
$SSH $STANDBY "$HDFSCMD /data/$dc/{1,2,3,4}/ipfix/$myyr2/$mymo2/$myda2/*/*/*IPFIX*.? 2>/dev/null"| awk '{print $5$8}'| awk -F "/" '{if ($9<7) subtot2 += $1} END {print ";"subtot2}';
done  2>/dev/null | awk -v "time=$TIMESTAMP" -F ";" '{printf "%s,SAP,%s,SAP_IPFIX_DC_volume,%s\n", time, $1, ($2+$3)}' 

for dc in $pnsaDC;
do
str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed`
if [[ $str ]]; then dcClli=`echo $dc | sed $str`; fi
$SSH $STANDBY "$HDFSCMD /data/$dc/ipfix/$myyr1/$mymo1/$myda1/*/*/*IPFIX*.? 2>/dev/null" | awk '{print $5$8}'| awk -v "dc=$dcClli" -F "/" '{if ($8>6) subtot1 += $1} END {printf "%s;%13d",dc, subtot1}';
$SSH $STANDBY "$HDFSCMD /data/$dc/ipfix/$myyr2/$mymo2/$myda2/*/*/*IPFIX*.? 2>/dev/null" | awk '{print $5$8}'| awk -F "/" '{if ($8<7) subtot2 += $1} END {print ";"subtot2}';
done 2> /dev/null | awk -v "time=$TIMESTAMP" -F ";" '{printf "%s,SAP,%s,SAP_IPFIX_DC_volume,%s\n", time, $1, ($2+$3)}'

# PILOTPACKET
write_log "  -- RADIUS Records"

for dc in $cmdsDC;
do
str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed`
if [[ $str ]]; then dcClli=`echo $dc | sed $str`; fi
$SSH $STANDBY "$HDFSCMD /data/$dc/{1,2,3,4}/pilotPacket/$myyr1/$mymo1/$myda1/*/*/*RADIUS*0 2>/dev/null" | awk '{print $5$8}'| awk -v "dc=$dcClli" -F "/" '{if ($9>6) subtot1a += $1} END {printf "%s;%13d",dc, subtot1a}';
$SSH $STANDBY "$HDFSCMD /data/$dc/{1,2,3,4}/pilotPacket/$myyr2/$mymo2/$myda2/*/*/*RADIUS*0 2>/dev/null" | awk '{print $5$8}'| awk -F "/" '{if ($9<7) subtot2a += $1} END {printf ";%13d;", subtot2a}';
#----
#$SSH $STANDBY "$HDFSCMD /data/$dc/1/pilotPacket/$myyr1/$mymo1/$myda1/*/*/*RADIUS*0" | awk '{print $5$8}'| awk -v "dc=$dcClli" -F "/" '{if ($9>6) subtot1a += $1} END {printf "%s;%13d",dc, subtot1a}';
#$SSH $STANDBY "$HDFSCMD /data/$dc/2/pilotPacket/$myyr1/$mymo1/$myda1/*/*/*RADIUS*0" | awk '{print $5$8}'| awk -F "/" '{if ($9>6) subtot1b += $1} END {printf ";%13d;", subtot1b}';
#$SSH $STANDBY "$HDFSCMD /data/$dc/1/pilotPacket/$myyr2/$mymo2/$myda2/*/*/*RADIUS*0" | awk '{print $5$8}'| awk -F "/" '{if ($9<7) subtot2a += $1} END {printf "%13d;", subtot2a}';
#$SSH $STANDBY "$HDFSCMD /data/$dc/2/pilotPacket/$myyr2/$mymo2/$myda2/*/*/*RADIUS*0" | awk '{print $5$8}'| awk -F "/" '{if ($9<7) subtot2b += $1} END {print subtot2b}';
#done 2> /dev/null | awk -v "time=$TIMESTAMP" -F ";" '{printf "%s, SAP, %s, SAP_PilotPacket_DC_volume; %s; %s", time, $1, ($2+$4), ($3+$5)}' | awk -F ";" '{if ($2>$3) print $1", "$2+$3;else if ($3>=$2) print $1", "$3+$2}'
#-----
done 2> /dev/null | awk -v "time=$TIMESTAMP" -F ";" '{printf "%s,SAP,%s,SAP_PilotPacket_DC_volume,%s\n", time, $1, ($2+$3)}' 

for dc in $pnsaDC;
do
str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed`
if [[ $str ]]; then dcClli=`echo $dc | sed $str`; fi
$SSH $STANDBY "$HDFSCMD  /data/$dc/pilotPacket/$myyr1/$mymo1/$myda1/*/*/*RADIUS*0 2>/dev/null" | awk '{print $5$8}'| awk -v "dc=$dcClli" -F "/" '{if ($8>6) subtot1 += $1} END {printf "%s;%13d",dc, subtot1}';
$SSH $STANDBY "$HDFSCMD  /data/$dc/pilotPacket/$myyr2/$mymo2/$myda2/*/*/*RADIUS*0 2>/dev/null" | awk '{print $5$8}'| awk -F "/" '{if ($8<7) subtot2 += $1} END {print "; " subtot2}';
done 2> /dev/null | awk -v "time=$TIMESTAMP" -F ";" '{printf "%s,SAP,%s,SAP_PilotPacket_DC_volume,%s\n", time, $1, ($2+$3)}' 


# SUBSCRIBER IB
write_log "  -- SUBIB Records"
for dc in $allDC;
do
str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed`
if [[ $str ]]; then dcClli=`echo $dc | sed $str`; fi
$SSH $STANDBY "$HDFSCMD /data/$dc/SubscriberIB/$myyr1/$mymo1/$myda1/*/X.MAPREDUCE.0.0 2>/dev/null" | awk '{print $5$8}'| awk -v "dc=$dcClli" -F "/" '{if ($8>6) subtot1 += $1} END {printf "%s;%13d",dc, subtot1}';
$SSH $STANDBY "$HDFSCMD /data/$dc/SubscriberIB/$myyr2/$mymo2/$myda2/*/X.MAPREDUCE.0.0 2>/dev/null" | awk '{print $5$8}'| awk -F "/" '{if ($8<7) subtot2 += $1} END {print "; " subtot2}';
done 2> /dev/null | awk -v "time=$TIMESTAMP" -F ";" '{printf "%s,SAP,%s,SAP_SubscriberIB_DC_volume,%s\n", time, $1,($2+$3)}' 

write_log "Done getting Volume Stats"

# Software Version and patches.
write_log "Starting software patches & version collection."
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
done 2>/dev/null

write_log "Completed software patches & version collection."
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
    if [[ $str ]]; then dcClli=`echo $dc | sed $str`; fi
    # Skip if chassis does not exist.
    if [[ `$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis 2>/dev/null"` ]]; then
      outFile="/tmp/binList-ipfix-${chassis}-${dc}"
      $SSH $STANDBY "$HDFSCMD /data/$dc/$chassis/ipfix/${y}/*/*/_DONE 2>/dev/null" | awk '{print $NF}' >$outFile
      if [[ -s $outFile && $? -eq '0' ]]; then
         cmdsIpfixCount=`wc -l $outFile 2>/dev/null`
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
    if [[ $str ]]; then dcClli=`echo $dc | sed $str`; fi
    #Skip if chassis does not exist.	- skipped as it is PNSA/VISP
    #if [[ `$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis 2>/dev/null"` ]]; then
      outFile="/tmp/binList-ipfix-${chassis}-${dc}"
      $SSH $STANDBY "$HDFSCMD /data/$dc/ipfix/${y}/*/*/_DONE 2>/dev/null" | awk '{print $NF}' >$outFile
      if [[ -s $outFile && $? -eq '0' ]]; then
         cmdsIpfixCount=`wc -l $outFile 2>/dev/null`
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
    if [[ $str ]]; then dcClli=`echo $dc | sed $str`; fi
    # Skip if chassis does not exist.
    if [[ `$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis 2>/dev/null"` ]]; then
      outFile="/tmp/binList-pilot-${chassis}-${dc}"
      $SSH $STANDBY "$HDFSCMD /data/$dc/$chassis/pilotPacket/${y}/*/*/_DONE 2>/dev/null" | awk '{print $NF}' >$outFile
      if [[ -s $outFile && $? -eq '0' ]]; then
         cmdsIpfixCount=`wc -l $outFile 2>/dev/null`
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
    if [[ $str ]]; then dcClli=`echo $dc | sed $str`; fi
    #Skip if chassis does not exist.	- skipped as it is PNSA/VISP
    #if [[ `$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis 2>/dev/null"` ]]; then
      outFile="/tmp/binList-pilot-${chassis}-${dc}"
      $SSH $STANDBY "$HDFSCMD /data/$dc/pilotPacket/${y}/*/*/_DONE 2>/dev/null" | awk '{print $NF}' >$outFile
      if [[ -s $outFile && $? -eq '0' ]]; then
         cmdsIpfixCount=`wc -l $outFile 2>/dev/null`
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
    if [[ $str ]]; then dcClli=`echo $dc | sed $str`; fi
    #Skip if chassis does not exist.	- skipped as it is PNSA/VISP
    #if [[ `$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis 2>/dev/null"` ]]; then
      outFile="/tmp/binList-subib-${chassis}-${dc}"
      $SSH $STANDBY "$HDFSCMD /data/$dc/SubscriberIB/${y}/*/distcp_DONE 2>/dev/null" | awk '{print $NF}' >$outFile
      if [[ -s $outFile && $? -eq '0' ]]; then
         cmdsIpfixCount=`wc -l $outFile 2>/dev/null`
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

