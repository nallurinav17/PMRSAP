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
if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi
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
if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi
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
if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi
$SSH $STANDBY "$HDFSCMD /data/$dc/{1,2,3,4}/ipfix/$myyr1/$mymo1/$myda1/*/*/*IPFIX*.? 2>/dev/null" | awk '{print $5$8}'| awk -v "dc=$dcClli" -F "/" '{if ($9>6) subtot1 += $1} END {printf "%s;%13d",dc, subtot1}';
$SSH $STANDBY "$HDFSCMD /data/$dc/{1,2,3,4}/ipfix/$myyr2/$mymo2/$myda2/*/*/*IPFIX*.? 2>/dev/null"| awk '{print $5$8}'| awk -F "/" '{if ($9<7) subtot2 += $1} END {print ";"subtot2}';
done  2>/dev/null | awk -v "time=$TIMESTAMP" -F ";" '{printf "%s,SAP,%s,SAP_IPFIX_DC_volume,%s\n", time, $1, ($2+$3)}' 

for dc in $pnsaDC;
do
str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed`
if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi
$SSH $STANDBY "$HDFSCMD /data/$dc/ipfix/$myyr1/$mymo1/$myda1/*/*/*IPFIX*.? 2>/dev/null" | awk '{print $5$8}'| awk -v "dc=$dcClli" -F "/" '{if ($8>6) subtot1 += $1} END {printf "%s;%13d",dc, subtot1}';
$SSH $STANDBY "$HDFSCMD /data/$dc/ipfix/$myyr2/$mymo2/$myda2/*/*/*IPFIX*.? 2>/dev/null" | awk '{print $5$8}'| awk -F "/" '{if ($8<7) subtot2 += $1} END {print ";"subtot2}';
done 2> /dev/null | awk -v "time=$TIMESTAMP" -F ";" '{printf "%s,SAP,%s,SAP_IPFIX_DC_volume,%s\n", time, $1, ($2+$3)}'

# PILOTPACKET
write_log "  -- RADIUS Records"

for dc in $cmdsDC;
do
str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed`
if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi
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
if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi
$SSH $STANDBY "$HDFSCMD  /data/$dc/pilotPacket/$myyr1/$mymo1/$myda1/*/*/*RADIUS*0 2>/dev/null" | awk '{print $5$8}'| awk -v "dc=$dcClli" -F "/" '{if ($8>6) subtot1 += $1} END {printf "%s;%13d",dc, subtot1}';
$SSH $STANDBY "$HDFSCMD  /data/$dc/pilotPacket/$myyr2/$mymo2/$myda2/*/*/*RADIUS*0 2>/dev/null" | awk '{print $5$8}'| awk -F "/" '{if ($8<7) subtot2 += $1} END {print "; " subtot2}';
done 2> /dev/null | awk -v "time=$TIMESTAMP" -F ";" '{printf "%s,SAP,%s,SAP_PilotPacket_DC_volume,%s\n", time, $1, ($2+$3)}' 


# SUBSCRIBER IB
write_log "  -- SUBIB Records"
for dc in $allDC;
do
str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed`
if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi
$SSH $STANDBY "$HDFSCMD /data/$dc/SubscriberIB/$myyr1/$mymo1/$myda1/*/X.MAPREDUCE.0.0 2>/dev/null" | awk '{print $5$8}'| awk -v "dc=$dcClli" -F "/" '{if ($8>6) subtot1 += $1} END {printf "%s;%13d",dc, subtot1}';
$SSH $STANDBY "$HDFSCMD /data/$dc/SubscriberIB/$myyr2/$mymo2/$myda2/*/X.MAPREDUCE.0.0 2>/dev/null" | awk '{print $5$8}'| awk -F "/" '{if ($8<7) subtot2 += $1} END {print "; " subtot2}';
done 2> /dev/null | awk -v "time=$TIMESTAMP" -F ";" '{printf "%s,SAP,%s,SAP_SubscriberIB_DC_volume,%s\n", time, $1,($2+$3)}' 

write_log "Done getting Volume Stats"

exit 0

