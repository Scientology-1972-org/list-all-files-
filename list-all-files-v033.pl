#!/usr/bin/perl -w
#!/usr/bin/perl
use strict;
use Getopt::Long;
Getopt::Long::Configure(qw{no_auto_abbrev no_ignore_case_always});
use List::Util qw(min max sum);
use List::MoreUtils qw(uniq);
use File::Copy;
use Cwd;
#my $dir = getcwd;
my $dir;
my $usage = <<'USAGE';
#my $dir;
############ Search for dates #############
usage: list-all-files-v033.pl [options]
		--dir|-d=
		--foldersToIgnore|-f
		--help|-h
#########################################

USAGE
print "$dir\n";
#my $dir;
my $foldersToIgnore;
my $printSize1;
#my $cutbycount=0; 	"split=s" => \$cutbycount,

my $result = GetOptions(
	"dir|d=s" => \$dir,
	"foldersToIgnore|f=s" => \$foldersToIgnore,

	"help|h|?" => sub{print $usage; exit}			
);

die $usage unless($dir);
print "$dir\n";
#################################################################################
my @ignore=();
if(defined $foldersToIgnore)
{
open(INFILE,$foldersToIgnore) or die "can-not find $foldersToIgnore file\n";
	while(my $line=<INFILE>)
	{
		$line=~s/\s$//g; 
		push(@ignore, $line);
	}
close(INFILE);
}
################################################################################
#make CSV hash of dir files
# first Argument is --datecalc to calculate date 2nd Argument is the foldername, if none, take the current one.
#--datecalc
# edit for new version-number:
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
$year=1900+$year; 
$mon++;
$mon = "0".$mon if $mon < 10;
if(length($mday)==1)
{
	$mday="0".$mday;
}
print "start: date $year-$mon-$mday time $hour:$min:$sec \n";
our $version = "v032";
my $datecalc="FALSE";
my $dateScript="Search-for-Dates-R8.pl";
if(exists $ARGV[0] && $ARGV[0] eq "--datecalc")
{
	$datecalc=shift(@ARGV);
	if(! -e $dateScript)
	{
		print "--datecalc is not avilable\nExiting now run wothout --datecalc parameter\n";
		exit;
	}
}
#print $datecalc;
# Library File::Basename - Parse file paths into directory, filename and suffix.
use File::Basename;

use warnings('all');
no warnings('recursion');

#specify hashing algo
#  Perl extension for SHA-1/224/256/384/512
use Digest::SHA qw(sha512_hex);

#Perl includes and options
use strict; 
use warnings;

#Lib File::Find - Traverse a directory tree.
use File::Find;

use strict;
#my $dir = $ARGV[0];
my $dirsize;
#find(sub{ -f and ( $dirsize += -s ) }, $dir );
#$dirsize = sprintf("%.02f",$dirsize / 1024 / 1024 / 1024);
#print "Directory '$dir' has size $dirsize GB\n";

# depending on arguments on command line:
#use curent dir if no dir specified as argument
push @ARGV, dirname(__FILE__) if $#ARGV < 0;

#take start time for calculation of duration at the end
our $start = time();

#choose path delimeter depending on OS: win is \, but other is /
our $delimeter = "/";
$delimeter = "\\" if $^O =~ /Win/ or $ARGV[0] =~ /\\/;

# depending on arguments on command line:
#use curent dir if no dir specified as argument
#if ($#ARGV < 0)
#{
#  my @pathParts = __FILE__ =~ m([^/\\]+)g;
#  pop @pathParts;
#  push @ARGV, join($delimeter, @pathParts);
#}

our $d = "/";
$d = "\\\\" if $^O =~ /Win/;

# this puts the path into the array @folder 
my @folder = split ($d, $dir);


my $lastFolderName = $folder[$#folder];
$lastFolderName = "this" if $lastFolderName eq ".";
$lastFolderName =~s/\://;

#create output filename from cur date
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
$mon++;
$mon = "0".$mon if $mon < 10;
if(length($mday)==1)
{
	$mday="0".$mday;
}
my $outname = ($year-100)."$mon$mday-list-of-all-files-in-$lastFolderName-$version";
our $outFile;

#open output file
open $outFile, qq{>$outname.tsv} or die "cannot create output file $outname.tsv";
print $outFile "path\tfilename\textension\tsize\tdate\thash\n";
#open log file for incorrect files names output
my $outlog = $outname.".log.txt";
print $outlog."\n";

our $logFile;
open $logFile, ">".$outlog or die "cannot create log file $outlog";
print $logFile "Logfile:$outlog\n";


our $processedFiles = 0;
our $processedSize = 0;
                             
#flush stdout
$|++;

#main run call - passDir: see below
passDir($dir);

sub checkErrors
{
  my $file = shift;
  if ((-r $file) || (-R $file))
  {}
  else 
  {
    print $logFile "\nCannot read file ".$!."\t".$file;
    return 0;
  }
  if (-e $file)
  {}
  else 
  {
    print $logFile "\nFile does not exist\t".$file;
    return 0;
  }
  if (-l $file)
  {
    print $logFile "\nFile is link\t".$file;
    return 0;
  }
  if (-p $file)
  {
    print $logFile "\nFile is pipe\t".$file;
    return 0;
  }
  if (-c $file)
  {
    print $logFile "\nFile is incorrect char\t".$file;
    return 0;
  }
  return 1;  
}

#recursive dir pass
sub passDir
{
  my $dir = shift;
  my $DIR_HANDLE;
  if (!opendir($DIR_HANDLE, $dir))
  {
    print $logFile "\ncant open dir\t$dir";
    return;
  }
  while (defined(my $file = readdir($DIR_HANDLE)))
  {
    next if $file =~ /^\.\.?$/;
    $file = ($dir.$delimeter.$file);
#skip link
    next if (-l $file);
#if dir, recursive self call
    if (-d $file)
    {
      passDir($file);   
    }
#if file, hash it
    elsif (-f $file)
    {
      process_file($file);
    }
    else
    {
      if (checkErrors($file))
      {
        print $logFile "\nUnknown object type\t".$file;
      }
    }
  }
  closedir($DIR_HANDLE);
}

sub stamp2float
{
  my $timeStamp = shift;
  my $unixEpoch = 25569;
  return $unixEpoch + $timeStamp / 86400;
}

sub time2float
{
  my @months = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
  my @in = @_;
#years
  my $res = ($in[0] - 1900)*365;
#add leap years
  my $leap = int(($in[0] - 1900) / 4);
  $res += $leap;
#add 30th Dec of 1899, hope we have no files until 1th of Jan 1900
  $res++;
#add 31th Dec of 1899, hope we have no files until 1th of Jan 1900
  $res++;
#add 29th Feb of cur date if it before cur date
  $res++ if $in[0] % 4 == 0 && $in[1] > 2;
#months
  for (my $i = 0; $i < $in[1]; $i++)
  {
    $res += $months[$i];
  }
#days: month day wihout current
  $res += $in[2] - 1;
#hours
  $res += $in[3] / 24;
  $res += $in[4] / (24 *60);
  $res += $in[5] / (24 *60 *60);
  return $res;
}



#main procedure
sub process_file
{

  my $file = shift;
#field delimeter for CSV
  my $tab = "\t";

#check whether input is file
  if (-f $file) 
  {
#replace / with \
#    $file =~ s/\//\\/;
#do hash myself
    return if __FILE__ eq $file;
#take path and file name from full file path
    my @mas = split ($d, $file);
#    print $mas[0]."\n";
    my $ext='';
    ($ext) = $file =~ /((\.[^.\s]+)+)$/;
	$ext=~s/^\.//;
    my $fname = pop @mas;
    $fname=~s/\r//g;	
    my $path = join $delimeter, @mas;
#open file for hashing
    my $fileHandle;
	
    if (!open $fileHandle, $file)
    {
      #check for valid file name, add here if needed
      if ($file =~ /[\&\^\@\?\%\*\|\"\<\>]/)
      {
        print $logFile "\nIncorrect file name\t".$file."\t".$&;
        return;
      }
      if (!checkErrors($file))
      {
        return;
      }
      print $logFile "\nCannot open file $!\t".$file;
      return;
    }
#get file info from os
    my @info = stat($file);
    my $size = $info[7];
    my @dateMass = localtime($info[9]);
#    $dateMass[4]++;
    for (my $i = 0; $i <= $#dateMass; $i++)
    {
      $dateMass[$i] = "0".$dateMass[$i] if int($dateMass[$i]) < 10;
    }
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = @dateMass;
    #my $date = ($year - 100).".".$mon.".".$mday."-".$hour.":".$min.":".$sec;
    #my $date = time2float($year + 1900, $mon, $mday, $hour, $min, $sec);
    my $date = stamp2float($info[9]);

if($size == 0)
{
	return;
}

	foreach my $ignorePath( @ignore)
	{
		
		if($path=~m/\Q$ignorePath\E/  && length($ignorePath) >0)
		{
			#print $line."\n";
			return;;
		}
		if(length($ignorePath)<10)
		{
			if($fname=~m/$ignorePath/  && length($ignorePath) >0)
			{
				#print $line."\n";
				return;;
			}	
		}
	}
#init hashing library
    my  $state = Digest::SHA->new(512);
#add file to hashing 
    $state->addfile($fileHandle);
#get HEX code of hash
    my $hash = $state->hexdigest;
#close file
    close $fileHandle;
#print CSV output

	

    print $outFile join $tab, ($path,$fname,$ext,$size,$date,$hash,"\n");
    $processedFiles++;
    $processedSize += $size;
    my $printSize = $processedSize > 1_000_000_000 ? (int($processedSize/1_000_000_000)." Gb") : ($processedSize > 1_000_000 ? (int($processedSize/1_000_000)." Mb") : $processedSize);
#print "-->$printSize<---\n";
	if($printSize=~m/^\d+\sGb/ && $printSize1 ne $printSize)
	{
    		print "\r".$processedFiles ." files of size ".$printSize. "                  ";
	}
$printSize1=$printSize;
  }
}

close $outFile;

# handling at end of script:
my $end = time();
#stat work time
print "\nran for ".($end - $start)." secs\n";
print $logFile "\nran for ".($end - $start)." secs = ".(($end - $start)/3600)." hours\n";
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
$year=1900+$year; 
$mon++;
$mon = "0".$mon if $mon < 10;
if(length($mday)==1)
{
	$mday="0".$mday;
}
print "End: date $year-$mon-$mday time $hour:$min:$sec \n";
#close file
    close $logFile;
#end of script
if($datecalc eq "--datecalc")
{
system(" perl $dateScript --input=$outname\.tsv"  );
}
