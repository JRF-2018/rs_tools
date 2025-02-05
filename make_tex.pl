#!/usr/bin/perl
our $VERSION = "0.0.2"; # Time-stamp: <2025-02-05T16:15:02Z>

##
## 使い方: 
##
##   perl make_tex.pl sample.txt -c cover_book-sample.png -o sample.tex
##   lualatex sample.tex
##   lualatex sample.tex
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
our $OUTPUT = "main.tex";
our $SAMPLE_TITLE = undef;
our $SAMPLE_DEFAULT_TITLE = "(試用版)";
our $TITLE = "宗教学雑考集";
our $SUBTITLE = "易理・始源論・神義論";
our $ISBN = "9798304102247";
our $PUBLISH_DATE = "2025年3月11日 第1.0版";
our @PUBLISH_INFO = (["2024年1月5日", "第0.8版"],
		     ["2025年3月11日", "第1.0版"],
		    );
our $AUTHOR = "JRF";
our $PUBLISHER = "ＪＲＦ電版";
our $PUBLISHER_LINK = "http://jrockford.s1010.xrea.com/epub/";
our $COVER_PNG = "cover_book-1.0.png";

## 読み込まれる PNG のオプションを指定する必要がある。
our %GRAPHICX_OPTION = ("youscout_table_1.png" =>  "scale=0.35",
			"youscout_table_2.png" =>  "scale=0.35",
			"youscout_table_r.png" =>  "scale=0.35",
		       );

## $GREEK_LENGTH 未満はギリシャ文字は JIS のギリシャ文字になる。
our $GREEK_LENGTH = 2;

## --amazon オプションを指定したときの左右のマージン。『宗教学雑考集』
## は 600ページ近いため、$INNER_MARGIN が大きい。
our $INNER_MARGIN = 24; ## mm
our $OUTER_MARGIN = 12; ## mm

## $NUM_{PRE|POST}_CHARS は、数値を使うときのスペースに関して警告を出
## すときの判定に使う。
our $NUM_PRE_CHARS = "。、（）「」『』【】〜：・第巻表図／前億説約年暦月兆万×＞→";
our $NUM_POST_CHARS = "。、（）「」『』【】〜：・千万年日人ヶ月時分倍割歳期回条章兆億光年個つ本番世王等パ乗巻位×枚次種親面名段代《》→／℃．";
our $NUM_POST_CHARS_2 = "万年人ヶ月倍割歳期回条章年個つ";

## 「 -- 」は $EM_DASH に置換される。
#our $EM_DASH = "\x{2015}\x{2015}"; # HORIZONTAL_BAR
our $EM_DASH = "\x{2014}\x{2014}";

## ユーザーが定義すべきパラメータは以上。

our $AMAZON_POD = 0;
our $NO_LINK = 0;

our @NO_REF_OK;
our @NO_REF_OK_SEC;

my %MARK_TO_CHAPTER = ();
my %SEC = ();
my @CHAP = ();
my %REF = ();
my %REF_TO_TITLE = ();
my @REFED = ();
my %REFED = ();

my %NO_REF_OK;
foreach my $k (@NO_REF_OK) {
  $NO_REF_OK{$k} = 1;
}
my %NO_REF_OK_SEC;
foreach my $k (@NO_REF_OK_SEC) {
  $NO_REF_OK_SEC{$k} = 1;
}


Getopt::Long::Configure("no_ignore_case", "auto_version");
GetOptions(
	   "a|amazon" => \$AMAZON_POD,
	   "n|no-link" => \$NO_LINK,
	   "o|output=s" => \$OUTPUT,
	   "s|sample-title=s" => \$SAMPLE_TITLE,
	   "c|cover=s" => \$COVER_PNG,
	   "help|h" => sub { usage(0); },
	  );

sub usage {
  my ($ext) = @_ || 0;
  print <<"EOU";
Usage: $0 [INPUT] [-o OUTPUT] [-s SAMPLE_TITLE]
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

if (! defined $SAMPLE_TITLE) {
  if ($TXT !~ /^main/) {
    $SAMPLE_TITLE = $SAMPLE_DEFAULT_TITLE;
  }
}

if ($AMAZON_POD) {
  $NO_LINK = 1;
}

sub escape_html {
  my ($s) = @_;
  $s =~ s/\&/\&amp\;/sg;
  $s =~ s/</\&lt\;/sg;
  $s =~ s/>/\&gt\;/sg;
#  $s =~ s/\'/\&apos\;/sg;
  $s =~ s/\"/\&quot\;/sg;
  return $s;
}

sub unescape_html {
  my ($s) = @_;
  $s =~ s/\&quot\;/\"/sg;
#  $s =~ s/\&apos\;/\'/sg;
  $s =~ s/\&gt\;/>/sg;
  $s =~ s/\&lt\;/</sg;
  $s =~ s/\&amp\;/\&/sg;
  return $s;
}

sub escape_pc {
  my ($s) = @_;
  $s =~ s/\%/\\\%/gs;
  return $s;
}

sub escape_tex {
  my ($s) = @_;
  my $r = "";
  my %trans = (
	       "#" => "{\\#}",
	       "\$" => "{\\\$}",
	       "%" => "{\\%}",
	       "\&" => "{\\\&}",
	       "~" => "{\\textasciitilde}",
	       "_" => "{\\_}",
	       "\\" => "{\\textbackslash}",
	       "\{" => "{\\{}",
	       "\{" => "{\\}}",
	       "\(" => "{(}",
	       "\)" => "{)}",
	      );
  my $q = join("", keys %trans);
  $trans{"["} = "{\\lbrack}";
  $trans{"]"} = "{\\rbrack}";
  $trans{"^"} = "{\\textasciicircum}";
  $trans{"-"} = "{-}";
  $trans{"--"} = "{---}";

  $s =~ s(--|[\[\]^\-\Q$q\E]){
    $trans{$&};
  }sexg;

  return $s;
}

sub is_kanji {# c:判別したい文字
  my ($c) = @_;
  my $unicode = ord($c);
  if ( ($unicode>=0x3005  && $unicode<=0x3006)  || #「々」と「〆」
       ($unicode>=0x4e00  && $unicode<=0x9fcf)  || # CJK統合漢字
       ($unicode>=0x3400  && $unicode<=0x4dbf)  || # CJK統合漢字拡張A
       ($unicode>=0x20000 && $unicode<=0x2a6df) || # CJK統合漢字拡張B
       ($unicode>=0xf900  && $unicode<=0xfadf)  || # CJK互換漢字
       ($unicode>=0x2f800 && $unicode<=0x2fa1f) ) { # CJK互換漢字補助
#	 ($unicode>=0x3190 && $unicode<=0x319f) ) { # 漢文用の記号

    return 1;
  }
  return 0;
}

sub num_check {
  my ($s) = @_;

  while ($s =~ /[01-9\.]+/) {
    my $pre = $`;
    my $c = $&;
    my $post = $';
    if (! ($pre eq "" || $pre =~ /[\x00-\xff\Q$NUM_PRE_CHARS\E]$/s)
	|| ! ($post eq "" || $post =~ /^[\x00-\xff\Q$NUM_POST_CHARS\E]/s)) {
      my $pr = "";
      if ($pre ne "") {
	$pr = substr($pre, -1);
      }
      my $ps = "";
      if ($post ne "") {
	$ps = substr($post, 0, 1);
      }
      warn "num warn $pr$c$ps\n";
    }
    if (($post =~ /^ [\Q$NUM_POST_CHARS_2\E]/s && $c !~ /\./)
	|| ($post =~ /^[\Q$NUM_POST_CHARS_2\E]/s && $c =~ /\./)) {
      my $pr = "";
      if ($pre ne "") {
	$pr = substr($pre, -1);
      }
      my $ps = "";
      if ($post ne "") {
	$ps = substr($post, 0, 2);
      }
      warn "num warn2 $pr$c$ps\n";
    }
    $s = $post;
  }
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
  split_chapters($all);
  my @chap = sort {$a->{"number"} <=> $b->{"number"}}
    (values %MARK_TO_CHAPTER);
  foreach my $c (@chap) {
    if ($c->{title} eq "参照なし") {
      preprocess_no_ref($c);
    } elsif ($c->{title} eq "参照なし節") {
      preprocess_no_ref_sec($c);
    } elsif ($c->{title} eq "参考文献") {
      preprocess_ref($c);
    } else {
      preprocess_chapter($c);
    }
  }
  print_top($ofh);
  foreach my $c (@chap) {
    if ($c->{title} eq "参照なし") {
    } elsif ($c->{title} eq "参照なし節") {
    } elsif ($c->{title} eq "参考文献") {
      print_ref($ofh, $c);
    } else {
      print_chapter($ofh, $c);
    }
  }
  print_bottom($ofh);

  print_summary();
  print_ref_summary();
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

sub translate_emdash {
  my ($s) = @_;

  $s =~ s/ -- /$EM_DASH/sg;
  return $s;
}


sub split_chapters {
  my ($all) = @_;
  my $num = 0;

  $all = strip_comment($all);
  #$all = translate_emdash($all);
  for my $c (split(/\n\nX\.\s*/, $all)) {
    if ($c !~ s/^([^\n]+)\n//s) {
      if ($num == 0) {
	next;
      }
      die "Parse Error. $c";
    }
    my $t = $1;
    my $mark;
    if ($t !~ s/\s*\(([^\)\,]+),[^\)]+\)\s*//) {
      if ($t ne "参照なし" && $t ne "参照なし節") {
	next;
      }
      $mark = $t;
    } else {
      $mark = $1;
    }
    $MARK_TO_CHAPTER{$mark} = {number => $num, mark => $mark,
			       title => $t, text => $c, sections => []};
    $CHAP[$num] = $MARK_TO_CHAPTER{$mark};
    $num++;
  }
}


sub preprocess_no_ref {
  my ($chap) = @_;
  my $s = $chap->{text};
  $s =~ s/^\s+//s;
  $s =~ s/^\s+$//s;
  my @l = split(/\n/, $s);
  while (@l) {
    my $s = shift(@l);
    $s =~ s/^\s+//s;
    $s =~ s/\s+$//s;
    next if $s =~ /^#/;
    push(@NO_REF_OK, $s);
  }
  foreach my $k (@NO_REF_OK) {
    $NO_REF_OK{$k} = 1;
  }
}


sub preprocess_no_ref_sec {
  my ($chap) = @_;
  my $s = $chap->{text};
  $s =~ s/^\s+//s;
  $s =~ s/^\s+$//s;
  my @l = split(/\n/, $s);
  while (@l) {
    my $s = shift(@l);
    $s =~ s/^\s+//s;
    $s =~ s/\s+$//s;
    next if $s =~ /^#/;
    push(@NO_REF_OK_SEC, $s);
  }
  foreach my $k (@NO_REF_OK_SEC) {
    $NO_REF_OK_SEC{$k} = 1;
  }
}

sub preprocess_ref {
  my ($chap) = @_;
  my $ref_num = 1;

  my $s = $chap->{text};
  $s =~ s/^\s+//s;
  $s =~ s/^\s+$//s;
  my @l = split(/\n/, $s);
  while (@l) {
    my $s = shift(@l);
    if ($s =~ /^\s*$/s) {
      next;
    }
    if ($s =~ /^\s*\<(\/)?([^\>]+)\>\s*$/s) {
      die "Parse Error.";
    } elsif ($s =~ /^\s*(\*\*?)\s*/) {
    } elsif ($s =~ /^\『([^\』]+)\』\s*\(([^\)]+)\)$/) {
      my $title = $1;
      my $info = $2;
      while (@l) {
	my $s2 = shift(@l);
	if ($s2 =~ /^\s*$/s) {
	  last;
	}
	if ($s2 !~ /^(https?\:[^\s]+)/) {
	  die "Parse Error: $s2";
	}
	my $url = $1;
	if ($url =~ /^https?\:\/\/www\.amazon\.co\.jp\//) {
	} elsif ($url =~ /^https?\:\/\/www\.amazon\.com\//) {
	} elsif ($url =~ /^https?\:\/\/kakuyomu\.jp\//) {
	} elsif ($url =~ /^https?\:\/\/7net\.omni7\.jp\//) {
	} elsif ($url =~ /^https?\:\/\/bookwalker\.jp\//) {
	} elsif ($url =~ /^https?\:\/\/[^\.]+\.booth\.pm\//) {
	} else {
	  die "Parse Error: $url";
	}
      }
      my $rn = $ref_num++;
      die "Multiple REF: $title" if exists $REF{$title};
      $REF_TO_TITLE{"ref_$rn"} = $title;
      $REF{$title} = "ref_$rn";
      if ($title =~ /\s+-\s+/) {
	die "Multiple REF: $`" if exists $REF{$`};
	$REF{$`} = "ref_$rn";
      }
    } elsif ($s =~ /^\《([^\》]+)\》\s*$/) {
      my $title = $1;
      my $urls = "";
      while (@l) {
	my $s2 = shift(@l);
	if ($s2 =~ /^\s*$/s) {
	  last;
	}
	if ($s2 !~ /^(https?\:[^\s]+)/) {
	  die "Parse Error: $s2";
	}
      }
      my $rn = $ref_num++;
      die "Multiple REF: $title" if exists $REF{$title};
      $REF_TO_TITLE{"ref_$rn"} = $title;
      $REF{$title} = "ref_$rn";
      if ($title =~ /\s+-\s+/) {
	die "Multiple REF: $`" if exists $REF{$`};
	$REF{$`} = "ref_$rn";
      }
    } else {
      die "Parse Error: $s";
    }
  }
}

sub preprocess_chapter {
  my ($chap) = @_;

  my $vspace = 0;
  my $mode = "";
  # my $close_tag = "";
  # my $open_tag = "";
  my $sec_num = 1;
  my $cn = $chap->{number};

  my $s = $chap->{text};
  $s =~ s/^\s+//s;
  $s =~ s/^\s+$//s;
  my @l = split(/\n/, $s);
  while (@l) {
    my $s = shift(@l);
    if ($s =~ /^\s*$/s) {
      $vspace++;
      next;
    }
    if ($s =~ /^\s*\<(\/)?([^\>]+)\>\s*$/s) {
      my $closing = $1;
      my $new_mode = $2;
      if ($closing) {
	if ($mode eq $new_mode) {
	  $mode = "";
	} else {
	  die "Parse Error: </$new_mode>";
	}
      } else {
	if ($new_mode eq "display") {
	  $mode = "display";
	  # $open_tag = "<div class=\"display\">\n";
	  # $close_tag = "</div>\n";
	} elsif ($new_mode eq "list") {
	  $mode = "list";
	  # $open_tag = "<div class=\"list\">\n";
	  # $close_tag = "</div>\n";
	} elsif ($new_mode eq "pre") {
	  $mode = "pre";
	  # $open_tag = "<pre class=\"pre-display\">\n";
	  # $close_tag = "</pre>\n";
	  while (@l) {
	    my $s2 = shift(@l);
	    if ($s2 =~ /^\s*<\/pre>\s*$/) {
	      last;
	    } else {
	    }
	  }
	  $mode = "";
	} elsif ($new_mode eq "quote") {
	  $mode = "quote";
	  # $open_tag = "<div class=\"quote\">\n";
	  # $close_tag = "</div>\n";
	} else {
	  die "Parse Error: <$new_mode>";
	}
      }
      $vspace = 0;
    } elsif ($s =~ /^\s*(\*\*?)\s*/) {
      my $c = $';
      my $m = $1;
      $c =~ s/\s+$//s;
      if ($m eq "*") {
      } else {
	my $sn = $sec_num++;
	my $ssn = "sec_${cn}_${sn}";
	die "Multiple SEC: $c" if exists $SEC{$c};
	$SEC{$c} = $ssn;
	push(@{$chap->{sections}}, $c);
	if ($c =~ /^コラム\s+/) {
	  $c = $';
	  die "Multiple SEC: $c" if exists $SEC{$c};
	  $SEC{$c} = $ssn;
	} elsif ($c =~ /\s+-\s+/) {
	  $c = $`;
	  die "Multiple SEC: $c" if exists $SEC{$c};
	  $SEC{$c} = $ssn;
	} elsif ($c =~ /\s+(抜粋)$/) {
	  $c = $`;
	  die "Multiple SEC: $c" if exists $SEC{$c};
	  $SEC{$c} = $ssn;
	}
      }
      $vspace = 0;
    } elsif ($s =~ /^\{\{([^\}]+)\}\}$/) {
      my $c = $1;
      if ($c =~ /^http/) {
      } else {
	die "Parse Error" if $c !~ /\.png$/s;
      }
      $vspace = 0;
    } else {
      if ($vspace > 1) {
      }
      $s =~ s/^\s+//s;
      if ($mode eq "pre") {
      } else {
      }
      $vspace = 0;
    }
  }
}


sub decorate_text {
  my ($chap, $sec, $s) = @_;
  my $r = "";
  while ($s =~ /\<b\>([^\<]*)<\/b\>/s) {
    my $pre = $`;
    my $c = $1;
    $s = $';
    $r .= decorate_text_2($chap, $sec, $pre);
    $r .= "\\textbf{" . decorate_text_2($chap, $sec, $c) . "}";
  }
  $r .= decorate_text_2($chap, $sec, $s);
  return $r;
}

sub decorate_text_2 {
  my ($chap, $sec, $s) = @_;
  my $r = "";

  while ($s =~ /\{\{([^\}]*)\}\}/s) {
    my $pre = $`;
    my $c = $1;
    $s = $';

    $r .= decorate_text_3($chap, $sec, $pre);
    if ($c =~ /^chapter:(.*)$/s) {
      if (exists $MARK_TO_CHAPTER{$1}) {
	if ($1 eq $chap->{mark}) {
	  $r .= "この章";
	} else {
	  $r .= "第$MARK_TO_CHAPTER{$1}->{number}章($1)";
	}
      } else {
	die "No chapter mark: $1";
      }
    } elsif ($c =~ /^ruby:([^\:]*):/s) {
      my $rc = $1;
      my $rt = $';
      $rc = decorate_text_3($chap, $sec, $rc);
      $rt = decorate_text_3($chap, $sec, $rt);
      $r .= "\\ruby{$rc}{$rt}";
    } else {
      die "Parse Error" if $c !~ /\.png$/s;
      die "No option info: $c" if ! exists $GRAPHICX_OPTION{$c};
      $r .= "\\includegraphics[$GRAPHICX_OPTION{$c}]{$c}";
    }
  }
  $r .= decorate_text_3($chap, $sec, $s);
  return $r;
}

sub decorate_text_3 {
  my ($chap, $sec, $s) = @_;
  my $r = "";

  while ($s =~ /([《『])(nc\:)?([^《》『』]*)([》』])/s) {
    my $pre = $`;
    my $ob = $1;
    my $nc = $2;
    my $c = $3;
    my $cb = $4;
    $s = $';
    my $cp = decorate_text_3b($c);
    $r .= decorate_text_3b($pre);
    if ($ob eq "《" and $cb eq "》" && exists $SEC{$c}) {
      if ($nc) {
	$r .= "${ob}\\hyperlink{$SEC{$c}}{$cp}${cb}";
      } else {
	my $ssn = $SEC{$c};
	if ($ssn !~ /^sec_([01-9]+)_/) {
	  die "Parse Error: $ssn";
	}
	my $ch1 = $CHAP[$1];
	my $chnum = $ch1->{number};
	my $chmark = $ch1->{mark};
	if ($chmark eq $chap->{mark}) {
	  $r .= "この章の${ob}\\hyperlink{$SEC{$c}}{$cp}${cb}";
	} else {
	  $r .= "第${chnum}章(${chmark})${ob}\\hyperlink{$SEC{$c}}{$cp}${cb}";
	}
      }
    } elsif (exists $REF{$c}) {
      my $rid = $REF{$c};
      if (! exists $REFED{$rid}) {
	push(@REFED, $rid);
	$REFED{$rid} = scalar(@REFED);
      }
      $r .= "${ob}\\hyperlink{$rid}{$cp}${cb}";
    } else {
      if ($c =~ / [01-9]+$/ && exists $REF{$`}) {
	my $rid = $REF{$`};
	if (! exists $REFED{$rid}) {
	  push(@REFED, $rid);
	  $REFED{$rid} = scalar(@REFED);
	}
	$r .= "${ob}\\hyperlink{$rid}{$cp}${cb}";
      } else {
	if (! exists $NO_REF_OK{$c} && ! exists $SEC{$c}
	    && ! (defined $sec && exists $NO_REF_OK_SEC{$sec})) {
	  warn "No ref or sec for: $c\n";
	}
	$r .= "${ob}$cp${cb}";
      }
    }
  }
  $r .= decorate_text_3b($s);
  return $r;
}

sub decorate_text_3b {
  my ($s) = @_;
  my $r = "";

  while ($s =~ /\[([^\]\[]*)\]/s) {
    my $pre = $`;
    my $rt = $1;
    $s = $';
    if (length($pre) > 0 && is_kanji(substr($pre, -1))) {
      my $rc = substr($pre, -1);
      $pre = substr($pre, 0, length($pre) - 1);
      while (length($pre) > 0 && is_kanji(substr($pre, -1))) {
	$rc = substr($pre, -1) . $rc;
	$pre = substr($pre, 0, length($pre) - 1);
      }
      $pre = decorate_text_4($pre);
      $rc = decorate_text_4($rc);
      if ($rt eq "") {
	$r .= $pre . $rc;
      } else {
	$rt = decorate_text_4($rt);
	$r .= $pre . "\\ruby{$rc}{$rt}";
      }
    } else {
      warn "ruby error : $rt";
      $r .= decorate_text_4($pre) . "[" . decorate_text_4($rt) . "]";
    }
  }
  $r .= decorate_text_4($s);
  return $r;
}

sub decorate_text_4 {
  my ($s) = @_;
  my $r = "";
  while ($s =~ /[\x{300}-\x{3ff}\x{1F00}-\x{1FFF}][ \x{300}-\x{3ff}\x{1F00}-\x{1FFF}]*/
	 && length($&) >= $GREEK_LENGTH) {
    my $pre = $`;
    my $c = $&;
    $s = $';
    $r .= decorate_text_5($pre);
    print "greek: $&\n";
    $r .= "\\greek{$c}";
  }
  $r .= decorate_text_5($s);
  return $r;
}

sub decorate_text_5 {
  my ($s) = @_;
  return escape_tex($s);
}

sub print_ref {
  my ($ofh, $chap) = @_;
  print "第$chap->{number}章 $chap->{title} ($chap->{mark})\n";
  my $vspace = 0;
  my $mode = "";
  my $close_tag = "";
  my $open_tag = "";
  my $c;
  if (grep {$chap->{title} eq $_} ("はじめに", "あとがき", "参考文献")) {
    $c = $chap->{title};
  } else {
    die "Print Error: $chap->{title}";
  }
  $c = escape_tex($c);
  print $ofh <<"EOT";
\\cleardoublepage
\\phantomsection
\\addcontentsline{toc}{chapter}{$c}
\\chapter*{$c}
\\chaptermark{$c}
\\thispagestyle{mystylefoot}
EOT
  $vspace = -1;

  my $s = $chap->{text};
  $s =~ s/^\s+//s;
  $s =~ s/^\s+$//s;
  my @l = split(/\n/, $s);
  while (@l) {
    my $s = shift(@l);
    if ($s =~ /^\s*$/s) {
      $vspace++;
      next;
    }
    if ($s =~ /^\s*\<(\/)?([^\>]+)\>\s*$/s) {
      die "Parse Error.";
    } elsif ($s =~ /^\s*(\*\*?)\s*/) {
      my $c = $';
      my $m = $1;
      if ($m eq "*") {
	print $ofh "\\subsection*{● $c}\n";
      } else {
	print $ofh "\\section{$c}\n";
      }
      $vspace = 0;
    } elsif ($s =~ /^\『([^\』]+)\』\s*\(([^\)]+)\)$/) {
      my $title = $1;
      my $info = $2;
      while (@l) {
	my $s2 = shift(@l);
	if ($s2 =~ /^\s*$/s) {
	  last;
	}
	if ($s2 !~ /^(https?\:[^\s]+)/) {
	  die "Parse Error: $s2";
	}
	my $url = $1;
	my $rest = $';
	my $add = "";
	if ($rest =~ /^\s*(\([^\)]+\))/) {
	  $add = $1;
	}
	my $dom;
	if ($url =~ /^https?\:\/\/www\.amazon\.co\.jp\//) {
	  $dom = "Amazon";
	} elsif ($url =~ /^https?\:\/\/www\.amazon\.com\//) {
	  $dom = "Amazon";
	} elsif ($url =~ /^https?\:\/\/kakuyomu\.jp\//) {
	  $dom = "Kakuyomu";
	} elsif ($url =~ /^https?\:\/\/7net\.omni7\.jp\//) {
	  $dom = "7net";
	} elsif ($url =~ /^https?\:\/\/bookwalker\.jp\//) {
	  $dom = "{\\BOOKWALKER}";
	} elsif ($url =~ /^https?\:\/\/[^\.]+\.booth\.pm\//) {
	  $dom = "Booth";
	} else {
	  die "Parse Error: $url";
	}
	$url = escape_pc($url);
	$add = escape_tex($add);
	$info .= ", \\href{$url}{$dom}$add" if ! $NO_LINK;
      }
      my $rid = $REF{$title};
      $title = escape_tex($title);
      print $ofh "\\noindent『\\linkdest{$rid}$title』($info)\\par\n\\halflineskip\n";
      $vspace = 0;
    } elsif ($s =~ /^\《([^\》]+)\》\s*$/) {
      my $title = $1;
      my $urls = "";
      while (@l) {
	my $s2 = shift(@l);
	if ($s2 =~ /^\s*$/s) {
	  last;
	}
	if ($s2 !~ /^(https?\:[^\s]+)/) {
	  die "Parse Error: $s2";
	}
	my $url = $1;
	my $rest = $';
	my $add = "";
	if ($rest =~ /^\s*(\([^\)]+\))/) {
	  $add = " " . $1;
	}
	if ($urls ne "") {
	  $urls .= ",\\\\\n";
	}
	$url = escape_pc($url);
	$urls .= "\\url{$url}$add";
      }
      my $rid = $REF{$title};
      $title = escape_tex($title);
      print $ofh "\\noindent《\\linkdest{$rid}$title》\\\\\n$urls\\par\n\\halflineskip\n";
      $vspace = 0;
    } else {
      die "Parse Error: $s";
      if ($vspace > 1) {
	print $ofh <<"EOT";
\\onelineskip
EOT
      }
      $s =~ s/^\s+//s;
      num_check($s);
      $s = decorate_text($chap, undef, $s);
      print $ofh "<p>$s</p>\n";
      $vspace = 0;
    }
  }
}

sub print_chapter {
  my ($ofh, $chap) = @_;
  print "第$chap->{number}章 $chap->{title} ($chap->{mark})\n";

  my $vspace = 0;
  my $mode = "";
  my $close_tag = "";
  my $open_tag = "";
  my $sec;
  if (grep {$chap->{title} eq $_} ("はじめに", "あとがき", "参考文献")) {
    my $c = escape_tex($chap->{title});
    print $ofh <<"EOT";
\\cleardoublepage
\\phantomsection
\\addcontentsline{toc}{chapter}{$c}
\\chapter*{$c}
\\chaptermark{$c}
\\thispagestyle{mystylefoot}
EOT
  } else {
    my $c = escape_tex($chap->{title});
    my $m = escape_tex($chap->{mark});
    my $n = $chap->{number} - 1;
    my $n1 = $chap->{number};
    print $ofh <<"EOT";
\\setcounter{chapter}{$n}
\\chapter{$c}[$m]
\\chaptermark{第${n1}章 $c}
\\thispagestyle{mystylefoot}
EOT
  }
  $vspace = -1;

  my $s = $chap->{text};
  $s =~ s/^\s+//s;
  $s =~ s/^\s+$//s;
  my @l = split(/\n/, $s);
  while (@l) {
    my $s = shift(@l);
    if ($s =~ /^\s*$/s) {
      $vspace++;
      next;
    }
    if ($s =~ /^\s*\<(\/)?([^\>]+)\>\s*$/s) {
      my $closing = $1;
      my $new_mode = $2;
      if ($closing) {
	if ($mode eq $new_mode) {
	  print $ofh $close_tag;
	  $mode = "";
	} else {
	  die "Parse Error: </$new_mode>";
	}
      } else {
	if ($new_mode eq "display") {
	  $mode = "display";
	  $open_tag = "\\begin{MyDisplay}\n";
	  $close_tag = "\\end{MyDisplay}\n";
	  print $ofh $open_tag;
	} elsif ($new_mode eq "list") {
	  $mode = "list";
	  $open_tag = "\\begin{MyList}\n";
	  $close_tag = "\\end{MyList}\n";
	  print $ofh $open_tag;
	} elsif ($new_mode eq "pre") {
	  $mode = "pre";
	  $open_tag = "\\begin{PreDisplay}\n";
	  $close_tag = "\\end{PreDisplay}\n";
	  print $ofh $open_tag;
	  while (@l) {
	    my $s2 = shift(@l);
	    if ($s2 =~ /^\s*<\/pre>\s*$/) {
	      print $ofh $close_tag;
	      last;
	    } else {
	      print $ofh "$s2\n";
	    }
	  }
	  $mode = "";
	} elsif ($new_mode eq "quote") {
	  $mode = "quote";
	  $open_tag = "\\begin{MyQuote}\n";
	  $close_tag = "\\end{MyQuote}\n";
	  print $ofh $open_tag;
	} else {
	  die "Parse Error: <$new_mode>";
	}
      }
      $vspace = 0;
    } elsif ($s =~ /^\s*(\*\*?)\s*/) {
      my $c = $';
      my $m = $1;
      $c =~ s/\s+$//s;
      if ($m eq "*") {
	print $ofh "\\subsection*{● $c}\n";
      } else {
	my $sid = $SEC{$c};
	$sec = $c;
	$c = escape_tex($c);
	print $ofh "\\hypertarget{$sid}{}%\n\\section{$c}\n";
      }
      $vspace = 0;
    } elsif ($s =~ /^\{\{([^\}]+)\}\}$/) {
      my $c = $1;
      if ($c =~ /^http/) {
	$c = escape_pc($c);
	print $ofh <<"EOT";
\\onelineskip
\\url{$c}
\\onelineskip
EOT
      } else {
	die "Parse Error" if $c !~ /\.png$/s;
	die "No option: $c" if ! exists $GRAPHICX_OPTION{$c};
	
	print $ofh <<"EOT";
\\begin{center}
\\includegraphics[$GRAPHICX_OPTION{$c}]{$c}
\\end{center}
EOT
      }
      $vspace = 0;
    } else {
      if ($vspace > 1) {
	print $ofh <<"EOT";
\\par\\onelineskip
EOT
      }
      $s =~ s/^\s+//s;
      num_check($s);
      $s = decorate_text($chap, $sec, $s);

      if ($mode eq "pre") {
	print $ofh "$s\n";
      } else {
	print $ofh "$s\\par\n";
      }
      $vspace = 0;
    }
  }
}


sub print_ref_summary {
  my () = @_;

  print "\n\n";

  my $chap;
  foreach my $c (@CHAP) {
    if ($c->{title} eq "参考文献") {
      $chap = $c;
    }
  }

  my $ref_num = 1;
  my $sec;
  my @sec;
  my $s = $chap->{text};
  $s =~ s/^\s+//s;
  $s =~ s/^\s+$//s;
  my @l = split(/\n/, $s);
  while (@l) {
    my $s = shift(@l);
    if ($s =~ /^\s*$/s) {
      next;
    }
    if ($s =~ /^\s*\<(\/)?([^\>]+)\>\s*$/s) {
      die "Parse Error.";
    } elsif ($s =~ /^\s*(\*\*?)\s*/) {
      my $new_sec = $';
      if (defined $sec) {
	my @ssec = sort {$REFED{$a} <=> $REFED{$b}} @sec;
	print "* $sec\n\n";
	foreach my $rid (@ssec) {
	  print "$REF_TO_TITLE{$rid}\n";
	}
	print "\n";
      }
      $sec = $new_sec;
      @sec = ();
    } elsif ($s =~ /^\『([^\』]+)\』\s*\(([^\)]+)\)$/) {
      my $title = $1;
      my $info = $2;
      while (@l) {
	my $s2 = shift(@l);
	if ($s2 =~ /^\s*$/s) {
	  last;
	}
	if ($s2 !~ /^(https?\:[^\s]+)/) {
	  die "Parse Error: $s2";
	}
	my $url = $1;
	if ($url =~ /^https?\:\/\/www\.amazon\.co\.jp\//) {
	} elsif ($url =~ /^https?\:\/\/www\.amazon\.com\//) {
	} elsif ($url =~ /^https?\:\/\/kakuyomu\.jp\//) {
	} elsif ($url =~ /^https?\:\/\/7net\.omni7\.jp\//) {
	} elsif ($url =~ /^https?\:\/\/bookwalker\.jp\//) {
	} elsif ($url =~ /^https?\:\/\/[^\.]+\.booth\.pm\//) {
	} else {
	  die "Parse Error: $url";
	}
      }
      my $rid = $REF{$title};
      push(@sec, $rid);
      if (! exists $REFED{$rid}) {
	push(@REFED, $rid);
	$REFED{$rid} = scalar(@REFED);
      }
    } elsif ($s =~ /^\《([^\》]+)\》\s*$/) {
      my $title = $1;
      my $urls = "";
      while (@l) {
	my $s2 = shift(@l);
	if ($s2 =~ /^\s*$/s) {
	  last;
	}
	if ($s2 !~ /^(https?\:[^\s]+)/) {
	  die "Parse Error: $s2";
	}
      }
      my $rid = $REF{$title};
      push(@sec, $rid);
      if (! exists $REFED{$rid}) {
	push(@REFED, $rid);
	$REFED{$rid} = scalar(@REFED);
      }
    } else {
      die "Parse Error: $s";
    }
  }
  my @ssec = sort {$REFED{$a} <=> $REFED{$b}} @sec;
  print "* $sec\n\n";
  foreach my $rid (@ssec) {
    print "$REF_TO_TITLE{$rid}\n";
  }
  print "\n";
}


sub print_summary {
  my () = @_;
  print "\n\n";
  foreach my $chap (@CHAP) {
    print "第$chap->{number}章 $chap->{title} ($chap->{mark})\n\n";
    my $i = 0;
    foreach my $s (@{$chap->{sections}}) {
      if ($i != 0) {
	print " / ";
      }
      print "$s";
      $i++;
    }
    print "\n\n";
  }
}


sub print_top {
  my ($ofh) = @_;

  my $ver = "";
  if (defined $SAMPLE_TITLE) {
    $ver = "\\\\\n$SAMPLE_TITLE";
  }

  print $ofh <<'EOT';
% for lualatex
% generated by make_tex.pl
\documentclass[paper=a5,book]{jlreq}
\usepackage{graphicx,xcolor}
\usepackage{luatexja-ruby}
\usepackage{luatexja-fontspec}
%\usepackage{luatexja-preset}
%\usepackage{mdframed}
\usepackage[most]{tcolorbox}
EOT
  if ($AMAZON_POD) {
    print $ofh <<"EOT";
\\usepackage[top=20truemm,bottom=12truemm,%
            inner=${INNER_MARGIN}truemm,outer=${OUTER_MARGIN}truemm,footskip=0truemm]{geometry}
EOT
  } else {
    my $margin = ($INNER_MARGIN + $OUTER_MARGIN) / 2;
    print $ofh <<"EOT";
\\usepackage[top=20truemm,bottom=12truemm,%
            inner=${margin}truemm,outer=${margin}truemm,footskip=0truemm]{geometry}
EOT
  }
  print $ofh <<'EOT';
\usepackage{titletoc}
\usepackage{fancybox}
\usepackage{titleps}
%\usepackage{fontspec}

\usepackage{bookmark}
\usepackage{xurl}
EOT
  if ($AMAZON_POD) {
    print $ofh <<'EOT';
\hypersetup{unicode,bookmarksnumbered=true,colorlinks=true,linkcolor=black,urlcolor=black,final}
EOT
  } else {
    print $ofh <<'EOT';
\hypersetup{unicode,bookmarksnumbered=true,colorlinks=true,linkcolor=teal,urlcolor=blue,final}
EOT
  }
  print $ofh <<'EOT';
\renewcommand{\thesection}{■}
\renewcommand{\thesubsection}{}
%\setlength{\parindent}{0pt}
\newcommand{\sectionskip}{\vspace{3\baselineskip}}
\newcommand{\onelineskip}{\vspace{\baselineskip}}
\newcommand{\halflineskip}{\vspace{0.5\baselineskip}}

\renewcommand{\jlreqxkanjiskip}{0.1\zw minus 0.1\zw}

% ギリシャ語に和文フォントを使わない。
%\ltjsetparameter{jacharrange={-2}}
%\setmainfont{TeX Gyre Pagella X}
%\setmainjfont{HaranoAji Mincho}
\newcommand{\greek}[1]{{\ltjsetparameter{jacharrange={-2}}\fontspec{TeX Gyre Pagella X}#1}}

\newcommand{\BOOKWALKER}{{\ltjsetparameter{autoxspacing=false}BOOK☆WALKER}}

\makeatletter
\newcommand{\linkdest}[1]{\Hy@raisedlink{\hypertarget{#1}{}}}
\makeatother

\newlength{\normalparindent}
\setlength{\normalparindent}{\parindent}

\makeatletter
\newcommand{\indentformdenv}{%
  \patchcmd\mdf@lrbox{\parindent\z@}{\parindent\normalparindent\relax}{}{}%
  \patchcmd\mdf@trivlist{\itemindent\z@}{\itemindent\normalparindent}{}{}%
}
\makeatother

\newcommand{\envtopskip}{0.85\topskip}
\newcommand{\envbotskip}{0.85\topskip}

% \newmdenv[skipabove=\envtopskip,skipbelow=\envbotskip,%
%           innertopmargin=0,innerbottommargin=0,%
%           innerleftmargin=0.5\zw,innerrightmargin=0,%
%           linecolor=gray,linewidth=3pt,%
%           leftmargin=0\zw,rightmargin=1\zw,%
% 	  rightline=false,topline=false,bottomline=false%
% ]{MyQuote}
% %\newenvironment{MyQuote}{\begin{PreMyQuote}\indent}{\end{PreMyQuote}}
% \patchcmd{\MyQuote}{\begin}{\indentformdenv\begin}{}{}

% \newmdenv[skipabove=\envtopskip,skipbelow=\envbotskip,%
%           innertopmargin=0,innerbottommargin=0,%
%           innerleftmargin=1.2\zw,innerrightmargin=1.2\zw,%
%           linecolor=gray,linewidth=3pt,%
%           leftmargin=0\zw,rightmargin=0\zw,%
% 	  rightline=false,topline=false,bottomline=false,leftline=false%
% ]{PreMyList}
% \newenvironment{MyList}{%
%   \begin{PreMyList}\setlength{\parindent}{0pt}%
% }{%
%   \end{PreMyList}%
% }

% \newmdenv[skipabove=\envtopskip,skipbelow=\envbotskip,%
%           innertopmargin=0,innerbottommargin=0,%
%           innerleftmargin=1.2\zw,innerrightmargin=1.2\zw,%
%           linecolor=gray,linewidth=3pt,%
%           leftmargin=0\zw,rightmargin=0\zw,%
% 	  rightline=false,topline=false,bottomline=false,leftline=false%
% ]{MyDisplay}
% \patchcmd{\MyDisplay}{\begin}{\indentformdenv\begin}{}{}

\newtcolorbox{MyQuote}{breakable,enhanced,colback=white,%
left=0.5\zw,right=0pt,top=0pt,bottom=0pt,%
sharp corners,boxrule=0pt,frame hidden,borderline west={3pt}{0pt}{gray},%
before skip=\envtopskip,after skip=\envbotskip,
before upper=\parindent\normalparindent%
}

\newtcolorbox{PreMyList}{breakable,enhanced,colback=white,%
left=1.2\zw,right=1.2\zw,top=0pt,bottom=0pt,%
sharp corners,boxrule=0pt,frame hidden,%
before skip=\envtopskip,after skip=\envbotskip%
}
\newenvironment{MyList}{%
  \begin{PreMyList}\setlength{\parindent}{0pt}%
}{%
  \end{PreMyList}%
}

\newtcolorbox{MyDisplay}{breakable,enhanced,colback=white,%
left=1.2\zw,right=1.2\zw,top=0pt,bottom=0pt,%
sharp corners,boxrule=0pt,frame hidden,%
before skip=\envtopskip,after skip=\envbotskip,%
before upper=\parindent\normalparindent%
}

\newenvironment{absolutelynopagebreak}
  {\par\nobreak\vfil\penalty0\vfilneg
   \vtop\bgroup}
  {\par\xdef\tpd{\the\prevdepth}\egroup
   \prevdepth=\tpd}

{\catcode`\ =12\gdef\ttspace{{\texttt }}}
\def\VerbatimFont{\ttfamily}

\newenvironment{PreDisplay}{\VerbatimEnvironment
\begin{samepage}\begin{PreMyList}\begin{Verbatim}%
}{%
\end{Verbatim}\end{PreMyList}\end{samepage}}

\makeatletter
\ModifyHeading{chapter}{format={\centering
#1\\
\vspace{5mm}#2%
\jlreqHeadingSubtitle{\\
#3%
}%
%\vspace{20mm}%
},lines=6,subtitle_font={\normalsize\mdseries\rmfamily},subtitle_format={(#1)}}
%\ModifyHeading{section}{font={\jlreq@keepbaselineskip{\Large\sffamily\gtfamily\bfseries}},lines=3,after_label_space=1\jlreq@zw,second_heading_text_indent={-1\jlreq@zw,1\jlreq@zw},subtitle_font={\jlreq@keepbaselineskip{\normalsize}}}

%\ModifyHeading{subsection}{font={\jlreq@keepbaselineskip{\large\sffamily\gtfamily\bfseries}},lines=2,after_label_space=1\jlreq@zw,second_heading_text_indent={-1\jlreq@zw,1\jlreq@zw},subtitle_font={\jlreq@keepbaselineskip{\small}}}

\ModifyHeading{subsection}{font={\jlreq@keepbaselineskip{\normalsize\sffamily\gtfamily\bfseries}},lines=2,after_label_space=1\jlreq@zw,second_heading_text_indent={-1\jlreq@zw,1\jlreq@zw},subtitle_font={\jlreq@keepbaselineskip{\small}}}

%\ModifyHeading{subsubsection}{font={\jlreq@keepbaselineskip{\normalsize\sffamily\gtfamily\bfseries}},lines=1,before_lines=1,subtitle_break=false,after_label_space=1\jlreq@zw,second_heading_text_indent={-1\jlreq@zw,1\jlreq@zw},subtitle_font={\jlreq@keepbaselineskip{\scriptsize}}}
\makeatother

\contentsmargin{0pt}
\titlecontents{chapter}[0pt]
{\addvspace{3pt}\bfseries}
{\thecontentslabel{ }}
{}
{\dotfill\thecontentspage}

% \contentsmargin{0pt}
% \titlecontents{chapter}[2.8pc]
% {\addvspace{3pt}\bfseries}
% {\contentslabel[\thecontentslabel]{2.8pc}}
% {}
% {\dotfill\thecontentspage}

\titlecontents*{section}[1.8pc]
{}
{}
{}
{ \thecontentspage /}
[\ ][]

\titlecontents*{subsection}[1.8pc]
{\ }
{}
{}
{ (\thecontentspage)}
[\ ][]

\newpagestyle{mystyle}{
\sethead[\footnotesize{\thepage\quad\chaptertitle}][][]{}{}{\footnotesize{\thesection\ \sectiontitle\quad\thepage}}
%\setfoot{}{\footnotesize{\thepage}}{}
}

\newpagestyle{mystylefoot}{
%\setfoot{}{\footnotesize{\thepage}}{}
}

\pagestyle{mystyle}
EOT

  print $ofh <<"EOT";
\\title{$TITLE\\\\
\\large $SUBTITLE$ver}
\\date{$PUBLISH_DATE}
\\author{$AUTHOR 著}
\\newcommand{\\mycoverpng}{$COVER_PNG}

EOT
  if ($AMAZON_POD) {
    print $ofh <<'EOT';
\begin{document}
%
\maketitle
%
\tableofcontents
%
EOT
  } else {
    print $ofh <<'EOT';
\begin{document}
%
\thispagestyle{empty} % no page number here
\newgeometry{left=0mm, right=0mm, top=0mm, bottom=0mm} % use full page
%
\begin{figure}[p] % [p] Place it on a page containing only floats
\includegraphics[width=\pagewidth, height=\pageheight]{\mycoverpng}
\end{figure}
\restoregeometry % revert to the original geometry from now on
\cleardoublepage
%
\maketitle
%
\tableofcontents
%
EOT
  }
}


sub print_bottom {
  my ($ofh) = @_;

  my $ver = "";
  if (defined $SAMPLE_TITLE) {
    $ver = " $SAMPLE_TITLE";
  }

  print $ofh <<'EOT';
\clearpage

\thispagestyle{empty}

\makeatletter%
    \ifodd\c@page\else%
        \hbox{}\newpage\thispagestyle{empty}%
    \fi%
\makeatother

\vspace*{\fill} % *をつけるとページ先頭でも入る。

EOT

  print $ofh <<"EOT";
\\begin{flushleft}
    \\begin{tabular*}{\\textwidth}{\@{}l\@{\\extracolsep{\\fill}}}
        \\textrm{\\large $TITLE $SUBTITLE$ver} \\\\
        \\hline
        \\begin{tabular}{\@{\\extracolsep{\\fill}}r\@{年}r\@{月}r\@{日\\kern1.5\\zw}ll}
EOT
  for my $l (@PUBLISH_INFO) {
    my $date = $l->[0];
    my $han = $l->[1];
    if ($date !~ /^(\d+)年(\d+)月(\d+)日$/) {
      die "Date Parse Error: $date";
    }
    my $y = $1;
    my $m = $2;
    my $d = $3;
    print $ofh <<"EOT";
	     $y&$m&$d& $han & \\\\
EOT
  }
  my $el = "Electronically ";
  $el = "" if $AMAZON_POD;
  my $isbn = "";
  $isbn = "\n\\textrm{ISBN $ISBN}\\\\" if $AMAZON_POD;
  print $ofh <<"EOT";
        \\end{tabular}\\\\
        \\\\
        \\begin{tabular}{\@{}l\@{\\kern.5\\zw\\textbf{ }\\kern1\\zw}l}
            \\textbf{著者} & $AUTHOR \\\\
            \\textbf{出版者} & $PUBLISHER \\\\
	    \\noalign{\\vskip -1.5mm}
            & \\url{$PUBLISHER_LINK} \\\\
        \\end{tabular} \\\\
        \\hline
	\\footnotesize\\textrm{${el}Published in Japan.}\\\\$isbn
    \\end{tabular*}
\\end{flushleft}

\\end{document}
EOT
}

main($TXT, $OUTPUT);
