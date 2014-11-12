#!/usr/bin/python 
import os
import sys
import subprocess
def mkdate():
  return os.system("date +%Y%m%d")
#date = subprocess.Popen(['date +%Y%m%d'], stdout=subprocess.PIPE, shell=True)
#(d,err) = date.communicate()
#print "DATE IS:", d

date = os.popen("date +%Y%m%d").read().rstrip()
print date
os.system("date +%Y%m%d")
#logFile="/var/log/nbi_events."+date+".log"
logFile="/var/log/nbi_events."+date+".log"
print logFile
if (os.path.exists(logFile) == False):
  print "False"
else:
  print "True"

days="1"
logFiled="/var/log/nbi_events."+date+".log"
if (os.path.exists(logFiled) == True):
   os.popen("find /var/log/ -type f -mmin +"+days+" -name nbi_events* -exec rm -rf {} \;")

dbg=os.popen("date +'[%Y-%m-%d %H:%M]'").read().rstrip()
print dbg, "Error opening the event file! Terminating...!\n"

