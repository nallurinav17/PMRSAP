#!/bin/bash

# Wrapper for SAP Node status script 15 minute interval

# Rread Configuration and quit if not Master
cd /data/scripts/PMR
. /data/scripts/PMR/etc/PMRConfig.cfg
if [[ `am_i_master` -ne 0 ]] ; then exit 0; fi


/data/scripts/PMR/SAP/getSAPNodesStatus.sh | /data/scripts/PMR/bin/pmfile_writer.sh 15m

exit 0
