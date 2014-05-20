#!/bin/bash

# Fetch SAR data for CPU and Memory utilization for the current hour at 5 minute interval

# -------------------------------------------------------------------------------------------------------
BASEPATH=/data/scripts/PMR

# Read main configuration file
source ${BASEPATH}/etc/PMRConfig.cfg

# Read SAP Configuration file
source ${BASEPATH}/etc/SAPConfig.cfg
# -------------------------------------------------------------------------------------------------------

#  Determine start and end time
  START=`${DATE} +"%H:50:00" -d "1 hour ago"`
  END=`${DATE} +"%H:59:00"`

  if [[ ${START} == '23:50:00' ]]; then
        START='00:00:00'
  fi

write_log "Starting Poller for CPU Mem Utilization"

# Poll ALl nodes in SAP
# ---------------------
for element in $CNP $CMP $UIP $CCP $SGW 
do

  # Get MEM Utilization and interpolate for 5 minute
  $SSH ${NETWORK}.${element} "${SADF} -D -s ${START} -e ${END}  -- -r " | egrep -v ^# | ${AWK} -F ";" {'printf ("%s, SAP, %s, Memory_utilization, %s\n%s, SAP, %s, Memory_utilization, %s\n", strftime("%Y%m%d-%H%M",$3), $1, $6, strftime("%Y%m%d-%H%M",$3+300), $1, $6)'} | grep -v "19700"
  # sar sometimes gives a null output i.e epoch zero. filter it out.

  # Get CPU Utilization and interpolate for 5 minute
  $SSH ${NETWORK}.${element} "${SADF} -D -s ${START} -e ${END} " | egrep -v ^# | ${AWK} -F ";" {'printf ("%s, SAP, %s, CPU_utilization, %0.2f\n%s, SAP, %s, CPU_utilization, %0.2f\n", strftime("%Y%m%d-%H%M",$3), $1, 100-$NF, strftime("%Y%m%d-%H%M",$3+300), $1, 100-$NF)'} | grep -v "19700"
  # sar sometimes gives a null output i.e epoch zero. filter it out.

done

write_log "Completed Poller for CPU Mem Utilization on all SAP Nodes"

exit 0
