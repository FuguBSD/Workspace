#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Tests for the remove refusal, the listing, and the settings guard
# of scripts/worktree.pl (WS-WORKTREE-6, WS-WORKTREE-7,
# WS-PROFILES-3).
#
# D-06 stops every automatic removal, so remove must refuse a
# worktree that holds work at risk. Each test makes a temp repository
# with one worktree. No test writes outside its temp tree.

use v5.36;
use Test::More;
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use FindBin    qw($RealBin);

my $script = "$RealBin/../../scripts/worktree.pl";

# _git(@args):
#	Run git, and die on a failure. Each argument is quoted.
sub _git (@args)
{
	my $a   = join q{ }, map { "'$_'" } @args;
	my $out = qx(git $a 2>&1);
	die "git $a: $out" if $?;

	return $out;
}

# _run($root, @args):
#	Run worktree.pl against $root. The exit code and the output.
sub _run ( $root, @args )
{
	my $a   = join q{ }, map { "'$_'" } @args;
	my $out = qx("$^X" "$script" -C "$root" $a 2>&1);

	return ( $? >> 8, $out );
}

# _write($path, $text):
#	Write one file, and make its parent directories.
sub _write ( $path, $text )
{
	make_path( $path =~ s{/[^/]+\z}{}r );
	open my $fh, '>', $path or die "write $path: $!";
	print {$fh} $text;
	close $fh;
}

# _repo($name):
#	A checkout with one commit on main and one worktree, called
#	$name. The gitignore hides the nested clone, as the org
#	gitignore hides Projects/ and Wiki/ in the workspace.
sub _repo ($name)
{
	my $dir = tempdir( CLEANUP => 1 );
	_git( 'init', '--quiet', '-b', 'main', $dir );
	_git( '-C', $dir, 'config', 'user.email', 'a@b' );
	_git( '-C', $dir, 'config', 'user.name',  'a' );

	# The test must not depend on the operator signing agent.
	_git( '-C', $dir, 'config', 'commit.gpgsign', 'false' );
	_write( "$dir/.gitignore", "Wiki/\n" );
	_write( "$dir/f.txt",      "x\n" );
	_git( '-C', $dir, 'add', '-A' );
	_git( '-C', $dir, 'commit', '--quiet', '-m', 'Initial commit' );
	_git( '-C', $dir, 'worktree', 'add', '--quiet',
		"$dir/.claude/worktrees/$name", '-b', $name );

	return ( $dir, "$dir/.claude/worktrees/$name" );
}

subtest 'a bootstrap writes no settings file' => sub {

	# WS-PROFILES-3: a checkout settings file must not hold a
	# credential, so a workspace tool must not write one.
	my ($main) = _repo('p3');
	_write( "$main/.env", "SCW_ACCESS_KEY=SCWFAKE0000000000\n" );
	my $dest = tempdir( CLEANUP => 1 );
	my $out  = qx(cd "$dest" && "$^X" "$script" -C "$main" clone .env 2>&1);
	is( $? >> 8, 0, 'clone exits 0' ) or diag $out;
	ok( -f "$dest/.env", 'the .env copy arrives' );
	ok( !-e "$dest/.claude/settings.local.json",
		'no settings file appears' );

	# The bootstrap recipe must hold no settings write, so a
	# settings step cannot return unnoticed.
	open my $mk, '<', "$RealBin/../../mk/local.mk" or die $!;
	my $fragment = do { local $/; <$mk> };
	close $mk;
	unlike( $fragment, qr/envsync|settings\.local/,
		'the make fragment holds no settings step' );
};

subtest 'a clean worktree is removed' => sub {
	my ( $root, $wt ) = _repo('clean');

	my ( $rc, $out ) = _run( $root, 'list' );
	is( $rc, 0, 'list exits zero' );
	like( $out, qr/^clean\s+\d+ d\s+clean/m,
		'the listing names the worktree, its age and its state' );

	( $rc, $out ) = _run( $root, 'remove', 'clean' );
	is( $rc, 0, 'remove exits zero' );
	ok( !-d $wt, 'the worktree is gone' );
};

subtest 'remove refuses an uncommitted change in the worktree' => sub {
	my ( $root, $wt ) = _repo('dirty');
	_write( "$wt/f.txt", "changed\n" );

	my ( $rc, $out ) = _run( $root, 'list' );
	like( $out, qr/uncommitted change/, 'the listing names the cause' );

	( $rc, $out ) = _run( $root, 'remove', 'dirty' );
	isnt( $rc, 0, 'remove refuses (WS-WORKTREE-6)' );
	like( $out, qr/uncommitted change/, 'the message names the cause' );
	ok( -d $wt, 'the worktree stays' );

	( $rc, $out ) = _run( $root, 'remove', '--force', 'dirty' );
	is( $rc, 0, '--force overrides the refusal' );
	ok( !-d $wt, 'the worktree is gone after --force' );
};

subtest 'remove refuses a commit that no remote holds' => sub {
	my ( $root, $wt ) = _repo('ahead');
	_write( "$wt/g.txt", "new\n" );
	_git( '-C', $wt, 'add', '-A' );
	_git( '-C', $wt, 'commit', '--quiet', '-m', 'work that is at risk' );

	my ( $rc, $out ) = _run( $root, 'remove', 'ahead' );
	isnt( $rc, 0, 'remove refuses' );
	like( $out, qr/commit\(s\) that no remote holds/,
		'the message names the cause' );
	ok( -d $wt, 'the worktree stays' );

	# A linked worktree shares one ref store with its checkout, so
	# the count must come from its own HEAD, not from --branches.
	( $rc, $out ) = _run( $root, 'list' );
	like( $out, qr/^ahead\s+\d+ d\s+\.: 1 commit/m,
		'the listing counts one commit, not every branch' );

	( $rc, $out ) = _run( $root, 'remove', '--force', 'ahead' );
	is( $rc, 0, '--force overrides the refusal' );
};

subtest 'a merged branch with no remote is safe' => sub {
	my ( $root, $wt ) = _repo('merged');
	_write( "$wt/g.txt", "new\n" );
	_git( '-C', $wt, 'add', '-A' );
	_git( '-C', $wt, 'commit', '--quiet', '-m', 'work that landed' );
	_git( '-C', $root, 'merge', '--quiet', '--ff-only', 'merged' );

	# The workspace has no remote before its publication, so the
	# merge to main is where the work becomes safe.
	my ( $rc, $out ) = _run( $root, 'remove', 'merged' );
	is( $rc, 0, 'remove accepts a branch that main holds' );
	ok( !-d $wt, 'the worktree is gone' );
};

subtest 'remove refuses uncommitted work in a nested clone' => sub {
	my ( $root, $wt ) = _repo('nested');

	# The workspace gitignores Projects/ and Wiki/, so a dirty
	# clone inside a worktree is invisible to the outer status.
	# The walk must find it anyway (WS-WORKTREE-6).
	_git( 'init', '--quiet', '-b', 'main', "$wt/Wiki" );
	_git( '-C', "$wt/Wiki", 'config', 'user.email', 'a@b' );
	_git( '-C', "$wt/Wiki", 'config', 'user.name',  'a' );
	_write( "$wt/Wiki/page.md", "an observation that is not committed\n" );

	my ( $rc, $out ) = _run( $root, 'remove', 'nested' );
	isnt( $rc, 0, 'remove refuses' );
	like( $out, qr{Wiki: uncommitted change},
		'the message names the nested clone' );
	ok( -d $wt, 'the worktree stays' );
};

done_testing();
