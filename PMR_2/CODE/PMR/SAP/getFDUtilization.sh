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
write_log "Starting FD Utilization Measurement."
for node in $CNP $UIP $CMP $SGW $CCP; do
  #-----
  hostn='';hostn=`/bin/grep -w "$NETWORK.$node" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
  if [[ ! ${hostn} ]]; then hostn=`$SSH $NETWORK.$node "hostname"`; fi
  if [[ ! ${hostn} ]]; then hostn="$NETWORK.$node"; fi
  #-----

  #----- FD Utilization

  val='';
  patches=''
  val=`$SSH $NETWORK.$node "/bin/cat /proc/sys/fs/file-nr 2>/dev/null"  2>/dev/null | awk '{print $1":"$2}' 2>/dev/null`
  
  if [[ $val && $? -eq '0' ]]; then
   usedAllocatedFD=`echo "$val" | awk -F ':' '{print $1}' 2>/dev/null`
   unUsedAllocatedFD=`echo "$val" | awk -F ':' '{print $2}' 2>/dev/null`
   if [[ $usedAllocatedFD && $unUsedAllocatedFD ]]; then
     echo "$TIMESTAMP,SAP/$hostn,,used_allocated_file_descriptors,$usedAllocatedFD"
     echo "$TIMESTAMP,SAP/$hostn,,unused_allocated_file_descriptors,$unUsedAllocatedFD"
     fdUtilization='';fdUtilization=`echo "$usedAllocatedFD + $unUsedAllocatedFD" | bc 2>/dev/null`
     echo "$TIMESTAMP,SAP/$hostn,,file_descriptor_utilization,$fdUtilization"
   else
     echo "$TIMESTAMP,SAP/$hostn,,used_allocated_file_descriptors,0"
     echo "$TIMESTAMP,SAP/$hostn,,unused_allocated_file_descriptors,0"
     echo "$TIMESTAMP,SAP/$hostn,,file_descriptor_utilization,0"
   fi
  else
     echo "$TIMESTAMP,SAP/$hostn,,used_allocated_file_descriptors,0"
     echo "$TIMESTAMP,SAP/$hostn,,unused_allocated_file_descriptors,0"
     echo "$TIMESTAMP,SAP/$hostn,,file_descriptor_utilization,0"
  fi
   

done 2>/dev/null
write_log "Completed computing FD Utilization for all nodes."

exit 0
