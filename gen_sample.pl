#!/usr/bin/perl
our $VERSION = "0.0.2"; # Time-stamp: <2025-02-04T07:35:17Z>

##
## 使い方: 
##
##   perl gen_sample.pl main.txt -o sample.txt
##
## Author: JRF ( http://jrf.cocolog-nifty.com/statuses/ )
##
## License: MIT License.
##

use utf8;
use strict;
use warnings;

use Encode;
use Getopt::Long;

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

our $TXT = "main.txt";
our $OUTPUT = "sample.txt";

our @INC_CHAP = ("はじめに", "あとがき", "参考文献", "参照なし", "参照なし節");
my %INC_CHAP;
foreach my $k (@INC_CHAP) {
  $INC_CHAP{$k} = 1;
}
our @INC_SEC = (
		"デカルトとアンサンブル学習",
		"我思うゆえにありうるのは我々までである",
		"熟慮の複数",
		"易の小集団主義",
		"法印",
		"鬼神論",
		"イエスはサタンか - 『新約聖書』ひろい読み",
		"プレイ",
		"Booth にグッズあり！",
		"大アルカナの数表",
		"要訓練薬効",
	       );
my %INC_SEC;
$INC_SEC{""} = 1;
foreach my $k (@INC_SEC) {
  $INC_SEC{$k} = 1;
}


Getopt::Long::Configure("no_ignore_case", "auto_version");
GetOptions(
	   "o|output=s" => \$OUTPUT,
	   "help|h" => sub { usage(0); },
	  );

sub usage {
  my ($ext) = @_ || 0;
  print <<"EOU";
Usage: $0 [INPUT] [-o OUTPUT]
EOU
  exit($ext);
}

if (@ARGV == 0 || @ARGV == 1) {
  if (@ARGV == 1) {
    $TXT = shift(@ARGV);
  }
} else {
  usage(1);
}


sub strip_comment {
  my ($s) = @_;
  my $r = "";
  while ($s =~ /<comment>/s) {
    $r .= $`;
    if ($s !~ /<\/comment>/s) {
      die "Parse Error: comment tag doesn't close.";
    }
    $s = $';
  }
  $r .= $s;
  return $r;
}


sub main {
  my ($file, $output) = @_;

  open(my $fh, "<", $file) or die "$file:$!";
  binmode($fh, ":utf8");
  my $all = join("", <$fh>);
  close($fh);
  $all =~ s/\x0d\x0a/\n/sg;
  my $ofh;
  if ($output eq "-") {
    open($ofh, ">-") or die "STDOUT:$!";
  } else {
    open($ofh, ">", $output) or die "$output:$!";
  }
  binmode($ofh, ":utf8");
  print $ofh <<"EOT";


	宗教哲学雑考集 易理・神義論・始原論 試用版
	(Created: 2023-08-20, Time-stamp: <>)


X. メモ

章タイトルの後に () が付かないものは、メモとして使える。



EOT

  $all = strip_comment($all);
  my @l = split(/\n/, $all);
  my $chap;
  my $sec;
  while (@l) {
    my $s = shift(@l);
    if ($s =~ /^X\.\s*/s) {
      my $new_chap = $';
      if (exists $INC_CHAP{$new_chap} || $new_chap =~ s/\s*\(([^\)]*)\)$//s) {
	$chap = $new_chap;
	$sec = "";
	print $ofh "$s\n";
	next;
      } else {
	$chap = undef;
	$sec = undef;
      }
    } elsif ($s =~ /^\s*\*\*\s*/) {
      $sec = $';
      if (! exists $INC_SEC{$sec}) {
	print $ofh "$s\n";
	print $ofh <<"EOT";

(割愛)


EOT
      }
    }
    if ((defined $chap && $INC_CHAP{$chap})
	|| (defined $sec && exists $INC_SEC{$sec})) {
      print $ofh "$s\n";
    }
  }
  close($ofh);
}

main($TXT, $OUTPUT);

