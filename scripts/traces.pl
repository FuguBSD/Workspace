#!/usr/bin/env perl
# traces.pl — measure the Claude Code sessions of this checkout.
#
#     traces.pl [--root DIR] [--name NAME]
#
# Claude Code keeps one trace directory for each working directory,
# under ~/.claude/projects/. The name of the directory is the absolute
# path of the working directory, with each character that is not a
# letter, a digit or a hyphen replaced by a hyphen. This program
# derives the name of the main checkout from the path of this file,
# matches the trace directories of that checkout, and prints one line
# for each session in them (WS-SESSION-5).
#
# The derivation cuts the path at the last .claude/worktrees/ marker,
# because a nested checkout holds the marker more than one time
# (WS-HOOKS-4). Three name forms belong to one checkout: the checkout
# itself, a worktree of it, and a project clone in either of them. The
# match takes the exact forms only, so a sibling checkout, such as a
# backup, stays out (WS-SESSION-6).
#
# The option --root names a trace root in place of ~/.claude/projects/,
# and --name replaces the derived name. The tests use both.
#
# The columns are:
#
#     session  the first eight characters of the session identifier
#     start    the time of the first record of the session, in UTC
#     reqs     the requests of the main session
#     peak     the largest context of one request: the fresh input
#              tokens, the cache writes and the cache reads
#     out      the output tokens of the main session, thinking
#              included
#     panel    the rounds of the review panel
#     edits    the file edits of the main session after the first
#              panel launch
#     sub-in   the input tokens of every sub-agent of the session
#     sub-out  the output tokens of every sub-agent
#
# One request writes one record for each content block, and each
# record carries the usage of the whole request. An early record can
# carry a partial count, so this program takes the usage of the last
# record of a request (WS-SESSION-7). A tool_use block appears in one
# record only, so each block counts one time.
#
# Exit codes: 0 = success, 2 = usage error, other values = failure.

use v5.36;

use Cwd            qw(abs_path);
use File::Basename qw(basename dirname);
use File::Spec     ();
use Getopt::Long   qw(GetOptions);
use JSON::PP       ();

my $prog   = 'traces.pl';
my $MARKER = '/.claude/worktrees/';
my $ROW    = "%-8s  %-16s  %6s  %8s  %8s  %6s  %6s  %10s  %10s\n";

# The tools that change a file. The panel reviews a commit, so an edit
# of the main session after the first launch of a round is an edit
# that no reviewer saw.
my %EDIT = map { $_ => 1 } qw(Edit Write MultiEdit NotebookEdit);

# The tools that launch a sub-agent.
my %LAUNCH = map { $_ => 1 } qw(Agent Task);

my $JSON = JSON::PP->new;

main();

sub main () {
    my ($root, $name);
    GetOptions('root=s' => \$root, 'name=s' => \$name) or usage();
    usage() if @ARGV;
    $root //= ($ENV{HOME} // '.') . '/.claude/projects';
    $name //= trace_name();
    die "$prog: no such trace root: $root\n" unless -d $root;

    my @rows;
    push @rows, sessions("$root/$_") for trace_dirs($root, $name);
    unless (@rows) {
        say "no session of $name";
        return;
    }

    printf $ROW, qw(session start reqs peak out panel edits sub-in sub-out);
    for my $row (sort { $a->{start} cmp $b->{start} } @rows) {
        printf $ROW, substr($row->{id}, 0, 8), substr($row->{start}, 0, 16),
            $row->{reqs}, $row->{peak}, $row->{out}, $row->{panel},
            $row->{edits}, $row->{sub_in}, $row->{sub_out};
    }
}

# The trace directory name of the main checkout that holds this file.
sub trace_name () {
    my $me = File::Spec->rel2abs(__FILE__);
    my $checkout = abs_path(dirname(dirname($me)))
        or die "$prog: cannot resolve $me\n";
    my $at = rindex($checkout, $MARKER);
    $checkout = substr($checkout, 0, $at) if $at >= 0;
    return $checkout =~ s/[^A-Za-z0-9-]/-/gr;
}

# The trace directories of one checkout: the checkout itself, each
# worktree of it, and each project clone in either of them.
sub trace_dirs ($root, $name) {
    my $token = qr/[A-Za-z0-9-]+/;
    my $re = qr{
        ^\Q$name\E
        (?:--claude-worktrees-$token)?
        (?:-Projects-$token)?
        \z
    }x;
    opendir my $dh, $root or die "$prog: opendir $root: $!\n";
    my @names = sort grep { /$re/ && -d "$root/$_" } readdir $dh;
    closedir $dh;
    return @names;
}

# One row for each session of one trace directory. A session with no
# request never reached the model, so it gets no row.
sub sessions ($dir) {
    my @rows;
    for my $path (jsonl($dir)) {
        my $row = tally($path);
        next unless $row->{reqs};
        my $id = basename($path) =~ s/\.jsonl\z//r;

        # A sub-agent of a workflow gets a directory of its own.
        my $sub = "$dir/$id/subagents";
        my ($in, $out) = (0, 0);
        for my $file (jsonl($sub), map { jsonl($_) }
            subdirs("$sub/workflows"))
        {
            my $agent = tally($file);
            $in  += $agent->{in};
            $out += $agent->{out};
        }

        @{$row}{qw(id sub_in sub_out)} = ($id, $in, $out);
        push @rows, $row;
    }
    return @rows;
}

# The measures of one trace file.
sub tally ($path) {
    my %row = (start => '', reqs => 0, peak => 0, in => 0, out => 0,
        panel => 0, edits => 0);
    open my $fh, '<:encoding(UTF-8)', $path or return \%row;

    my (%usage, @order, %round);
    my $launched = 0;
    while (my $line = <$fh>) {
        my $rec;

        # The start time comes from the first record that carries one,
        # whatever its type.
        if (!length $row{start}) {
            $rec = eval { $JSON->decode($line) };
            $row{start} = $rec->{timestamp} // '' if ref $rec eq 'HASH';
        }

        # A full parse of every record costs minutes over a long
        # history. Only an assistant record carries a usage block or a
        # tool_use block, and every one of them holds the word.
        $rec = eval { $JSON->decode($line) }
            if !defined $rec && index($line, 'assistant') >= 0;
        next unless ref $rec eq 'HASH' && ($rec->{type} // '') eq 'assistant';

        # An old trace carries no requestId. Its records then count
        # one by one, which is the safe direction.
        my $req = $rec->{requestId} // $rec->{uuid} // '';
        push @order, $req unless exists $usage{$req};
        $usage{$req} = usage_of($rec);

        for my $block (@{ $rec->{message}{content} // [] }) {
            next unless ($block->{type} // '') eq 'tool_use';
            if (is_panel($block)) {
                $launched = 1;
                $round{$req} = 1;
            } elsif ($launched && $EDIT{ $block->{name} // '' }) {
                $row{edits}++;
            }
        }
    }
    close $fh;

    for my $req (@order) {
        my ($in, $out) = @{ $usage{$req} };
        $row{in}  += $in;
        $row{out} += $out;
        $row{peak} = $in if $in > $row{peak};
    }
    $row{reqs}  = scalar @order;
    $row{panel} = scalar keys %round;
    return \%row;
}

# The context and the output of one request. The context is the input
# that the request paid for: the fresh input, the cache writes and the
# cache reads.
sub usage_of ($rec) {
    my $u = $rec->{message}{usage} // {};
    my $in = ($u->{input_tokens} // 0)
        + ($u->{cache_creation_input_tokens} // 0)
        + ($u->{cache_read_input_tokens} // 0);
    return [$in, $u->{output_tokens} // 0];
}

# One launch of one panel member. The panel dispatches a reviewer
# agent, and the description of each member names the panel.
sub is_panel ($block) {
    return 0 unless $LAUNCH{ $block->{name} // '' };
    my $input = $block->{input} // {};
    return 1 if ($input->{subagent_type} // '') eq 'reviewer';
    return ($input->{description} // '') =~ /panel/i ? 1 : 0;
}

# The trace files directly in one directory. A directory that is
# absent holds none.
sub jsonl ($dir) {
    opendir my $dh, $dir or return ();
    my @names = sort grep { /\.jsonl\z/ && -f "$dir/$_" } readdir $dh;
    closedir $dh;
    return map { "$dir/$_" } @names;
}

# The subdirectories of one directory.
sub subdirs ($dir) {
    opendir my $dh, $dir or return ();
    my @names = sort grep { !/^\./ && -d "$dir/$_" } readdir $dh;
    closedir $dh;
    return map { "$dir/$_" } @names;
}

sub usage () {
    print STDERR "usage: $prog [--root DIR] [--name NAME]\n";
    exit 2;
}
