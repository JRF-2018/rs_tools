#!/usr/bin/perl
our $VERSION = "0.0.2"; # Time-stamp: <2025-02-05T16:11:21Z>

##
## 使い方: 
##
##   perl txt2epubhtml.pl sample.txt -o Section0001.xhtml
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
our $OUTPUT = "Section0001.xhtml";
our $SAMPLE_TITLE = undef;
our $SAMPLE_DEFAULT_TITLE = "(試用版)";
our $TITLE = "宗教学雑考集";
our $SUBTITLE = "易理・始源論・神義論";
our $PUBLISH_DATE = "2025年3月11日 第1.0版";
our @PUBLISH_INFO = (["2024年1月5日", "第0.8版"],
		     ["2025年3月11日", "第1.0版"],
		    );
our $AUTHOR = "JRF";
our $PUBLISHER = "ＪＲＦ電版";
our $PUBLISHER_LINK = "http://jrockford.s1010.xrea.com/epub/";

## $NUM_{PRE|POST}_CHARS は、数値を使うときのスペースに関して警告を出
## すときの判定に使う。
our $NUM_PRE_CHARS = "。、（）「」『』【】〜：・第巻表図／前億説約年暦月兆万×＞→";
our $NUM_POST_CHARS = "。、（）「」『』【】〜：・千万年日人ヶ月時分倍割歳期回条章兆億光年個つ本番世王等パ乗巻位×枚次種親面名段代《》→／℃．";
our $NUM_POST_CHARS_2 = "万年人ヶ月倍割歳期回条章年個つ";

## 「 -- 」は $EM_DASH に置換される。
#our $EM_DASH = "\x{2015}\x{2015}"; # HORIZONTAL_BAR
our $EM_DASH = "\x{2014}\x{2014}";

## ユーザーが定義すべきパラメータは以上。

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
my %NO_REF_OK_SEC;


Getopt::Long::Configure("no_ignore_case", "auto_version");
GetOptions(
	   "n|no-link" => \$NO_LINK,
	   "o|output=s" => \$OUTPUT,
	   "s|sample-title=s" => \$SAMPLE_TITLE,
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
  if ($TXT ne "main.txt") {
    $SAMPLE_TITLE = $SAMPLE_DEFAULT_TITLE;
  }
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
  $all = translate_emdash($all);
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
  my $close_tag = "";
  my $open_tag = "";
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
	  $open_tag = "<div class=\"display\">\n";
	  $close_tag = "</div>\n";
	} elsif ($new_mode eq "list") {
	  $mode = "list";
	  $open_tag = "<div class=\"list\">\n";
	  $close_tag = "</div>\n";
	} elsif ($new_mode eq "pre") {
	  $mode = "pre";
	  $open_tag = "<pre class=\"pre-display\">\n";
	  $close_tag = "</pre>\n";
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
	  $open_tag = "<div class=\"quote\">\n";
	  $close_tag = "</div>\n";
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
    $c = "第$chap->{number}章<br/>$chap->{title}<br/>($chap->{mark})";
  }
  #$c = escape_html($c);
  print $ofh <<"EOT";
<hr class="page-break" />
<h2>$c</h2>
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
	print $ofh "<h4>$c</h4>\n";
      } else {
	print $ofh "<h3>$c</h3>\n";
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
	  $dom = "BOOK☆WALKER";
	} elsif ($url =~ /^https?\:\/\/[^\.]+\.booth\.pm\//) {
	  $dom = "Booth";
	} else {
	  die "Parse Error: $url";
	}
	$info .= ", <a href=\"$url\">$dom</a>$add" if ! $NO_LINK;
      }
      my $rid = $REF{$title};
      print $ofh "<p id=\"$rid\" class=\"ref\">『$title』($info)</p>\n";
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
	  $urls .= ",<br/> ";
	}
	if ($NO_LINK) {
	  $urls .= "$url$add";
	} else {
	  $urls .= "<a href=\"$url\">$url</a>$add";
	}
      }
      my $rid = $REF{$title};
      print $ofh "<p id=\"$rid\" class=\"ref\">《$title》<br/>$urls</p>\n";
      $vspace = 0;
    } else {
      die "Parse Error: $s";
      if ($vspace > 1) {
	print $ofh <<"EOT";
<p class="vspace">&#160;</p>
EOT
      }
      $s =~ s/^\s+//s;
      num_check($s);
      $s = escape_html($s);
      $s =~ s/\&lt\;(\/)?b\&gt\;/<${1}b>/sg;
      $s =~ s(\{\{([^\}]*)\}\}){
	my $c = $1;
	if ($c =~ /^chapter:(.*)$/s) {
	  if (exists $MARK_TO_CHAPTER{$1}) {
	    if ($1 eq $chap->{mark}) {
	      "この章";
	    } else {
	      "第$MARK_TO_CHAPTER{$1}->{number}章($1)";
	    }
	  } else {
	    die "No chapter mark: $1";
	  }
	} else {
	  die "Parse Error" if $c !~ /\.png$/s;
	  <<"EOT";
<img class="small-img" alt="$c" src="../Images/$c" />
EOT
        }
      }sexg;
      my $c = $s;
      my $r = "";
      while ($c =~ /\[([^\]\[]*)\]/) {
	my $pre = $`;
	my $rt = $1;
	$c = $';
	if (length($pre) > 0 && is_kanji(substr($pre, -1))) {
	  my $rc = substr($pre, -1);
	  $pre = substr($pre, 0, length($pre) - 1);
	  while (length($pre) > 0 && is_kanji(substr($pre, -1))) {
	    $rc = substr($pre, -1) . $rc;
	    $pre = substr($pre, 0, length($pre) - 1);
	  }
	  if ($rt eq "") {
	    $r .= $pre . $rc;
	  } else {
	    $r .= $pre . "<ruby>$rc<rt>$rt</rt></ruby>";
	  }
	} else {
	  warn "ruby error : $rt";
	  $r .= $pre . "[" . $rt . "]";
	}
      }
      $r .= $c;

      $s = $r;
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
  my $c;
  if (grep {$chap->{title} eq $_} ("はじめに", "あとがき", "参考文献")) {
    $c = $chap->{title};
  } else {
    $c = "第$chap->{number}章<br/>$chap->{title}<br/>($chap->{mark})";
  }
  #$c = escape_html($c);
  print $ofh <<"EOT";
<hr class="page-break" />
<h2>$c</h2>
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
	  $open_tag = "<div class=\"display\">\n";
	  $close_tag = "</div>\n";
	  print $ofh $open_tag;
	} elsif ($new_mode eq "list") {
	  $mode = "list";
	  $open_tag = "<div class=\"list\">\n";
	  $close_tag = "</div>\n";
	  print $ofh $open_tag;
	} elsif ($new_mode eq "pre") {
	  $mode = "pre";
	  $open_tag = "<pre class=\"pre-display\">\n";
	  $close_tag = "</pre>\n";
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
	  $open_tag = "<div class=\"quote\">\n";
	  $close_tag = "</div>\n";
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
	print $ofh "<h4>$c</h4>\n";
      } else {
	my $sid = $SEC{$c};
	$sec = $c;
	print $ofh "<h3 id=\"$sid\">$c</h3>\n";
      }
      $vspace = 0;
    } elsif ($s =~ /^\{\{([^\}]+)\}\}$/) {
      my $c = $1;
      if ($c =~ /^http/) {
	print $ofh <<"EOT";
<p class="vspace">&#160;</p>
<p><a href="$c">$c</a></p>
<p class="vspace">&#160;</p>
EOT
      } else {
	die "Parse Error" if $c !~ /\.png$/s;
	print $ofh <<"EOT";
<img class="wide-img" alt="$c" src="../Images/$c" />
EOT
      }
      $vspace = 0;
    } else {
      if ($vspace > 1) {
	print $ofh <<"EOT";
<p class="vspace">&#160;</p>
EOT
      }
      $s =~ s/^\s+//s;
      num_check($s);
      $s = escape_html($s);
      $s =~ s/\&lt\;(\/?)b\&gt\;/<${1}b>/sg;
      $s =~ s(\{\{([^\}]*)\}\}){
	my $c = $1;
	if ($c =~ /^chapter:(.*)$/s) {
	  if (exists $MARK_TO_CHAPTER{$1}) {
	    if ($1 eq $chap->{mark}) {
	      "この章";
	    } else {
	      "第$MARK_TO_CHAPTER{$1}->{number}章($1)";
	    }
	  } else {
	    die "No chapter mark: $1";
	  }
	} elsif ($c =~ /^ruby:([^\:]*):/s) {
	  my $rc = $1;
	  my $rt = $';
	  "<ruby>$rc<rt>$rt</rt></ruby>";
	} else {
	  die "Parse Error: {{$c}}" if $c !~ /\.png$/s;
	  <<"EOT";
<img class="small-img" alt="$c" src="../Images/$c" />
EOT
        }
      }sexg;
      $s =~ s(([《『])(nc\:)?([^《》『』]*)([》』])){
	my $ob = $1;
	my $nc = $2;
	my $c = $3;
	my $cb = $4;
	if ($ob eq "《" and $cb eq "》" && exists $SEC{$c}) {
	  if ($nc) {
	    "${ob}<a href=\"#$SEC{$c}\">$c</a>${cb}";
	  } else {
	    my $ssn = $SEC{$c};
	    if ($ssn !~ /^sec_([01-9]+)_/) {
	      die "Parse Error: $ssn";
	    }
	    my $ch1 = $CHAP[$1];
	    my $chnum = $ch1->{number};
	    my $chmark = $ch1->{mark};
	    if ($chmark eq $chap->{mark}) {
	      "この章の${ob}<a href=\"#$SEC{$c}\">$c</a>${cb}";
	    } else {
	      "第${chnum}章(${chmark})${ob}<a href=\"#$SEC{$c}\">$c</a>${cb}";
	    }
	  }
	} elsif (exists $REF{$c}) {
	  my $rid = $REF{$c};
	  if (! exists $REFED{$rid}) {
	    push(@REFED, $rid);
	    $REFED{$rid} = scalar(@REFED);
	  }
	  "${ob}<a href=\"#$rid\">$c</a>${cb}";
	} else {
	  if ($c =~ / [01-9]+$/ && exists $REF{$`}) {
	    my $rid = $REF{$`};
	    if (! exists $REFED{$rid}) {
	      push(@REFED, $rid);
	      $REFED{$rid} = scalar(@REFED);
	    }
	    "${ob}<a href=\"#$rid\">$c</a>${cb}";
	  } else {
	    if (! exists $NO_REF_OK{$c} && ! exists $SEC{$c}
		&& ! (defined $sec && exists $NO_REF_OK_SEC{$sec})) {
	      warn "No ref or sec for: $c\n";
	    }
	    "${ob}$c${cb}";
	  }
	}
      }sexg;
      my $c = $s;
      my $r = "";
      while ($c =~ /\[([^\]\[]*)\]/) {
	my $pre = $`;
	my $rt = $1;
	$c = $';
	if (length($pre) > 0 && is_kanji(substr($pre, -1))) {
	  my $rc = substr($pre, -1);
	  $pre = substr($pre, 0, length($pre) - 1);
	  while (length($pre) > 0 && is_kanji(substr($pre, -1))) {
	    $rc = substr($pre, -1) . $rc;
	    $pre = substr($pre, 0, length($pre) - 1);
	  }
	  if ($rt eq "") {
	    $r .= $pre . $rc;
	  } else {
	    $r .= $pre . "<ruby>$rc<rt>$rt</rt></ruby>";
	  }
	} else {
	  warn "ruby error : $rt";
	  $r .= $pre . "[" . $rt . "]";
	}
      }
      $r .= $c;

      $s = $r;
      if ($mode eq "pre") {
	print $ofh "$s\n";
      } else {
	print $ofh "<p>$s</p>\n";
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
    $ver = "<br/>$SAMPLE_TITLE";
  }

  print $ofh <<"EOT";
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="ja">
<head>
  <link href="../Styles/Style0001.css" rel="stylesheet" title="横組" type="text/css"/>
  <title>$TITLE $SUBTITLE</title>
</head>

<body>
<div class="title-page">
  <div class="title-block">
  <h1>$TITLE<br/>$SUBTITLE$ver</h1>
  <p class="title-author">${AUTHOR} 著</p>
  <p class="title-date">${PUBLISH_DATE}</p>
  </div>
</div>

EOT
}


sub print_bottom {
  my ($ofh) = @_;

  my $ver = "";
  if (defined $SAMPLE_TITLE) {
    $ver = "<br/>$SAMPLE_TITLE";
  }

  print $ofh <<"EOT";
<div class="okuduke-page">
<div class="okuduke">
<p>$TITLE $SUBTITLE$ver</p>
<hr/>
<div class="okuduke-rireki">
EOT
  foreach my $l (@PUBLISH_INFO) {
    my ($date, $han) = @$l;
    print $ofh "<p>${date}　${han}</p>\n";
  }
  print $ofh <<"EOT";
</div>
<p>著　者　　${AUTHOR}</p>
<p>出版者　　${PUBLISHER}<br/>
EOT
  if ($NO_LINK) {
    print $ofh <<"EOT";
　　　　　<span class="okuduke-anchor">${PUBLISHER_LINK}</span></p>
EOT
  } else {
    print $ofh <<"EOT";
　　　　　<span class="okuduke-anchor"><a href="${PUBLISHER_LINK}">${PUBLISHER_LINK}</a></span></p>
EOT
  }
  print $ofh <<"EOT";
<hr/>
<div class="okuduke-okuri">
<p>Electronically Published in Japan.</p>
</div>
</div>
</div>

</body>
</html>
EOT
}

sub trash {
  my $ofh;
  my $fh;
  my $beg = 0;
  my $chapter = 1;
  my $vspace = 0;
  while (my $s = <$fh>) {
    $s =~ s/\s+$//s;
    if (! $beg && $s =~ /^X[X]\.\s*/) {
      $beg = 1;
    }
    if ($beg) {
      if ($s =~ /^\s*$/s) {
	$vspace++;
      } elsif ($s =~ /^XX\.\s*/) {
      } elsif ($s =~ /^X\.\s*/) {
	my $c = $';
	$c =~ s/\([^\(\)]*\)$//s;
	$c = escape_html($c);
	print $ofh <<"EOT";
<h3>$c</h3>
EOT
	$vspace = -1;
      } elsif ($s =~ /^\{\{([^\}]+)\}\}$/) {
	my $c = $1;
	if ($c =~ /^http/) {
	  print $ofh <<"EOT";
<p class="vspace">&#160;</p>
<p><a href="$c">$c</a></p>
<p class="vspace">&#160;</p>
EOT
	} else {
	  print $ofh <<"EOT";
<img class="wide-img" alt="$1" src="../Images/$1" />
EOT
	}
	$vspace = 0;
      } else {
	if ($vspace > 1) {
	  print $ofh <<"EOT";
<p class="vspace">&#160;</p>
EOT
	}
	num_check($s);
	$s = escape_html($s);
	$s =~ s(\{\{([^\}]*)\}\}){
	  my $c = $1;
	  die "Parse Error" if $c !~ /\.png$/s;
	  <<"EOT";
<img class="small-image" alt="$1" src="../Images/$c" />
EOT
}sexg;
	my $c = $s;
	my $r = "";
	while ($c =~ /\[([^\]\[]*)\]/) {
	  my $pre = $`;
	  my $rt = $1;
	  $c = $';
	  if (length($pre) > 0 && is_kanji(substr($pre, -1))) {
	    my $rc = substr($pre, -1);
	    $pre = substr($pre, 0, length($pre) - 1);
	    while (length($pre) > 0 && is_kanji(substr($pre, -1))) {
	      $rc = substr($pre, -1) . $rc;
	      $pre = substr($pre, 0, length($pre) - 1);
	    }
	    if ($rt eq "") {
	      $r .= $pre . $rc;
	    } else {
	      $r .= $pre . "<ruby>$rc<rt>$rt</rt></ruby>";
	    }
	  } else {
	    warn "ruby error : $rt";
	    $r .= $pre . "[" . $rt . "]";
	  }
	}
	$r .= $c;

	$s = $r;
	print $ofh <<"EOT";
<p>$s</p>
EOT
	$vspace = 0;
      }
    }
  }
  if ($beg) {
  }
}

main($TXT, $OUTPUT);

