#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Tests for scripts/wiki.pl (LIB-WIKI, LIB-PAGES, LIB-HOOKS,
# LIB-CANDIDATE).
#
# Each test makes a temp tree with a bare repository as the origin
# and one or two checkouts that clone it. No test reaches the
# network, and no test writes outside its temp tree.

use v5.36;
use Test::More;
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use FindBin    qw($RealBin);
use POSIX      qw(strftime);

my $script = "$RealBin/../../scripts/wiki.pl";

# _git(@args):
#	Run git, quiet, and die on a failure. Each argument is quoted:
#	a commit subject holds a space.
sub _git (@args)
{
	my $a   = join q{ }, map { "'$_'" } @args;
	my $out = qx(git $a 2>&1);
	die "git $a: $out" if $?;

	return $out;
}

# _wiki($checkout, @args):
#	Run wiki.pl against $checkout. The exit code and the output.
sub _wiki ( $checkout, @args )
{
	my $a   = join q{ }, map { "'$_'" } @args;
	my $out = qx("$^X" "$script" -C "$checkout" $a 2>&1);

	return ( $? >> 8, $out );
}

# _hook($command, $json):
#	Feed one payload to a hook subcommand on stdin.
sub _hook ( $command, $json )
{
	open my $fh, '|-', qq("$^X" "$script" $command >/dev/null 2>&1)
	    or die "run $command: $!";
	print {$fh} $json;
	close $fh;

	return $? >> 8;
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

# _origin($dir):
#	A bare repository with one commit on main, as the origin.
sub _origin ($dir)
{
	my $origin = "$dir/origin.git";
	_git( 'init', '--quiet', '--bare', $origin );
	_git( '-C', $origin, 'symbolic-ref', 'HEAD', 'refs/heads/main' );
	_git( 'clone', '--quiet', $origin, "$dir/seed" );
	_git( '-C', "$dir/seed", '-c', 'user.email=a@b', '-c',
		'user.name=a', 'commit', '--quiet', '--allow-empty',
		'-m', 'Initial commit' );
	_git( '-C', "$dir/seed", 'branch', '-M', 'main' );
	_git( '-C', "$dir/seed", 'push', '--quiet', 'origin', 'main' );

	return $origin;
}

# _checkout($dir, $name, $origin):
#	A checkout that holds scripts/wiki.pl and a Wiki clone. The
#	program walks up to a directory that holds both a .git entry
#	and scripts/wiki.pl, so both must exist.
sub _checkout ( $dir, $name, $origin )
{
	my $co = "$dir/$name";
	make_path("$co/scripts");
	_write( "$co/scripts/wiki.pl", "# a marker for checkout_root\n" );
	_git( 'init', '--quiet', $co );
	_git( 'clone', '--quiet', $origin, "$co/Wiki" );
	_git( '-C', "$co/Wiki", 'config', 'user.email', 'a@b' );
	_git( '-C', "$co/Wiki", 'config', 'user.name', 'a' );

	return $co;
}

my $today = strftime( '%Y-%m-%d', gmtime );

subtest 'open is idempotent and note commits and pushes' => sub {
	my $dir    = tempdir( CLEANUP => 1 );
	my $origin = _origin($dir);
	my $co     = _checkout( $dir, 'c1', $origin );

	my ( $rc, $out ) = _wiki( $co, 'open', 'FuguSTX', 'sess-1' );
	is( $rc, 0, 'open exits zero' );
	like( $out, qr/Session-FuguSTX-\Q$today\E-1/, 'the page name' );

	( $rc, $out ) = _wiki( $co, 'open', 'FuguSTX', 'sess-1' );
	like( $out, qr/already open/, 'a second open changes nothing' );
	my @pages = glob "$co/Wiki/Session-*";
	is( scalar @pages, 1, 'one page for one session (LIB-WIKI-4)' );

	# An empty page is not an open session (LIB-WIKI-5).
	( $rc, $out ) = _wiki( $co, 'status' );
	like( $out, qr/open sessions: none/,
		'an empty page is not an open session' );

	_write( "$dir/obs.md", "Claim: the probe returns three zones.\n" );
	( $rc, $out ) =
	    _wiki( $co, 'note', "Session-FuguSTX-$today-1", "$dir/obs.md" );
	is( $rc, 0, 'note exits zero' );

	( $rc, $out ) = _wiki( $co, 'status' );
	like( $out, qr/1 claim\(s\), 0 admitted/, 'status counts the claim' );
	like( $out, qr/unpushed commits: 0/, 'the commit reached the origin' );

	my $log = qx(git -C "$origin" log --oneline);
	like( $log, qr/note: Session-FuguSTX/,
		'the origin holds the note commit (LIB-WIKI-1)' );
};

subtest 'a rejected push rebases and retries, and never forces' => sub {
	my $dir    = tempdir( CLEANUP => 1 );
	my $origin = _origin($dir);
	my $one    = _checkout( $dir, 'c1', $origin );
	my $two    = _checkout( $dir, 'c2', $origin );

	_wiki( $one, 'open', 'FuguSTX', 'sess-1' );

	# The second checkout pushes, so the first is behind. Its next
	# push is a non-fast-forward rejection (constraint 3).
	_wiki( $two, 'open', 'FuguCTX', 'sess-2' );

	_write( "$dir/obs.md", "Claim: the lease expires at ninety minutes.\n" );
	my ( $rc, $out ) =
	    _wiki( $one, 'note', "Session-FuguSTX-$today-1", "$dir/obs.md" );
	is( $rc, 0, 'note exits zero after a rejected push' );
	like( $out, qr/rebasing and retrying/, 'the retry ran (LIB-WIKI-3)' );

	# Both sessions survive, so the rebase kept the other commit.
	my $log = qx(git -C "$origin" log --oneline);
	like( $log, qr/Session-FuguCTX/, 'the other checkout keeps its page' );
	like( $log, qr/note: Session-FuguSTX/, 'the retry landed the note' );
};

subtest 'a page name stays inside the clone' => sub {
	my $dir    = tempdir( CLEANUP => 1 );
	my $origin = _origin($dir);
	my $co     = _checkout( $dir, 'c1', $origin );
	_wiki( $co, 'open', 'FuguSTX', 'sess-1' );
	_write( "$dir/obs.md", "Claim: x\n" );

	for my $bad (qw(../../../etc/passwd sub/dir ..)) {
		my ( $rc, $out ) = _wiki( $co, 'note', $bad, "$dir/obs.md" );
		isnt( $rc, 0, "note refuses $bad (LIB-WIKI-6)" );
	}

	# The ste-lint file walk skips this prefix, so a page that uses
	# it would never meet the prose gate (LIB-PAGES-3).
	my ( $rc, $out ) = _wiki( $co, 'note', 'SCRATCHPAD-1', "$dir/obs.md" );
	isnt( $rc, 0, 'note refuses a SCRATCHPAD page name' );
};

subtest 'close marks the page and stays idempotent' => sub {
	my $dir    = tempdir( CLEANUP => 1 );
	my $origin = _origin($dir);
	my $co     = _checkout( $dir, 'c1', $origin );
	_wiki( $co, 'open', 'FuguSTX', 'sess-1' );
	_write( "$dir/obs.md", "Claim: x\n" );
	_wiki( $co, 'note', "Session-FuguSTX-$today-1", "$dir/obs.md" );

	my ( $rc, $out ) = _wiki( $co, 'close', 'sess-1' );
	is( $rc, 0, 'close exits zero' );

	( $rc, $out ) = _wiki( $co, 'close', 'sess-1' );
	like( $out, qr/already closed/, 'a second close changes nothing' );

	( $rc, $out ) = _wiki( $co, 'status' );
	like( $out, qr/open sessions: none/, 'a closed page is not open' );

	# A session that ran no campaign has no page, and that is
	# normal (LIB-HOOKS-5).
	( $rc, $out ) = _wiki( $co, 'close', 'sess-never-opened' );
	is( $rc, 0, 'close of an unknown session exits zero' );
};

subtest 'the hooks skip a sub-agent and find the checkout' => sub {
	my $dir    = tempdir( CLEANUP => 1 );
	my $origin = _origin($dir);
	my $co     = _checkout( $dir, 'c1', $origin );

	# An observer dispatches an operator for each step and a
	# verifier for each claim. Without this test each of them opens
	# its own page (LIB-HOOKS-3).
	is(
		_hook( 'hook-start',
			qq({"session_id":"s1","cwd":"$co","agent_id":"a1"}) ),
		0,
		'a sub-agent payload exits zero'
	);
	is( scalar( glob "$co/Wiki/Session-*" ),
		undef, 'a sub-agent opens no page' );

	is( _hook( 'hook-start', qq({"session_id":"s1","cwd":"$co"}) ),
		0, 'a main session payload exits zero' );
	my @pages = glob "$co/Wiki/Session-Workspace-*";
	is( scalar @pages, 1, 'the main session opens one page' );

	# A session under Projects/<name> belongs to that project.
	make_path("$co/Projects/FuguSTX");
	is(
		_hook( 'hook-start',
			qq({"session_id":"s2","cwd":"$co/Projects/FuguSTX"}) ),
		0,
		'a project session exits zero'
	);
	@pages = glob "$co/Wiki/Session-FuguSTX-*";
	is( scalar @pages, 1, 'the project name comes from the path' );

	# A hook must never stop a session.
	is( _hook( 'hook-start', 'not json at all' ),
		0, 'a payload that does not parse exits zero' );
	is( _hook( 'hook-end', '{}' ), 0, 'a payload with no cwd exits zero' );
};

subtest 'candidates reports the undelivered ones with an age' => sub {
	my $dir    = tempdir( CLEANUP => 1 );
	my $origin = _origin($dir);
	my $co     = _checkout( $dir, 'c1', $origin );

	# The third item wraps: the prose gate reflows the page, so
	# "Delivered:" lands on a continuation line.
	_write(
		"$co/Wiki/Rule-candidates.md", <<'END'
# Rule candidates

- 2026-08-01 the observer must not edit code
- 2026-08-20 the verifier reads the log. Delivered: FuguTTX AGT-OBS-3
- 2026-08-21 a skill must export the project env, because the checkout
  shadows every project key. Delivered: FuguTTX AGT-SKILL-4
END
	);

	my ( $rc, $out ) = _wiki( $co, 'candidates' );
	is( $rc, 0, 'candidates exits zero' );
	like( $out, qr/the observer must not edit code/,
		'an undelivered candidate appears' );
	unlike( $out, qr/the verifier reads the log/,
		'a delivered candidate does not appear' );
	unlike( $out, qr/a skill must export the project env/,
		'a delivered candidate that wraps does not appear' );
	like( $out, qr/^\s*\d+ d\s+2026-08-01/m, 'the age is in days' );

	# The target runs inside make check, so a checkout with no
	# library must still pass (LIB-CANDIDATE-2).
	my $bare = tempdir( CLEANUP => 1 );
	( $rc, $out ) = _wiki( $bare, 'candidates' );
	is( $rc, 0, 'candidates exits zero with no library clone' );
};

done_testing();
