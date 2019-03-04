package util::blastf;

use strict;
use warnings;
use Carp;


sub getLookupTable{

    my $config = shift;
    my $db_handler = shift;

    my $tempDir = $config->getValue("TempDir");

    my $classifierDir = $tempDir.$config->getValue("ClassifierDir");

    my $type = $config->getValue("Type");

    my $cacheFile = $config->getValue("lookupfile");

    unless( -e $cacheFile){
        $cacheFile = "$classifierDir/$type.cached";
    }


    my %lookUp=();
    my $rebuild = 1;

    open CACHE,"<$cacheFile" or die "Cannot open $cacheFile" if -e $cacheFile;

    if( -e $cacheFile ){

        $rebuild = 0;

        if(defined $db_handler  && (time() - (stat(CACHE))[9]) > 86400 ){
            $rebuild = 1;
        } else {

            while(<CACHE>){

                next unless $_ =~ /\w/;
                my ($ac, $bv) = (split /\s+/, $_)[0,1];
                $lookUp{$ac} = $bv;
            }

            if (scalar(keys %lookUp) == 0){
                warn "cache file: [$cacheFile] is empty! Rebuilding";
                $rebuild = 1;
            }
        }
    }

    close CACHE if -e $cacheFile;



    if($rebuild && defined $db_handler){

        my $blastset = $config->getValue("Type");

        my $sql = "SELECT accession, blastvalue FROM blast_info WHERE blastset = '$blastset'";

        my @resultRow = @{$db_handler->getResult($sql)};

        open CACHE,">$cacheFile" or die "Cannot open $cacheFile";

        foreach my $row (@resultRow){

            if(!exists($lookUp{$row->[0]})){

                $lookUp{$row->[0]} = $row->[1];

                print CACHE "$row->[0]\t$row->[1]\n";
            }

        }

        close CACHE;

    }

    return \%lookUp;

}


1;