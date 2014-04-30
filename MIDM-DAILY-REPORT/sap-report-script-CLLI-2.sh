#!/bin/bash
# Initial script by Glenn Davis
#==============================================================================
#
# Requires script "enr-dataDuration.sh" in same path as this script ($baseDir as set below)
#
# Output file:  ${baseDir}/pm-SAP-$today.csv
#

# Find current path and set as baseDir.
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done

baseDir="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

#
#---- General Variables -------------------------------------------------------
#
## config file contains DC variable lists for single location to update

tody=`date +"%Y%m%d %H%M%S"`
today=`date +"%Y%m%d-%H%M"`

csvDoc=${baseDir}/pm-SAP-$today.csv;

# cvsDoc is not deleted between runs, so we zero it out here
cat /dev/null > ${csvDoc};

# Source variables in dc-config.cfg
. ${baseDir}/dc-config.cfg

#
#midmEnrDuration
subtot=0;
for DC in ${midmDC};do
tail -10 /data/oozie-admi/`${baseDir}/enr-dataDuration.sh | grep MidmEnr| grep $DC | awk '{print $8'}`/mapredAction--ssh/*0.stdout 2>/dev/null | grep "Midm Mapred Action Time taken" | awk -F "|" '{print $8}' > ${baseDir}/mapTime;
mapTime=`cat ${baseDir}/mapTime | awk -F "." '{print $1}'`;
let "runTime=$mapTime / 60";
echo $tody","$DC",chassis-1,MIDM_data_processing_duration,"$runTime | tee -a ${csvDoc};
let "subtot += $runTime";
done;
echo $tody",SAP,MIDM,MIDM_data_processing_duration,"$subtot | tee -a ${csvDoc};

#
#midmDataTransferDuration
subtot=0;
for DC in ${midmDC};do
tail -5 /data/oozie-admi/`${baseDir}/enr-dataDuration.sh | grep MidmData| grep $DC | awk '{print $8'}`/invokeDataTransferScripts--ssh/*0.stdout 2>/dev/null | grep "stats: DataTransferAction" | awk -F "|" '{print $3}' > ${baseDir}/dataTime;
dataTime=`cat ${baseDir}/dataTime | awk -F "." '{print $1}'`;
let "runTime=$dataTime / 60";
echo $tody","$DC",chassis-1,MIDM_data_transfer_duration,"$runTime | tee -a ${csvDoc};
let "subtot += $runTime";
done;
echo $tody",SAP,MIDM,MIDM_data_transfer_duration,"$subtot | tee -a ${csvDoc};

#
#midmTotalDuration
# Original does not seem to work with apricot in lab
# Following change is recommended and needs to be tested in production
startDC="Wilmington"
endDC="Vista"
# README - 
# no need to tail and then grep	define start DC	enrscript puts job No need of head as we are id as last field grep for Running job line				

grep "mapred.JobClient: Running job:" /data/oozie-admi/`${baseDir}/enr-dataDuration.sh | grep MidmEnr | grep "${startDC}" | awk {'print $NF'}`/mapredAction--ssh/*stderr 2>/dev/null | awk '{print $1" "$2}' | sed 's/\//-/g' > ${baseDir}/startTime;

#
## head /data/oozie-admi/`${baseDir}/enr-dataDuration.sh | grep MidmEnr| grep Wilmington | awk '{print $8'}`/mapredAction--ssh/*stderr 2>/dev/null | grep -v WARN | grep reduce | awk '{print $1" "$2}' | head -1 | sed 's/\//-/g' > ${baseDir}/startTime;
startTime=`cat ${baseDir}/startTime`;

#																	  use $lastDC variable here
tail -1 /data/oozie-admi/`${baseDir}/enr-dataDuration.sh | grep MidmData| grep $endDC | awk '{print $8'}`/invokeDataTransferScripts--ssh/*stdout|cut -c 2-18 > ${baseDir}/endTime;
endTime=`cat ${baseDir}/endTime`;

# Add check to ensure both start and end are non null
# if [[ -n $startTime && -n $endTime ]] ; then
start=`date -d "$startTime" +%s`;
end=`date -d "$endTime" +%s`;
elapsed=`expr $end - $start`;
let "runTime=$elapsed / 60";
# else
# runTime="N/A" 
# fi
echo $tody",SAP,MIDM,MIDM_total_duration,"$runTime | tee -a ${csvDoc};

#
# MidmAgg file size - total bytes for each DC MidmAgg files which are sent to VIT
#
myda=`date "+%d" --date="2 days ago"`;
mymo=`date "+%m" --date="2 days ago"`;
myyr=`date "+%Y" --date="2 days ago"`;
#
for dc in ${midmDC};
do 
hadoop dfs -ls /data/output/$dc/Midm/$myyr/$mymo/$myda/GVS.MIDM_Aggregate* | awk '{print $5$8}'| awk -v "t1=$tody" 'BEGIN{FS="/"} {sum1+= $1} END{print t1","$4",chassis,MIDM_DC_aggregated_data_volume,"sum1}';
done 2>/dev/null | tee -a ${csvDoc};
#
# MidmEnr File Size -total bytes for each DC MidmEnr files which are sent to VIT
for dc in ${midmDC};
do
hadoop dfs -ls /data/output/$dc/Midm/$myyr/$mymo/$myda/GVS.MIDM_Enriched* | awk '{print $5$8}'| awk -v "t1=$tody" 'BEGIN{FS="/"} {sum1+= $1} END{print t1","$4",chassis,MIDM_DC_enriched_data_volume,"sum1}';
done 2>/dev/null | tee -a ${csvDoc};

#
# FILE SIZE STATS (run on NEC host with hadoop mounted)
#
# ipfix -7am to end of day yesterday plus 12am to 6:55 am today
#
myda1=`date "+%d" --date="1 days ago"`;
myda2=`date "+%d" --date="0 days ago"`;
mymo1=`date "+%m" --date="1 days ago"`;
mymo2=`date "+%m" --date="0 days ago"`;
myyr1=`date "+%Y" --date="1 days ago"`;
myyr2=`date "+%Y" --date="0 days ago"`;
#
#
# ipfixtmp is not deleted between runs, so we zero it out here
cat /dev/null  > ipfixtmp;
#
for dc in $cmdsDC;
do
hadoop dfs -ls /data/$dc/{1,2}/ipfix/$myyr1/$mymo1/$myda1/*/*/*IPFIX*.?| awk '{print $5$8}'| awk -F "/" '{if ($9>6) subtot1 += $1} END {printf "%10s;%13d",$3, subtot1}';
hadoop dfs -ls /data/$dc/{1,2}/ipfix/$myyr2/$mymo2/$myda2/*/*/*IPFIX*.?| awk '{print $5$8}'| awk -F "/" '{if ($9<7) subtot2 += $1} END {print ";"subtot2}';
done 2> /dev/null | awk -F ";" '{print $1","$2+$3}' >> ipfixtmp
for dc in $pnsaDC;
do
hadoop dfs -ls /data/$dc/ipfix/$myyr1/$mymo1/$myda1/*/*/*IPFIX*.?| awk '{print $5$8}'| awk -F "/" '{if ($8>6) subtot1 += $1} END {printf "%10s;%13d",$3, subtot1}';
hadoop dfs -ls /data/$dc/ipfix/$myyr2/$mymo2/$myda2/*/*/*IPFIX*.?| awk '{print $5$8}'| awk -F "/" '{if ($8<7) subtot2 += $1} END {print "; " subtot2}';
done 2> /dev/null | awk -F ";" '{print $1","$2+$3}' >> ipfixtmp
cat ipfixtmp | awk -v "t1=$tody" 'BEGIN{FS=","} {print t1","$1",chassis-1&2,HTTP_data_volume,"$2}' | tee -a ${csvDoc};

#
# pilotPacket -7am to end of day yesterday plus 12am to 6:55 am today
#
# pptmp is not deleted between runs, so zero it out here
cat /dev/null > pptmp;
#

for dc in $cmdsDC;
do
hadoop dfs -ls /data/$dc/1/pilotPacket/$myyr1/$mymo1/$myda1/*/*/*RADIUS*0| awk '{print $5$8}'| awk -F "/" '{if ($9>6) subtot1a += $1} END {printf "%10s;%13d",$3, subtot1a}';
hadoop dfs -ls /data/$dc/2/pilotPacket/$myyr1/$mymo1/$myda1/*/*/*RADIUS*0| awk '{print $5$8}'| awk -F "/" '{if ($9>6) subtot1b += $1} END {printf ";%13d;", subtot1b}';
hadoop dfs -ls /data/$dc/1/pilotPacket/$myyr2/$mymo2/$myda2/*/*/*RADIUS*0| awk '{print $5$8}'| awk -F "/" '{if ($9<7) subtot2a += $1} END {printf "%13d;", subtot2a}';
hadoop dfs -ls /data/$dc/2/pilotPacket/$myyr2/$mymo2/$myda2/*/*/*RADIUS*0| awk '{print $5$8}'| awk -F "/" '{if ($9<7) subtot2b += $1} END {print subtot2b}';
done 2> /dev/null | awk -F ";" '{print $1";"$2+$4";"$3+$5}' | awk -F ";" '{if ($2>$3) print $1","$2;else if ($3>=$2) print $1","$3}' >> pptmp;

# Rename according to dc -config.cfg
for dc in $pnsaDC;
do
hadoop dfs -ls /data/$dc/pilotPacket/$myyr1/$mymo1/$myda1/*/*/*RADIUS*0| awk '{print $5$8}'| awk -F "/" '{if ($8>6) subtot1 += $1} END {printf "%10s;%13d",$3, subtot1}';
hadoop dfs -ls /data/$dc/pilotPacket/$myyr2/$mymo2/$myda2/*/*/*RADIUS*0| awk '{print $5$8}'| awk -F "/" '{if ($8<7) subtot2 += $1} END {print "; " subtot2}';
done 2> /dev/null | awk -F ";" '{print $1","$2+$3}' >> pptmp;
cat pptmp | awk -v "t1=$tody" 'BEGIN{FS=","} {print t1","$1",chassis-1or2,PilotPacket_data_volume,"$2}' | tee -a ${csvDoc}; 

#
# subscriberib - 7am to end of day yesterday plus 12am to 6:55 am today
#
# subtmp is not deleted between runs, so zero it out here
cat /dev/null > subtmp;
for dc in $allDC;
do hadoop dfs -ls /data/$dc/SubscriberIB/$myyr1/$mymo1/$myda1/*/X.MAPREDUCE.0.0| awk '{print $5$8}'| awk -F "/" '{if ($8>6) subtot1 += $1} END {printf "%10s;%13d",$3, subtot1}';
hadoop dfs -ls /data/$dc/SubscriberIB/$myyr2/$mymo2/$myda2/*/X.MAPREDUCE.0.0| awk '{print $5$8}'| awk -F "/" '{if ($8<7) subtot2 += $1} END {print "; " subtot2}';
done 2> /dev/null | awk -F ";" '{print $1","$2+$3}' >> subtmp
cat subtmp | awk -v "t1=$tody" 'BEGIN{FS=","} {print t1","$1",chassis-shared,SubscriberIB_data_volume,"$2}' | tee -a ${csvDoc};
#
# records per second - 24 hours prior day UTC
#
myda=`date "+%d" --date="1 day ago"`;
mymo=`date "+%m" --date="1 day ago"`;
myyr=`date "+%Y" --date="1 day ago"`;

for DC in ${cmdsDC}; do
	printf `date +"%Y%m%d"`  | tee -a ${csvDoc};
	printf " "  | tee -a ${csvDoc};
	printf `date +"%H%M%S"` | tee -a ${csvDoc};
	printf "," | tee -a ${csvDoc};
	printf ${DC}|sed 's/\//,chassis-/' | tee -a ${csvDoc};
			hadoop dfs -text /data/$DC/ipfix/$myyr/$mymo/$myda/*/*/*IPFIX*_DONE 2>/dev/null |  cut -c 9,12,15,18,21,24,27,30,33,36,39,42 > ${baseDir}/tot1;
			totsum=`(cat ${baseDir}/tot1 |tr "\012" "+";echo "0")| bc`;				
			avg=$((totsum/86400));
		printf ",HTTP_data_throughput,"${avg} | tee -a  ${csvDoc};
printf "\n" | tee -a ${csvDoc};
done;
#
for DC in ${pnsaDC}; do
	printf `date +"%Y%m%d"` | tee -a ${csvDoc};
	printf " " | tee -a ${csvDoc};
	printf `date +"%H%M%S"` | tee -a ${csvDoc};
	printf "," | tee -a ${csvDoc};
	printf ${DC} | tee -a ${csvDoc};
	printf ",chassis-1"  | tee -a ${csvDoc};
			hadoop dfs -text /data/$DC/ipfix/$myyr/$mymo/$myda/*/*/*IPFIX*_DONE 2>/dev/null |  cut -c 9,12,15,18,21,24,27,30,33,36,39,42 > ${baseDir}/tot1;
			totsum=`(cat ${baseDir}/tot1 |tr "\012" "+";echo "0")| bc`;				
			avg=$((totsum/86400));
		printf ",HTTP_data_throughput,"${avg} | tee -a  ${csvDoc};
printf "\n" | tee -a ${csvDoc};
done;
#
#
for DC in ${cmdsDC}; do
	printf `date +"%Y%m%d"`  | tee -a ${csvDoc};
	printf " "  | tee -a ${csvDoc};
	printf `date +"%H%M%S"` | tee -a ${csvDoc};
	printf "," | tee -a ${csvDoc};
	printf ${DC}|sed 's/\//,chassis-/' | tee -a ${csvDoc};
			hadoop dfs -text /data/$DC/pilotPacket/$myyr/$mymo/$myda/*/*/*RADIUS*_DONE 2>/dev/null |  cut -c 9,12,15,18,21,24,27,30,33,36,39,42 > ${baseDir}/tot1;
			totsum=`(cat ${baseDir}/tot1 |tr "\012" "+";echo "0")| bc`;				
			avg=$((totsum/86400));
		printf ",pilotPacket_data_throughput,"${avg} | tee -a  ${csvDoc};
printf "\n" | tee -a ${csvDoc};
done;
#
for DC in ${pnsaDC}; do
	printf `date +"%Y%m%d"` | tee -a ${csvDoc};
	printf " " | tee -a ${csvDoc};
	printf `date +"%H%M%S"` | tee -a ${csvDoc};
	printf "," | tee -a ${csvDoc};
	printf ${DC} | tee -a ${csvDoc};
	printf ",chassis-1"  | tee -a ${csvDoc};
			hadoop dfs -text /data/$DC/pilotPacket/$myyr/$mymo/$myda/*/*/*RADIUS*_DONE 2>/dev/null |  cut -c 9,12,15,18,21,24,27,30,33,36,39,42 > ${baseDir}/tot1;
			totsum=`(cat ${baseDir}/tot1 |tr "\012" "+";echo "0")| bc`;				
			avg=$((totsum/86400));
		printf ",pilotPacket_data_throughput,"${avg} | tee -a  ${csvDoc};
printf "\n" | tee -a ${csvDoc};
done;

#
# Traffic report - ipfix, pp, subib - current or minutes delayed
#
myda=`date "+%d"`;
mymo=`date "+%m"`;
myyr=`date "+%Y"`;
mytime=`date "+%T" | awk -F: '{print $1*60 + $2}'`;

for DC in ${cmdsDC};do

printf "$tody" | tee -a  ${csvDoc};
printf ",$DC," | tee -a  ${csvDoc};
		hadoop dfs -lsr /data/$DC/1/ipfix/$myyr/$mymo/ 2>/dev/null| grep "\/_DONE" | tail -1 |awk -v t1=$mytime -F "/" '{print $4 ", "$5", " t1-(60*$9+$10)-7"," $8}'| awk -F "," -v d1=$myda '{if ($3<9 && $3>=0 && d1=$4) print "chassis-"$1",HTTP_data_transfer_backlog,current";
else if (d1!=$4) print "chassis-"$1",HTTP_data_transfer_backlog, not current day";
else print "chassis-"$1",HTTP_data_transfer_backlog,"$3-8}' | tee -a ${csvDoc};

printf "$tody" | tee -a  ${csvDoc};
printf ",$DC," | tee -a  ${csvDoc};
		hadoop dfs -lsr /data/$DC/2/ipfix/$myyr/$mymo/ 2>/dev/null| grep "\/_DONE" | tail -1 |awk -v t1=$mytime -F "/" '{print $4 ", "$5", " t1-(60*$9+$10)-7"," $8}'| awk -F "," -v d1=$myda '{if ($3<9 && $3>=0 && d1=$4) print "chassis-"$1",HTTP_data_transfer_backlog,current";
else if (d1!=$4) print "chassis-"$1",HTTP_data_transfer_backlog, not current day";
else print "chassis-"$1",HTTP_data_transfer_backlog,"$3-8}' | tee -a ${csvDoc};

printf "$tody" | tee -a  ${csvDoc};
printf ",$DC," | tee -a  ${csvDoc};
		hadoop dfs -lsr /data/$DC/1/pilotPacket/$myyr/$mymo/ 2>/dev/null| grep "\/_DONE" | tail -1|awk -v t1=$mytime -F "/" '{print $4 ", "$5", " t1-(60*$9+$10)-7"," $8}'| awk -F "," -v d1=$myda '{if ($3<9 && $3>=0 && d1=$4) print "chassis-"$1",PilotPacket_data_transfer_backlog,current";
else if (d1!=$4) print "chassis-"$1",PilotPacket_data_transfer_backlog,not current day";
else print "chassis-"$1",PilotPacket_data_transfer_backlog,"$3-8}' | tee -a ${csvDoc};

printf "$tody" | tee -a  ${csvDoc};
printf ",$DC," | tee -a  ${csvDoc};
		hadoop dfs -lsr /data/$DC/2/pilotPacket/$myyr/$mymo/ 2>/dev/null| grep "\/_DONE" | tail -1|awk -v t1=$mytime -F "/" '{print $4 ", "$5", " t1-(60*$9+$10)-7"," $8}'| awk -F "," -v d1=$myda '{if ($3<9 && $3>=0 && d1=$4) print "chassis-"$1",PilotPacket_data_transfer_backlog,current";
else if (d1!=$4) print "chassis-"$1",PilotPacket_data_transfer_backlog,not current day";
else print "chassis-"$1",PilotPacket_data_transfer_backlog,"$3-8}' | tee -a ${csvDoc};

printf "$tody" | tee -a  ${csvDoc};
printf ",$DC," | tee -a  ${csvDoc};
hadoop dfs -lsr /data/$DC/SubscriberIB/$myyr/$mymo/ 2>/dev/null| grep "\/_DONE" | tail -1 |awk -v t1=$mytime -F "/" '{print $3 ","$4", " t1-(60*$8)"," $7}'| awk -F"," -v d1=$myda '{if (d1!=$4) print "chassis-1,SubscriberIB_data_transfer_backlog,not current day";
else if ($3<100 && $3>=1 && d1=$4) print "chassis-1,SubscriberIB_data_transfer_backlog,current";
else print "chassis-1,SubscriberIB_data_transfer_backlog,"$3}' | tee -a ${csvDoc};

done;

myda=`date "+%d"`;
mymo=`date "+%m"`;
myyr=`date "+%Y"`;
mytime=`date "+%T" | awk -F: '{print $1*60 + $2}'`;

for DC in ${pnsaDC};do

printf "$tody" | tee -a  ${csvDoc};
printf ",$DC," | tee -a  ${csvDoc};
		hadoop dfs -lsr /data/$DC/ipfix/$myyr/$mymo/ 2>/dev/null| grep "\/_DONE" | tail -1 |awk -v t1=$mytime -F "/" '{print $3 ","$4", " t1-(60*$8+$9)-7"," $7}'| awk -F "," -v d1=$myda '{if ($3<9 && $3>=0 && d1=$4) print "chassis-1,HTTP_data_transfer_backlog,current";
else if (d1!=$4) print "chassis-1,HTTP_data_transfer_backlog, not current day";
else print "chassis-1,HTTP_data_transfer_backlog,"$3-8}' | tee -a ${csvDoc};

printf "$tody" | tee -a  ${csvDoc};
printf ",$DC," | tee -a  ${csvDoc};
		hadoop dfs -lsr /data/$DC/pilotPacket/$myyr/$mymo/ 2>/dev/null| grep "\/_DONE" | tail -1 |awk -v t1=$mytime -F "/" '{print $3 ","$4", " t1-(60*$8+$9)-7"," $7}'| awk -F "," -v d1=$myda '{if ($3<9 && $3>=0 && d1=$4) print "chassis-1,PilotPacket_data_transfer_backlog,current";
else if (d1!=$4) print "chassis-1,PilotPacket_data_transfer_backlog, not current day";
else print "chassis-1,PilotPacket_data_transfer_backlog,"$3-8}' | tee -a ${csvDoc};

printf "$tody" | tee -a  ${csvDoc};
printf ",$DC," | tee -a  ${csvDoc};
hadoop dfs -lsr /data/$DC/SubscriberIB/$myyr/$mymo/ 2>/dev/null| grep "\/_DONE" | tail -1 |awk -v t1=$mytime -F "/" '{print $3 ","$4"," t1-(60*$8)"," $7}'| awk -F"," -v d1=$myda '{if (d1!=$4) print "chassis-1,SubscriberIB_data_transfer_backlog,not current day";
else if ($3<100 && $3>=1 && d1=$4) print "chassis-1,SubscriberIB_data_transfer_backlog,current";
else print "chassis-1,SubscriberIB_data_transfer_backlog,"$3}' | tee -a ${csvDoc};

done;

#
# Convert to CLLI DC names
#
sed -f ${baseDir}/script.sed ${csvDoc} > ${baseDir}/pm-SAP-$today.csv.tmp && mv ${baseDir}/pm-SAP-$today.csv.tmp ${baseDir}/pm-SAP-$today.csv
exit 0;
