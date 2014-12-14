#!/bin/bash

# Wrapper for SAP Byte Volumes for MIDM Agg, MIDMEnr, IPFIX, PILOTPACKET, SUBIB Files per DC and Total


# Rread Configuration and quit if not Master 
cd /data/scripts/PMR
. /data/scripts/PMR/etc/PMRConfig.cfg
if [[ `am_i_master` -ne 0 ]] ; then exit 0; fi

# Call SAP PMR v2 hourly KPI Scripts and send to pmfile writer

# Running every hour, calculating 5 minute stats.
/data/scripts/PMR/SAP/getCollectorStats-5min.sh | /data/scripts/PMR/bin/pmfile_writer.sh 05m 60
# Data Transfer Backlog
/data/scripts/PMR/SAP/getFDUtilization.sh | /data/scripts/PMR/bin/pmfile_writer.sh 1h 60
# FD Utilization
/data/scripts/PMR/SAP/getDcBacklog.sh | /data/scripts/PMR/bin/pmfile_writer.sh 1h 60


exit 0
