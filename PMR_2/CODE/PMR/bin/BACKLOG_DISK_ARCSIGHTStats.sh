#!/bin/bash

# Wrapper for SAP Backlog for IPFIX, PILOTPACKET & SUBIB Files per DC. Arcsight & disk partition stats for SAP nodes

HOSTNAME=`hostname`

# Read Configuration and quit if not Master 
cd /data/scripts/PMR
. /data/scripts/PMR/etc/PMRConfig.cfg
if [[ `am_i_master` -ne 0 ]] ; then exit 0; fi

. /data/scripts/PMR/etc/SAPConfig.cfg
. /data/scripts/PMR/etc/dc-config.cfg

# Call SAP BACKLOG_DISK_ARCSIGHTStats and send to pmfile writer
export CLI CLIRAW SSH BASEPATH DATAPATH HOSTNAME HADOOP
export BASEPATH HOSTNAME cmdsDC pnsaDC dcCMDS dcPNSA DATE LOGFILE NETWORK CNP CMP CCP SGW UIP CNP0
/data/scripts/PMR/SAP/getBACKLOG_DISK_ARCSIGHTStats.pl | /data/scripts/PMR/bin/pmfile_writer.sh 15m

exit 0
