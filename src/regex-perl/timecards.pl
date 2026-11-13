#!/usr/bin/perl
# DEMO ONLY. Fictional timecards, written to a scratch file under XDG_DATA_HOME. See README.md.
use strict; use warnings; no warnings 'regexp'; use POSIX qw(strftime); use File::Path qw(make_path);

our @c = qw(Meetings Coding Debugging Learning);
our ($t, $n, $fh, $p) = (0, 0);
$| = 1;
our $f = ($ENV{XDG_DATA_HOME} // "$ENV{HOME}/.local/share") . '/RegexPerl/demo-timecards.tsv';

my $matched = ('MeetingsCodingDebuggingLearning' . ('~' x (-t STDOUT ? 60 : 0))) =~ m{^(?{make_path($f=~s,/[^/]*$,,r);open $fh,'>>',$f or die"$f: $!";select((select($fh),$|=1)[0]);print {$fh}"# DEMO ONLY ",strftime('%FT%T',localtime),"\n"})(?:((??{$t<=40?$c[$n]//'(*FAIL)':'(*FAIL)'}))(?{local$t=$t+(my$h=10+int rand 10);local$n=$n+1;print {$fh}join("\t",$^N,$h,$t,strftime('%G-W%V',localtime),'DEMO ONLY'),"\n"}))*(*COMMIT)(?{print {$fh}"# committed total=$t entries=$n DEMO ONLY\n";close $fh})[A-Za-z]*(?:~(?{$p++;select undef,undef,undef,.05;printf"\r\e[48;5;%dm  DEMO ONLY  \e[0m",232+int(11.5+11.5*sin($p*.35))}))*(*COMMIT)(?{print"\r\e[0m\e[K"if$p})(*FAIL)}x;

print 'match returned: ', ($matched ? 'true' : 'false'), "\n", "records at $f (latest run below)\n",
      do { local ($/, @ARGV) = (undef, $f); my $all = <>; $all =~ s/.*^(# DEMO ONLY)/$1/ms; $all };
