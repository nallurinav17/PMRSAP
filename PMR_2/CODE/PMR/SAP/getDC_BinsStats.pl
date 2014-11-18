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

# NameNode VIP
# Missing DC_bin Compute
my $nn = $ENV{NETWORK} . '.' . $ENV{CNP0};

# Get day before yesterday date
my ($sec, $min, $hour, $myda, $mymo, $myyr) = localtime(time - 24*60*60*2);
$mymo += 1; $mymo = '0'.$mymo if(length($mymo) == 1);
$myyr +=1900;

my $pnsaDC = $ENV{pnsaDC} || $ENV{dcPNSA};
my $cmdsDC = $ENV{cmdsDC} || $ENV{dcCMDS};

my %typeMapping = ('ipfix' => 'IPFIX', 'pilotPacket' => 'PilotPacket', 'SubscriberIB' => 'SubscriberIB');

foreach my $pnsa_dc (split(/\s/, $pnsaDC)) {
  my $siteCLLI = $nameCLLI{$pnsa_dc} || $pnsa_dc;
  foreach my $type (keys %typeMapping) {
    my $cmd = "$ENV{SSH} $nn \'$ENV{HADOOP} dfs -lsr /data/$pnsa_dc/$type/$myyr/$mymo/$myda/ 2>/dev/null| grep \"\/_DONE\"'";

    my @cmd_out = `$cmd`; 

    if($type eq 'SubscriberIB') {
      my ($missing_dates, $cnt) = findMissingSIB(\@cmd_out, "${myyr}${mymo}${myda}-");
      printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, $siteCLLI, 'SAP', 'SAP_missing_'.$typeMapping{$type}.'_DC_bins', $missing_dates;
      printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, $siteCLLI, 'SAP', 'SAP_missing_'.$typeMapping{$type}.'_DC_bin_count', $cnt;
    }

    else {
      my ($missing_dates, $cnt) = findMissingIP_PP(\@cmd_out, "${myyr}${mymo}${myda}-");
      printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, "$siteCLLI/1", 'SAP', 'SAP_missing_'.$typeMapping{$type}.'_DC_bins', $missing_dates;
      printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, "$siteCLLI/1", 'SAP', 'SAP_missing_'.$typeMapping{$type}.'_DC_bin_count', $cnt;
    }
  }
}
#$myyr='2013';$mymo=12;$myda=30;
# CMDS Missing DC_Bins
foreach my $cmds_dc (split(/\s/, $cmdsDC)) {
  my $siteCLLI = $nameCLLI{$cmds_dc} || $cmds_dc;
  foreach my $type (keys %typeMapping) {

    if($type eq 'SubscriberIB') {

      my $cmd = "$ENV{SSH} $nn \'$ENV{HADOOP} dfs -lsr /data/$cmds_dc/$type/$myyr/$mymo/$myda/ 2>/dev/null| grep \"\/_DONE\"\'";

      my @cmd_out = `$cmd`;

      my ($missing_dates, $cnt) = findMissingSIB(\@cmd_out, "${myyr}${mymo}${myda}-");
      printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, $siteCLLI, 'SAP', 'SAP_missing_'.$typeMapping{$type}.'_DC_bins', $missing_dates;
      printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, $siteCLLI, 'SAP', 'SAP_missing_'.$typeMapping{$type}.'_DC_bin_count', $cnt;

    }
    else {

      foreach my $chassis (1..2) {

        my $cmd = "$ENV{SSH} $nn \'$ENV{HADOOP} dfs -lsr /data/$cmds_dc/$chassis/$type/$myyr/$mymo/$myda/ 2>/dev/null| grep \"\/_DONE\"\'";

        my @cmd_out = `$cmd`;

        my ($missing_dates, $cnt) = findMissingIP_PP(\@cmd_out, "${myyr}${mymo}${myda}-");
        printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, "$siteCLLI/$chassis", 'SAP', 'SAP_missing_'.$typeMapping{$type}.'_DC_bins', $missing_dates;
        printf "%s, %s, %s, %s, %s\n", $TIMESTAMP, "$siteCLLI/$chassis", 'SAP', 'SAP_missing_'.$typeMapping{$type}.'_DC_bin_count', $cnt;

      }
    }
  }
}

write_log("Completed script $script_name");

sub findMissingSIB {
  my ($row, $date) = @_;

  # There is no data found
  return ('ALL', 24-0) if(scalar (@$row) == 0);

  # If all folders are present, return 1
  return ('NONE', 24-24) if(scalar (@$row) == 24);

  my $missingSIB = '';

  # Keep a track of completed _DONE for each hour
  my %_DONE;

  map {
    my @dt = split(/\//, $_);
    $_DONE{$dt[-2]} = 1;
  } @$row;

  my $cnt = 0;
  foreach my $i (0..23) {
    $i = '0' . $i if(length($i) == 1);
    unless(defined $_DONE{$i}) {
      $cnt++;
      if($missingSIB) {
        $missingSIB = $missingSIB .'|' . $date . "$i:00";
      }
      else {
        $missingSIB =  $date . "$i:00";
      }
    }
  }

  # if there are more than 12 (>12 and not >=) bins missing, then the value shall be "SET"
  return ('SET', $cnt) if($cnt > 12);

  return ($missingSIB, $cnt);;

}

sub findMissingIP_PP {
  my ($row, $date) = @_;

  # There is no data found
  return ('ALL', 24*12-0) if(scalar (@$row) == 0);

  # If all folders are present, return NONE
  return ('NONE', 24*12-24*12) if(scalar (@$row) == 24*12);

  my $missingIP_PP = '';

  # Keep a track of completed _DONE for each hour
  my %_DONE;

  map {
    my @dt = split(/\//, $_);
    $_DONE{$dt[-3].':'.$dt[-2]} = 1;
  } @$row;

  my $cnt = 0;
  foreach my $i (0..23) {
    for(my $min=0;$min<=55;$min+=5) {

      $i = '0' . $i if(length($i) == 1);
      $min = '0' . $min if(length($min) == 1);

      unless(defined $_DONE{$i.':'.$min}) {
        $cnt++;
        if($missingIP_PP) {
          $missingIP_PP = $missingIP_PP .'|' . $date . "$i:$min";
        }
        else {
          $missingIP_PP =  $date . "$i:$min";
        }
      }
    }
  }

  # if there are more than 12 (>12 and not >=) bins missing, then the value shall be "SET"
  return ('SET', $cnt) if($cnt > 12);

  return ($missingIP_PP, $cnt);

}


sub write_log {
  my $msg = shift;

  open(LOGF, ">>$ENV{LOGFILE}") or print "Unable to write to $ENV{LOGFILE}\n";
  print LOGF "$TIMESTAMP [$script_name] $msg\n";
  close(LOGF);
}

