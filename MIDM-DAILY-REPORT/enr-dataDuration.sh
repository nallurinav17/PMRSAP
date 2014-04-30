#!/bin/bash
#==============================================================================
# Name: enr-dataDuration.sh  - Enr job time metric for VzW (SAP/PNSA)
# Date: 31-Dec-12
# Auth: Glenn Davis, Guavus
# Vers: 1.0.0
#------------------------------------------------------------------------------
# 31-Dec-12 1.0.0 gd  Created original logic to report 
#
# 20-Apr-13 2.0.0 Converted from single command line to bash script
#==============================================================================
#
# Performance Counters imported by eHealth from ASCII-CSV PM files
#
#     PM File naming format:    vzw-sap-pm-YYYY-MM-DD-HH-mm.csv
#     PM file location:    TBD
#
#     PM File format:     ASCII CSV, set of lines/records
#     Line/record format:    <day & time>, <DC CLLI>, <counter ID>, 
# <counter value>
#         with:
#         <day & time>    timestamp of the peg of the counter, format: 
# YYYY-MM-DD HH:mm:ss (24 hours format)
#         <CLLI>    CLLI of the equipment polled or to which the counter 
# applies, format: string
#         <counter ID>    Id of the PM counter, format: string
#         <counter value>    value of the PM counter, format: string
#
#     Supported PM counters
#     enrDuration    counter ID="enrDuration"
#         counter value: integer  in minutes
#         CLLI: DC CLLI
#         timestamp: day of data for MIDM processing, time= 00:00:00
#         Example:   in file: vzw-sap-pm-2013-04-18-00-00.csv
#         2013-04-16  00:00:00, CHRXNCLH, "enrDuration", 64
#         2013-04-16  00:00:00, WHCKTN04, "enrDuration", 25
#
#==============================================================================
#
#---- General Variables -------------------------------------------------------
# mydate - date for script to report on

mydate=`date "+%Y-%m-%d"`
#mydate=`date "+%Y-%m-%d" --date="1 days ago"`
# masterCollector - can be 118 or 88

masterCollector=118

#----------------------------------------------------------------------------------------
#  Body
#----------------------------------------------------------------------------------------
#
/opt/oozie/bin/oozie jobs -oozie http://10.136.239.${masterCollector}:8080/oozie -jobtype wf -len 30000  |sed -e 's/Wall SUCCEEDED/\WallSUCCEEDED/g'  |sed -e 's/Duff SUCCEEDED/\DuffSUCCEEDED/g'|awk -v d1="$mydate" '{if (($5 ~d1) && ($2 ~ /MidmEnr|MidmData_/)) print $2 "\t" $5 "\t" $6 "\t" $7 "\t" $8 "\t" $1}'|sed -e 's/RUNNING/\tRUNNING/g' -e 's/SUCCEEDED/\tSUCCEEDED/g' -e 's/KILLED/\tKILLED/g' -e 's/_/\t/g'|awk -F "\t" '{printf "%-17s %-8s %-9s %s %s %s %s %s\n", $2, $1, $3, $4, $5, $6, $7, $8}' |sort -k 7 | grep Enr;
echo;
/opt/oozie/bin/oozie jobs -oozie http://10.136.239.${masterCollector}:8080/oozie -jobtype wf -len 30000  |sed -e 's/Wall SUCCEEDED/\WallSUCCEEDED/g' | sed -e 's/Duff SUCCEEDED/\DuffSUCCEEDED/g' | awk -v d1="$mydate" '{if (($5 ~d1) && ($2 ~ /MidmEnr|MidmData_/)) print $2 "\t" $5 "\t" $6 "\t" $7 "\t" $8 "\t" $1}'|sed -e 's/RUNNING/\tRUNNING/g' -e 's/SUCCEEDED/\tSUCCEEDED/g' -e 's/KILLED/\tKILLED/g' -e 's/_/\t/g'|awk -F "\t" '{printf "%-17s %-8s %-9s %s %s %s %s %s\n", $2, $1, $3, $4, $5, $6, $7, $8}' |sort -k 7|grep Data;

#----------------------------------------------------------------------------------------
# End of Program
#----------------------------------------------------------------------------------------
exit 0;

