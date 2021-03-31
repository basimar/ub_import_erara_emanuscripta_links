#!/usr/local/bin/perl -w
#--------------------------------------------------------------------------------- 
# Kurz:     Laedt via "HTTP-GET" ein XML mit den 'seit dem Letzten Scriptaufruf neu
#           digitalisierten RARA-Titeln' von der OAI-Schnittstelle herunter und
#           erstellt anhand dieser Daten ein SEQ-File mit den Feldern '0247 ',
#           '856 A', '907  ', '909EB' und '940  '.
#           
# Autor:    Tobias Rindlisbacher - ETH-Bibliothek Zuerich/ITS/BIT
# Datum:    16.05.2010
# IDSBB:    andreas.bigger@unibas.ch, bernd.luchner@unibas.ch
# Datum:    7.9.2010
# Korrektur: 909-Indikator und Unterfeld/abi, 21.10.2010           
#            949-Feld fuer Exemplargenerierung nur fuer basel/blu, 23.10.2012
#            949-Felder werden nicht mehr erzeugt (Bestellungen laufen ueber EoD), blu, 26.02.2013
#            localtime wird auf den gestrigen Tag berechnet. So werden Freigaben des lfd. Tages
#            beim folgenden Lauf mitgenommen/blu, 13.11.2013
#            907-Felder sind in RDA obsolet, stattdessen werden 007-Felder geschrieben/blu, 10.03.2016 
#---------------------------------------------------------------------------------
# 
# WICHTIG !!!!!!!!!!!
# Mindestens die jeweils letzte Datei jedes downloads im $data_dir muss stehenbleiben!
# Sonst holt das Programm wieder alles von Beginn weg!
#
#---------------------------------------------------------------------------------

use strict;
use LWP::Simple;
use File::Basename;
use FindBin;

my $option = shift(@ARGV);

my $oaiset;
my $lccode;
my $sublib;
my $ind;

if ( $option eq "basel" ) {

$oaiset = "bau_1";
$lccode = "erarabs";
$sublib = "A100";
$ind    = "A";

}
elsif ( $option eq "mab" ) {

$oaiset = "mab";
$lccode = "eraramab";
$sublib = "A332";
$ind    = "A";

}
elsif ( $option eq "bern" ) {

$oaiset = "bes_1";
$lccode = "erarabe";
$sublib = "B400";
$ind    = "B";

}
else {
	usage();
}

# Aktuelles Datum (und Zeit) ermitteln und auf gestern zurueckrechnen:
my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime time-(24 * 60 * 60);
$year += 1900;
$month++;
$mday = sprintf("%02d" , $mday);
$month = sprintf("%02d" , $month);
$hour = sprintf("%02d" , $hour);
$min = sprintf("%02d" , $min);
$sec = sprintf("%02d" , $sec);


my $data_dir = "data/$oaiset"; # Verzeichnis, in dem die XML-Files abgelegt werden
my $ud_dir = "ud/$oaiset"; # Verzeichnis, in dem die seq-Files fuer den Aleph-Update abgelegt werden

# Die OAI-Schnittstelle erlaubt es, ein Zeitintervall zu definieren, in dem nach frisch digitalisierten 
# alten Drucken gesucht werden soll: 
my $until_date = "$year-$month-$mday"; # als obere Grenze dient das aktuelle Datum 
my $from_date = '2000-01-01'; # als untere Grenze wird zunaechst mal ein Datum gewaehlt welches sicher vor
                              # der ersten Digitalisierung liegt. 
my $from_date_check = '20000101';  # Zum numerischen Vergleich
# Falls das Script nicht zum erstenmal ausgefuehrt wird, enthaelt $data_dir bereits XML-Files, aus denen
# das Juengste rausgesucht wird und dessen 'until_date' nun als neue $from_date dient.
# So werden nicht unnoetig alte Daten runtergeladen, welche schonmal verarbeitet wurden:
opendir(DIR, $data_dir) || die "Error: $! .\n";
rewinddir(DIR);
my @direntries = readdir(DIR);
closedir(DIR);
foreach my $de (@direntries) {
  if($de =~ /u(\d{4})-(\d{2})-(\d{2})/) {
    if($1.$2.$3 > $from_date_check) {
      $from_date_check = $1.$2.$3;
      $from_date = "$1-$2-$3";
    }
  }
}

my $data_file = $data_dir.'/e-rara_f'.$from_date.'_u'.$until_date.'.xml'; # Name des zu erstellenden XML-Files (Muss u<until-date> enthalten!)
my $ud_file = $ud_dir.'/e-rara_f'.$from_date.'_u'.$until_date.'.seq'; # Name des zu erstellenden seq-Files fuer den Aleph-Update

# URL fuer den "GET-Request" (dieser liefert zunaechst nur die ersten 10 Titel aus dem angegebenen Zeitintervall; der Output muss
# anschliessend mit weiteren "GET-Requests" in denen jeweils ein resumption-Token uebergeben wird, kompletiert werden (siehe unten
# in der while-Schleife...)
# 

my $url = 'http://www.e-rara.ch/'.$oaiset.'/oai/?verb=ListRecords&metadataPrefix=mets&from='.$from_date.'T00:00:00Z&until='.$until_date.'T23:59:59Z';


my $content = get($url); # Die runtergeladenen Teildaten werden in $content geschrieben. 
if(!defined $content) {
  die("Error: Can't get data from $url.\n");
}

my $record;
my $sys_no;
my $doi;

open(WRITED, ">$data_file") or die "cannot read $data_file: $!"; # Oeffnen des Filehandlers zum Schreiben des XML-Files

open(WRITE, ">$ud_file") or die "cannot read $ud_file: $!"; # Oeffnen des Filehandlers zum Schreiben des seq-Files

# Verarbeiten der XML-Daten:
while(1) {
  print WRITED $content; # XML-Daten werden ins XML-File geschrieben (angehaengt).

  # Mittels eines regulaeren Ausdrucks (regExp) werden die <record>-XML-Bloecke sukzessive ausgelesen:
  while($content =~ /<record>(.*?)<\/record>/gs) { # fuer alle gefundenen Records durchfuehren:
    $record = $1; # Inhalt des "record"-Blocks wird in $record geschrieben.
    $sys_no = '';
    $doi = '';
    
    # Aus dem <reference>-Block wird mittels regExp die Aleph-Systemnummer des aktuellen Blocks ausgelesen:
    if($record =~ /<dv\:reference>.*?request=(\d{9}).*?<\/dv\:reference>/s) {
      $sys_no = $1;
    } else {
      next;
    }

    # Aus dem <mods:identifier type="doi">-Block wird mittel regExp der DOI ermittelt:
    if($record =~ /<mods\:identifier type=\"doi\">(.*?)<\/mods\:identifier>/s) {
      $doi = $1;
    } else {
      next;
    }

    # Die gewonnenen Daten zum Record werden nun in die zu erstellenden Aleph-Felder abgefuellt und ins seq-File geschrieben:
    print WRITE "$sys_no 007   L cr-|||||||||||\n";
    print WRITE "$sys_no 0247  L \$\$a$doi\$\$2doi\n";
    print WRITE "$sys_no 856   L \$\$uhttp://dx.doi.org/$doi\$\$zDigitalisat in e-rara\n";
    print WRITE "$sys_no 337   L \$\$aComputermedien\$\$bc\$\$2rdamedia\n";
    print WRITE "$sys_no 338   L \$\$aOnline-Ressource\$\$bcr\$\$2rdacarrier\n";
    print WRITE "$sys_no 909$ind  L \$\$f$lccode\n";
    print WRITE "$sys_no 909I  L \$\$ahybrid-el\n";
    if ( $option eq "bern" ) {
       print WRITE "$sys_no 909B  L \$\$flza-cc0\n";
       print WRITE "$sys_no 909B  L \$\$ferarabe\n";
    };
    print ".";
  }

  # Falls es einen resumption-Token gibt, wird dieser mittels regExp eruiert und via eines weiteren GET-requests koennen
  # neue 10 Records in $content geschrieben und anschliessend verarbeitet werden. Gibt es keinen resumption-Token, sind 
  # alle Records durch und die Schleife muss nicht mehr wiederhot werden; wird also via "last;" abgebrochen. 
  if($content =~ /<resumptionToken[^>]*>(.*?)<\/resumptionToken>/s) {
    $url = 'http://www.e-rara.ch/'.$oaiset.'/oai/?verb=ListRecords&resumptionToken='.$1;
    $content = '';
    $content = get($url);
    if(!defined $content) {
      last;
    }
  } else {
    last;
  }
}
close(WRITE); # Filehandler fuer XML-File wird geschlossen
close(WRITED); # Filehandler fuer seq-File wird geschlossen


# Sofern das seq-File nicht leer ist, wird es an das Script 02_check_in_z00_data.pl uebergeben, welches sicherstellt, dass
# das seq-File keine Felder enthaelt, die es im Aleph in der entsprechenden Titelaufnahme bereits gibt:
if(!(-z $ud_file)) {
  system('perl '. $FindBin::Bin .'/02_check_in_z00_data.pl '.$ud_file); 
}


# -------------------
# Usage
# -------------------
sub usage {
    my $prog=basename($0);
    print<<EOD;
$prog: Generiere Ladelisten in ALEPH-Sequential aus e-rara-OAI

Gebrauch:  $prog <options>

options:
  basel		get data for Basel
  bern		get data for Bern
  mab		get data for Musikakademie Basel

Beachte: Die Ergebnisse werden in den Verzeichnissen

	<programmverzeichnis>/data/bau_1
	<programmverzeichnis>/data/bes_1
	<programmverzeichnis>/data/mab
bzw.
	<programmverzeichnis>/ud/bau_1
	<programmverzeichnis>/ud/bes_1
	<programmverzeichnis>/ud/mab
gespeichert.

Diese müssen vor dem ersten Start des Programmes von Hand erstellt werden.

EOD
    exit;
}
