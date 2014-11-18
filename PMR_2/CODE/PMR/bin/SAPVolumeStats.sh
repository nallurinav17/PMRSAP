#!/bin/bash

# Wrapper for SAP Byte Volumes for MIDM Agg, MIDMEnr, IPFIX, PILOTPACKET, SUBIB Files per DC and Total


# Rread Configuration and quit if not Master 
cd /data/scripts/PMR
. /data/scripts/PMR/etc/PMRConfig.cfg
if [[ `am_i_master` -ne 0 ]] ; then exit 0; fi

# Call SAP Volume Script and send to pmfile writer
/data/scripts/PMR/SAP/getVolumeStats.sh | /data/scripts/PMR/bin/pmfile_writer.sh 01d

exit 0
