#!/usr/bin/perl
# DEMO ONLY. Fictional timecards, written to a scratch file under XDG_DATA_HOME. See README.md.
use strict; use warnings; no warnings 'regexp'; use POSIX qw(strftime); use File::Path qw(make_path);

our @c = qw(Meetings Coding Debugging Learning);
our ($t, $n, $fh) = (0, 0);
our $f = ($ENV{XDG_DATA_HOME} // "$ENV{HOME}/.local/share") . '/RegexPerl/demo-timecards.tsv';

my $matched = 'MeetingsCodingDebuggingLearning' =~ m{^(?{make_path($f=~s,/[^/]*$,,r);open $fh,'>>',$f or die"$f: $!";select((select($fh),$|=1)[0]);print {$fh}"# DEMO ONLY ",strftime('%FT%T',localtime),"\n"})(?:((??{$t<=40?$c[$n]//'(*FAIL)':'(*FAIL)'}))(?{local$t=$t+(my$h=10+int rand 10);local$n=$n+1;print {$fh}join("\t",$^N,$h,$t,strftime('%G-W%V',localtime),'DEMO ONLY'),"\n"}))*(*COMMIT)(?{print {$fh}"# committed total=$t entries=$n DEMO ONLY\n";close $fh})(*FAIL)}x;

print 'match returned: ', ($matched ? 'true' : 'false'), "\n", "records at $f (latest run below)\n",
      do { local ($/, @ARGV) = (undef, $f); my $all = <>; $all =~ s/.*^(# DEMO ONLY)/$1/ms; $all };
