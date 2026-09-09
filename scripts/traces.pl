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
# for each session in them that holds a request (WS-SESSION-5).
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
#              panel launch: a file inside the checkout, outside
#              scratch/ and SCRATCHPAD*.md
#     sub-in   the input tokens of every sub-agent of the session
#     sub-out  the output tokens of every sub-agent
#     rev-peak the largest peak context of one panel reviewer
#
# One request writes one record for each content block, and each
# record carries the usage of the whole request. An early record can
# carry a partial count, so this program takes the usage of the last
# record of a request (WS-SESSION-7). A tool_use block appears in one
# record only, so each block counts one time.
#
# The sub-in and sub-out columns hold every sub-agent together, so
# neither one measures one reviewer. A panel launch is a tool_use
# block with an identifier, and each sub-agent trace has a sibling
# <agent>.meta.json that carries the identifier of its launch. The
# rev-peak column maps the launch identifiers of the panel to their
# traces, and it reports the largest peak of them (WS-SESSION-8).
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
my $ROW    = "%-8s  %-16s  %6s  %8s  %8s  %6s  %6s  %10s  %10s  %8s\n";

# The tools that change a file. The panel reviews a commit, so an edit
# of the main session after the first launch of a round is an edit
# that no reviewer saw. Only a repository file of the measured
# checkout is one (WS-SESSION-8). A write outside the checkout is no
# repository file: the operator HOME, a dotfile and another project
# all sit outside it. A write to scratch space is no repository file
# either: the panel writes its ledger under scratch/, an audit writes
# its findings to a SCRATCHPAD-<N>.md file, and .gitignore holds both.
my %EDIT = map { $_ => 1 } qw(Edit Write MultiEdit NotebookEdit);
my $SCRATCH = qr{(?:\A|/)(?:scratch/|SCRATCHPAD[^/]*\.md\z)};

# The tools that launch a sub-agent.
my %LAUNCH = map { $_ => 1 } qw(Agent Task);

# The agent types that name no role. A launch of one of them holds the
# role of the agent in its description only.
my %CATCHALL = map { $_ => 1 } qw(general-purpose claude);

# The main checkout that holds this file. The trace name comes from
# the path, and the edits column takes a file inside the path only,
# so the program derives it one time.
my $CHECKOUT = checkout();

my $JSON = JSON::PP->new;

main();

sub main () {
    my ($root, $name);
    GetOptions('root=s' => \$root, 'name=s' => \$name) or usage();
    usage() if @ARGV;
    $root //= ($ENV{HOME} // '.') . '/.claude/projects';
    $name //= trace_name($CHECKOUT);
    die "$prog: no such trace root: $root\n" unless -d $root;

    my @rows;
    push @rows, sessions("$root/$_") for trace_dirs($root, $name);
    unless (@rows) {
        say "no session of $name";
        return;
    }

    printf $ROW,
        qw(session start reqs peak out panel edits sub-in sub-out rev-peak);
    for my $row (sort { $a->{start} cmp $b->{start} } @rows) {
        printf $ROW, substr($row->{id}, 0, 8), substr($row->{start}, 0, 16),
            $row->{reqs}, $row->{peak}, $row->{out}, $row->{panel},
            $row->{edits}, $row->{sub_in}, $row->{sub_out},
            $row->{rev_peak};
    }
}

# The path of the main checkout that holds this file. The derivation
# cuts the path at the last .claude/worktrees/ marker (WS-HOOKS-4).
sub checkout () {
    my $me   = File::Spec->rel2abs(__FILE__);
    my $path = abs_path(dirname(dirname($me)))
        or die "$prog: cannot resolve $me\n";
    my $at = rindex($path, $MARKER);
    return $at >= 0 ? substr($path, 0, $at) : $path;
}

# The trace directory name of one checkout path: each character that
# is not a letter, a digit or a hyphen becomes a hyphen.
sub trace_name ($path) {
    return $path =~ s/[^A-Za-z0-9-]/-/gr;
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

        # A sub-agent of a workflow gets a directory of its own. The
        # launch identifiers of the panel select the reviewers among
        # them, so rev-peak takes the largest peak of one reviewer.
        my $sub = "$dir/$id/subagents";
        my ($in, $out, $rev) = (0, 0, 0);
        for my $file (jsonl($sub), map { jsonl($_) }
            subdirs("$sub/workflows"))
        {
            my $agent = tally($file);
            $in  += $agent->{in};
            $out += $agent->{out};
            $rev = $agent->{peak}
                if $agent->{peak} > $rev
                && $row->{launches}{ meta_id($file) };
        }

        @{$row}{qw(id sub_in sub_out rev_peak)} = ($id, $in, $out, $rev);
        push @rows, $row;
    }
    return @rows;
}

# The measures of one trace file.
sub tally ($path) {
    my %row = (start => '', reqs => 0, peak => 0, in => 0, out => 0,
        panel => 0, edits => 0, launches => {});
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
                $row{launches}{ $block->{id} } = 1
                    if length($block->{id} // '');
            } elsif ($launched && $EDIT{ $block->{name} // '' }) {
                $row{edits}++ if repo_edit($block);
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

# True when one edit block changes a repository file. The target is
# file_path, or notebook_path for a notebook.
#
# An absolute target must sit inside the checkout, on a directory
# boundary, so a write to the operator HOME, or to a sibling such as
# <checkout>-backup, is no repository file. A relative target sits
# inside it, because the path resolves against the working directory
# of the session. A block with no target counts as an edit, which is
# the safe direction.
#
# A target in scratch space is no repository file: a path under
# scratch/, or a SCRATCHPAD*.md file. The name must start a path
# segment and the scratchpad must end the path, so myscratch/x.md,
# NOTSCRATCHPAD.md and SCRATCHPAD-3.md.bak stay edits.
sub repo_edit ($block) {
    my $input = $block->{input} // {};
    my $path  = $input->{file_path} // $input->{notebook_path} // '';
    return 0 if $path =~ m{\A/} && index($path, "$CHECKOUT/") != 0;
    return $path =~ $SCRATCH ? 0 : 1;
}

# One launch of one panel member. The type of the agent decides
# first: a reviewer is a member, and another role, such as a fixer, is
# not one. A catch-all type and an absent type name no role, so the
# description decides. The panel of an early session dispatched a
# catch-all agent, and the description of each member names the panel.
sub is_panel ($block) {
    return 0 unless $LAUNCH{ $block->{name} // '' };
    my $input = $block->{input} // {};
    my $type  = $input->{subagent_type} // '';
    return 1 if $type eq 'reviewer';
    return 0 if length $type && !$CATCHALL{$type};
    return ($input->{description} // '') =~ /panel/i ? 1 : 0;
}

# The launch identifier of one sub-agent trace. The trace has a
# sibling meta file, and the file names the tool_use block that
# launched the sub-agent. A trace with no meta file gives the empty
# string, which matches no launch.
sub meta_id ($path) {
    my $meta = $path =~ s/\.jsonl\z/.meta.json/r;
    open my $fh, '<:encoding(UTF-8)', $meta or return '';
    my $text = do { local $/; <$fh> };
    close $fh;
    my $rec = eval { $JSON->decode($text // '') };
    return ref $rec eq 'HASH' ? $rec->{toolUseId} // '' : '';
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
