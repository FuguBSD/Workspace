#!/usr/bin/env perl
# worktree.pl — create, bootstrap, and remove workspace worktrees.
#
#     worktree.pl [-C <main-checkout>] create <name>
#     worktree.pl [-C <main-checkout>] remove [--force] <name>
#     worktree.pl [-C <main-checkout>] list
#     worktree.pl [-C <main-checkout>] clone <path> [<path>...]
#     worktree.pl envsync
#
# The command "create" makes the worktree at
# <main>/.claude/worktrees/<name>, on a new branch <name> that starts
# at the local HEAD. The workspace then does its own bootstrap: if the
# worktree has a makefile, create runs the bootstrap make target with
# MAIN=<main checkout>. Create writes the worktree path to stdout as
# the only line — this is the contract of the WorktreeCreate hook.
# Create refuses a name that puts the new worktree in an existing
# worktree. After a failure, or after SIGINT or SIGTERM, create stops
# its child processes and removes all that it made.
#
# The command "remove" removes the worktree and its branch. It can
# remove locked worktrees, debris from a killed create, and worktrees
# that a user removed by hand. A second run causes no change. Create
# and remove do not remove the branch that the main checkout has
# checked out.
#
# Only an operator runs remove: no hook removes a worktree (D-06). A
# session captures its work in the clones inside its worktree, so an
# automatic removal at a failed session destroys that work. Remove
# refuses a worktree that holds work at risk, and the message names
# each cause: an uncommitted change in the worktree or in a clone
# inside it, and a commit that no remote and no main branch holds. The
# option --force overrides the refusal.
#
# The command "list" reports each worktree with its age in days and
# its state, so an operator can see which worktree is safe to remove.
# The age comes from the .git gitfile that `git worktree add` writes,
# because that file records the creation and later work does not
# touch it.
#
# The command "clone" is the tool that a make target calls: it copies
# gitignored paths from the main checkout into the current directory,
# with no network access. For a path that is a git repository, or a
# directory of git repositories, clone makes a local clone, sets
# origin to the origin URL of the source, and copies each .env file in
# the tree. For a path that is a plain file, clone copies the file.
# Destinations that exist do not change. Thus a second run repairs an
# incomplete bootstrap and keeps local changes.
#
# The command "envsync" merges each .env file under the current
# directory into the env object of .claude/settings.local.json, per
# spec WS-ENVSYNC and decision D-05. Claude Code injects that object
# into every Bash call. Envsync runs in a checkout root: it stops
# without a .git entry in the current directory. The file list sorts
# by depth, shallowest first, then by path, and the first file that
# states a key sets it.
# A later statement of a set key gets a warning that names the file
# and the keys, never the values. Envsync owns the whole env object,
# keeps each other top-level key, and writes canonical sorted output
# through a temp file with mode 0600. A settings file that does not
# parse stops the program before any change.
#
# Create and remove only make changes in <main>/.claude/worktrees/.
# Clone and envsync only write in the current directory.
# Exit codes: 0 = success, 2 = usage error, other values = failure.
#
# The commands are safe in the failure conditions that follow. Agents
# run the commands in parallel and with bad input:
# - Parallel creates of one name: the command `git branch` is the
#   atomic lock. Only one create is successful. The other creates
#   stop and change nothing.
# - A name that puts the new worktree in an existing worktree (fix,
#   then fix/auth): create refuses the name immediately, because
#   removal of the outer worktree also destroys the inner worktree.
#   Sibling worktrees that share a plain parent directory are
#   permitted.
# - SIGINT or SIGTERM during the bootstrap (for example, a hook
#   timeout): the program stops the child process group and waits for
#   it. The cleanup starts after that. Thus an orphan clone cannot
#   make new files while the cleanup removes files.
# - SIGKILL during the bootstrap: debris stays. But remove can remove
#   each type of debris: a branch without a directory, a directory
#   that git does not know, and orphan child processes that continue
#   in the worktree.
# - Parallel removes of one name: if the directory or the branch is
#   gone between a check and an action, this is not an error. The
#   work is done.
# - A remove of a name that is the branch that the main checkout has
#   checked out (main, master, trunk, ...): the program does not
#   remove that branch.
# - A bootstrap step that fails: the cleanup does all its steps, also
#   when one step fails. Create then stops with an error, and no
#   worktree and no branch stay behind.

use strict;
use warnings;

use Cwd qw(abs_path);
use Encode ();
use Fcntl qw(O_CREAT O_EXCL O_WRONLY);
use File::Basename qw(basename dirname);
use File::Copy qw(copy);
use File::Find qw(find);
use File::Path qw(make_path remove_tree);
use JSON::PP ();
use POSIX qw(_exit);

my $prog = basename($0);
my $WORKTREES = '.claude/worktrees';
my $SETTINGS = '.claude/settings.local.json';

# The pid of the child for which run() waits. A signal handler can
# stop this child and its process group before the cleanup starts. If
# it does not, a make or git clone that continues can make new files
# while the cleanup removes them.
my $child;

# Stdout is only for command results (create writes the worktree
# path). All other output, child output included, goes to stderr.
open(my $result, '>&', \*STDOUT) or die "$prog: cannot dup stdout: $!\n";
open(STDOUT, '>&', \*STDERR) or die "$prog: cannot redirect stdout: $!\n";

main();

sub main {
    if (@ARGV && ($ARGV[0] eq '-h' || $ARGV[0] eq '--help')) {
        print {$result} usage_text();
        exit 0;
    }

    my $dir = '.';
    my $c_given = 0;
    if (@ARGV && $ARGV[0] eq '-C') {
        shift @ARGV;
        $dir = shift @ARGV // usage();
        $c_given = 1;
    }
    my $command = shift @ARGV // usage();

    # Envsync runs in the current directory and does not read the
    # main checkout, so it takes no -C. Its own checkout guard is in
    # cmd_envsync.
    if ($command eq 'envsync') {
        usage() if @ARGV || $c_given;
        cmd_envsync();
        return;
    }

    my $root = abs_path($dir);
    die "$prog: not the main checkout (no .git directory): $dir\n"
        unless defined $root && -d "$root/.git";

    if ($command eq 'clone') {
        usage() unless @ARGV;
        cmd_clone($root, @ARGV);
        return;
    }

    if ($command eq 'list') {
        usage() if @ARGV;
        cmd_list($root);
        return;
    }

    # Only remove takes --force. It overrides the refusal that guards
    # the work inside a worktree.
    my $force = 0;
    if ($command eq 'remove' && @ARGV && $ARGV[0] eq '--force') {
        shift @ARGV;
        $force = 1;
    }

    my $name = shift @ARGV // usage();
    usage() if @ARGV;
    die "$prog: invalid worktree name: $name\n"
        unless $name =~ m{^[A-Za-z0-9][A-Za-z0-9._/-]*$} && $name !~ m{\.\.};

    if ($command eq 'create') { cmd_create($root, $name) }
    elsif ($command eq 'remove') { cmd_remove($root, $name, $force) }
    else { usage() }
}

sub cmd_create {
    my ($root, $name) = @_;
    my $wt = "$root/$WORKTREES/$name";
    die "$prog: already exists: $wt\n" if -e $wt;

    # A worktree with a slash in its name must not be in an existing
    # worktree: removal of the outer worktree also destroys the inner
    # worktree, with no message. An empty parent directory from a
    # sibling such as a/x is safe, because it has no .git.
    for (my $dir = dirname($wt);
        length($dir) > length("$root/$WORKTREES");
        $dir = dirname($dir)) {
        die "$prog: $name nests inside an existing worktree: $dir\n"
            if -e "$dir/.git";
    }

    # Make the branch first, as its own step. The command git worktree
    # add makes the branch before the directory. Thus an add that
    # fails can keep a branch whose owner is not known. If this branch
    # step fails, the branch was already there, and nothing has
    # changed. If this step is successful, this program owns all that
    # the steps below make, and the cleanup can remove it after a
    # failure or a signal. This step is also the lock against a
    # parallel create of the same name. Only one create is successful.
    # The other creates stop here and change nothing.
    run('git', '-C', $root, 'branch', $name);

    my $cleanup = sub {
        system('git', '-C', $root, 'worktree', 'remove', '--force',
            '--force', $wt)
            if -d $wt;
        remove_tree($wt) if -d $wt;
        # Each cleanup step must run. delete_branch stops the program
        # when it cannot remove the branch. The eval catches this
        # error.
        eval { delete_branch($root, $name); 1 } or warn $@;
        system('git', '-C', $root, 'worktree', 'prune');
        prune_parents($root, $wt);
    };
    my $on_signal = sub {
        $SIG{INT} = $SIG{TERM} = 'IGNORE';
        print "$prog: interrupted, cleaning up\n";
        if ($child) {
            # The child is the leader of its own process group. Thus
            # the signal also goes to the processes that make starts
            # (git clone and others).
            kill 'TERM', -$child;
            waitpid($child, 0);
        }
        $cleanup->();
        exit 1;
    };
    local $SIG{INT} = $on_signal;
    local $SIG{TERM} = $on_signal;

    eval {
        run('git', '-C', $root, 'worktree', 'add', $wt, $name);
        # The bootstrap is a task of the workspace: the bootstrap make
        # target makes all that the worktree needs. It makes local
        # clones from MAIN, usually with the clone subcommand below.
        run('make', '-C', $wt, 'bootstrap', "MAIN=$root")
            if -f "$wt/GNUmakefile" || -f "$wt/Makefile" || -f "$wt/makefile";
        1;
    } or do {
        my $err = $@;
        $cleanup->();
        die $err;
    };

    print {$result} "$wt\n";
}

sub cmd_remove {
    my ($root, $name, $force) = @_;
    my $base = "$root/$WORKTREES/";
    my $wt = $base . $name;

    # Resolve the symlinks, then do the check again: a link in the
    # base must not permit an operation outside of the base. A
    # parallel remove can remove the directory between the -d test and
    # abs_path. Each of the two undef results goes to the
    # worktree-is-gone code below.
    my $resolved = -d $wt ? abs_path($wt) : undef;

    if (defined $resolved) {
        die "$prog: refusing to remove: $wt resolves outside $base\n"
            unless rindex($resolved, $base, 0) == 0
            && length($resolved) > length($base);

        # The guard of D-06: work inside the worktree must survive.
        # Debris from a killed create holds no session work, so a
        # directory that git does not know does not reach this test.
        unless ($force) {
            my @risk = risks($resolved);
            if (@risk) {
                warn "$prog: $_\n" for @risk;
                die "$prog: refusing to remove $name: "
                    . "the worktree holds work at risk. "
                    . "Use --force to override.\n";
            }
        }

        # Use the branch that the worktree has checked out, if it is
        # available. Debris from a killed create has no branch that
        # git can read. Then use the branch that create names after
        # the worktree.
        my $branch = capture('git', '-C', $resolved, 'branch',
            '--show-current');
        $branch = $name unless defined $branch && length($branch);

        # A double --force also removes locked worktrees. If git
        # refuses (incomplete debris that git does not know), remove
        # the directory — it is in the base — and prune the git
        # records.
        if (system('git', '-C', $root, 'worktree', 'remove', '--force',
                '--force', $resolved) != 0) {
            warn "$prog: git refused, deleting the directory\n";
            remove_tree($resolved);
            run('git', '-C', $root, 'worktree', 'prune');
        }
        delete_branch($root, $branch);
    } else {
        # The worktree is gone (or a user removed it by hand). Prune
        # the unwanted git records and remove the branch. Then the
        # name is available again.
        run('git', '-C', $root, 'worktree', 'prune');
        delete_branch($root, $name);
    }

    prune_parents($root, $wt);
}

# Report each worktree with its age in days and its state
# (WS-WORKTREE-7). The state names an uncommitted change and an
# unpushed commit, so an operator can see which worktree is safe to
# remove. D-06 stops every automatic removal, so this listing is the
# mitigation for the worktrees that accumulate.
sub cmd_list {
    my ($root) = @_;
    my $base = "$root/$WORKTREES/";

    my $out = capture('git', '-C', $root, 'worktree', 'list',
        '--porcelain');
    my @paths;
    for my $line (split /\n/, $out // '') {
        next unless $line =~ /^worktree (.+)$/;
        my $path = $1;
        push @paths, $path if rindex($path, $base, 0) == 0;
    }

    unless (@paths) {
        print {$result} "no worktrees\n";
        return;
    }

    for my $path (sort @paths) {
        my $name = substr($path, length($base));
        # The gitfile records the creation. Later work does not touch
        # it, so its mtime is the age of the worktree.
        my @st = stat "$path/.git";
        my $age = @st ? int((time - $st[9]) / 86400) : -1;
        my @risk = risks($path);
        my $state = @risk ? join('; ', @risk) : 'clean';
        printf {$result} "%-40s %4s d  %s\n", $name,
            $age < 0 ? '?' : $age, $state;
    }
}

# The reasons why a worktree holds work at risk (WS-WORKTREE-6). An
# empty list means the worktree is safe to remove. Each string names
# one repository and one cause.
sub risks {
    my ($wt) = @_;
    my @risk;
    for my $repo (repos_in($wt)) {
        my $rel = $repo eq $wt ? '.' : substr($repo, length($wt) + 1);

        my $dirty = capture('git', '-C', $repo, 'status', '--porcelain');
        push @risk, "$rel: uncommitted change"
            if defined $dirty && length $dirty;

        # A commit that no remote holds is at risk. Without a remote,
        # a commit that the main branch holds is safe: the merge to
        # main is where the work lands in this workspace.
        #
        # A linked worktree shares one ref store with its main
        # checkout, so --branches there counts the branches of every
        # other worktree too. Its own HEAD is the only ref it owns. A
        # nested clone is an independent repository, so --branches is
        # correct for it.
        my $linked = -f "$repo/.git";
        my $remotes = capture('git', '-C', $repo, 'remote');
        my @excl = ('--remotes');
        push @excl, 'main'
            if (!defined $remotes || !length $remotes)
            && branch_exists($repo, 'main');
        my $n = capture('git', '-C', $repo, 'rev-list', '--count',
            ($linked ? 'HEAD' : '--branches'), '--not', @excl);
        push @risk, "$rel: $n commit(s) that no remote holds"
            if defined $n && $n =~ /^\d+$/ && $n > 0;
    }
    return @risk;
}

# Each git repository in the worktree: the worktree itself, and each
# repository below it, such as a clone under Projects/ or the library
# at Wiki/. The walk stops at a repository it finds, because the
# content of a clone is that clone's own business. It prunes the
# scratch directories that hold no session work.
sub repos_in {
    my ($wt) = @_;
    my @repos = ($wt);
    find({
        no_chdir => 1,
        preprocess => sub {
            return grep { $_ ne '.git' && $_ ne 'explore' } @_;
        },
        wanted => sub {
            my $name = $File::Find::name;
            return if $name eq $wt;
            return unless -d $name && !-l $name;
            if ($name =~ m{(?:^|/)\.claude/worktrees\z}) {
                $File::Find::prune = 1;
                return;
            }
            return unless -e "$name/.git";
            push @repos, $name;
            $File::Find::prune = 1;
        },
    }, $wt);
    return @repos;
}

# Copy gitignored paths from the main checkout into the current
# directory. Clone repositories locally, use a directory as a set of
# repositories, and copy plain files.
sub cmd_clone {
    my ($root, @paths) = @_;
    for my $p (@paths) {
        $p =~ s{/+$}{};
        die "$prog: invalid path: $p\n"
            unless $p =~ m{^[A-Za-z0-9._][A-Za-z0-9._/-]*$}
            && $p !~ m{\.\.}
            && $p ne '.';
    }
    my $here = abs_path('.');
    if (defined $here && $here eq $root) {
        print "already the main checkout, nothing to do\n";
        return;
    }
    for my $p (@paths) {
        my $src = "$root/$p";
        if (-d $src && -e "$src/.git") {
            clone_repo($src, $p);
        } elsif (-d $src) {
            opendir(my $dh, $src) or die "$prog: $src: $!\n";
            my @names = sort grep { !/^\./ && -d "$src/$_" } readdir $dh;
            closedir $dh;
            clone_repo("$src/$_", "$p/$_") for @names;
        } elsif (-f $src) {
            copy_file($src, $p);
        } elsif (!-e $src) {
            print "missing in main checkout, skipped: $p\n";
        } else {
            die "$prog: not a repository, directory or file: $src\n";
        }
    }
}

# Clone one repository locally from the main checkout. A project that
# is not cloned, or is cloned partially, gives an incomplete workspace
# with no warning. Thus stop with an error.
sub clone_repo {
    my ($src, $dst) = @_;
    if (-e $dst) {
        print "already exists, skipped: $dst\n";
        return;
    }
    die "$prog: unreadable or not a git repository: $src\n"
        unless -r $src && -x $src && -e "$src/.git";
    my $parent = dirname($dst);
    make_path($parent) unless -d $parent;
    run('git', 'clone', '--quiet', $src, $dst);
    my $origin = capture('git', '-C', $src, 'remote', 'get-url',
        'origin');
    run('git', '-C', $dst, 'remote', 'set-url', 'origin', $origin)
        if defined $origin;
    copy_env_tree($src, $dst);
}

# Copy each .env file in the source tree, at each level. The files are
# gitignored, thus the clone above did not copy them. Copy only
# regular files: a .env symlink in a project is repository content and
# stays in the source. Do not go into .git or into a nested
# .claude/worktrees of the project.
sub copy_env_tree {
    my ($src, $dst) = @_;
    find({
        no_chdir => 1,
        wanted => sub {
            my $name = $File::Find::name;
            my $base = basename($name);
            if ($base eq '.git' || $name =~ m{/\.claude/worktrees\z}) {
                $File::Find::prune = 1;
                return;
            }
            return unless $base eq '.env' && !-l $name && -f $name;
            my $rel = substr($name, length($src) + 1);
            # The full parent directory can be gitignored. Then the
            # clone does not have it.
            my $parent = dirname("$dst/$rel");
            make_path($parent) unless -d $parent;
            copy_file($name, "$dst/$rel");
        },
    }, $src);
}

sub copy_file {
    my ($src, $dst) = @_;
    # Do not write through a symlink that a project put at the
    # destination: replace the symlink with a regular file. Keep a
    # regular file that exists: a subsequent run must not overwrite
    # local changes.
    unlink $dst if -l $dst;
    if (-e $dst) {
        print "already exists, skipped: $dst\n";
        return;
    }
    # The .env files contain credentials: give the copy the mode of
    # the source, not the umask default. Do the stat before the copy.
    # A stat after the copy can occur after a parallel process removes
    # the source. Then the chmod sets the mode of the copy to 0.
    my @st = stat $src;
    copy($src, $dst) or die "$prog: copy $src -> $dst: $!\n";
    chmod($st[2] & 07777, $dst) if @st;
    print "copied $src -> $dst\n";
}

# Merge each .env under the current directory into the env object of
# .claude/settings.local.json (WS-ENVSYNC). The first file that
# states a key sets it; env_files() puts the shallowest file first.
# A later statement of a set key gets one warning for each file, with
# the file path and the key names, never the values.
sub cmd_envsync {
    # The guard against a run in a wrong directory, for example a
    # home directory: the walk below visits the full tree. The
    # explicit exit keeps code 2 for usage errors; a die after a
    # failed stat exits with the errno, which is also 2.
    unless (-e '.git') {
        warn "$prog: not a checkout root (no .git here)\n";
        exit 1;
    }

    my @files = env_files();
    my (%env, %owner);
    for my $file (@files) {
        my %shadowed;
        open(my $fh, '<:raw', $file) or die "$prog: read $file: $!\n";
        my $bytes = do { local $/; <$fh> };
        close $fh;
        # The settings file is UTF-8, so each value must decode. A
        # bad byte stops the program, and the error names the file
        # only (WS-ENVSYNC-10). An encoding layer instead rewrites
        # the value and warns with it.
        my $text =
            eval { Encode::decode('UTF-8', $bytes, Encode::FB_CROAK) };
        die "$prog: $file is not valid UTF-8\n" unless defined $text;
        for my $line (split /\n/, $text) {
            $line =~ s/\r\z//;
            next unless $line =~ /^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/;
            if (exists $env{$1}) {
                # A repeat inside the file that set the key is not a
                # shadow (WS-ENVSYNC-5): the first statement wins.
                $shadowed{$1} = 1 unless $owner{$1} eq $file;
                next;
            }
            $env{$1} = $2;
            $owner{$1} = $file;
        }
        warn "$prog: $file: shadowed keys: @{[sort keys %shadowed]}\n"
            if %shadowed;
    }

    # A merge with no key must not make a new settings file
    # (WS-ENVSYNC-8). With a settings file, the write below removes a
    # stale env object.
    if (!%env && !-e $SETTINGS) {
        print "no keys and no $SETTINGS, nothing to do\n";
        return;
    }

    write_settings(\%env);
    print "synced $SETTINGS: " . scalar(keys %env) . " key(s) from "
        . scalar(@files) . " file(s)\n";
}

# The regular .env files under the current directory, at any depth,
# sorted by depth, shallowest first, then by path. The walk prunes
# each .git, each .claude/worktrees, and each explore scratch
# directory, and it skips symlinks (WS-ENVSYNC-2).
sub env_files {
    my @files;
    find({
        no_chdir => 1,
        wanted => sub {
            my $name = $File::Find::name;
            my $base = basename($name);
            if ($base eq '.git'
                || $base eq 'explore'
                || $name =~ m{(?:^|/)\.claude/worktrees\z}) {
                $File::Find::prune = 1;
                return;
            }
            return unless $base eq '.env' && !-l $name && -f $name;
            $name =~ s{^\./}{};
            push @files, $name;
        },
    }, '.');
    return sort {
        ($a =~ tr{/}{}) <=> ($b =~ tr{/}{}) || $a cmp $b
    } @files;
}

# Replace the env object of the settings file, and keep each other
# top-level key. An empty merge removes the env object. The write is
# canonical and atomic: sorted keys, a temp file with mode 0600, then
# a rename. Thus a re-run with unchanged .env files gives a
# byte-identical file. A settings file that does not parse as a JSON
# object stops the program before any change.
sub write_settings {
    my ($env) = @_;

    # The settings file is UTF-8: decode the bytes on read, and
    # encode the characters on write.
    my $data = {};
    if (-e $SETTINGS) {
        open(my $fh, '<:raw', $SETTINGS)
            or die "$prog: read $SETTINGS: $!\n";
        my $text = do { local $/; <$fh> };
        close $fh;
        $data = eval { JSON::PP->new->utf8->decode($text) };
        die "$prog: $SETTINGS does not parse, fix it by hand\n"
            unless defined $data;
        die "$prog: $SETTINGS is not a JSON object\n"
            unless ref $data eq 'HASH';
    }
    if (%$env) { $data->{env} = $env }
    else { delete $data->{env} }

    # Two-space indent, sorted keys, and a space after the colon:
    # one stable format, so a re-run gives byte-identical output.
    # The org .gitignore hides the file from git and from the
    # prettier format gate.
    my $text = JSON::PP->new->utf8->canonical->indent->indent_length(2)
        ->space_after->encode($data);
    $text .= "\n" unless $text =~ /\n\z/;

    my $parent = dirname($SETTINGS);
    make_path($parent) unless -d $parent;
    my $tmp = "$SETTINGS.tmp$$";
    sysopen(my $out, $tmp, O_WRONLY | O_CREAT | O_EXCL, 0600)
        or die "$prog: open $tmp: $!\n";
    # The mode argument of sysopen goes through the umask; the chmod
    # makes the mode 0600 in every case.
    chmod 0600, $tmp;
    unless (print {$out} $text and close $out) {
        my $err = $!;
        unlink $tmp;
        die "$prog: write $tmp: $err\n";
    }
    rename($tmp, $SETTINGS) or do {
        my $err = $!;
        unlink $tmp;
        die "$prog: rename $tmp: $err\n";
    };
}

# Remove a branch if it exists. Make no report about, and no change
# to: a branch that is gone, the branch main, and the branch that the
# main checkout has checked out. If a parallel remove removes the
# branch first, this is not an error. If git refuses (for example, the
# branch is checked out in a different worktree) and the branch stays,
# stop with an error.
sub delete_branch {
    my ($root, $branch) = @_;
    return unless defined $branch && length($branch) && $branch ne 'main';
    my $head = capture('git', '-C', $root, 'symbolic-ref', '--quiet',
        '--short', 'HEAD');
    return if defined $head && $branch eq $head;
    return unless branch_exists($root, $branch);
    return
        if system('git', '-C', $root, 'branch', '-D', $branch) == 0;
    die "$prog: cannot delete branch: $branch\n"
        if branch_exists($root, $branch);
}

sub branch_exists {
    my ($root, $branch) = @_;
    return system('git', '-C', $root, 'show-ref', '--verify', '--quiet',
        "refs/heads/$branch") == 0;
}

# A worktree with slashes in its name (a/b/c) is in nested
# directories. Remove the empty directories. Stop at the first parent
# that is not empty, or at the base.
sub prune_parents {
    my ($root, $wt) = @_;
    my $limit = "$root/$WORKTREES";
    my $dir = dirname($wt);
    while (length($dir) > length($limit) && rindex($dir, "$limit/", 0) == 0) {
        rmdir $dir or last;
        $dir = dirname($dir);
    }
}

# The same as system(), but a failure stops the program with an error.
# The child is the leader of its own process group, and its pid is in
# $child. Thus a signal handler can stop the full process tree before
# the cleanup.
sub run {
    my @cmd = @_;
    my $pid = fork();
    die "$prog: fork: $!\n" unless defined $pid;
    if ($pid == 0) {
        $SIG{INT} = $SIG{TERM} = 'DEFAULT';
        setpgrp(0, 0);
        exec {$cmd[0]} @cmd;
        warn "$prog: exec $cmd[0]: $!\n";
        _exit(127);
    }
    $child = $pid;
    waitpid($pid, 0);
    $child = undef;
    die "$prog: command failed: @cmd\n" if $? != 0;
}

# Return the output of the command, without the last newline. Return
# undef if the command fails.
sub capture {
    my @cmd = @_;
    open(my $fh, '-|', @cmd) or die "$prog: cannot run @cmd: $!\n";
    my $out = do { local $/; <$fh> };
    close $fh;
    return undef if $? != 0 || !defined $out;
    chomp $out;
    return $out;
}

sub usage_text {
    return "usage: $prog [-C <main-checkout>] create <name>\n"
        . "       $prog [-C <main-checkout>] remove [--force] <name>\n"
        . "       $prog [-C <main-checkout>] list\n"
        . "       $prog [-C <main-checkout>] clone <path> [<path>...]\n"
        . "       $prog envsync\n";
}

sub usage {
    print STDERR usage_text();
    exit 2;
}
