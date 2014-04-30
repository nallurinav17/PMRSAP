#!/bin/bash
#==============================================================================
# Name: pnsaReport.sh  - Traffic Report for VzW (PNSA, etc.)
# Date: 31-Dec-12
# Auth: Glenn Davis & Clifford M. Conklin, Guavus
# Vers: 2.0.0
#------------------------------------------------------------------------------
# 11-Nov-12 1.0.0 gd  Created original logic to report on PNSA DC traffic
#
# 27-Dec-12 2.0.0 cmc Converted from single command line to bash script
#			Embedded html.
#
# 03-Jan-03 2.0.0 cmc/gd Converted from single command line to bash script
#			Embedded html.
#
# 03-jun-03 3.0.0 gd Added hadoop check for SAP
#==============================================================================

#------------------------------------------------------------------------------
# Global Variables
#------------------------------------------------------------------------------

#---- DC List -----------------------------------------------------------------
# dcXXXX is the list of DC names as they appear in the /data/XXXX directory
# as reported by "hadoop dfs -ls /data"
#
# config file contains DC variable lists for single location to update

# . /data/traffic/dc-config.cfg

dcPNSA=" Westborough Windsor Rochester Branchburg Wall HickoryHills NewBerlin Lodge Westland Columbus Duff Euless  Memphis Tulsa Charlotte Nashville PembrokePines Orlando Sunnyvale Rocklin Marina Azusa Ontario Vista"
#---- Packet List -------------------------------------------------------------
# List of packet types to monitor.
#
packetList="ipfix pilotPacket SubscriberIB"

#---- Constraint Variables ----------------------------------------------------
# IPFIX and pilotPacket are accumulated in 5 minute 'bins' and considered
# current if posted to NEC within 9 minutes of subscriber activity. SubIB
# is generated hourly from prior hour of IPFIX and pilotPacket data and takes
# a varying amount of time to generate depending on the size of the prior
# hour's file set.  SubIB is considered current if posted within 100 minutes
# of last posting.
#
maxBinDela=10
maxSubDelay=100
minBinDelay=0
minSubDelay=1

#---- General Variables -------------------------------------------------------
#
baseDir="/data/traffic"
webDoc=${baseDir}/pnsaReport.html

#---- Control Variables -------------------------------------------------------
# tillNextReport is the number of seconds to sleep before running the this
# report again. Currently it is set to 1200 seconds, i.e. 20 minutes.
#
tillNextReport=1200


#------------------------------------------------------------------------------
# Main loop that controls the execution of the report, that loops forever.
# There is a sleep statement at the bottom of the loop, which uses the
# variable ${tillNextReport} to determine when when to execute the next
# interation.
#------------------------------------------------------------------------------

while true
do

	echo "<!DOCTYPE html>" > ${webDoc}
	echo "<html><body>" >> ${webDoc}
	cat /dev/null > ${baseDir}/input.csv;
	echo "<table BGCOLOR=Lightgoldenrodyellow border="1">" >> ${webDoc};
	#date "+%k"| awk \
	#	'{
	#	print "<font style=\"BACKGROUND-COLOR: Red\">";
	#	if ($1==0)
	#		print "This is the 00 hour UTC, DO NOT RUN THIS CHECK within this hour (can break logic if near 12am UTC)";
	#	else if ($1==1)
	#		print "This is the 01 hour UTC, DOUBLE CHECK (may show errant check result)";
	#	print "</font>";
	#	}' | tee -a  ${webDoc};

	pnsaTableHeading=`TZ=America/Los_Angeles date "+%m/%d/%y %H:%M  %Z"`
	printf "<tr><th colspan=\"6\" style=\"BACKGROUND-COLOR: LightSteelBlue\">" | tee -a ${webDoc};
	printf "DC -> NEC Traffic Report %s" "${pnsaTableHeading}" | tee -a  ${webDoc};
	printf "</th></tr>\n" | tee -a ${webDoc};

	myda=`date "+%d"`;
	myhr=`date "+%H"`;
	mymo=`date "+%m"`;
##	myyr=`date "+%Y"`;
	myyr=2013;
	mytime=`date "+%T" | awk -F: '{print $1*60 + $2}'`;

#----------------------------------------------------------------------------------------
# PNSA Heading
#----------------------------------------------------------------------------------------

	printf "<tr>\n" | tee -a ${webDoc};
	printf "\t<th style=\"BACKGROUND-COLOR: LightSteelBlue\">PNSA</th>\n" | tee -a ${webDoc};

	for i in ${packetList}; do
		printf "\t<th style=\"BACKGROUND-COLOR: LightSteelBlue\">${i}</th>\n" | tee -a ${webDoc};
	done;

	printf "</tr>\n" | tee -a ${webDoc};

#----------------------------------------------------------------------------------------
# PNSA Body
#----------------------------------------------------------------------------------------

	for DC in ${dcPNSA}; do
		printf "<tr>\n" >> ${webDoc};
		printf "\t<td>${DC}</td>\n" | tee -a ${webDoc};

		for pType in ${packetList}; do
			doneRes=`hadoop dfs -lsr /data/${DC}/${pType}/$myyr/$mymo/$myda/ 2>/dev/null| grep "\/_DONE" | tail -1`;
			dcPacketTime=`echo ${doneRes} | awk -v t1=$mytime -F "/" '{print $3 ", "$4", " t1-(60*$8+$9)-7"," $7}'`;
			echo ${dcPacketTime} | awk -F "," -v d1=$myda \
			'{
			maxDelay=(match($2, "SubscriberIB"))? 100 : 10;
			minDelay=(match($2, "SubscriberIB"))? 1 : 0;
			if ($3<maxDelay && $3>=minDelay && d1=$4)
				print "\t<td style=\"BACKGROUND-COLOR: Palegreen\">Current</td>";
			else if (d1!=$4)
				print "\t<td style=\"BACKGROUND-COLOR: Tomato\">Not Current</td>";
			else
				print "\t<td style=\"BACKGROUND-COLOR: Aquamarine\">" $3 - 9 " min</td>";
			}' | tee -a  ${webDoc};
		done;
		printf "</tr>\n" >> ${webDoc};
	done;
	printf "<tr><th colspan=\"6\" style=\"BACKGROUND-COLOR: DarkOrchid\">" | tee -a ${webDoc};
	printf "</th></tr>\n" | tee -a ${webDoc};
	hadoop dfsadmin -report 2>/dev/null  | head -11|grep "DFS Used%" | awk -F ":" '{print "<td>SAP - DFS Used: </td><td>"$2"</td>"}' | tee -a ${webDoc};
	hadoop dfsadmin -report 2>/dev/null  | head -11|grep "DFS Used" | grep TB | awk -F ":" '{print $2}' | awk '{print "<td>"$2" "$3"</td>"}'| tee -a ${webDoc};
	printf "</tr>\n" | tee -a ${webDoc};
	hadoop dfsadmin -report 2>/dev/null  | head -11|grep "Datanodes available" | sed s/dead/offline/ | awk -F ":" '{print "<td>"$1"</td><td>"$2"</td>"}' | tee -a ${webDoc};
	printf "</tr>\n" | tee -a ${webDoc};
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

cp ${webDoc} ${baseDir}/reports/

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

