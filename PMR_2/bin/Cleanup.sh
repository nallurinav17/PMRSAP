#!/bin/bash


# Rread Configuration and quit if not Master 
cd /data/scripts/PMR
. /data/scripts/PMR/etc/PMRConfig.cfg

find ${CLEANUPPATH} -mindepth 2 -type d -mtime +5 -exec rm -fr {} \;
#find ${SANDATA} -mindepth 2 -type d -mtime +${RETENTION} -exec rm -fr {} \;

exit 0
