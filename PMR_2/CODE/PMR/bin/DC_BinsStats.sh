#!/bin/bash

# Wrapper for SAP Missing DC_bins

HOSTNAME=`hostname`

# Read Configuration and quit if not Master 
cd /data/scripts/PMR
. /data/scripts/PMR/etc/PMRConfig.cfg
if [[ `am_i_master` -ne 0 ]] ; then exit 0; fi

. /data/scripts/PMR/etc/SAPConfig.cfg
. /data/scripts/PMR/etc/dc-config.cfg

# Call Missing DC_bins Script and send to pmfile writer
export CLI CLIRAW SSH BASEPATH DATAPATH HOSTNAME HADOOP
export BASEPATH HOSTNAME cmdsDC pnsaDC dcCMDS dcPNSA DATE LOGFILE NETWORK CNP CMP CCP SGW UIP CNP0
/data/scripts/PMR/SAP/getDC_BinsStats.pl | /data/scripts/PMR/bin/pmfile_writer.sh 01d

exit 0
