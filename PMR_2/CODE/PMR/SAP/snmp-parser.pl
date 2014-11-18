#!/usr/bin/perl -w

use strict "vars";
my $snmpLogs='/tmp/zabbix_trap.log';
my $oidMaps='/data/scripts/PMR/etc/oidMaps.csv';
my $tmp="/tmp/last_eof";
my %stat=();
my %OIDMap=();



# MAIN
# Identify EOF
my $curLast='';
my $FILE='';
if (-f $snmpLogs) {

	$FILE=opnFile($snmpLogs,"A");
	if ($FILE) {
		$curLast=reachEof($FILE);	
		$curLast=0 if (!$curLast);
	} else { 
		print "Error: Unable to open file.\nCommitting exit!\n";
		exit;
	}
} else {
	print "Unable to locate SNMP trap translator logs: $snmpLogs\nCommitting exit!\n";
	exit;
}



# Read last EOF
my $last='';
my $rm=`/bin/rm -rf $tmp 2>&1>/dev/null`;
if (-f $tmp) { #Identify fresh run
	my $LF=opnFile($tmp,"A");

	if($LF) {
		$last=lastEof($LF);
	 	if (!$last) {
			$last=0;		
		}
	clsFile($tmp);
	} else { $last=0;}

} else {$last=0;}

# Compare Last EOF and Current EOF
my $set='';
if ($curLast < $last) {
	$set=0;
} else {
	$set=$last;
}

# Reach Specific and Read
my $FH='';
$FH=reachSpecific($FILE,$set);
if (!$FH) {
	print "Unable to locate the last state of file.\nCommitting exit!\n";
	exit;
}


# Load OID vs Trap name mappings.
my $oidMapping=loadOIDs($oidMaps);

# Parse latest traps and write to PMR.
readTrap($FH);


# Open temp ($file)
my $WR='';
$WR=opnFile($tmp,"N");

# Save last EOF (FH, $eof)
if ($WR) {
	saveLastEof($WR, $curLast);
	clsFile($tmp);
}
clsFile($snmpLogs);

######################################
# Open file to read, new file (removes old file) -use "N", open to append -use "A"
sub opnFile {
	my $F=''; my $fh='';
	$F=shift;
	my $mode=shift;
	my $sign='+<';
	$sign='+>' if ($mode eq "N");
	if ($mode eq "N" && -f $F) {
		my $ret=`/bin/rm -rf $F`;
		
	}
	eval {
		open(my $tfh, "$sign", "$F") or die("Error: Unable to open a file! $!\n");
		$fh=$tfh;
	};
	if ($@) {
		print "Can not open the file. Committing clean exit!\n$@";
		return undef;
	}
	$stat{$F}=$fh if ($fh);
	return $fh;
}

# Close opened file.
sub clsFile {
	my $H='';
	my $F=shift;
	#foreach my $F (keys %stat) {
		$H=$stat{$F};
		close ($H) if ($H);
		return 0;
	#}
}



sub lastEof {
	my $last='';
	my $FH='';
	$FH=shift;
	if ($FH) {
                $last=<$FH>;
		while (<$FH>) {
			print "TTTTT $_\n";
		}
		return $last if ($last);
		return undef;
	} else { 
		return undef;
	}

}

# Temp filename, last location.
sub saveLastEof {
	my $eof=''; my $FH='';
	$FH=shift;
	$eof=shift;

	if($eof && $FH) {
		print $FH "$eof";
		return 0;
	} 
	return undef;

}

sub readTrap {

	my $H=shift;
	my $pos='';

	while (<$H>) {
		my $out='';
		#if ($_=~/ZBXTRAP\s+(\d+.\d+.\d+.\d+)\s+(\S+)\s+(.*)$/) {	
		if ($_=~/^(.*)ZBXTRAP\s+(\d+.\d+.\d+.\d+)\s+(\S+)\s+(.*)$/) {	
			#$pos=tell($H);
			my $stampString=$1;
			my $ip=$2;
			my $trapName=$3;
			my $string=$4;
			$string=~s/^\s*//;
			$out=formatOut($stampString,$ip,$trapName,$string);
			print "$out\n";
			#return "$out" if ($out);
			#return undef;
		}
	#sleep 5;
	}	

}


sub formatOut {

	my $stampString='';
	my $string='';
	my ($out,$ip,$trapName)='';
	$stampString=shift;
	$ip=shift;
	$trapName=shift;
	$string=shift;

#02:59:23 2014/04/15 .1.3.6.1.4.1.37140.3.0.26 Normal "Data receive failed" 172.30.5.51 - ZBXTRAP 172.30.5.51 receiveFailure .1.3.6.1.4.1.37140.1.2.7.1:VERIZONITSERVER .1.3.6.1.4.1.37140.1.2.7.2:NOOACIL
	my @initial=();
	#print "SUPREET: $stampString\n";
	@initial=split(/\s+/,$stampString);
	chomp @initial;
	#print "SUPREET: @initial\n";
	$out="$initial[1]\|$initial[0], $ip";	# Add timestamp and IP

	my @line=();
        #@line=split(/\s+/, $string); # commented due to "wildcard_expansion_separator" in snmptt.ini being set to ";"
        @line=split(/;/, $string);
	chomp @line;
        $out="$out, $trapName, $initial[3]";			# Add severity
	my $parameterString='';
	foreach my $element (@line) {
		my ($oid,$value)='';
		($oid,$value)=split(/:/,$element,2);
		$oid=$OIDMap{$oid} if ($OIDMap{$oid});
		if ($parameterString) {
		    $parameterString="$parameterString, $oid\=\"$value\"";
		} else {
		    $parameterString="$oid\=\"$value\"";
		}
	}
	$out="$out, $parameterString" if ($parameterString);

#        my $FLAG=0;
#        my $Time=''; my $Toid='';
#        $out="$out, $trapName, $initial[3]";			# Add severity
#	 my $parameterString='';
#        foreach my $element (@line) {
#        	my ($oid,$value)='';
#        	if ($FLAG==0) {
#		if ($element=~/\S+\.37140\.1\.2\.2\.2:\S+$/) {
#                	$FLAG=1;
#                        ($Toid,$Time)=split(/:/,$element);
#			$Toid=$OIDMap{$Toid} if ($OIDMap{$Toid});
#                        next;
#                }
#                }
#                if ($FLAG==1) {
#                        $Time.=$element;
#                } else {
#                        ($oid,$value)=split(/:/,$element);
#			$oid=$OIDMap{$oid} if ($OIDMap{$oid});
#                        #print "$value, ";
#                        $parameterString="$parameterString, $oid\=\"$value\"";
#                }
#
#        }
#        ##my $oidTime, $Time = split(/:/,$newElement);
#	$parameterString="$parameterString, $Toid\=\"$Time\"" if ($Time);
#	if ($parameterString) {
#		$parameterString=~s/^\,\s*//;
#        	$out="$out, $parameterString";
#	}
	return $out;

}

sub reachSpecific {

        my $H=shift;
	my $set=shift;
	eval {
		seek($H,$set,0);

	};
	if ($@) {
		return undef;
	}	
	return $H;
}

sub reachEof {
 
        my $H=shift;
        my $pos='0';
	eval {
		seek ($H,$pos,2);
	};
	if ($@) {
		return undef;
	}
	my $last='';
	$last=tell($H);
	return $last if ($last);
	return undef;
}

sub loadOIDs {

	my $file=shift;
	if (-f $file) {
		my $fhoid=opnFile ($file,"A");
		while (<$fhoid>) {
			next if ($_=~/^\s*#/);
			my ($oid,$tname)=split(/,/,$_);
			$oid=~s/\s+//g; $tname=~s/\s+//g;
			$OIDMap{$oid}=$tname if ($tname);
		} 
		clsFile($file);
		return \%OIDMap;
	} else {
		return undef;
	}

}


#chomp $line;

# 11:53:13 2014/04/09 .1.3.6.1.4.1.37140.3.0.17 Normal "data is not received by collector" 172.30.6.11 - ZBXTRAP 172.30.6.11 noDataTrap .1.3.6.1.4.1.37140.1.2.2.1:ipfix .1.3.6.1.4.1.37140.1.2.2.2:Tue Apr  8 16:58:35 2014

#if ($line=~/ZBXTRAP/) {
#	my ($time, $date, $OID, $priority, $description, $source, $hyphen, $ZBXTRAP, $source2, $name, @rest) = split /\s+/, $line ;
#	$source=$source2 if(! $source); 
#	print "$source, $name, $OID, $priority, $description\n";

