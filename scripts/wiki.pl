#!/usr/bin/env perl
# wiki.pl — operate the learning library at Wiki/.
#
#     wiki.pl [-C <checkout>] init
#     wiki.pl [-C <checkout>] open <project> <session>
#     wiki.pl [-C <checkout>] note <page> <file>
#     wiki.pl [-C <checkout>] admit <page> <file>
#     wiki.pl [-C <checkout>] close <session>
#     wiki.pl [-C <checkout>] status
#     wiki.pl [-C <checkout>] candidates
#     wiki.pl hook-start
#     wiki.pl hook-end
#
# The two hook subcommands read the Claude Code payload on stdin and
# do the work of LIB-HOOKS. They hold the payload logic, so
# .claude/settings.json holds one short command for each event.
#
# The library is the git repository FuguBSD/Wiki, cloned at Wiki/ in
# each checkout (D-07). This program operates the clone of one
# checkout, and -C names that checkout. It is the counterpart of
# scripts/worktree.pl, which operates a worktree.
#
# Every capture commits, and then pushes (LIB-WIKI-1). The commit
# carries the durability, and the push carries the visibility. The
# SessionEnd hook does not run after an abnormal stop, so a capture
# that waits for the end of a session is a capture that a crash loses
# (LIB-HOOKS-6).
#
# A failed push must not stop a capture (LIB-WIKI-2): the subcommand
# warns and exits zero, and the commit stays for the next push. On a
# rejected push, the program fetches, rebases and retries. It never
# forces a push, because a ruleset forbids one (LIB-LIBRARY-4).
#
# Pages stay flat, and the page name carries the structure
# (LIB-PAGES-1). This program writes only inside the Wiki clone of the
# checkout that -C names (LIB-WIKI-6).
#
# Exit codes: 0 = success, 2 = usage error, other values = failure.

use v5.34;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(basename dirname);
use JSON::PP ();
use POSIX qw(strftime);

my $prog = basename($0);
my $WIKI = 'Wiki';
my $ORIGIN = 'https://github.com/FuguBSD/Wiki.git';
my $CANDIDATES = 'Rule-candidates.md';

# Stdout is only for command results. All other output, child output
# included, goes to stderr. A hook reads stdout, so a git message must
# never reach it.
open(my $result, '>&', \*STDOUT) or die "$prog: cannot dup stdout: $!\n";
open(STDOUT, '>&', \*STDERR) or die "$prog: cannot redirect stdout: $!\n";

main();

sub main {
    if (@ARGV && ($ARGV[0] eq '-h' || $ARGV[0] eq '--help')) {
        print {$result} usage_text();
        exit 0;
    }

    my $dir = '.';
    if (@ARGV && $ARGV[0] eq '-C') {
        shift @ARGV;
        $dir = shift @ARGV // usage();
    }
    my $command = shift @ARGV // usage();

    # The hook subcommands take no -C: they read the session path from
    # the payload on stdin.
    if ($command eq 'hook-start' || $command eq 'hook-end') {
        usage() if @ARGV;
        cmd_hook($command);
        return;
    }

    my $root = checkout_root($dir);
    die "$prog: no such checkout: $dir\n" unless defined $root && -d $root;
    my $wiki = "$root/$WIKI";

    if ($command eq 'init') { usage() if @ARGV; cmd_init($wiki) }
    elsif ($command eq 'open') {
        my ($project, $session) = (shift @ARGV, shift @ARGV);
        usage() if @ARGV || !defined $project || !defined $session;
        cmd_open($wiki, $project, $session);
    }
    elsif ($command eq 'note' || $command eq 'admit') {
        my ($page, $file) = (shift @ARGV, shift @ARGV);
        usage() if @ARGV || !defined $page || !defined $file;
        cmd_append($wiki, $command, $page, $file);
    }
    elsif ($command eq 'close') {
        my $session = shift @ARGV;
        usage() if @ARGV || !defined $session;
        cmd_close($wiki, $session);
    }
    elsif ($command eq 'status') { usage() if @ARGV; cmd_status($wiki) }
    elsif ($command eq 'candidates') {
        usage() if @ARGV;
        cmd_candidates($wiki);
    }
    else { usage() }
}

# Clone the library when it is absent. A second run causes no change
# (LIB-WIKI-4). The repository can be absent, and a checkout without
# network access is normal, so a failed clone warns and exits zero:
# the session that follows must still start.
sub cmd_init {
    my ($wiki) = @_;
    if (-d $wiki) {
        print "already exists, nothing to do: $wiki\n";
        return;
    }
    if (system('git', 'clone', '--quiet', $ORIGIN, $wiki) != 0) {
        warn "$prog: cannot clone $ORIGIN, the library stays absent\n";
        return;
    }
    print {$result} "$wiki\n";
}

# Start the session page, commit, then push. A second run for one
# session causes no change (LIB-WIKI-4), so the SessionStart hook can
# fire at a start, a resume, a clear and a compact (LIB-HOOKS-5).
sub cmd_open {
    my ($wiki, $project, $session) = @_;
    return unless have_wiki($wiki);
    check_token($project, 'project');
    check_token($session, 'session');

    if (my $page = page_of_session($wiki, $session)) {
        print "already open: $page\n";
        print {$result} "$page\n";
        return;
    }

    # One session can drive several runs, so the page name holds no
    # run identifier (LIB-PAGES-4). The index only separates two
    # sessions of one project on one day.
    my $date = strftime('%Y-%m-%d', gmtime);
    my $n = 1;
    $n++ while -e "$wiki/Session-$project-$date-$n.md";
    my $page = "Session-$project-$date-$n.md";
    my $now = strftime('%Y-%m-%dT%H:%M:%SZ', gmtime);

    write_file("$wiki/$page", <<"END");
# Session $project $date $n

Session: $session
Project: $project
Opened: $now

## Observations
END

    save($wiki, $page, "open: $page");
    print {$result} "$page\n";
}

# Append one observation or one admitted claim, commit, then push.
# The two subcommands share this path: they differ in the target page
# and in the commit subject only.
sub cmd_append {
    my ($wiki, $command, $page, $file) = @_;
    return unless have_wiki($wiki);
    my $path = page_path($wiki, $page);
    # The caller can name a page with or without the .md suffix. Git
    # needs the name of the file, so take it back from the path.
    my $name = basename($path);
    die "$prog: no such page: $page\n" unless -f $path;
    die "$prog: no such file: $file\n" unless -f $file;

    open(my $in, '<:encoding(UTF-8)', $file)
        or die "$prog: read $file: $!\n";
    my $text = do { local $/; <$in> };
    close $in;
    die "$prog: $file is empty\n" unless defined $text && $text =~ /\S/;
    $text .= "\n" unless $text =~ /\n\z/;

    open(my $out, '>>:encoding(UTF-8)', $path)
        or die "$prog: append $path: $!\n";
    print {$out} "\n$text" or die "$prog: append $path: $!\n";
    close $out or die "$prog: append $path: $!\n";

    save($wiki, $name, "$command: $name");
    print {$result} "$name\n";
}

# Mark the session page closed, commit, then push. Close adds no
# durability of its own: every observation reached a commit through
# note (LIB-HOOKS-6). A session with no page is normal, because a
# session can run no campaign.
sub cmd_close {
    my ($wiki, $session) = @_;
    return unless have_wiki($wiki);
    check_token($session, 'session');

    my $page = page_of_session($wiki, $session);
    unless ($page) {
        print "no page for this session, nothing to do\n";
        return;
    }
    my $path = "$wiki/$page";
    if (slurp($path) =~ /^Closed:/m) {
        print "already closed: $page\n";
        return;
    }

    my $now = strftime('%Y-%m-%dT%H:%M:%SZ', gmtime);
    open(my $out, '>>:encoding(UTF-8)', $path)
        or die "$prog: append $path: $!\n";
    print {$out} "\nClosed: $now\n" or die "$prog: append $path: $!\n";
    close $out or die "$prog: append $path: $!\n";

    save($wiki, $page, "close: $page");
    print {$result} "$page\n";
}

# Report each open session, each unadmitted claim, and each unpushed
# commit (LIB-WIKI-5). An empty page is not an open session: a hook
# fires for every session, and most sessions run no campaign
# (LIB-HOOKS-5).
sub cmd_status {
    my ($wiki) = @_;
    return unless have_wiki($wiki);

    my @open;
    # The parentheses matter: `sort pages(...)` reads pages as the
    # comparison routine, not as the list.
    my @session_pages = sort(pages($wiki, qr/^Session-/));
    for my $page (@session_pages) {
        my $text = slurp("$wiki/$page");
        next if $text =~ /^Closed:/m;

        # The observations follow the heading. A page with nothing
        # under it is a session that captured nothing.
        my ($body) = $text =~ /^## Observations$(.*)\z/ms;
        next unless defined $body && $body =~ /\S/;

        # The consolidator writes one Admitted: line for each claim
        # that it moves into a library page. The difference is the
        # work that the library is still waiting for.
        my $claims = () = $body =~ /^Claim:/mg;
        my $admitted = () = $body =~ /^Admitted:/mg;
        push @open, sprintf('%-44s %d claim(s), %d admitted',
            $page, $claims, $admitted);
    }

    if (@open) { print {$result} "open sessions:\n  $_\n" for @open }
    else { print {$result} "open sessions: none\n" }

    my $unpushed = capture($wiki, 'rev-list', '--count', 'HEAD',
        '--not', '--remotes');
    $unpushed = 'unknown' unless defined $unpushed && $unpushed =~ /^\d+$/;
    print {$result} "unpushed commits: $unpushed\n";
}

# Report each undelivered rule candidate with its age in days
# (LIB-CANDIDATE-1). A candidate is a list item that starts with a
# date. A candidate that carries "Delivered:" is done.
sub cmd_candidates {
    my ($wiki) = @_;
    # The target runs inside make check, so a checkout that has not
    # bootstrapped must still pass (LIB-CANDIDATE-2).
    unless (-d $wiki && -f "$wiki/$CANDIDATES") {
        print {$result} "no $CANDIDATES, nothing to report\n";
        return;
    }

    # An item can wrap: the prose gate reflows the page, so
    # "Delivered:" often sits on a continuation line. Join each item
    # into one string before the test, or a delivered candidate gets
    # reported forever.
    my @items;
    for my $line (split /\n/, slurp("$wiki/$CANDIDATES")) {
        if ($line =~ /^-\s+(\d{4})-(\d{2})-(\d{2})\s+(.*)$/) {
            push @items, { y => $1, m => $2, d => $3, text => $4 };
        } elsif (@items && $line =~ /^\s+(\S.*)$/) {
            $items[-1]{text} .= " $1";
        }
    }

    my $now = time;
    my $found = 0;
    for my $item (@items) {
        next if $item->{text} =~ /Delivered:/;
        my $age = int(
            ($now - timegm_day($item->{y}, $item->{m}, $item->{d})) / 86400);
        printf {$result} "%4d d  %s-%s-%s  %s\n", $age, $item->{y},
            $item->{m}, $item->{d}, $item->{text};
        $found++;
    }
    print {$result} "no undelivered candidate\n" unless $found;
}

# Do the work of one session hook (LIB-HOOKS). The payload arrives on
# stdin. A hook must never stop a session, so every failure here
# warns and exits zero.
sub cmd_hook {
    my ($command) = @_;
    my $raw = do { local $/; <STDIN> };
    my $payload = eval { JSON::PP->new->utf8->decode($raw // '') };
    unless (ref $payload eq 'HASH') {
        warn "$prog: the hook payload does not parse\n";
        return;
    }

    # A sub-agent carries agent_id. An observer dispatches an operator
    # for each step and a verifier for each claim, so without this
    # test each of them opens its own page (LIB-HOOKS-3).
    return if defined $payload->{agent_id};

    my $cwd = $payload->{cwd};
    my $session = $payload->{session_id};
    unless (defined $cwd && defined $session) {
        warn "$prog: the hook payload names no cwd or no session\n";
        return;
    }
    $session =~ s/[^A-Za-z0-9._-]/-/g;

    # A session can start in a worktree, and a worktree is a checkout
    # with its own library clone (LIB-HOOKS-2).
    my $root = checkout_root($cwd);
    return unless defined $root;
    my $wiki = "$root/$WIKI";

    eval {
        if ($command eq 'hook-start') {
            cmd_init($wiki);
            cmd_open($wiki, project_of($root, $cwd), $session);
        } else {
            cmd_close($wiki, $session);
        }
        1;
    } or warn $@;
}

# The project that a session works on. A session under Projects/<name>
# belongs to that project. Any other session belongs to the workspace
# itself.
sub project_of {
    my ($root, $cwd) = @_;
    my $abs = abs_path($cwd);
    return 'Workspace' unless defined $abs;
    return $1 if $abs =~ m{^\Q$root\E/Projects/([A-Za-z0-9][\w.-]*)};
    return 'Workspace';
}

# The checkout that owns a path. A worktree is a checkout of its own,
# and a clone under Projects/ is not: it carries no scripts/wiki.pl.
# So walk up to the nearest directory that holds both a .git entry and
# this program.
sub checkout_root {
    my ($dir) = @_;
    my $abs = abs_path($dir);
    return undef unless defined $abs;
    my $at = $abs;
    while (length($at) > 1) {
        return $at if -e "$at/.git" && -f "$at/scripts/wiki.pl";
        my $up = dirname($at);
        last if $up eq $at;
        $at = $up;
    }
    return $abs;
}

# Write the page, commit it, and push it. The commit is the
# durability, so a failed commit stops the program. The push is the
# visibility, so a failed push warns only (LIB-WIKI-2).
sub save {
    my ($wiki, $page, $subject) = @_;
    run($wiki, 'add', '--', $page);

    # A commit with nothing staged returns non-zero. That is not a
    # failure: a second identical capture changes nothing.
    if (capture($wiki, 'diff', '--cached', '--name-only') // '') {
        run($wiki, 'commit', '--quiet', '-m', $subject);
    } else {
        print "no change to commit: $page\n";
        return;
    }
    push_now($wiki);
}

# Push, and settle a lost race. Two checkouts push to one origin, so
# the loser gets a non-fast-forward rejection (constraint 3). A fetch,
# a rebase and a retry settle it. A force push is never correct here:
# LIB-LIBRARY-4 has a ruleset that forbids one.
sub push_now {
    my ($wiki) = @_;
    my $branch = capture($wiki, 'branch', '--show-current');
    unless (defined $branch && length $branch) {
        warn "$prog: detached HEAD, not pushing\n";
        return 0;
    }

    for my $try (1 .. 3) {
        return 1 if git($wiki, 'push', '--quiet', 'origin', $branch) == 0;
        print "push rejected, rebasing and retrying ($try of 3)\n";
        if (git($wiki, 'fetch', '--quiet', 'origin', $branch) != 0) {
            last;
        }
        last if git($wiki, 'rebase', '--quiet', "origin/$branch") != 0;
    }
    # The commit stays. The next capture pushes it, and status reports
    # it in the meantime.
    warn "$prog: push failed, the commit stays local\n";
    return 0;
}

# The page that records this session, or undef. The session
# identifier lives in the page, not in the page name, so open stays
# idempotent across a resume and a compact.
sub page_of_session {
    my ($wiki, $session) = @_;
    my @session_pages = sort(pages($wiki, qr/^Session-/));
    for my $page (@session_pages) {
        return $page if slurp("$wiki/$page") =~ /^Session: \Q$session\E$/m;
    }
    return undef;
}

sub pages {
    my ($wiki, $re) = @_;
    opendir(my $dh, $wiki) or die "$prog: $wiki: $!\n";
    my @names = grep { /\.md\z/ && /$re/ && -f "$wiki/$_" } readdir $dh;
    closedir $dh;
    return @names;
}

# Resolve a page name to a path inside the clone. Pages stay flat, so
# a name with a slash, a dot segment or a leading dot is invalid. This
# is the guard of LIB-WIKI-6.
sub page_path {
    my ($wiki, $page) = @_;
    $page =~ s/\.md\z//;
    die "$prog: invalid page name: $page\n"
        unless $page =~ m{^[A-Za-z][A-Za-z0-9._-]*$} && $page !~ m{\.\.};
    die "$prog: a page name must not start with SCRATCHPAD\n"
        if $page =~ /^SCRATCHPAD/;
    return "$wiki/$page.md";
}

sub check_token {
    my ($value, $what) = @_;
    die "$prog: invalid $what: $value\n"
        unless $value =~ m{^[A-Za-z0-9][A-Za-z0-9._-]*$};
}

# The library can be absent: the repository is not created yet, and a
# checkout can have no network access. A subcommand that needs it
# reports and exits zero, so no hook stops a session.
sub have_wiki {
    my ($wiki) = @_;
    return 1 if -d $wiki && -e "$wiki/.git";
    print "no library at $wiki, nothing to do\n";
    return 0;
}

sub write_file {
    my ($path, $text) = @_;
    open(my $fh, '>:encoding(UTF-8)', $path)
        or die "$prog: write $path: $!\n";
    print {$fh} $text or die "$prog: write $path: $!\n";
    close $fh or die "$prog: write $path: $!\n";
}

sub slurp {
    my ($path) = @_;
    open(my $fh, '<:encoding(UTF-8)', $path) or return '';
    my $text = do { local $/; <$fh> };
    close $fh;
    return $text // '';
}

# The days since a UTC date, with no dependence on Time::Local.
sub timegm_day {
    my ($y, $m, $d) = @_;
    # The days from the civil epoch, by the algorithm of Howard
    # Hinnant. It needs no module and no local time zone.
    my $yy = $y - ($m <= 2 ? 1 : 0);
    my $era = int(($yy >= 0 ? $yy : $yy - 399) / 400);
    my $yoe = $yy - $era * 400;
    my $doy = int((153 * ($m + ($m > 2 ? -3 : 9)) + 2) / 5) + $d - 1;
    my $doe = $yoe * 365 + int($yoe / 4) - int($yoe / 100) + $doy;
    return ($era * 146097 + $doe - 719468) * 86400;
}

sub git {
    my ($wiki, @args) = @_;
    return system('git', '-C', $wiki, @args);
}

sub run {
    my ($wiki, @args) = @_;
    die "$prog: git @args failed in $wiki\n" if git($wiki, @args) != 0;
}

sub capture {
    my ($wiki, @args) = @_;
    open(my $fh, '-|', 'git', '-C', $wiki, @args) or return undef;
    my $out = do { local $/; <$fh> };
    close $fh;
    return undef if $? != 0 || !defined $out;
    chomp $out;
    return $out;
}

sub usage_text {
    return "usage: $prog [-C <checkout>] init\n"
        . "       $prog [-C <checkout>] open <project> <session>\n"
        . "       $prog [-C <checkout>] note <page> <file>\n"
        . "       $prog [-C <checkout>] admit <page> <file>\n"
        . "       $prog [-C <checkout>] close <session>\n"
        . "       $prog [-C <checkout>] status\n"
        . "       $prog [-C <checkout>] candidates\n"
        . "       $prog hook-start\n"
        . "       $prog hook-end\n";
}

sub usage {
    print STDERR usage_text();
    exit 2;
}
