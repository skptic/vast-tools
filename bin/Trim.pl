#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;

my $verboseFlag = 1;
my $stepSize = 25;

my $targetLength = 50;

my $pairedEndFile;
my $fastaFlag = 0;
my $onceTrim = 0;

Getopt::Long::Configure("no_auto_abbrev");
GetOptions("verbose" => \$verboseFlag,
		    "v" => \$verboseFlag,
			 "stepSize=i" => \$stepSize,
          "paired=s" => \$pairedEndFile,
			 "fasta" => \$fastaFlag,
			 "once" => \$onceTrim
);

sub sysErrMsg {
  my $sysCommand = shift;
  not system($sysCommand) or die "[vast trim]: $sysCommand Failed in $0!";
}

sub verbPrint {
  my $verbMsg = shift;
  if($verboseFlag) {
    chomp($verbMsg);
    print STDERR "[vast trim]: $verbMsg\n";
  }
}

sub randString {
  my $len = shift;
  my @chars=('a'..'z','A'..'Z','0'..'9');
  my $ret = "";
  for(my $c=0; $c < $len; $c++) {
    $ret .= $chars[int rand @chars];
  }
  return($ret);
}

### Initialize variables
my $total_reads = 0;
my $total_reads_accepted = 0;
my $name;
my $name2;
my $seq;
my $rest;

my $rand;
my $seqRev;
my $restRev;

my $pairedFlag = 0;
### CHECK PAIRED -tsw
if(defined($pairedEndFile)) {
  $pairedFlag = 1;
  open(REV, $pairedEndFile) or sysErrMsg "Can't open paired end file = $pairedEndFile!" and die "\n";
}

### Parses the original reads
my $lineCounter = 1;
while (my $fwd = <>){
  chomp $fwd;

  my $rev;
  if($pairedFlag) {
    $rev = <REV>; #iterate in tandem;
    chomp $rev;
  }

  my $mod = $lineCounter % 4;
  if ($mod == 1) {
      #$name = $fwd;
      $rand = randString(32);
      my $preChar = ($fastaFlag ? ">" : "@");
      $name = "$preChar$rand";
  } elsif ($mod == 2) {
      $seq = $fwd;
      $seqRev = $rev if($pairedFlag);
  } elsif ($mod == 3) {
      $name2 = "\+$rand";
  } elsif ($mod == 0) {
      $rest = $fwd;
      $restRev = $rev if($pairedFlag);
  
      $total_reads++;
    
      my $trimNum = 1;
      $stepSize = "inf" if($onceTrim); ### ONLY TRIM ONCE FOR EACH READ
      for(my $off=0; length($seq) >= $off + $targetLength; $off += $stepSize) { 
        # make sure the length of the sequence AND quality scores are >= length
        my $S1 = substr($seq, $off, $targetLength);
        my $R1 = substr($rest, $off, $targetLength);

        if($fastaFlag) {
          print STDOUT "$name-$trimNum\n$S1\n";
        } else {
          print STDOUT "$name-$trimNum\n$S1\n$name2-$trimNum\n$R1\n";
        }
		  $trimNum++;
      }
      # NOW FOR PAIR IF EXISTS
      if($pairedFlag) {
        for(my $off=0; length($seqRev) >= $off + $targetLength; $off += $stepSize) {
          my $S1 = substr($seqRev, $off, $targetLength);
          my $R1 = substr($restRev, $off, $targetLength);
          if($fastaFlag) {
            print STDOUT "$name-$trimNum\n$S1\n";
          } else {
            print STDOUT "$name-$trimNum\n$S1\n$name2-$trimNum\n$R1\n";
          }
          $trimNum++;
        }
      }
      $total_reads_accepted++;
  }
  $lineCounter++;
}

verbPrint "Total processed reads: $total_reads\n";
verbPrint "Total valid reads: $total_reads_accepted\n";

if($total_reads <= 1 or $total_reads_accepted <= 1) { exit 1; }

exit $total_reads_accepted;

