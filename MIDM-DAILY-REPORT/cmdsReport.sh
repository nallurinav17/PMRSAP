#!/bin/bash
#==============================================================================
# Name: cmdsReport-new.sh  - File Size Report for VzW
# Date: 27-Feb-03
# Auth: Glenn Davis & Clifford M. Conklin, Guavus
### Vers: 2.0.0
## 29 May-03
## added new DC's and reformatted
#==============================================================================

#------------------------------------------------------------------------------
# Global Variables
#------------------------------------------------------------------------------



#---- DC List -----------------------------------------------------------------
# dcXXXX is the list of DC names as they appear in the /data/XXXX directory
# as reported by "hadoop dfs -ls /data"
#
# Currently there is a self documenting list for CMDS
#

## config file contains DC variable lists for single location to update

. /data/traffic/dc-config.cfg

# dcListCMDS="NWCSDEBG:Wilmington WMTPPAAA:PlymouthMeeting AnnapolisJunction:AnnapolisJunction Chantilly:Chantilly IPLUINXI:Westside Guion:Guion Johnstown:Johnstown Bridgeville:Bridgeville Lenexa:Lenexa SaintLouis:SaintLouis Bloomington:Bloomington Omaha:Omaha Copperfield:Copperfield BatonRouge:BatonRouge  ALPRGAGQ:Alpharetta Birmingham:Birmingham RDMEWA22:RedmondRidge HLBOOR38:Hillsboro WJRDUT30:WestJordan AURSCOTY:Aurora NLVGNVOQ:LasVegas TEMQAZKW:Tempe";

#---- General Variables -------------------------------------------------------
#
baseDir="/data/traffic";
webDoc=${baseDir}/cmdsReport.html;

#---- Control Variables -------------------------------------------------------
# tillNextReport is the number of seconds to sleep before running the this
# report again. Currently it is set to 1200 seconds, i.e. 20 minutes.
#
tillNextReport=1200

#---- Target Host -------------------------------------------------------------
# When completed send the report to the following host.  Currently the report
# will be copied into the home directory.
#

#------------------------------------------------------------------------------
# Main loop that controls the execution of the report, that loops forever.
# There is a sleep statement at the bottom of the loop, which uses the
# variable ${tillNextReport} to determine when when to execute the next
# interation.
#------------------------------------------------------------------------------

while true
do

	echo "<!DOCTYPE html>" > ${webDoc};
	echo "<html><body>" >> ${webDoc};
	echo "<table BGCOLOR=Lightgoldenrodyellow border="1">" | tee -a ${webDoc};
	
	mytime=`date "+%T" | awk -F: '{print $1*60 + $2}'`;
	myda=`date "+%d"`;
	mymo=`date "+%m"`;
	myyr=`date "+%Y"`;
	myti=`date "+%H"`;
	mytime=`date "+%T" | awk -F: '{print $1*60 + $2}'`;


#----------------------------------------------------------------------------------------
# CMDS Heading
#----------------------------------------------------------------------------------------
		
	TableHeading=`TZ=America/Los_Angeles date "+%m/%d/%y %H:%M  %Z"`;
	
	printf "<tr><th colspan=\"6\" style=\"BACKGROUND-COLOR: LightSteelBlue\">" | tee -a ${webDoc};
	printf "DC->NEC Traffic Report %s" "${TableHeading}" | tee -a  ${webDoc};
	printf "</th></tr>\n" | tee -a ${webDoc};

#----------------------------------------------------------------------------------------
# ROW Heading
#----------------------------------------------------------------------------------------

	printf "<tr>\n" | tee -a ${webDoc};
	
	for i in CMDS ipfix1 ipfix2 pilotPacket1 pilotpacket2 SubscriberIB; do
		printf "<th align=\"center\" style=\"BACKGROUND-COLOR: LightSteelBlue\">${i}</th>\n" | tee -a ${webDoc};
	done;
	printf "</th></tr>\n" | tee -a ${webDoc};
	
#		printf "<tr><th colspan=\"6\" style=\"BACKGROUND-COLOR: DarkOrchid\">" | tee -a ${webDoc};
#		printf "</th></tr>\n" | tee -a ${webDoc};

#----------------------------------------------------------------------------------------
# CMDS Body
#----------------------------------------------------------------------------------------

for dc in ${dcListCMDS}; do	
printf "<td>"${dc#*:}"</td>" | tee -a ${webDoc};
for ptype in ipfix pilotPacket;do
	for chassis in 1 2;do
	myti=`date "+%H"`;
	mytime=`date "+%T" | awk -F: '{print $1*60 + $2}'`;
	hadoop dfs -lsr /data/${dc%:*}/$chassis/$ptype/$myyr/$mymo/$myda/ 2>/dev/null| grep "\/_DONE" | tail -1 |awk -v t1=$mytime -F "/" '{print $4","$5","t1-(60*$9+$10)-7","$8}'| awk -F "," -v d1=$myda '{if ($3<10 && $3>=0 && d1=$4) print "<td>Current</td>";
	else if (d1!=$4) print "<td> Not Current</td>";
	else print "<td>"$3-9" min</td>"}' |  tee -a ${webDoc};
	done;
done;
hadoop dfs -lsr /data/${dc%:*}/SubscriberIB/$myyr/$mymo/$myda/ 2>/dev/null| grep "\/_DONE" | tail -1 |awk -v t1=$mytime -F "/" '{print $3 ","$4", " t1-(60*$8)"," $7}'| awk -F"," -v d1=$myda '{if (d1!=$4) print "<td>Not Current</td>";
else if ($3<100 && $3>=1 && d1=$4) print "<td>Current</td>";
else print "<td>"$3" min</td>"}' |  tee -a ${webDoc};

printf "</tr>\n" >> ${webDoc};
done;		
		
	printf "<tr><th colspan=\"6\" style=\"BACKGROUND-COLOR: DarkOrchid\">" | tee -a ${webDoc};
	printf "</th></tr>\n" | tee -a ${webDoc};
		
echo "</table>" >> ${webDoc};
echo "</body></html>" >> ${webDoc};

#----------------------------------------------------------------------------------------
# End of Document
#----------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------
# Copy doc to reports dir
#----------------------------------------------------------------------------------------

cp ${baseDir}/${webDoc} ${baseDir}/reports/

#----------------------------------------------------------------------------------------
# Cleanup files
#----------------------------------------------------------------------------------------

#	rm -f ${webDoc};

#	sleep 1200
	sleep ${tillNextReport}

#----------------------------------------------------------------------------------------
# End of Program
#----------------------------------------------------------------------------------------

done;

exit 0;