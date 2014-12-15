#!/bin/bash

# -------------------------------------------------------------------------------------------------------
# Read Configuration and needs to run on both management nodes.
BASEPATH=/data/scripts/PMR

cd ${BASEPATH}
#if [[ `am_i_master` -ne 0 ]] ; then exit 0; fi

# Read main configuration file
source ${BASEPATH}/etc/PMRConfig.cfg

# Read SAP Configuration file
source ${BASEPATH}/etc/SAPConfig.cfg

# Source variables in dc-config.cfg
source ${BASEPATH}/etc/dc-config.cfg
# -------------------------------------------------------------------------------------------------------

## Frequency (in secs) at which we should retry to restart snmptrapd and snmptt, in case they are not running. Should be less than 30 seconds.
FREQ=5

## Total number of restart attempts to be made after each FREQ seconds within a minute. FREQ*ATTEMPTS should not be greater than 30 sconds, since monitor script frequency is 1 minute and there are two daemons/processes to be monitored in every one minute, thus spending maximum of 30 seconds on each process.
ATTEMPTS=5

# Restore snmptt.ini change, to point to custom snmptt.conf
#RESTORE="/usr/bin/perl -pi -e 's/\/platform_latest\/gms\/monitoring\/conf\/snmptt\.conf/\/platform_latest\/gms\/monitoring\/conf\/snmptt\.conf\n\/data\/scripts\/PMR\/etc\/customsnmptt.conf/g' /platform_latest/gms/monitoring/conf/snmptt.ini"

## Trap Logs file : /tmp/zabbix_trap.log
TLOGS="/tmp"
## Variables
PIDTD=''
PIDTT=''
PIDS=''
PS='/bin/ps -ef'
FLAGTD='1'
FLAGTT='1'
FLAGS=''
LOGF="${TLOGS}/zabbix_trap.log"
INIF="/platform_latest/gms/monitoring/conf/snmptt.ini"
TRAPDF="/platform_latest/gms/monitoring/conf/snmptrapd.conf"

function identifyCustomSnmpttIniEntry {
if [[ -f /etc/snmp/snmptt.ini ]]; then 
  /bin/grep "customsnmptt.conf" ${INIF}
   if [[ $? -ne '0' ]]; then
	/usr/bin/perl -pi -e 's/\/platform_latest\/gms\/monitoring\/conf\/guavus_snmptt\.conf/\/platform_latest\/gms\/monitoring\/conf\/guavus_snmptt\.conf\n\/data\/scripts\/PMR\/etc\/customsnmptt.conf/g' ${INIF}
	sleep 1
	/usr/bin/perl -pi -e 's/\/platform_latest\/gms\/monitoring\/conf\/snmptt\.conf/\/platform_latest\/gms\/monitoring\/conf\/snmptt\.conf\n\/data\/scripts\/PMR\/etc\/customsnmptt.conf/g' ${INIF}
	sleep 1
	perl -pi -e 's/^\s*wildcard_expansion_separator.*$/wildcard_expansion_separator = ";"/' ${INIF}
	sleep 1
	/bin/grep "customsnmptt.conf" ${INIF}
	if [[ $? -eq '0' ]]; then write_log "Successfully restored ${INIF} to include customsnmptt.conf"
	else 
		write_log "Unable to restore ${INIF} to include customsnmptt.conf"
	fi
   fi
fi
}

function identifySnmpTrapdHandlerEntry {
if [[ -s /platform_latest/gms/monitoring/conf/snmptrapd.conf ]]; then
  /bin/grep "traphandle default snmptt" ${TRAPDF}
   if [[ $? -ne '0' ]]; then
        /usr/bin/perl -pi -e 's/^\s*traphandle default.*$/traphandle default snmptt/g' ${TRAPDF}
        sleep 1
        /bin/grep "traphandle default snmptt" ${TRAPDF}
        if [[ $? -eq '0' ]]; then write_log "Successfully restored traphandler in ${TRAPDF}"
	   SNMPTD_PID=''; SNMPTD_PID=`ps -ef | grep -v grep | egrep 'snmptrapd|snmptt' 2>/dev/null | awk '{print $2}' 2>/dev/null`;
           if [[ $SNMPTD_PID ]]; then	
  	        /bin/kill -9 ${SNMPTD_PID} 2>/dev/null
	   fi
        else
                write_log "Unable to restore traphandler in ${TRAPDF}"
        fi
   fi
fi
}

function identifySelf {

NAME=`basename $0`
PIDS=`${PS} | grep -v grep | grep ${NAME} | awk '{print $2}'`
count='0'
for i in $PIDS; do
  count=`expr $count + 1`
done
if [[ ${count} -gt '2' ]]; then exit; fi

}

function identifyTrapD {

PIDTD=`${PS} | egrep -v 'grep|tail' | grep 'snmptrapd' | awk '{print $2}'`
if [[ ! $PIDTD ]]; then
   write_log "SNMPTRAPD restart attempt."
   #/bin/bash -c "/usr/sbin/snmptrapd -On -Cc /platform_latest/gms/monitoring/conf/snmptrapd.conf -Lf /var/log/snmptrapd.log -m ALL"
   /usr/bin/ssh -q root@localhost '/usr/sbin/snmptrapd -On -Cc /platform_latest/gms/monitoring/conf/snmptrapd.conf -Lf /var/log/snmptrapd.log -m ALL'
   if [[ $? -eq '0' ]]; then FLAGTD='0'; write_log "SNMPTRAPD restarted!"; identifyCustomSnmpttIniEntry; sleep 1; /sbin/service snmptt restart; fi
else
FLAGTD='0'
fi

}

function identifyTrapT {

PIDTT=`${PS} | egrep -v 'grep|tail' | grep 'snmptt' | grep zabbix | awk '{print $2}'`
if [[ ! $PIDTT ]]; then
   write_log "SNMPTT restart attempt."
   identifyCustomSnmpttIniEntry; sleep 1;
   /sbin/service snmptt restart
   if [[ $? -eq '0' ]]; then FLAGTT='0'; write_log "SNMPTT restarted!"; fi
else
FLAGTT='0'
fi

}


function rotate {

/bin/find ${TLOGS}/ -type f -mtime +${SNMPTTLOGROTATE} -name zabbix_* -exec rm -rf {} \;
DATE=`date +%Y%m%d`
if [[ ! -e ${LOGF}.${DATE}.gz ]]; then 
  if [[ -e ${LOGF} ]]; then
  /bin/gzip -cf ${LOGF} > ${LOGF}.${DATE}.gz
  if [[ $? -eq '0' ]]; then echo > ${LOGF}; fi
  fi
fi 

}

identifySelf

rotate

identifyCustomSnmpttIniEntry

identifySnmpTrapdHandlerEntry

ATT='0'
while [[ $FLAGTD -eq '1' ]]; do
   identifyTrapD
   ATT=`expr $ATT + 1`
   sleep $FREQ
   if [[ ${ATT} -eq ${ATTEMPTS} ]]; then FLAGTD='0'; fi
done

ATT='0'
while [[ $FLAGTT -eq '1' ]]; do
   identifyTrapT
   ATT=`expr $ATT + 1`
   sleep $FREQ
   if [[ ${ATT} -eq ${ATTEMPTS} ]]; then FLAGTT='0'; fi
done
