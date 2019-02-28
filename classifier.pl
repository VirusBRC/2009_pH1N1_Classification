#!/usr/bin/perl 

use lib ("/opt/tools/classifier");
use db::DB_Handler;
use config::Config_Reader;
use algo::H1N1NewPand;
use util::Utils;

my $configFile = "/opt/tools/classifier/".$ARGV[0];

unless(defined $configFile && -e $configFile){
    warn "Usage: classifier [configuration file]\n";
    exit(1);
}

my $config = config::Config_Reader->new(fileName=>$configFile);
my $OUT = $config->getValue("output");
my $IN = $config->getValue("input");

if($IN eq "text" ){
	unless(defined $ARGV[1] && -f $ARGV[1]) {

		warn "Usage: classifier [configuration file] [input sequence file fasta]\n";
		exit(1);
	}
}

my $outputfile;  

if($OUT eq "text" && defined $ARGV[2]){
        $outputfile = $ARGV[2];
} 

my $dbConn = ($IN eq "DB" || $OUT eq "DB") ? db::DB_Handler->new(
		"db_name" => $config->getValue(uc("db_name")),
		"db_host" => $config->getValue(uc("db_host")),
		"db_user" => $config->getValue(uc("db_user")),
		"db_platform" => $config->getValue(uc("db_platform")),
		"db_pass" => $config->getValue(uc("db_password")),
		"db_debug" => "0"
		) :  undef;

my $inputFile = $ARGV[1] if defined $ARGV[1]; 

my $blastout = 0;

my $fluType = $config->getValue("flutype");
my $seroType = $config->getValue("serotype");
my $seg = $config->getValue("seg");
my $type = $config->getValue("Type");
my $lookupfile = $config->getValue("lookupfile");

my $class = "algo::$type";

my $classifier =  $class->new(config=>$config,
		db_conn=>$dbConn,
		blastout=>$blastout,
		count=>3); 

my $classifierDir = $config->getValue("TempDir")."/".$config->getValue("ClassifierDir");
my $tempDir = $config->getValue("TempDir");
open LOG,">>$tempDir/classification.$type.log" or die "Cannot open log file. \t $tempDir/classification.$type.log";
my $tempFile = $tempDir."/".$$.".tmp";

print LOG "Classifier - $type ".localtime()."\n";

my $whereClause = "";

my $sequenceSql = "select isdid, sequence  from sequence where isdid in (select isdid from temp_sequence where c_type='".lc($type)."')"; 

my @resultRow;
eval{
	@resultRow = ($IN eq "DB" ) ? @{$dbConn->getResult($sequenceSql)} : @{util::Utils::getSequenceFromFasta($inputFile)};
};

if($@){
	warn "Error in collection of result. $@";
	exit(1);
}


my $size = scalar(@resultRow);

print LOG "Total number of sequences: $size \n";

my $OUTFILE;

if(defined $outputfile){
    open $OUTFILE,">$outputfile" or warn "Cannot open outputfile";
}

print $OUTFILE "Sequence Identifier\tClassification\n" if ($OUT eq "text" && defined $ARGV[2]);

foreach my $row (@resultRow){

	my $isdid = $row->[0];

	my $seq = util::Utils::trim($row->[1]);

	if ($seq eq "" ){
		print LOG "-------- Empty SEQ ----------\n";
		print LOG "Accession number: $isdid\n";
		print LOG "-------------------------------\n";
		next;
	}

	open SEQ,">$tempFile";
	print SEQ "$seq";
	close SEQ;


	print "\n" if $blastout;
	my $classification = $classifier->getClassification($tempFile, length($seq));


	my $sql = "SELECT up_metadata($isdid,'".lc($type)."','$classification')";

	print "ISDID:\t$isdid\t\tClassification:\t$classification\n" if ($OUT eq "text" && !defined $OUTFILE);

    print $OUTFILE "$isdid\t$classification\n" if (defined $OUTFILE);

	eval{

		$dbConn->setResult($sql) if ($OUT eq "DB");
		print LOG "isdid:$isdid\tclassification:$classification\n" if ($OUT eq "DB");

	};

	if($@){

		print LOG "-------- ERROR in DB ----------\n";
		print LOG "$isdid\t $seq\n";
		print LOG "$@";
		print LOG "-------------------------------\n";
	}
}

$dbConn->setResult("DELETE FROM TEMP_SEQUENCE WHERE C_TYPE='".lc($type)."'") if ($OUT eq "DB");

$dbConn->close() if ($OUT eq "DB");
close LOG;

my $archDir ="$classifierDir/archives/" ;
unless( -d $archDir){

	mkdir($archDir,0600);
}

my $logFile = "$classifierDir/classification.$type.log";
my $logSize = ( -s $logFile);

if($logSize >= 13107200){

	my $archFile = strftime("classification.$type.log.%Y-%m-%d",localtime);

	my $archFilePath = "$archDir/$archFile";

	my $archZipFile = "$archDir/$archFile.tar.gz";

	system "mv $logFile $archFilePath";

	system "tar -czf $archZipFile $archFilePath";

	unlink($archFilePath);

}

unlink($tempFile);


