#!/usr/bin/perl 

use strict;
use warnings;
use Carp;
use config::Config_Reader;
use Data::Dumper;
use db::DB_Handler;
use util::IST;



my $configFile =  $ARGV[0];

unless(defined $configFile){
    croak "Usage: perl blast_db.pl [config file]\n";
}

unless(-e $configFile) {
    croak "Invalid configuration file\n";
}

my $conf = config::Config_Reader->new(fileName => $configFile);

my $tempdir = $conf->getValue("TempDir");

my $classifierDir = $tempdir.$conf->getValue("ClassifierDir");

unless( -d $classifierDir){
    mkdir($classifierDir,0600);
}

my $blastdir = "$classifierDir/".$conf->getValue("blastdir");

my $blastdb = $conf->getValue("blastdb");

my $blastfile = "$blastdir/$blastdb";

unless( -d $blastdir ){
    mkdir($blastdir,0600);
}
 

open LOG,">> $blastdir/$blastdb.log" or die "Couldn't able to open the log file: $blastdir/$blastdb.log\n";

  

my $dbCon = db::DB_Handler->new(
                "db_name" => $conf->getValue(uc("db_name")),
                "db_host" => $conf->getValue(uc("db_host")),
                "db_user" => $conf->getValue(uc("db_user")),
                "db_platform" => $conf->getValue(uc("db_platform")),
                "db_pass" => $conf->getValue(uc("db_password")),
                "db_debug" => "1"
            );


my $BLASTSET = $conf->getValue("Type"); 

my $sql = "SELECT accession, sequence FROM sequence where accession in (SELECT accession from blast_info WHERE blastset = '$BLASTSET')";

print LOG "Getting sequences from data base.\t\t".localtime()."\n";

my @result = @{$dbCon->getResult($sql)};

my $tempFile = $blastdir."/$blastdb.tmp";


print LOG "Opening temp blast file. \t\t".localtime()."\n";

open TMPBLAST,">$tempFile" or die "Couldn't open $tempFile \n";


foreach my $row (@result){
    my $isdid = $row->[0];
    my $sequence =$row->[1];
    print TMPBLAST ">$isdid /1-".(length($sequence))." ";
    print TMPBLAST "\n$sequence\n";


}

close TMPBLAST;

my $command = "diff $tempFile $blastfile 2> /dev/null";

my $diff ="";

$diff = `$command` if(-e $blastfile);


if ( -e $blastfile && $diff !~ /\S/ && $?){
    unlink($tempFile);
    exit 0;
}

rename($tempFile,$blastfile);

print LOG "Running formatdb on $blastfile.\t\t".localtime()."\n";

my $formatdbcmd = "nice formatdb -i $blastfile -p F -o T ";

system($formatdbcmd);




