#!/bin/bash

BASEPATH="/data/scripts/PMR"
source ${BASEPATH}/etc/PMRConfig.cfg

FILEStamp=''
if [[ $# -eq 0 ]] ; then TYPE='05m' ; else TYPE=$1; fi
# Introduced the FileStamp variable (round off to upper value by $2 minutes) to put the KPI collected at every 5 minute into a single file name forming at upper $2 minutes from current time.
if [[ $2 ]] ; then FILEStamp=$2; else FILEStamp='5'; fi

# Calculate the file Stamp.

if [[ ${FILEStamp} ]]; then
 FILEStamp=`echo "$FILEStamp * 60" | bc`
fi

# Round off to next 5/$2 minute
CURR=`date +%s`
ROUNDOFF=$(echo "(${CURR}-(${CURR}%${FILEStamp}))+${FILEStamp}" | bc)
#ROUNDOFF=$(echo "(${CURR}-(${CURR}%300))+300" | bc)
myY=`date -d @${ROUNDOFF} +%Y`
myM=`date -d @${ROUNDOFF} +%m`
myD=`date -d @${ROUNDOFF} +%d`
PMDIR="$DATAPATH/$myY/$myM/$myD"
PMFILE=`date -d @${ROUNDOFF} +"PM-%Y%m%d-%H%M-${TYPE}-0.csv"`
PMPATH="$PMDIR/$PMFILE"

if [[ ! -e $PMDIR ]] ; then mkdir -p $PMDIR ; fi

if [[ ! -f ${PMPATH} ]] ; then echo "#timestamp, entity, subentity, counterid, countervalue" > ${PMPATH} ; fi

while IFS= read -r line; do
  printf '%s\n' "$line" >> ${PMPATH}
done 

write_log "Wrote data to $PMPATH"

exit 0 
