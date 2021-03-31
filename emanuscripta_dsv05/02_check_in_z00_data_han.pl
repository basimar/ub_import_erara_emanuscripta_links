#!/usr/local/bin/perl -w
#------------------------------------------------------------------------------- 
# Kurz:     Checkt in der bib01.z00, ob die in $src_file enthaltenen Zeilen
#           bereits existieren. 
#           
# Autor:    Tobias Rindlisbacher - ETH-Bibliothek Zuerich/ITS/BIT
# Datum:    23.12.2009
# IDSBB:    Anpassung bernd.luchner@unibas.ch, 08.09.2010
#           Korrektur: Pruefung auf 949 entfaellt, 949-Felder werden nicht mehr angelegt. blu, 26.02.2013
# HAN:      Anpassungen fuer HAN (DSV05)
#           oliver.schihin@unibas.ch, 12.04.2013
#-------------------------------------------------------------------------------

use strict;
use Encode qw(encode decode);
use DBI;
#use DBD::Oracle;

my $src_file = $ARGV[0];
my $dst_file = $src_file.'_neu';
my $link_exists_file = $src_file.'_link_exists';
my $nwrf_file = $src_file.'_nwrf';

my $normalisation = '[^\w\d\$\&\=]';
my %s_str_hash = ();
 # -  Für jedes Feld kann ein Array mit Kriterien definiert werden, die erfüllt sein müssen,
 # damit ein Feld aus den zu ladenden Daten (UD) mit einem Feld aus dem Aleph (AD) als 
 # übereinstimmend betrachtet wird.
 #
 # -  Jedes Element dieses Kriterien-Arrays besteht wiederum aus 2 Elementen:
 # Element 0: enthält einen Regulären Ausdruck, welcher die für den Vergleich relevanten
 # Daten aus dem UD-Feld extrahiert (Die Entsprechenden Daten müssen im RegExp eingeklammert
 # werden.
 # Element 1: enthält einen Regulären Asdruck, welcher mit den mittels RegExp aus Element 0
 # extrahierten Daten aus dem UD-Feld nun im AD-Feld matchen muss. Die Daten werden über den
 # Platzhalter \#1 im RegExp platziert.

@{$s_str_hash{'0247 '}} = (['(\$\$a[^\$]+)','\#1']);
@{$s_str_hash{'909  '}} = (['(\$\$b[^\$]+)','\#1']);
@{$s_str_hash{'907  '}} = (['(\$\$g[^\$]+)','\#1']);
# @{$s_str_hash{'949  '}} = (['(\$\$s[^\$]+)','\#1']);
@{$s_str_hash{'856##'}} = (['\$\$z([^\$]+)','\#1']);

 # Bestimmt, ob Felder, für die keine Vergleichsregel definiert wurde, generell nicht geladen
 # werden sollen, oder ob diese über ihren gesammten Inhalt verglichen werden sollen: (1 = löschen, 0 = über gesammten Inhalt vergleichen)
my $del_others = 0;

my @incl_libs = ('DSV05');

my $g_enc = 'utf-8';

my $dbuser = 'dsv05';
my $dbpw   = 'dsv05';

# $ENV{ORACLE_SID} or die 'ORACLE_SID ???';
# $ENV{ORACLE_HOME} or die 'ORACLE_HOME ???';

# Alternativ dbh mit Zuweisung:
my $dbh = DBI->connect('dbi:Oracle:', $dbuser, $dbpw, {LongReadLen=>48000, AutoCommit=>1})
    or die "$DBI::errstr\n";

# Original, bringt Fehler seit Jan. 2011:
# my $dbh = DBI->connect('dbi:Oracle:', $dbuser, $dbpw) or die "$DBI::errstr\n";
# $dbh->{LongReadLen} == 48000 or die "$DBI::errstr\n";

my $sql = "select z00_no_lines, z00_data from dsv05.z00 where z00_doc_number = ?";
my $sth = $dbh->prepare ($sql) or die "$DBI::errstr\n";

my %n_ex = u_count_ex();
my $n;

my $doc_number = '0';
my $fld;
my $ind;
my $cnt;
my %hash;
open(READ, "<$src_file") || die "$!";
open(WRITE, ">$dst_file") || die "$!";
open(WRITELE, ">$link_exists_file") || die "$!";
open(WRITENWR, ">$nwrf_file") || die "$!";
while(<READ>) {
  if($_ =~ /^(\d{9}) (.{5}) L (.*)$/) {
    if($doc_number ne $1 && $doc_number ne '0') {
      check_z00($doc_number, \%hash);
      %hash = ();
    }
    $doc_number = $1;
    $fld = $2;
    $cnt = $3;
    if($fld !~ /^940/ && !u_exists($hash{$fld}, $cnt)) {
      push(@{$hash{$fld}}, $cnt);
    }
  }
}
check_z00($doc_number, \%hash);
%hash = ();
close(WRITENWR);
close(WRITE);
close(WRITELE);
close(READ);
$sth->finish;
$dbh->disconnect;


sub check_z00 {
  my $doc_number = shift;
  my $t_data = shift;
  my %n_data = %{$t_data};
  my ($no_lines, $data);
  my $t_cnt;
  my $nwc;
  my $tt_cnt;
  my @t_str_arr;
  my %w_data;
  $sth->execute($doc_number) || die "$DBI::errstr\n";
  $sth->bind_columns(undef, \$no_lines, \$data) || die "$DBI::errstr\n";
  my %z00_data;
  if($sth->fetch()) {
    %z00_data = z00_to_hash_nlz($no_lines, $data);
  } else {
    %z00_data = ();
  }
  my $regexp;
  my $val;
  my $tt_key;
  my $t_key;
  my $t_fld;
  my @z00_rval;
  my @sfx_e;
  my @sfx_n;
  while(my ($fld,$t_cnt) = each(%n_data)) {
    if(!exists $s_str_hash{$fld}) {
      $t_fld = 0;
      while(my ($key,) = each(%s_str_hash)) {
        $tt_key = $key;
        $tt_key =~ s/#/./g;
        if($fld =~ $tt_key) { 
          $t_fld = $key;
          $t_key = $tt_key;
        }
      }
      if(!$t_fld) {
        $t_fld = $fld;
        $t_key = $fld;
      }
    } else {
      $t_fld = $fld;
      $t_key = $fld;
    }
    if($del_others == 1 && !exists $s_str_hash{$t_fld}) {
      foreach my $cnt (@{$n_data{$fld}}) {
        print WRITENWR "$doc_number $fld L $cnt\n";
      }
      next;
    }
    @z00_rval = u_get_by_rkey(\%z00_data, $t_key);
    foreach my $cnt (@{$t_cnt}) {
      $t_cnt = lc($cnt);
      $t_cnt =~ s/$normalisation//g;
      @t_str_arr = ();
      if(exists $s_str_hash{$t_fld}) {
        foreach my $t_s_str (@{$s_str_hash{$t_fld}}) {
          $regexp = ${@{$t_s_str}}[0];
          $tt_cnt = ${@{$t_s_str}}[1];
          $nwc = 0;
          foreach ($t_cnt =~ /$regexp/) {
            $nwc++;
            $val = $_;
            $val =~ s/\\/\\\\/g;
            $val =~ s/\^/\\\^/g;
            $val =~ s/\$/\\\$/g;
            $val =~ s/\%/\\\%/g;
            $val =~ s/\@/\\\@/g;
            $val =~ s/\./\\\./g;
            $val =~ s/\//\\\//g;
            $val =~ s/\+/\\\+/g;
            $val =~ s/\*/\\\*/g;
            $val =~ s/\?/\\\?/g;
            $val =~ s/\|/\\\|/g;
            $val =~ s/\[/\\\[/g;
            $val =~ s/\]/\\\]/g;
            $val =~ s/\(/\\\(/g;
            $val =~ s/\)/\\\)/g;
            $val =~ s/\{/\\\{/g;
            $val =~ s/\}/\\\}/g;
            $tt_cnt =~ s/\\#$nwc/$val/;
          }
          if($tt_cnt =~ /\#/) {
            $val = $t_cnt;
            $val =~ s/\\/\\\\/g;
            $val =~ s/\^/\\\^/g;
            $val =~ s/\$/\\\$/g;
            $val =~ s/\%/\\\%/g;
            $val =~ s/\@/\\\@/g;
            $val =~ s/\./\\\./g;
            $val =~ s/\//\\\//g;
            $val =~ s/\+/\\\+/g;
            $val =~ s/\*/\\\*/g;
            $val =~ s/\?/\\\?/g;
            $val =~ s/\|/\\\|/g;
            $val =~ s/\[/\\\[/g;
            $val =~ s/\]/\\\]/g;
            $val =~ s/\(/\\\(/g;
            $val =~ s/\)/\\\)/g;
            $val =~ s/\{/\\\{/g;
            $val =~ s/\}/\\\}/g;
            $tt_cnt = $val;
          }
          warn("$doc_number  $tt_cnt\n");
          push(@t_str_arr, $tt_cnt);
        }
      } else {
        push(@t_str_arr, $t_cnt);
      }
      if(!u_find_m(\@z00_rval, \@t_str_arr)) {
        push(@{$w_data{$fld}}, $cnt);
      } else {
        print WRITENWR "$doc_number $fld L $cnt\n";
      }
    }
  }
  @z00_rval = u_get_by_rkey(\%z00_data, '856..');
  @sfx_e = u_get_by_find_any(\@z00_rval, ['\$\$zonline']);
  @z00_rval = u_get_by_rkey(\%w_data, '856..');
  @sfx_n = u_get_by_find_any(\@z00_rval, ['\$\$zOnline']);
  foreach my $lib (@incl_libs) {
    if(exists ${%{$n_ex{$doc_number}}}{$lib}) {
      $n = ${%{$n_ex{$doc_number}}}{$lib};
    } else {
      $n = 0;
    }
    warn("$doc_number: (".($#sfx_n + 1)." + ".($#sfx_e + 1)." - $n)\n");
    for(my $i = 1; $i <= (($#sfx_n + 1) + ($#sfx_e + 1) - $n); $i++) {
      if($lib eq 'DSV05') {
        push(@{$w_data{'940  '}}, '$$cONL$$d60$$f'.$lib.'$$gEL$$jOnline');
      } elsif(index('E08E10E17E19E37E66E68',$lib)>=0) {
        push(@{$w_data{'940  '}}, '$$cONL$$d60$$f'.$lib.'$$g'.$lib.'EL$$jOnline');
      } else {
        push(@{$w_data{'940  '}}, '$$cONL$$d60$$f'.$lib.'$$g'.$lib.'OL$$jOnline');
      }
    }
  }
  if($#sfx_n >= 0 && $#sfx_e >= 0) {
    foreach my $fld (sort(fld_sort keys(%w_data))) {
      foreach my $cnt (@{$w_data{$fld}}) {
        print WRITELE "$doc_number $fld L $cnt\n";
      }
    }
  } else {
    foreach my $fld (sort(fld_sort keys(%w_data))) {
      foreach my $cnt (@{$w_data{$fld}}) {
        print WRITE "$doc_number $fld L $cnt\n";
      }
    }
  }
}

# bib01, adm50, ADM50 anpassen 

sub u_count_ex {
  my $sqlex = "select substr(z103_rec_key_1,6,9), substr(z30_sub_library,1,3), count(z30_rec_key) from dsv51.z30, dsv05.z103
               where z30_material = \'ONL\' and z103_rec_key like \'DSV51\'||substr(z30_rec_key,1,9)||\'%\' and z103_lkr_type = \'ADM\'
               group by substr(z103_rec_key_1,6,9), substr(z30_sub_library,1,3)";
  my $sthex = $dbh->prepare($sqlex) || die "$DBI::errstr\n";
  my %hash;
  my ($sys_no, $sub_library, $n);
  $sthex->execute() || die "$DBI::errstr\n";
  $sthex->bind_columns(undef, \$sys_no, \$sub_library, \$n) || die "$DBI::errstr\n";
  while($sthex->fetch()) {
    ##warn("$sys_no -- $sub_library -- $n\n");
    ${%{$hash{$sys_no}}}{$sub_library} = $n;
  }
  $sthex->finish;
  return %hash;
}

sub z00_to_hash {
  my $lines = shift;
  my $data = shift;
  my $p = 0;
  my $l = 0;
  my %h_data;
  $data = encode($g_enc, $data);
  my $t_data;
  for(my $i = 0; $i < $lines; $i++) {
    $l = substr($data,$p,4);
    $p+=4;
    $t_data = substr($data, $p, $l);
    push(@{$h_data{substr($t_data, 0, 5)}}, substr($t_data, 6, $l - 6));
    $p+=$l;
  }
  return %h_data;
}

sub z00_to_hash_nlz {
  my $lines = shift;
  my $data = shift;
  my $p = 0;
  my $l = 0;
  my $t_cnt;
  my %h_data;
  $data = encode($g_enc, $data);
  my $t_data;
  for(my $i = 0; $i < $lines; $i++) {
    $l = substr($data,$p,4);
    $p+=4;
    $t_data = substr($data, $p, $l);
    $t_cnt = lc(substr($t_data, 6, $l - 6));
    $t_cnt =~ s/$normalisation//g;
    push(@{$h_data{substr($t_data, 0, 5)}}, $t_cnt);
    $p+=$l;
  }
  return %h_data;
}

sub u_get_by_rkey {
  my $arr = shift;
  if(!defined $arr) {
    return ();
  }
  my %hash = %{$arr};
  my @arr = keys(%hash);
  my $str = shift;
  my @fk;
  foreach my $key (@arr) {
    if($key =~ /$str/) {
      foreach my $cnt (@{$hash{$key}}) {
        push(@fk,$cnt);
      }
    }
  }
  if($#fk >= 0) {
    return @fk;
  } else {
    return ();
  }
}

sub u_get_by_find_any {
  my $arr = shift;
  if(!defined $arr) {
    return ();
  }
  my @arr = @$arr;
  my $str = shift;
  if(!defined $str) {
    return ();
  }
  my @str_arr = @$str;
  if($#str_arr < 0) {
    return ();
  }
  my @fk;
  for(my $i=0; $i <= $#arr; $i++) {
    for(my $j=0; $j <= $#str_arr; $j++) {
      if($arr[$i] =~ /$str_arr[$j]/i) {
        push(@fk, $arr[$i]);
      }
    }
  }
  if($#fk >= 0) {
    return @fk;
  } else {
    return ();
  }
}

sub u_find {
  my $arr = shift;
  if(!defined $arr) {
    return 0;
  }
  my @arr = @$arr;
  my $str = shift;
  for(my $i=0; $i <= $#arr; $i++) {
    if($arr[$i] =~ /$str/) {
      return 1;
    }
  }
  return 0;
}

sub u_exists {
  my $arr = shift;
  if(!defined $arr) {
    return 0;
  }
  my @arr = @$arr;
  my $str = shift;
  for(my $i=0; $i <= $#arr; $i++) {
    if($arr[$i] eq $str) {
      return 1;
    }
  }
  return 0;
}

sub u_find_m {
  my $arr = shift;
  if(!defined $arr) {
    return 0;
  }
  my @arr = @$arr;
  my $str = shift;
  if(!defined $str) {
    return 0;
  }
  my @str_arr = @$str;
  my $ok = 0;
  for(my $i=0; $i <= $#arr; $i++) {
    $ok = 1;
    for(my $j=0; $j <= $#str_arr; $j++) {
      if($arr[$i] !~ /$str_arr[$j]/) {
        $ok = 0;
        last;
      }
    }
    if($ok == 1) {
      return 1;
    }
  }
  return 0;
}

sub fld_sort {
  my $n = 0;
  my $srt = 'AaÄäÂâÀàÃãBbCcDdEeÊêÈèÉéËëFfGgHhIiJjKkLlMmNnOoÖöÔôPpQqRrSsTtUuÜüÛûVvWwXxYyZz0123456789';
  my $la = length($a);
  my $lb = length($b);
  while($n < $la && $n < $lb) {
    if(index($srt, substr($a, $n, 1)) < index($srt, substr($b, $n, 1))) {
      return -1;
    } elsif(index($srt, substr($a, $n, 1)) > index($srt, substr($b, $n, 1))) { 
      return 1;
    }
    $n++;
  }
  return 0;
}
