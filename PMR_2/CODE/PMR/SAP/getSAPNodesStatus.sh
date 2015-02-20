#!/bin/bash

# -------------------------------------------------------------------------------------------------------
BASEPATH=/data/scripts/PMR

# Read main configuration file
source ${BASEPATH}/etc/PMRConfig.cfg

# Read SAP Configuration file
source ${BASEPATH}/etc/SAPConfig.cfg
# -------------------------------------------------------------------------------------------------------

TIMESTAMP=`date "+%Y%m%d-%H%M"`

TMPFILE=/tmp/pmr_tmp_$TIMESTAMP

ENTITY='SAP'

write_log "Starting SAP Node status check"

DFSUSED='-1'

# Get Hadoop Status from Master Name node
SUBENTITY=`$SSH $NETWORK.$CNP0 'hostname'`
if [[ $? -eq '0' ]] 
then 
  # Ok to start  
  HADOOPSTATUS=0 
  # Get list of processes
  $SSH $NETWORK.$CNP0 'ps -ef' > $TMPFILE
  # Check Namenode process
  if ! egrep -q "org.apache.hadoop.hdfs.server.namenode.NameNode" $TMPFILE ; then let HADOOPSTATUS+=$NAMENODE ; fi
  # Check Datanode process
  if ! egrep -q "org.apache.hadoop.hdfs.server.datanode.DataNode" $TMPFILE ; then let HADOOPSTATUS+=$DATANODE ; fi
  # Check Jobtracker process
  if ! egrep -q "org.apache.hadoop.mapred.JobTracker" $TMPFILE ; then let HADOOPSTATUS+=$JOBTRACKER ; fi
  # Check oozie server process
  if ! egrep -q "org.apache.catalina.startup.Bootstrap start" $TMPFILE ; then let HADOOPSTATUS+=$CATALINA ; fi
  # HDFS Utilization
  $SSH $NETWORK.$CNP0 "$HADOOP dfsadmin -report" 2>/dev/null > $TMPFILE.dfsreport
  DFSUSED=`cat $TMPFILE.dfsreport | grep "DFS Used%" |head -1 | sed -e 's/DFS Used\%: //' | sed -e 's/\%//'`
else 
  HADOOPSTATUS=1
  SUBENTITY=`/bin/grep $NETWORK.$CNP0 /etc/hosts | awk '{print $2}'`
fi

# Cleanup
rm -f $TMPFILE
rm -f $TMPFILE.dfsreport
# Write Data
printf "%s,%s,%s,Hadoop_status,%s\n" "$TIMESTAMP" "$ENTITY" "$SUBENTITY" "$HADOOPSTATUS" 
printf "%s,%s,%s,HDFS_utilization,%s\n" "$TIMESTAMP" "$ENTITY" "$SUBENTITY" "$DFSUSED" 

# Get Collector Status
for node in $CNP ; do
  SUBENTITY=`$SSH $NETWORK.$node 'hostname'`
  if [[ $? -eq '0' ]] 
  then 
  STATUS=0
  # Check Collector process
    $SSH $NETWORK.$node '/opt/tms/bin/cli -t "en" "show pm process collector"' > $TMPFILE
    if ! egrep -q "Current status:  running" $TMPFILE ; then let STATUS+=$COLLECTOR ; fi

  else 
  # Not reachable
  STATUS=1
  SUBENTITY=`/bin/grep $NETWORK.$node /etc/hosts | awk '{print $2}'`
  fi

  # Write Data
    printf "%s,%s,%s,Node_status,%s\n" "$TIMESTAMP" "$ENTITY" "$SUBENTITY" "$STATUS" 
  # Clean up
    rm -f $TMPFILE
done


# Get Compute Nodes status 
for node in $CMP ; do
  SUBENTITY=`$SSH $NETWORK.$node 'hostname'`
  if [[ $? -eq '0' ]] 
  then 
  STATUS=0
  $SSH $NETWORK.$node 'ps -ef' > $TMPFILE

  # Check Datanode and Tasktracker processes
    if ! egrep -q "org.apache.hadoop.hdfs.server.datanode.DataNode" $TMPFILE ; then let STATUS+=$DATANODE ; fi
    if ! egrep -q "org.apache.hadoop.mapred.TaskTracker" $TMPFILE ; then let STATUS+=$TASKTRACKER ; fi

  else 
  # Not reachable
  STATUS=1
  SUBENTITY=`/bin/grep $NETWORK.$node /etc/hosts | awk '{print $2}'`
  fi

  # Write Data
    printf "%s,%s,%s,Node_status,%s\n" "$TIMESTAMP" "$ENTITY" "$SUBENTITY" "$STATUS" 
  # Clean up
    rm -f $TMPFILE
done

# Get UI Nodes status 
for node in $UIP ; do
  SUBENTITY=`$SSH $NETWORK.$node 'hostname'`
  if [[ $? -eq '0' ]] 
  then 
  STATUS=0
  $SSH $NETWORK.$node 'ps -ef' > $TMPFILE

  # Check HSQLDB and Tomcat processes
    #if ! egrep -q "org.hsqldb.Server" $TMPFILE ; then let STATUS+=$HSQLDB; fi
    if ! egrep -q "org.apache.catalina.startup.Bootstrap" $TMPFILE ; then let STATUS+=$TOMCAT; fi

  else 
  # Not reachable
  STATUS=1
  SUBENTITY=`/bin/grep $NETWORK.$node /etc/hosts | awk '{print $2}'`
  fi

  # Write data
    printf "%s,%s,%s,Node_status,%s\n" "$TIMESTAMP" "$ENTITY" "$SUBENTITY" "$STATUS" 
  # Clean up
    rm -f $TMPFILE
done


# ------------------------------------------------------------------------------------------
STANDBY_SG=`$SSH $NETWORK.$SGW0 "$CLI 'show cluster standby'" 2>/dev/null | grep internal | awk '{print $4}' | sed 's/,//g'`
if [[ -z ${STANDBY_SG} ]] ; then write_log "Could not determine standby service gateway, exiting"; exit 127 ; fi

MASTER_SG=`$SSH $NETWORK.$SGW0 "$CLI 'show cluster master'" 2>/dev/null | grep internal | awk '{print $4}' | sed 's/,//g'`
if [[ -z ${MASTER_SG} ]] ; then write_log "Could not determine master service gateway, exiting"; exit 127 ; fi
# ------------------------------------------------------------------------------------------

# Get Service gateway Nodes status 
for node in $SGW; do
  SUBENTITY=`$SSH $NETWORK.$node 'hostname'`
  if [[ $? -eq '0' ]] 
  then 
  STATUS=0
  if [[ "$NETWORK.$node" == "$MASTER_SG" ]]; then
    $SSH $NETWORK.$node 'ps -ef' > $TMPFILE
    # Check Oozie process
    if ! egrep -q "org.apache.catalina.startup.Bootstrap" $TMPFILE ; then let STATUS+=$CATALINA ; fi
  fi
  # Check Tibco process
    $SSH $NETWORK.$node '/opt/tms/bin/cli -t "en" "show pm process tibco"' > $TMPFILE
    if ! egrep -q "Current status:  running" $TMPFILE ; then let STATUS+=$TIBCO ; fi

  else 
  # Not reachable
  STATUS=1
  SUBENTITY=`/bin/grep $NETWORK.$node /etc/hosts | awk '{print $2}'`
  fi

  # Write data
    printf "%s,%s,%s,Node_status,%s\n" "$TIMESTAMP" "$ENTITY" "$SUBENTITY" "$STATUS" 
  # Clean up
    rm -f $TMPFILE
done


# Get Caching compute Nodes status 
for node in $CCP ; do
  SUBENTITY=`$SSH $NETWORK.$node 'hostname'`
  if [[ $? -eq '0' ]] ; then STATUS=0 ; else STATUS=1 ; SUBENTITY=`/bin/grep $NETWORK.$node /etc/hosts | awk '{print $2}'` ; fi
  # Write data
  printf "%s,%s,%s,Node_status,%s\n" "$TIMESTAMP" "$ENTITY" "$SUBENTITY" "$STATUS" 
done


# Get Insta status from MASTER CCP
# Get cc command result 
#$SSH $NETWORK.$CCP0 '/usr/local/Calpont/bin/calpontConsole getsysteminfo' > $TMPFILE
INSTASTATUS=0
# Check status of both nodes
#  if ! egrep -q "Module pm1    ACTIVE" $TMPFILE ; then let INSTASTATUS+=1 ; fi
#  if ! egrep -q "Module pm2    ACTIVE" $TMPFILE ; then let INSTASTATUS+=1 ; fi
for module in `$SSH $NETWORK.$CCP0 '/usr/local/Calpont/bin/calpontConsole getsysteminfo' 2>/dev/null | grep ^Module 2>/dev/null | awk '{print $2";"$3}'`; do
mod=`echo $module | awk -F ';' '{print $1}'`;
status=`echo $module | awk -F ';' '{print $2}'`;
if [[ ! "$status" == "ACTIVE" ]]; then
 let INSTASTATUS+=1 
fi
done

# write data
  printf "%s,%s,%s,Insta_status,%s\n" "$TIMESTAMP" "$ENTITY" "$SUBENTITY" "$INSTASTATUS" 

# Clean up
  rm -f $TMPFILE

write_log "Completed SAP Node status check"
write_log "Starting SAP Nodes disk stats"

# Get Disk Stats - SAP PMR V2
#-----
# Disk Monitoring
for node in $CNP $UIP $CMP $SGW $CCP $MGT; do
  #-----
  hostn='';hostn=`/bin/grep -w "$NETWORK.$node" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
  if [[ ! ${hostn} ]]; then hostn=`$SSH $NETWORK.$node "hostname"`; fi
  if [[ ! ${hostn} ]]; then hostn="$NETWORK.$node"; fi
  #-----
  val='';
  for value in `$SSH $NETWORK.$node "/bin/df -P | tail -n+3 | tr -s ' ' | sed 's/%//g'" | awk '{print $6";"$2*1024";"$5}'`; do
     #disk='';disk=`echo $value | awk -F ";" '{print $1}' | sed 's/\//_/g'`
     disk='';disk=`echo $value | awk -F ";" '{print $1}'`
     valSize=`echo $value | awk -F ";" '{print $2}'`
     val=`echo $value | awk -F ";" '{print $3}'`
    if [[ $val && $disk && $valSize ]]; then
     echo "$TIMESTAMP,SAP/$hostn://$disk,,Disk_partition_size,$valSize"
     echo "$TIMESTAMP,SAP/$hostn://$disk,,Disk_partition_utilization,$val"
    else
     echo "$TIMESTAMP,SAP/$hostn://$disk,,Disk_partition_size,0"
     echo "$TIMESTAMP,SAP/$hostn://$disk,,Disk_partition_utilization,0"
    fi
  done 2>/dev/null
#  if [[ ! $val ]] ; then
#     echo "$TIMESTAMP,SAP/$hostn://$disk,Disk_partition_size,0"
#     echo "$TIMESTAMP,SAP/$hostn://$disk,Disk_partition_utilization,0"
#  fi
done 2>/dev/null

write_log "Completed SAP Nodes disk stats"
exit 0

