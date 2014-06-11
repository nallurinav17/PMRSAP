#!/bin/bash

BASEPATH="/data/scripts/PMR"
source ${BASEPATH}/etc/PMRConfig.cfg

if [[ $# -eq 0 ]] ; then TYPE='05m' ; else TYPE=$1; fi

CURR=`date +%s`
myY=`date +%Y`
myM=`date +%m`
myD=`date +%d`

# Round off to next 5 minute
ROUNDOFF=$(echo "(${CURR}-(${CURR}%300))+300" | bc)

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
