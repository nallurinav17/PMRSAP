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

H=`date -d "1 hours ago" +"%Y/%m/%d %H"`

TMPFILE=/tmp/pmr_tmp_$TIMESTAMP

ENTITY='SAP'

write_log "Starting Collector Stats Collection."

STANDBY=`$SSH $NETWORK.$CNP0 "$CLI 'show cluster standby'" 2>/dev/null | grep internal | awk '{print $4}' | sed 's/,//g'`
if [[ -z ${STANDBY} ]] ; then write_log "Could not determine standby namenode, exiting"; exit 127 ; fi

MASTER=`$SSH $NETWORK.$CNP0 "$CLI 'show cluster master'" 2>/dev/null | grep internal | awk '{print $4}' | sed 's/,//g'`
if [[ -z ${MASTER} ]] ; then write_log "Could not determine master namenode, exiting"; exit 127 ; fi

hostn='';hostn=`/bin/grep -w "$MASTER" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
if [[ ! ${hostn} ]]; then hostn=`$SSH $NETWORK.$CNP0 "hostname"`; fi
if [[ ! ${hostn} ]]; then hostn="$MASTER"; fi

NNVIP="$NETWORK.$CNP0"
HDFSCMD="$HADOOP dfs -ls "

# -------------------------------------------------------------------------------------------------------


ADAPTORS_NN=''; ADAPTORS_NN=`$SSH $STANDBY "/opt/tms/bin/cli -t 'en' 'internal query iterate subtree /nr/collector/instance/1/adaptor'" 2>/dev/null | awk -F/ '{print $7"\n"}' | awk '{print $1}' | sort -u`

for ADAPTOR in ${ADAPTORS_NN}; do

# --------- Collector Stats Dropped Flow, hourly.
  stamp=''
  for collectorStatsDroppedFlow in `$SSH $NETWORK.$CNP0 "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR dropped-flow interval-type 5-min interval-count 12' 2>/dev/null | grep -v ^[A-Z] " 2>/dev/null | awk '{print $2"_"$3"_"$NF}' 2>/dev/null` ; do
  ds1='';ds1=`echo "$collectorStatsDroppedFlow" | awk -F '_' '{print $1" "$2}'`
  if [[ $ds1 ]]; then
    stamp=`date -d "$ds1" "+%Y%m%d-%H%M"`
  else 
    stamp=$TIMESTAMP
  fi
  collectorStatsDroppedFlow=`echo "$collectorStatsDroppedFlow" | awk -F '_'  '{print $NF}'`

  if [[ $collectorStatsDroppedFlow ]]; then
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_dropped_record_data_volume,$collectorStatsDroppedFlow"
  else
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_dropped_record_data_volume,0"
  fi
  done 2>/dev/null

  if [[ ! $stamp ]]; then
    epo=`date -d "1 hour ago" +"%s"`; epo=`echo "$epo - \`echo \"$epo % 300\" | bc \`" | bc`
    for i in `seq 0 300 3300`; do
      stamp=`echo "$epo + $i" | bc`
      stamp=`date -d \@${stamp} +%Y%m%d-%H%M`
      echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_dropped_record_data_volume,0"
    done
  fi

# --------- Collector Stats Total Flow, hourly.

  stamp=''
  for collectorStatsTotalFlow in `$SSH $NETWORK.$CNP0 "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR total-flow interval-type 5-min interval-count 12' 2>/dev/null | grep -v ^[A-Z]" 2>/dev/null | awk '{print $2"_"$3"_"$NF}' 2>/dev/null`; do

  ds2='';ds2=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $1" "$2}'`
  if [[ $ds2 ]]; then
    stamp=`date -d "$ds2" "+%Y%m%d-%H%M"`
  else
    stamp=$TIMESTAMP
  fi
  collectorStatsTotalFlow=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $NF}'`
  if [[ $collectorStatsTotalFlow ]]; then
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_record_data_volume,$collectorStatsTotalFlow"
  else
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_record_data_volume,0"
  fi
  done

  if [[ ! $stamp ]]; then
    epo=`date -d "1 hour ago" +"%s"`; epo=`echo "$epo - \`echo \"$epo % 300\" | bc \`" | bc`
    for i in `seq 0 300 3300`; do
      stamp=`echo "$epo + $i" | bc`
      stamp=`date -d \@${stamp} +%Y%m%d-%H%M`
      echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_record_data_volume,0"
    done
  fi

# ----------- Collector Stats Dropped Flow Percentage, hourly.

#collectorStatsDroppedFlowPercent='0'
#if [[ $collectorStatsDroppedFlow && $collectorStatsTotalFlow ]]; then
#    collectorStatsDroppedFlowPercent=`echo "scale=2;($collectorStatsDroppedFlow/$collectorStatsTotalFlow)*100"|bc 2>/dev/null`
#    #if [[ ! $collectorStatsDroppedFlowPercent ]]; then collectorStatsDroppedFlowPercent='-1'; fi
#    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_dropped_record_data_percent,$collectorStatsDroppedFlowPercent"
#else
#    #collectorStatsDroppedFlowPercent='-1'
#    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_dropped_record_data_percent,$collectorStatsDroppedFlowPercent"
#fi

done


# Second collector - SGW adaptor stats.
# ------------------------------------------------------------------------------------------
STANDBY_SG=`$SSH $NETWORK.$SGW0 "$CLI 'show cluster standby'" 2>/dev/null | grep internal | awk '{print $4}' | sed 's/,//g'`
if [[ -z ${STANDBY_SG} ]] ; then write_log "Could not determine standby service gateway, exiting"; exit 127 ; fi

MASTER_SG=`$SSH $NETWORK.$SGW0 "$CLI 'show cluster master'" 2>/dev/null | grep internal | awk '{print $4}' | sed 's/,//g'`
if [[ -z ${MASTER_SG} ]] ; then write_log "Could not determine master service gateway, exiting"; exit 127 ; fi

hostn='';hostn=`/bin/grep -w "${MASTER_SG}" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
if [[ ! ${hostn} ]]; then hostn=`$SSH $NETWORK.$SGW0 "hostname"`; fi
if [[ ! ${hostn} ]]; then hostn="${MASTER_SG}"; fi
# ------------------------------------------------------------------------------------------

ADAPTORS_SGW=''; ADAPTORS_SGW=`$SSH ${STANDBY_SG} "/opt/tms/bin/cli -t 'en' 'internal query iterate subtree /nr/collector/instance/1/adaptor'" 2>/dev/null | awk -F/ '{print $7"\n"}' | awk '{print $1}' | sort -u`

for ADAPTOR in ${ADAPTORS_SGW}; do

# --------- Collector Stats Dropped Flow, hourly.
  stamp=''
  for collectorStatsDroppedFlow in `$SSH $NETWORK.$SGW0 "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR dropped-flow interval-type 5-min interval-count 12' 2>/dev/null | /bin/grep -v ^[A-Z] 2>/dev/null" 2>/dev/null | awk '{print $2"_"$3"_"$NF}' 2>/dev/null` ; do
  ds1='';ds1=`echo "$collectorStatsDroppedFlow" | awk -F '_' '{print $1" "$2}'`
  if [[ $ds1 ]]; then
    stamp=`date -d "$ds1" "+%Y%m%d-%H%M"`
  else
    stamp=$TIMESTAMP
  fi
  collectorStatsDroppedFlow=`echo "$collectorStatsDroppedFlow" | awk -F '_' '{print $NF}'`

  if [[ $collectorStatsDroppedFlow ]]; then
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_dropped_record_data_volume,$collectorStatsDroppedFlow"
  else
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_dropped_record_data_volume,0"
  fi
  done

  if [[ ! $stamp ]]; then
    epo=`date -d "1 hour ago" +"%s"`; epo=`echo "$epo - \`echo \"$epo % 300\" | bc \`" | bc`
    for i in `seq 0 300 3300`; do
      stamp=`echo "$epo + $i" | bc`
      stamp=`date -d \@${stamp} +%Y%m%d-%H%M`
      echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_dropped_record_data_volume,0"
    done
  fi

# --------- Collector Stats Total Flow, hourly.
  stamp=''
  for collectorStatsTotalFlow in `$SSH $NETWORK.$SGW0 "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR total-flow interval-type 5-min interval-count 12' 2>/dev/null | /bin/grep -v ^[A-Z] 2>/dev/null " 2>/dev/null | awk '{print $2"_"$3"_"$NF}' 2>/dev/null`; do

  ds2='';ds2=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $1" "$2}'`
  if [[ $ds2 ]]; then
    stamp=`date -d "$ds2" "+%Y%m%d-%H%M"`
  else
    stamp=$TIMESTAMP
  fi
  collectorStatsTotalFlow=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $NF}'`
  if [[ $collectorStatsTotalFlow ]]; then
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_record_data_volume,$collectorStatsTotalFlow"
  else
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_record_data_volume,0"
  fi
  done

  if [[ ! $stamp ]]; then
    epo=`date -d "1 hour ago" +"%s"`; epo=`echo "$epo - \`echo \"$epo % 300\" | bc \`" | bc`
    for i in `seq 0 300 3300`; do
      stamp=`echo "$epo + $i" | bc`
      stamp=`date -d \@${stamp} +%Y%m%d-%H%M`
      echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_record_data_volume,0"
    done
  fi

# --------- Collector Stats Files Processed, hourly.

   stamp=''
   for collectorStatsTotalFlow in `$SSH $NETWORK.$SGW0 "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR num-files-processed interval-type 5-min interval-count 12' 2>/dev/null | /bin/grep -v ^[A-Z] 2>/dev/null" 2>/dev/null | awk '{print $2"_"$3"_"$NF}' 2>/dev/null`; do

  ds2='';ds2=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $1" "$2}'`
  if [[ $ds2 ]]; then
    stamp=`date -d "$ds2" "+%Y%m%d-%H%M"`
  else
    stamp=$TIMESTAMP
  fi
  collectorStatsTotalFlow=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $NF}'`
  if [[ $collectorStatsTotalFlow ]]; then
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_processed,$collectorStatsTotalFlow"
  else
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_processed,0"
    write_log "Unable to calculate num-files-processed for $ADAPTOR"
  fi
  done

  if [[ ! $stamp ]]; then
    epo=`date -d "1 hour ago" +"%s"`; epo=`echo "$epo - \`echo \"$epo % 300\" | bc \`" | bc`
    for i in `seq 0 300 3300`; do
      stamp=`echo "$epo + $i" | bc`
      stamp=`date -d \@${stamp} +%Y%m%d-%H%M`
      echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_processed,0"
    done
  fi

# --------- Collector Stats Files Dropped, hourly.


  stamp=''
  for collectorStatsTotalFlow in `$SSH $NETWORK.$SGW0 "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR num-files-dropped interval-type 5-min interval-count 12' 2>/dev/null | /bin/grep -v ^[A-Z] 2>/dev/null" 2>/dev/null | awk '{print $2"_"$3"_"$NF}' 2>/dev/null`; do

  ds2='';ds2=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $1" "$2}'`
  if [[ $ds2 ]]; then
    stamp=`date -d "$ds2" "+%Y%m%d-%H%M"`
  else
    stamp=$TIMESTAMP
  fi
  collectorStatsTotalFlow=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $NF}'`
  if [[ $collectorStatsTotalFlow ]]; then
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_dropped,$collectorStatsTotalFlow"
  else
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_dropped,0"
    write_log "Unable to calculate num-files-dropped for $ADAPTOR"
  fi
  done
 
  if [[ ! $stamp ]]; then
    epo=`date -d "1 hour ago" +"%s"`; epo=`echo "$epo - \`echo \"$epo % 300\" | bc \`" | bc`
    for i in `seq 0 300 3300`; do
      stamp=`echo "$epo + $i" | bc`
      stamp=`date -d \@${stamp} +%Y%m%d-%H%M`
      echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_dropped,0"
    done
  fi

# --------- Collector Stats Files With Errors, hourly.

  stamp=''
  for collectorStatsTotalFlow in `$SSH $NETWORK.$SGW0 "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR num-files-with-errors interval-type 5-min interval-count 12' 2>/dev/null | /bin/grep -v ^[A-Z] 2>/dev/null" 2>/dev/null | awk '{print $2"_"$3"_"$NF}' 2>/dev/null`; do

  ds2='';ds2=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $1" "$2}'`
  if [[ $ds2 ]]; then
    stamp=`date -d "$ds2" "+%Y%m%d-%H%M"`
  else
    stamp=$TIMESTAMP
  fi
  collectorStatsTotalFlow=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $NF}'`
  if [[ $collectorStatsTotalFlow ]]; then
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_with_errors,$collectorStatsTotalFlow"
  else
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_with_errors,0"
    write_log "Unable to calculate num-files-with-errors for $ADAPTOR"
  fi
  done

  if [[ ! $stamp ]]; then
    epo=`date -d "1 hour ago" +"%s"`; epo=`echo "$epo - \`echo \"$epo % 300\" | bc \`" | bc`
    for i in `seq 0 300 3300`; do
      stamp=`echo "$epo + $i" | bc`
      stamp=`date -d \@${stamp} +%Y%m%d-%H%M`
      echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_with_errors,0"
   done
  fi

done

write_log "Completed calculating collector stats."
write_log "Calculating ArcSight SNMP messages resolved or unresolved stats."

stamp="$TIMESTAMP"
flag='1'

for ID in `/opt/oozie/bin/oozie jobs -oozie http://${NETWORK}.${CNP0}:8080/oozie -jobtype wf -len 100000 2>/dev/null | grep "\`date -d \"1 hour ago\" +\"%Y-%m-%d %H\"\`" 2>/dev/null | grep ArcSight | grep SUCCEEDED | awk '{print $1}'`; do
  write_log "------ Calibrated job ID ${ID}"
  for node in $NNVIP $STANDBY $MASTER; do 
    checkSource=''; checkSource=`$SSH ${node} "/bin/ls /data/oozie-admi/${ID} 2>/dev/null" 2>/dev/null `
    if [[ $? -eq '0' ]]; then
       write_log "------ Found job ID ${ID} at ${node}"
       
# Sample output ########################       
#14/11/25 16:03:19 INFO mapred.JobClient:     ipv6 snmp records resolved=0
#14/11/25 16:03:19 INFO mapred.JobClient:     ipv6 snmp records not resolved=0
#14/11/25 16:03:19 INFO mapred.JobClient:     ipv4 snmp records not resolved=8534
#14/11/25 16:03:19 INFO mapred.JobClient:     ipv4 snmp records resolved=1514
#########################################

       # Count records.       
       $SSH ${node} "/bin/egrep 'snmp records resolved|snmp records not resolved' /data/oozie-admi/${ID}/MdnQueryJob--ssh/*.stdout 2>/dev/null" 2>/dev/null >>${TMPFILE}
       if [[ -s ${TMPFILE} && $? -eq '0' ]]; then
 	 resolved='0'; resolved=`/bin/grep "records resolved" ${TMPFILE} | awk -F= '{sum=sum+$NF} END {print sum}'` 
         unresolved='0'; unresolved=`/bin/grep "records not resolved" ${TMPFILE} | awk -F= '{sum=sum+$NF} END {print sum}'`
 	 stamp=`/bin/grep "records not resolved" ${TMPFILE} | awk '{print $2}' | tail -1`; stamp=`date -d "$stamp" +%Y%m%d-%H%M`
       else
	 resolved='0'; unresolved='0'
       fi

       # Remove temporary
       /bin/rm -f ${TMPFILE} 2>/dev/null

       # Hostname
       hostn='';hostn=`/bin/grep -w "${node}" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
       if [[ ! ${hostn} ]]; then hostn=`$SSH $node "hostname"`; fi
       if [[ ! ${hostn} ]]; then hostn="${node}"; fi

       echo "$stamp,$ENTITY/$hostn,,NS_MDN_lookup_resolved_msg_volume,$resolved"
       echo "$stamp,$ENTITY/$hostn,,NS_MDN_lookup_unresolved_msg_volume,$unresolved" 
       flag='';break
    else
       write_log "------ Unable to locate job ID ${ID} at ${node}"
       continue
    fi
  done

done 2>/dev/null 

if [[ $flag ]]; then
  write_log "------ Can not find successful iteration of ArcSight job in the last hour `date -d \"1 hour ago\" +\"%Y-%m-%d %H00\"`"
  echo "$TIMESTAMP,$ENTITY/$hostn,,NS_MDN_lookup_resolved_msg_volume,0"
  echo "$TIMESTAMP,$ENTITY/$hostn,,NS_MDN_lookup_unresolved_msg_volume,0"
fi

write_log "Completed calculating ArcSight SNMP messages resolved or unresolved stats."
exit 0

