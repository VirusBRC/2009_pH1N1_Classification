package algo::Algo;

use strict;
use warnings;
use util::blastf;
use File::Basename;
use util::Utils;



sub new{
    my $class = shift;
    my $self = { @_ };
    bless( $self,$class);
    $self->_init;
    return $self;
}

sub config {$_[0]->{config}}

sub db_conn { $_[0]->{db_conn}} 


#Initialize look up table for consistent hits. 
# Hashvalue for lookup table is store in $self{"lookup"}
#
sub _init{

    my $self = shift;

    my $config = $self->{config};

    my $db_conn = $self->{db_conn};
    
    my $hits = 3;
    
    if (defined $self->{"count"}){ 
        $hits = $self->{"count"};
    }

    $self->setLengths();
    $self->{"lookup"} = \%{util::blastf::getLookupTable($config,$db_conn)};

    $self->{"blastdb"} = "/var/www/html/classifier/".$config->getValue("blastdir")."/".$config->getValue("blastdb");

    $self->{blastall} = join( ' ',
      $config->getValue("blastall"),
      "blastall -p blastn -m 8 -e 1 -F F -v $hits -b $hits -g F -d",
      $self->{"blastdb"},
      "--path " . $config->getValue("blastpath"),
      "-i <INPUTFILE>" );

    $self->{"blastout"} = 0 unless defined $self->{"blastout"};

}

sub getLookup{
    
    my $self = shift;
    my $accession = shift;

    my %l = %{$self->{"lookup"}};

    return $l{$accession};

}

sub setLengths {
  my $self        = shift;
  my $config      = $self->config;
  my $lengthsFile = $config->getValue("lengthsFile");
  $self->{lengths} = {};
  if (!defined($lengthsFile) || $lengthsFile eq "") {
    ###
    ### Lengths File is not defined so it will be empty
    ###
    return;
  }
  open( LENGTHS, "< $lengthsFile" )
    or die "Couldn't able to open the lengths file: lengthFile\n";
  while (<LENGTHS>) {
    chomp $_;
    my ( $accession, $length ) = split( /\t/, $_ );
    $self->{lengths}->{$accession} = $length;
  }
  close LENGTHS;
}

sub getLength {
  my $self = shift;
  my ($accession) = @_;
  return $self->{lengths}->{$accession};
}

sub getClassification{}
1;
