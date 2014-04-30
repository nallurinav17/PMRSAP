#!/usr/bin/perl

use strict;
use Data::Dumper;
use Time::Local;

my $script_name = [split(/\//, $0)]->[-1];

my $TIMESTAMP = `$ENV{DATE} "+%Y%m%d-%H%M"`; chomp($TIMESTAMP);

# nameCLLI mapper
open(FL, "$ENV{BASEPATH}/etc/nameCLLI.sed") or die "Unable to open file $ENV{BASEPATH}/etc/nameCLLI.sed for reading";

my %nameCLLI;
map {
  my $row = $_; chomp($_);
  my @row = split(/\//, $row);
  $nameCLLI{$row[1]} = $row[2];
} <FL>;
close(FL);

#writelog
write_log("Starting script $script_name");

# Loop through each type of host and compute metrics as required

# Collector Nodes
print_DFUtilization('CNP');

foreach my $cn (split(/\s/, $ENV{CNP})) {
  my $ip = $ENV{NETWORK} . '.' . $cn;

  my $hostaname_cmd = "$ENV{SSH} $ip \"hostname\"";
  my $HOSTNAME = `$hostaname_cmd`; chomp($HOSTNAME);

   # Collector KPIs
    my $collectorKPIs = collectorStats($ip);

    my %adaptor_statsMap = ('snmp' => 'Arcsight', 'ipfix' => 'HTTP', 'pilotPacket' => 'PilotPacket');

    foreach my $adaptor_stats (sort keys %$collectorKPIs) {
      foreach my $statType (sort keys %{$collectorKPIs->{$adaptor_stats}}) {
        printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, 'SAP', $HOSTNAME, $adaptor_statsMap{$adaptor_stats}.$statType, $collectorKPIs->{$adaptor_stats}->{$statType};
      }
    }
}


# Compute Nodes
print_DFUtilization('CMP');

# CCP Nodes
print_DFUtilization('CCP');

# SVGW Nodes
print_DFUtilization('SGW');

# UI Nodes
print_DFUtilization('UIP');


# NameNode VIP
# Backlog Compute
my $nn = $ENV{NETWORK} . '.' . $ENV{CNP0};
my $myda=`date "+%d"`; chomp($myda);
my $mymo=`date "+%m"`; chomp($mymo);
my $myyr=`date "+%Y"`; chomp($myyr);

my $pnsaDC = $ENV{pnsaDC} || $ENV{dcPNSA};
my $cmdsDC = $ENV{cmdsDC} || $ENV{dcCMDS};

my %typeMapping = ('ipfix' => 'IPFIX', 'pilotPacket' => 'PilotPacket', 'SubscriberIB' => 'SubscriberIB');

foreach my $pnsa_dc (split(/\s/, $pnsaDC)) {
  my $siteCLLI = $nameCLLI{$pnsa_dc} || $pnsa_dc;
  foreach my $type (keys %typeMapping) {

    my $cmd = "$ENV{SSH} $nn \'$ENV{HADOOP} dfs -lsr /data/$pnsa_dc/$type/$myyr/$mymo/$myda/ 2>/dev/null| grep \"\/_DONE\" | tail -1\'";

    my $cmd_out = `$cmd`; chomp($cmd_out);

    # Default backlog of 1 day
    my $last_epoc = time - 24*60*60;

    if($type eq 'SubscriberIB') {
      if($cmd_out =~ /.*\s(\/data\/.+)/) {
        my @tm = split(/\//, $1);
        $last_epoc = timelocal(0, 0, $tm[-2], $tm[-3], $tm[-4] -1 , $tm[-5]);
      }
      printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, $siteCLLI, 'DC', $typeMapping{$type}.'_data_transfer_backlog', int((time - $last_epoc)/60);
    }
    else {
      if($cmd_out =~ /.*\s(\/data\/.+)/) {
        my @tm = split(/\//, $1);
        $last_epoc = timelocal(0, $tm[-2], $tm[-3], $tm[-4], $tm[-5] -1 , $tm[-6]);
      }
      printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, "$siteCLLI/1", 'DC', $typeMapping{$type}.'_data_transfer_backlog', int((time - $last_epoc)/60);
    }
  }
}

# CMDS BACKLOG
foreach my $cmds_dc (split(/\s/, $cmdsDC)) {
  my $siteCLLI = $nameCLLI{$cmds_dc} || $cmds_dc;
  foreach my $type (keys %typeMapping) {

    if($type eq 'SubscriberIB') {
      my $cmd = "$ENV{SSH} $nn \'$ENV{HADOOP} dfs -lsr /data/$cmds_dc/$type/$myyr/$mymo/$myda/ 2>/dev/null| grep \"\/_DONE\" | tail -1\'";
      my $cmd_out = `$cmd`; chomp($cmd_out);

      # Default backlog of 1 day
      my $last_epoc = time - 24*60*60;
      if($cmd_out =~ /.*\s(\/data\/.+)/) {
        my @tm = split(/\//, $1);
        $last_epoc = timelocal(0, 0, $tm[-2], $tm[-3], $tm[-4] -1 , $tm[-5]);
      }

      printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, $siteCLLI, 'DC', $typeMapping{$type}.'_data_transfer_backlog', int((time - $last_epoc)/60);
    }
    else {

      foreach my $chassis (1..2) {

        my $cmd = "$ENV{SSH} $nn \'$ENV{HADOOP} dfs -lsr /data/$cmds_dc/$chassis/$type/$myyr/$mymo/$myda/ 2>/dev/null| grep \"\/_DONE\" | tail -1\'";

        my $cmd_out = `$cmd`; chomp($cmd_out);

        # Default backlog of 1 day
        my $last_epoc = time - 24*60*60;

        if($cmd_out =~ /.*\s(\/data\/.+)/) {
          my @tm = split(/\//, $1);
          $last_epoc = timelocal(0, $tm[-2], $tm[-3], $tm[-4], $tm[-5] -1 , $tm[-6]);
        }

        printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, "$siteCLLI/$chassis", 'DC', $typeMapping{$type}.'_data_transfer_backlog', int((time - $last_epoc)/60);
      }
    }
  }
}

write_log("Completed script $script_name");

sub print_DFUtilization {
  my $envValue = shift;

  foreach my $_ip (split(/\s/, $ENV{$envValue})) {
    my $ip = $ENV{NETWORK} . '.' . $_ip;

    my $hostaname_cmd = "$ENV{SSH} $ip \"hostname\"";
    my $HOSTNAME = `$hostaname_cmd`; chomp($HOSTNAME);

    # DF Utilization
    my $DFUtilization = computeDFStats($ip);
    foreach my $vol (sort keys %$DFUtilization) {
      printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, 'SAP', $HOSTNAME, 'Disk_partition_size'.$vol, $DFUtilization->{$vol}->{'Disk_partition_size'};
      printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, 'SAP', $HOSTNAME, 'Disk_partition_utilization'.$vol, $DFUtilization->{$vol}->{'Disk_partition_utilization'};
    }
  }


}


sub collectorStats() {
  my $ip = shift;

  my $collStats = {};

  my %collStatsMapping = (
          'total-flow'   => '_record_data_volume',
          'dropped-flow' => '_dropped_record_data_volume',
  );


  foreach my $adaptor_stats (qw(snmp)) {
    foreach my $stats_type ( qw(total-flow dropped-flow) ) {

      my $coll_stats_cmd = "$ENV{SSH} $ip \'$ENV{CLIRAW} -t \"en\" \"collector stats instance-id 1 adaptor-stats $adaptor_stats $stats_type interval-type 5-min interval-count 5\"\'";

      my $coll_stats_cmd_out = `$coll_stats_cmd`;

      $collStats->{$adaptor_stats}->{$collStatsMapping{$stats_type}} = getTotalCollStats($coll_stats_cmd_out);
    }
  }

  return $collStats;
}

sub getTotalCollStats {
  my $coll_stats_cmd_out = shift;

  my $sum = 0;
  map {
   my $row = $_;
   if($row =~ /\s+\d+$/) {
     $sum += [split(/\s+/, $row)]->[-1];
   }
  } split(/\n/, $coll_stats_cmd_out);

  return $sum;
}



sub computeDFStats {
  my $ip = shift;

  my $comp_dfstats_cmd = "$ENV{SSH} $ip \'df'";

  my $comp_dfstats_cmd_out = `$comp_dfstats_cmd`;

  my %data;
  map {
    my $row = $_; chomp($row);
    my @row = split(/\s+/, $row);

    $row[-1] =~ s/\//_/g; $row[-1] = '_root' if($row[-1] =~ /^_$/g);
    $row[4] =~ s/\%//g;
    %{$data{$row[-1]}} = ('Disk_partition_size' => $row[1], 'Disk_partition_utilization' => $row[4])
                            if($row[1] =~ /^\d+$/);

  } split(/\n/, $comp_dfstats_cmd_out);

  return \%data;
}


sub write_log {
  my $msg = shift;

  open(LOGF, ">>$ENV{LOGFILE}") or print "Unable to write to $ENV{LOGFILE}\n";
  print LOGF "$TIMESTAMP [$script_name] $msg\n";
  close(LOGF);
}

