#!/bin/bash
#==============================================================================
# Name: midm-daily-report-auto.sh - gather scripts for reporting to VzW
# Date: 19-Ju1-2013
# Centralized DC list variables in external config file
# Auth: Glenn Davis, Guavus
# Vers: 1.0.0
#==============================================================================
#
#

#---- General Variables -------------------------------------------------------
#
## config file contains DC variable lists for single location to update

. /data/traffic/dc-config.cfg

# midmDC are DC's that are actually processing MIDM currently
# midmDC="Wilmington PlymouthMeeting AnnapolisJunction Chantilly Westside Guion Johnstown Bridgeville Lenexa SaintLouis Bloomington Omaha Copperfield BatonRouge Alpharetta Birmingham RedmondRidge Hillsboro WestJordan Aurora LasVegas Tempe Branchburg Wall HickoryHills NewBerlin Charlotte Nashville Marina Azusa Ontario Vista";

# midmLIST are DC's that are not actually processing MIDM now but will be soon
# midmLIST="Wilmington PlymouthMeeting AnnapolisJunction Chantilly Westside Guion Johnstown Bridgeville Lenexa SaintLouis Bloomington Omaha Copperfield BatonRouge Alpharetta Birmingham RedmondRidge Hillsboro WestJordan Aurora LasVegas Tempe Branchburg Wall HickoryHills NewBerlin Lodge Columbus Duff Charlotte Nashville Sunnyvale Rocklin Marina Azusa Ontario Vista";
#
# dcCMDS="NWCSDEBG WMTPPAAA AnnapolisJunction Chantilly IPLUINXI Guion Johnstown Bridgeville Lenexa SaintLouis Bloomington Omaha Copperfield BatonRouge ALPRGAGQ Birmingham RDMEWA22 HLBOOR38 WJRDUT30 AURSCOTY NLVGNVOQ TEMQAZKW";

# dcPNSA="Branchburg Wall HickoryHills NewBerlin Lodge Columbus Duff Charlotte Nashville Sunnyvale Rocklin Marina Azusa Ontario Vista";

# allDC="NWCSDEBG WMTPPAAA AnnapolisJunction Chantilly IPLUINXI Guion Johnstown Bridgeville Lenexa SaintLouis Bloomington Omaha Copperfield BatonRouge ALPRGAGQ Birmingham RDMEWA22 HLBOOR38 WJRDUT30 AURSCOTY NLVGNVOQ TEMQAZKW Branchburg Wall HickoryHills NewBerlin Lodge Columbus Duff Charlotte Nashville Sunnyvale Rocklin Marina Azusa Ontario Vista";

masterCollector=118;

#---- Control Variables -------------------------------------------------------
# tillNextReport is the number of seconds to sleep before running the this
# report again. Currently it is set to 86400 seconds, i.e. 24 hours.
#
tillNextReport=86400

#---- Target Host -------------------------------------------------------------
# When completed send the report to the following host.  Currently the report
# will be copied into the home directory.
#
targetHost="root@10.136.239.88"

#------------------------------------------------------------------------------
# Main loop that controls the execution of the report, that loops forever.
# There is a sleep statement at the bottom of the loop, which uses the
# variable ${tillNextReport} to determine when when to execute the next
# interation.
#------------------------------------------------------------------------------

while true
do
today=`date +"%Y%m%d-%H%M"`

baseDir="/data/traffic";
webDoc=${baseDir}/midmReport${today}.txt;

# if current use current date, if going back a day use the 1 day ago date

mydate=`date "+%Y-%m-%d"`;

# mydate=`date "+%Y-%m-%d" --date="1 day ago"`;

/opt/oozie/bin/oozie jobs -oozie http://10.136.239.${masterCollector}:8080/oozie -jobtype wf -len 30000  |sed -e 's/Wall SUCCEEDED/\WallSUCCEEDED/g'  |sed -e 's/Duff SUCCEEDED/\DuffSUCCEEDED/g'|awk -v d1="$mydate" '{if (($5 ~d1) && ($2 ~ /MidmEnr|MidmData_/)) print $2 "\t" $5 "\t" $6 "\t" $7 "\t" $8 "\t" $1}'|sed -e 's/RUNNING/\tRUNNING/g' -e 's/SUCCEEDED/\tSUCCEEDED/g' -e 's/KILLED/\tKILLED/g' -e 's/_/\t/g'|awk -F "\t" '{printf "%-17s %-8s %-9s %s %s %s %s %s\n", $2, $1, $3, $4, $5, $6, $7, $8}' |sort -k 7 | grep Enr| tee -a ${webDoc};
#
echo| tee -a ${webDoc};
/opt/oozie/bin/oozie jobs -oozie http://10.136.239.${masterCollector}:8080/oozie -jobtype wf -len 30000  |sed -e 's/Wall SUCCEEDED/\WallSUCCEEDED/g' | sed -e 's/Duff SUCCEEDED/\DuffSUCCEEDED/g' | awk -v d1="$mydate" '{if (($5 ~d1) && ($2 ~ /MidmEnr|MidmData_/)) print $2 "\t" $5 "\t" $6 "\t" $7 "\t" $8 "\t" $1}'|sed -e 's/RUNNING/\tRUNNING/g' -e 's/SUCCEEDED/\tSUCCEEDED/g' -e 's/KILLED/\tKILLED/g' -e 's/_/\t/g'|awk -F "\t" '{printf "%-17s %-8s %-9s %s %s %s %s %s\n", $2, $1, $3, $4, $5, $6, $7, $8}' |sort -k 7|grep Data| tee -a ${webDoc};
echo| tee -a ${webDoc};
#
/opt/oozie/bin/oozie jobs -oozie http://10.136.239.${masterCollector}:8080/oozie -jobtype wf -len 30000 |awk -v d1="${mydate}" '{if (($5 ~d1) && ($2 ~ /MidmProcessTime/)) print $2 "\t" $5 "\t" $6 "\t" $7 "\t" $8 "\t" $1}'|sed -e 's/RUNNING/\tRUNNING/g' -e 's/SUCCEEDED/\tSUCCEEDED/g' -e 's/KILLED/\tKILLED/g' -e 's/_/\t/g'|awk -F "\t" '{printf "%-17s %-8s %-9s %s %s %s %s %s\n", $2, $1, $3, $4, $5, $6, $7, $8}' |sort -k 7 | tee -a ${webDoc};
echo| tee -a ${webDoc};
##
# Indiv MidmEnr times
##
echo "Job Enr duration times" | tee -a ${webDoc};
echo | tee -a ${webDoc};


for dc in ${midmDC}; do
head -500 /data/oozie-admi/`cat ${webDoc} | grep MidmEnr| grep ${dc} |awk '{print $8'}`/mapredAction--ssh/*stderr 2>/dev/null | grep --binary-files=text 'map 1% reduce 0%' | awk '{print $1" "$2}' | head -1 | sed 's/\//-/g' > ${baseDir}/startTime;

startTime=`cat ${baseDir}/startTime`;
start=`date -d "$startTime" +%s`;

tail -60 /data/oozie-admi/`cat ${webDoc} | grep MidmEnr| grep ${dc} | awk '{print $8'}`/mapredAction--ssh/*stderr 2>/dev/null |  grep --binary-files=text 'map 100% reduce 100%' | awk '{print $1" "$2}' | head -1 | sed 's/\//-/g' > ${baseDir}/endTime;

endTime=`cat ${baseDir}/endTime`;
end=`date -d "${endTime}" +%s`;

elapsed=`expr $end - $start`;

let "runTime=${elapsed} / 60";

echo ${dc} "," ${runTime} | tee -a ${webDoc}; 

done;

##
# Total all jobs MidmEnr time
##
tail -20 /data/oozie-admi/`cat ${webDoc}  | grep MidmProcessTime| awk '{print $7'}`/calProcessTimeAction--ssh/*stdout 2>/dev/null | grep "time taken for midm mapreduce data processing" | awk -F ":" '{print $6 $7}' | cut -c 1,2,3,4,5,6,7 | sed s/hr/:/  > ${baseDir}/midmTime;
midmTime=`cat ${baseDir}/midmTime`;
echo "All DC MidmEnr,"$midmTime| tee -a ${webDoc};
echo| tee -a ${webDoc};



##
# Indiv MidmData times
##
subtot=0;
for DC in ${midmDC};do
tail -100 /data/oozie-admi/`cat ${webDoc} | grep MidmData | grep SUCCEEDED | grep $DC | awk '{print $8'}`/invokeDataTransferScripts--ssh/*0.stdout 2>/dev/null | grep "stats: DataTransferAction" | awk -F "|" '{print $3}' > ${baseDir}/dataTime;
dataTime=`cat ${baseDir}/dataTime | awk -F "." '{print $1}'`;
let "runTime=$dataTime / 60";
echo $DC","$runTime| tee -a ${webDoc};
done;


#
#MidmData TotalDuration end to end on the clock
#
head /data/oozie-admi/`cat ${webDoc} | grep MidmData| grep Wilmington | awk '{print $8'}`/invokeDataTransferScripts--ssh/*out 2>/dev/null | grep "starting action run" | cut -c 2-18 > ${baseDir}/startTime;
startTime=`cat ${baseDir}/startTime`;
start=`date -d "$startTime" +%s`;
tail -1 /data/oozie-admi/`cat ${webDoc} | grep MidmData| grep Orlando | awk '{print $8'}`/invokeDataTransferScripts--ssh/*stdout|cut -c 2-18 > ${baseDir}/endTime;
endTime=`cat ${baseDir}/endTime`;
end=`date -d "$endTime" +%s`;
elapsed=`expr $end - $start`;
let "runTime=$elapsed / 60";
echo "MidmData_total_duration,"$runTime| tee -a ${webDoc}; 
echo| tee -a ${webDoc};



#
#Midm Enr and Data Total Duration  - both Enr and Data, end to end on the clock
#
head /data/oozie-admi/`cat ${webDoc}  | grep MidmEnr| grep Wilmington | awk '{print $8'}`/mapredAction--ssh/*stderr 2>/dev/null | grep -v WARN | grep reduce | awk '{print $1" "$2}' | head -1 | sed 's/\//-/g' > ${baseDir}/startTime;
startTime=`cat ${baseDir}/startTime`;
start=`date -d "$startTime" +%s`;
tail -1 /data/oozie-admi/`cat ${webDoc} | grep MidmData| grep Orlando | awk '{print $8'}`/invokeDataTransferScripts--ssh/*stdout|cut -c 2-18 > ${baseDir}/endTime;
endTime=`cat ${baseDir}/endTime`;
end=`date -d "$endTime" +%s`;
elapsed=`expr $end - $start`;
let "runTime=$elapsed / 60";
echo "SAP MIDM_total_duration,"$runTime| tee -a ${webDoc}; 
echo| tee -a ${webDoc};



#
#
# MidmAgg file size - total bytes for each DC MidmAgg files which are sent to VIT
#
tody=`date +"%Y%m%d %H%M%S"`
myda=`date "+%d" --date="2 days ago"`;
mymo=`date "+%m" --date="2 days ago"`;
myyr=`date "+%Y" --date="2 days ago"`;

#tody=`date +"%Y%m%d %H%M%S" --date="1 day ago"`
#myda=`date "+%d" --date="3 days ago"`;
#mymo=`date "+%m" --date="3 days ago"`;
#myyr=`date "+%Y" --date="3 days ago"`;

#
#
dc=${midmLIST}
echo| tee -a ${webDoc};
echo "Agg Files per DC for "$mymo"/"$myda"/"$myyr" at "`TZ=America/Los_Angeles date "+%m/%d/%y %H:%M  %Z"`| tee -a ${webDoc};
echo| tee -a ${webDoc};
for dc in ${midmLIST};do hadoop dfs -ls /data/output/$dc/Midm/$myyr/$mymo/$myda/GVS.MIDM_Aggregate* | awk '{print $5$8}'| awk -F "/" '{sum1+= $1} END{print $4 "; "sum1}';done 2>/dev/null| tee -a ${webDoc};
#
# MidmEnr File Size -total bytes for each DC MidmEnr files which are sent to VIT
#
echo| tee -a ${webDoc};
echo "Enr Files per DC for "$mymo"/"$myda"/"$myyr" at "`TZ=America/Los_Angeles date "+%m/%d/%y %H:%M  %Z"`| tee -a ${webDoc};
echo| tee -a ${webDoc};
for dc in ${midmLIST};do hadoop dfs -ls /data/output/$dc/Midm/$myyr/$mymo/$myda/GVS.MIDM_Enriched* | awk '{print $5$8}'| awk -F "/" '{sum1+= $1} END{print $4 "; "sum1}';done 2>/dev/null| tee -a ${webDoc};
#
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

#myda1=`date "+%d" --date="2 days ago"`;
#myda2=`date "+%d" --date="1 days ago"`;
#mymo1=`date "+%m" --date="2 days ago"`;
#mymo2=`date "+%m" --date="1 days ago"`;
#myyr1=`date "+%Y" --date="2 days ago"`;
#myyr2=`date "+%Y" --date="1 days ago"`;

echo > ipfixtmp;
echo "IPFIX file sum per DC at "`date "+%m/%d/%y %H:%M  %Z"` >> ipfixtmp;
echo >> ipfixtmp;
echo "7am to end of yesterday "$mymo1"/"$myda1"/"$myyr1" plus" >> ipfixtmp;
echo "12am to 6:55 am today "$mymo2"/"$myda2"/"$myyr2" UTC" >> ipfixtmp;
echo >> ipfixtmp;
for dc in $dcCMDS;
do
hadoop dfs -ls /data/$dc/{1,2}/ipfix/$myyr1/$mymo1/$myda1/*/*/*IPFIX*.?| awk '{print $5$8}'| awk -F "/" '{if ($9>6) subtot1 += $1} END {printf "%7s;%13d",$3, subtot1}';
hadoop dfs -ls /data/$dc/{1,2}/ipfix/$myyr2/$mymo2/$myda2/*/*/*IPFIX*.?| awk '{print $5$8}'| awk -F "/" '{if ($9<7) subtot2 += $1} END {print "; " subtot2}';
done 2> /dev/null | awk -F ";" '{print $1";"$2+$3}' >> ipfixtmp
for dc in $dcPNSA;
do
hadoop dfs -ls /data/$dc/ipfix/$myyr1/$mymo1/$myda1/*/*/*IPFIX*.?| awk '{print $5$8}'| awk -F "/" '{if ($8>6) subtot1 += $1} END {printf "%7s;%13d",$3, subtot1}';
hadoop dfs -ls /data/$dc/ipfix/$myyr2/$mymo2/$myda2/*/*/*IPFIX*.?| awk '{print $5$8}'| awk -F "/" '{if ($8<7) subtot2 += $1} END {print "; " subtot2}';
done 2> /dev/null | awk -F ";" '{print $1";"$2+$3}' >> ipfixtmp
cat ipfixtmp| tee -a ${webDoc};
#
# pilotPacket -7am to end of day yesterday plus 12am to 6:55 am today
#
echo > pptmp;
echo "pilotPacket file sum per DC at "`date "+%m/%d/%y %H:%M  %Z"` >> pptmp;
echo >> pptmp;
echo "7am to end of yesterday "$mymo1"/"$myda1"/"$myyr1" plus" >> pptmp;
echo "12am to 6:55 am today "$mymo2"/"$myda2"/"$myyr2" UTC" >> pptmp;
echo >> pptmp;
for dc in $dcCMDS;
do
hadoop dfs -ls /data/$dc/1/pilotPacket/$myyr1/$mymo1/$myda1/*/*/*RADIUS*0| awk '{print $5$8}'| awk -F "/" '{if ($9>6) subtot1a += $1} END {printf "%7s;%13d",$3, subtot1a}';
hadoop dfs -ls /data/$dc/2/pilotPacket/$myyr1/$mymo1/$myda1/*/*/*RADIUS*0| awk '{print $5$8}'| awk -F "/" '{if ($9>6) subtot1b += $1} END {printf ";%13d;", subtot1b}';
hadoop dfs -ls /data/$dc/1/pilotPacket/$myyr2/$mymo2/$myda2/*/*/*RADIUS*0| awk '{print $5$8}'| awk -F "/" '{if ($9<7) subtot2a += $1} END {printf "%13d;", subtot2a}';
hadoop dfs -ls /data/$dc/2/pilotPacket/$myyr2/$mymo2/$myda2/*/*/*RADIUS*0| awk '{print $5$8}'| awk -F "/" '{if ($9<7) subtot2b += $1} END {print subtot2b}';
done 2> /dev/null | awk -F ";" '{print $1";"$2+$4";"$3+$5}' | awk -F ";" '{if ($2>$3) print $1";"$2;else if ($3>=$2) print $1";"$3}' >> pptmp;
for dc in $dcPNSA;
do
hadoop dfs -ls /data/$dc/pilotPacket/$myyr1/$mymo1/$myda1/*/*/*RADIUS*0| awk '{print $5$8}'| awk -F "/" '{if ($8>6) subtot1 += $1} END {printf "%7s;%13d",$3, subtot1}';
hadoop dfs -ls /data/$dc/pilotPacket/$myyr2/$mymo2/$myda2/*/*/*RADIUS*0| awk '{print $5$8}'| awk -F "/" '{if ($8<7) subtot2 += $1} END {print "; " subtot2}';
done 2> /dev/null | awk -F ";" '{print $1";"$2+$3}' >> pptmp;
echo >> pptmp;
cat pptmp| tee -a ${webDoc};
#
#
# subscriberib - 7am to end of day yesterday plus 12am to 6:55 am today
#
echo > subtmp;
echo "SubscriberIB file sum per DC at "`date "+%m/%d/%y %H:%M  %Z"` >> subtmp;
echo;echo "7am to end of yesterday "$mymo1"/"$myda1"/"$myyr1" plus" >> subtmp;
echo "12am to 6:55 am today "$mymo2"/"$myda2"/"$myyr2" UTC" >> subtmp;
echo >> subtmp;
for dc in $allDC;
do hadoop dfs -ls /data/$dc/SubscriberIB/$myyr1/$mymo1/$myda1/*/X.MAPREDUCE.0.0| awk '{print $5$8}'| awk -F "/" '{if ($8>6) subtot1 += $1} END {printf "%7s;%13d",$3, subtot1}';
hadoop dfs -ls /data/$dc/SubscriberIB/$myyr2/$mymo2/$myda2/*/X.MAPREDUCE.0.0| awk '{print $5$8}'| awk -F "/" '{if ($8<7) subtot2 += $1} END {print "; " subtot2}';
done 2> /dev/null | awk -F ";" '{print $1";"$2+$3}' >> subtmp
cat subtmp| tee -a ${webDoc};
#
echo| tee -a ${webDoc};

##
# Thread check
##
echo | tee -a  ${webDoc};
printf "NEC Thread Check for JobTracker, max is 32K: "| tee -a  ${webDoc};
ps uH `ps -ef | grep JobTracker | awk '{print $2}'` | wc -l | tee -a  ${webDoc};
printf "\n" | tee -a  ${webDoc};
echo | tee -a  ${webDoc};

##
# /data/drbd and local file system check
##

echo | tee -a  ${webDoc};
echo "NEC file system check"| tee -a  ${webDoc};
echo | tee -a  ${webDoc};
df -h | tee -a  ${webDoc};
echo | tee -a  ${webDoc};


##
# SubIBtoQE Job Check
##
echo | tee -a  ${webDoc};
echo "SubIBtoQE Job Check"| tee -a ${webDoc};	
echo | tee -a  ${webDoc};
for DC in ${midmDC};do
	printf ${DC}| tee -a ${webDoc} ;
	hadoop dfs -cat /data/SubscriberIBToQEJob_${DC}/done.txt 2>/dev/null | awk '{print ","$1}'| tee -a ${webDoc};
done;
echo | tee -a  ${webDoc};


##
# Agg and Enr Listing
##
echo "Agg and Enr - full file set print out to verify good size and all files in set present"| tee -a  ${webDoc};
#

echo| tee -a ${webDoc};
echo "MIDM Enriched and Aggregate file checked on "`date "+%m/%d/%y %H:%M  %Z"`| tee -a ${webDoc};
echo| tee -a ${webDoc};
echo "File set: "$mymo"/"$myda"/"$myyr| tee -a ${webDoc};
echo| tee -a ${webDoc};
for dc in ${midmDC};do echo "--------------- "$dc" -------------------";hadoop dfs -ls /data/output/$dc/Midm/$myyr/$mymo/$myda/GVS.MIDM*|awk '{print $5" "$8}';echo;done 2>/dev/null| tee -a ${webDoc};

#
#records per second - yesterday
#

baseDir="/data/traffic";

echo| tee -a ${webDoc};
echo "CMDS PNSA RPS 24 hours ipfix pp"| tee -a ${webDoc};
echo| tee -a ${webDoc};
for DC in ${dcCMDS}; do
		printf ${DC} | tee -a ${webDoc};
		cat  /dev/null > /tmp/tot;
			for chassis in 1 2;do
			hadoop dfs -text /data/$DC/$chassis/ipfix/$myyr1/$mymo1/$myda1/*/*/*IPFIX*_DONE 2>/dev/null |  cut -c 9,12,15,18,21,24,27,30,33,36,39,42 >> /tmp/tot;
			totsum=`(cat /tmp/tot |tr "\012" "+";echo "0")| bc`;				
			done;
		hravg=$((totsum/86400));
		printf ";"${hravg} | tee -a  ${webDoc};
		for chassis in 1 2;do
			cat  /dev/null > /tmp/tot;
			hadoop dfs -text /data/$DC/$chassis/pilotPacket/$myyr1/$mymo1/$myda1/*/*/*RADIUS*_DONE 2>/dev/null |  cut -c 9,12,15,18,21,24,27,30,33,36,39,42 >> /tmp/tot;
			let totsum${chassis}=`(cat /tmp/tot |tr "\012" "+";echo "0")| bc`;				
		done;			
		hravg1=$((totsum1/86400));
		hravg2=$((totsum2/86400));
		echo $hravg1 $hravg2 | awk -v h1=$hravg1 -v h2=$hravg2 '{if (h1>h2) print ";"h1;else if (h2>=h1) print ";"h2}' | tee -a  ${webDoc};
		done;	
	for DC in ${dcPNSA}; do
		printf ${DC} | tee -a ${webDoc};
		for pType in ipfix:IPFIX pilotPacket:RADIUS;do
			hadoop dfs -text /data/$DC/${pType%:*}/$myyr1/$mymo1/$myda1/*/*/*${pType#*:}*_DONE 2>/dev/null |  cut -c 9,12,15,18,21,24,27,30,33,36,39,42 > /tmp/tot;
			totsum=`(cat /tmp/tot |tr "\012" "+";echo "0")| bc`;				
			hravg=$((totsum/86400));
			printf ";"${hravg} | tee -a  ${webDoc};
		done;
	printf "\n" | tee -a  ${webDoc};
	done;
echo | tee -a  ${webDoc};
#

## convert CLLI to DC

sed -f ${baseDir}/CLLItoNAME.sed ${webDoc} > ${webDoc}.tmp && mv ${webDoc}.tmp ${webDoc}


#----------------------------------------------------------------------------------------
# End of Document
#----------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------
# Transfer doc to other host
#----------------------------------------------------------------------------------------

scp ${webDoc} ${targetHost}:/data/traffic/reports

#	sleep 86400 -  24 hours
	sleep ${tillNextReport}

#----------------------------------------------------------------------------------------
# End of Program
#----------------------------------------------------------------------------------------

done;

exit 0;
