package algo::H1N1NewPand;

use strict;
use warnings;
use Cwd 'chdir';
use algo::Algo;
use util::Utils;

our @ISA = qw(algo::Algo);

sub getClassification {
  my ( $self, $sequenceFile, $queryLength ) = @_;

  my $config = $self->config;
  my $classifierDir =
    join( '', $config->getValue("TempDir"),
    $config->getValue("ClassifierDir") );
  chdir($classifierDir);

  my $blastCmd = $self->{"blastall"};
  $blastCmd =~ s/<INPUTFILE>/$sequenceFile/;
  my $blastResult = `$blastCmd`;

  print $blastResult if $self->{"blastout"};
  print $blastResult;

  my %perc  = ();
  my %types = ();
  my %count = ();
  foreach my $row ( split( /[\n\r]/, $blastResult ) ) {
    my ( $n, $accession, $percid, $cov ) = split( /\t/, $row );
    $percid = util::Utils::trim($percid);
    my $type    = $self->getLookup($accession);
    my $len     = $self->getLength($accession);
    my $divisor = undef;
    if ( $len <= $queryLength ) {
      $divisor = $len;
    }
    else {
      $divisor = $queryLength;
    }
    my $weightedAverage = $percid * ( $cov / $divisor );
    if ( !defined( $perc{$accession} ) ) {
      $perc{$accession} = $weightedAverage;
    }
    else {
      $perc{$accession} += $weightedAverage;
    }
    if ( !defined( $types{$type} ) ) {
      $types{$type} = [];
      $count{$type} = 0;
    }
    ###
    ### Add accession if not defined...
    ###
    my $foundAcc = 0;
    foreach my $acc ( @{ $types{$type} } ) {
      if ( $acc eq $accession ) {
        $foundAcc = 1;
        last;
      }
    }
    if ( !$foundAcc ) {
      push( @{ $types{$type} }, $accession );
      $count{$type}++;
    }
  }
  unless ( ( scalar keys %perc ) > 0 ) {
    warn "$blastResult";
    return $self->returnClassification(undef);
  }
  my @typesArray = keys %count;
  if ( ( scalar @typesArray ) == 1 ) {
    my $type = $typesArray[0];
    ###
    ### All Other or all NPDM
    ###
    if ( $type eq "Other" ) {
      return $self->returnClassification("Other");
    }
    else {
      ###
      ### Processing NPDM
      ###
      for my $accession ( @{ $types{"NPDM"} } ) {
        my $weightedIdentity = $perc{$accession};
        if ( $weightedIdentity < 97 ) {
          return $self->returnClassification("Other");
        }
      }
      return $self->returnClassification("NPDM");
    }
  }
  else {
    ###
    ### Both Other and NPDM
    ###
    if ( $count{"Other"} >= $count{"NPDM"} ) {
      return $self->returnClassification("Other");
    }
    else {
      ###
      ### More NPDM
      ###
      for my $accession ( @{ $types{"NPDM"} } ) {
        my $weightedIdentity = $perc{$accession};
        if ( $weightedIdentity < 98 ) {
          return $self->returnClassification("Other");
        }
      }
      return $self->returnClassification("NPDM");
    }
  }
}

sub returnClassification {
  my ( $self, $classification ) = @_;
  if ( !defined($classification) || $classification eq "" ) {
    return "N";
  }
  elsif ( $classification eq "NPDM" ) {
    return "Y";
  }
  else {
    return "N";
  }
}

1;
