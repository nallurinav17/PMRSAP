#!/usr/bin/python
import sys
import os
import time
import xml.etree.ElementTree as ET

### Declarations
tree = ET.parse('NBI.xml')
root = tree.getroot()
date = os.popen("date +%Y%m%d").read()
days = 1    # GET FROM SHELL
logFiled="/var/log/nbi_events."+date+".log"

### Definitions
def sync(name,hostname,ip,user,password,destPath,includeDc,excludeDc,syncDays):
   "Synchronizing the SAP PM data."
   #print (name,hostname,ip,user,password,destPath,includeDc,excludeDc,syncDays)
   return

def rotate():
   if (os.path.exists(logfiled) == True):
      os.popen("find /var/log/ -type f -mtime +"+days+" -name nbi_events* -exec rm -rf {} \;")
   return

def writeLog(file,content):
   dbg=os.popen("date +'[%Y-%m-%d %H:%M]'").read().rstrip()
   file.write(dbg+content+"\n")
   return

### MAIN ###
try:
   log = open(logFiled,'ab+')
except IOError:
   dbg=os.popen("date +'[%Y-%m-%d %H:%M]'").read().rstrip()
   print dbg, "Error opening the event file! Terminating...!\n"
   sys.exit()

rotate()

for i in root.findall('nbi'):
   if (i.get('switch') == 'off'):
     continue
   name = i.get('name')
   hostname = i.find('hostname').text or 'Not Defined'
   ip = i.find('ipAddr').text 
   user = i.find('user').text or 'root'
   password = i.find('password').text or 'Gu@vu$!!'
   destPath = i.find('destPath').text or '/data/pmr'
   includeDc = i.find('includeDc').text
   excludeDc = i.find('excludeDc').text
   syncDays = i.find('syncDays').text or '3'
#   stamp = 
#   writeLog(log,"Initiating sync for : "+ip+" for "+syncDays+" days.\n["+
#   sync (name,hostname,ip,user,password,destPath,includeDc,excludeDc,syncDays)
   

#log.close()
