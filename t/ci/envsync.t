#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Tests for the envsync subcommand of scripts/worktree.pl
# (WS-ENVSYNC).
#
# Each test makes a temp tree with fake .env files and runs envsync
# in it. No test writes outside its temp tree, and no test uses a
# real credential. The bootstrap subtest reads mk/local.mk as text.

use v5.36;
use Test::More;
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use FindBin    qw($RealBin);
use JSON::PP   ();

my $script   = "$RealBin/../../scripts/worktree.pl";
my $settings = '.claude/settings.local.json';

# _envsync($dir):
#	Run envsync in $dir. The exit code and the combined output.
sub _envsync ($dir)
{
	my $out = qx(cd "$dir" && "$^X" "$script" envsync 2>&1);
	return ( $? >> 8, $out );
}

# _tree():
#	A temp checkout root: a temp directory with an empty .git
#	directory, per WS-ENVSYNC-1.
sub _tree ()
{
	my $dir = tempdir( CLEANUP => 1 );
	mkdir "$dir/.git" or die "mkdir $dir/.git: $!";

	return $dir;
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

# _slurp($path):
#	Whole file as text.
sub _slurp ($path)
{
	open my $fh, '<', $path or die "read $path: $!";
	local $/ = undef;
	my $text = <$fh>;
	close $fh;

	return $text;
}

# _env($dir):
#	The decoded settings file of one temp tree.
sub _env ($dir)
{
	return JSON::PP->new->utf8->decode( _slurp("$dir/$settings") );
}

subtest 'envsync stops outside a checkout root' => sub {
	my $dir = tempdir( CLEANUP => 1 );
	_write( "$dir/.env", "A=1\n" );
	my ( $exit, $out ) = _envsync($dir);
	is( $exit, 1, 'exit 1, not the usage code 2' );
	like( $out, qr{no \.git here}, 'the error names the cause' );
	ok( !-e "$dir/$settings", 'no settings file appears' );
};

subtest 'no .env files and no settings file' => sub {
	my $dir = _tree();
	my ( $exit, $out ) = _envsync($dir);
	is( $exit, 0, 'exit 0' );
	ok( !-e "$dir/$settings", 'no settings file appears' );
};

subtest 'a keyless .env makes no settings file' => sub {
	my $dir = _tree();
	_write( "$dir/.env", "# only a comment\n" );
	my ( $exit, undef ) = _envsync($dir);
	is( $exit, 0, 'exit 0' );
	ok( !-e "$dir/$settings", 'no settings file appears' );
};

subtest 'create-new, parse, and depth precedence' => sub {
	my $dir = _tree();
	_write( "$dir/.env",
		    "ROOT_ONLY=from-root\n"
		  . "SHARED=root-wins\n"
		  . "\n"
		  . "# A comment and a blank line do not match.\n"
		  . "1BAD=skipped\n"
		  . "export FOO=skipped\n"
		  . "QUOTED=\"stays verbatim\"\n"
		  . "CRLF=stripped\r\n" );
	_write( "$dir/Projects/Deep/.env", <<'EOF' );
SHARED=deep-secret-value
DEEP_ONLY=from-deep
EOF

	my ( $exit, $out ) = _envsync($dir);
	is( $exit, 0, 'exit 0' );

	my $env = _env($dir)->{env};
	is( $env->{ROOT_ONLY}, 'from-root',          'root key merges' );
	is( $env->{SHARED},    'root-wins',          'the shallowest file wins' );
	is( $env->{DEEP_ONLY}, 'from-deep',          'a scoped key merges' );
	is( $env->{QUOTED},    '"stays verbatim"',   'no quote processing' );
	is( $env->{CRLF},      'stripped',           'a CRLF line ending goes away' );
	ok( !exists $env->{'1BAD'} && !exists $env->{FOO},
		'a bad line and an export line do not match' );

	like( $out, qr{Projects/Deep/\.env}, 'the warning names the file' );
	like( $out, qr{shadowed keys: SHARED}, 'the warning names the key' );
	unlike( $out, qr{deep-secret-value}, 'no output holds a value' );

	my $mode = ( stat "$dir/$settings" )[2] & 07777;
	is( $mode, 0600, 'the settings file has mode 0600' );
};

subtest 'a repeat inside one file is not a shadow' => sub {
	my $dir = _tree();
	_write( "$dir/.env", "A=first\nA=second\n" );
	my ( $exit, $out ) = _envsync($dir);
	is( $exit, 0, 'exit 0' );
	unlike( $out, qr{shadowed}, 'no shadow warning' );
	is( _env($dir)->{env}{A}, 'first', 'the first statement wins' );
};

subtest 'envsync rejects -C as a usage error' => sub {
	my $dir = _tree();
	_write( "$dir/.env", "A=1\n" );
	my $out =
	    qx(cd "$dir" && "$^X" "$script" -C "$dir" envsync 2>&1);
	is( $? >> 8, 2, 'exit 2' );
	like( $out, qr{^usage:}m, 'usage text appears' );
	ok( !-e "$dir/$settings", 'no settings file appears' );
};

subtest 'the path breaks a tie at equal depth' => sub {
	my $dir = _tree();
	_write( "$dir/a/.env", "KEY=from-a\n" );
	_write( "$dir/b/.env", "KEY=from-b\n" );
	my ( $exit, $out ) = _envsync($dir);
	is( $exit, 0, 'exit 0' );
	is( _env($dir)->{env}{KEY}, 'from-a', 'the first path wins' );
	like( $out, qr{b/\.env}, 'the warning names the later file' );
};

subtest 'a re-run is byte-identical' => sub {
	my $dir = _tree();
	_write( "$dir/.env",     "B=2\nA=1\n" );
	_write( "$dir/sub/.env", "C=3\n" );
	_envsync($dir);
	my $first = _slurp("$dir/$settings");
	my ( $exit, undef ) = _envsync($dir);
	is( $exit, 0, 'exit 0' );
	is( _slurp("$dir/$settings"), $first, 'byte-identical output' );
};

subtest 'envsync keeps each other top-level key' => sub {
	my $dir = _tree();
	_write( "$dir/.env", "NEW=1\n" );
	_write( "$dir/$settings",
		    '{"env":{"OLD":"gone"},'
		  . '"permissions":{"deny":["WebFetch"]}}' );

	my ( $exit, undef ) = _envsync($dir);
	is( $exit, 0, 'exit 0' );

	my $data = _env($dir);
	is( $data->{env}{NEW}, '1', 'the new key is in the env object' );
	ok( !exists $data->{env}{OLD}, 'envsync owns the whole env object' );
	is_deeply(
		$data->{permissions},
		{ deny => ['WebFetch'] },
		'the permissions key stays'
	);
};

subtest 'an empty merge removes the env object' => sub {
	my $dir = _tree();
	_write( "$dir/$settings", '{"env":{"OLD":"gone"},"other":true}' );
	my ( $exit, undef ) = _envsync($dir);
	is( $exit, 0, 'exit 0' );
	my $data = _env($dir);
	ok( !exists $data->{env}, 'the env object is gone' );
	ok( $data->{other},       'the other key stays' );
};

subtest 'a settings file that does not parse stops envsync' => sub {
	my $dir = _tree();
	_write( "$dir/.env",      "A=1\n" );
	_write( "$dir/$settings", "{ nope" );
	my ( $exit, $out ) = _envsync($dir);
	isnt( $exit, 0, 'nonzero exit' );
	like( $out, qr{does not parse}, 'the error names the cause' );
	is( _slurp("$dir/$settings"), '{ nope', 'the file did not change' );
	my @tmp = glob "$dir/$settings.tmp*";
	is( scalar @tmp, 0, 'no temp file stays' );
};

subtest 'a settings file that is not a JSON object stops envsync' => sub {
	my $dir = _tree();
	_write( "$dir/.env",      "A=1\n" );
	_write( "$dir/$settings", "[1, 2]\n" );
	my ( $exit, $out ) = _envsync($dir);
	isnt( $exit, 0, 'nonzero exit' );
	like( $out, qr{not a JSON object}, 'the error names the cause' );
	is( _slurp("$dir/$settings"), "[1, 2]\n", 'the file did not change' );
};

subtest 'UTF-8 survives the round trip' => sub {
	my $dir = _tree();
	_write( "$dir/.env",      "UMLAUT=\xc3\xbcber\n" );
	_write( "$dir/$settings", "{\"note\":\"caf\\u00e9\"}" );
	my ( $exit, undef ) = _envsync($dir);
	is( $exit, 0, 'exit 0' );
	my $data = _env($dir);
	is( $data->{env}{UMLAUT}, "\x{fc}ber", 'a .env value keeps its character' );
	is( $data->{note}, "caf\x{e9}", 'a settings value keeps its character' );
	my ( $exit2, undef ) = _envsync($dir);
	is( $exit2, 0, 'a re-run stays valid' );
};

subtest 'a .env that is not valid UTF-8 stops envsync' => sub {
	my $dir = _tree();
	_write( "$dir/.env", "BAD=\xe9\n" );
	my ( $exit, $out ) = _envsync($dir);
	isnt( $exit, 0, 'nonzero exit' );
	like( $out, qr{not valid UTF-8}, 'the error names the cause' );
	ok( !-e "$dir/$settings", 'no settings file appears' );
};

subtest 'the bootstrap target runs envsync after its clone step' => sub {
	my $mk = _slurp("$RealBin/../../mk/local.mk");
	my ($recipe) = $mk =~ /^bootstrap:\n((?:\t[^\n]*\n)+)/m;
	ok( defined $recipe, 'the bootstrap recipe exists' ) or return;
	like(
		$recipe,
		qr{^\t\@perl scripts/worktree\.pl envsync$}m,
		'the recipe runs envsync'
	);
	cmp_ok( index( $recipe, 'clone' ), '>=', 0,
		'the recipe has a clone step' );
	cmp_ok(
		index( $recipe, 'envsync' ), '>', index( $recipe, 'clone' ),
		'envsync comes after the clone step'
	);
};

subtest 'envsync skips a symlink and prunes .git and worktrees' => sub {
	my $dir = _tree();
	_write( "$dir/.env",                            "KEEP=1\n" );
	_write( "$dir/link-target.txt",                 "LINKED=1\n" );
	_write( "$dir/proj/.git/.env",                  "GITKEY=1\n" );
	_write( "$dir/proj/.claude/worktrees/w/.env",   "WTKEY=1\n" );
	_write( "$dir/.claude/worktrees/w/.env",        "TOPWT=1\n" );
	_write( "$dir/explore/scratch/.env",            "SCRATCH=1\n" );
	make_path("$dir/sub");
	symlink( "$dir/link-target.txt", "$dir/sub/.env" )
	    or plan skip_all => 'no symlink support';

	my ( $exit, undef ) = _envsync($dir);
	is( $exit, 0, 'exit 0' );

	my $env = _env($dir)->{env};
	is( $env->{KEEP}, '1', 'the regular file merges' );
	ok( !exists $env->{LINKED}, 'a symlink .env is skipped' );
	ok( !exists $env->{GITKEY}, 'the walk prunes .git' );
	ok( !exists $env->{WTKEY},
		'the walk prunes a nested .claude/worktrees' );
	ok( !exists $env->{TOPWT},
		'the walk prunes the top-level .claude/worktrees' );
	ok( !exists $env->{SCRATCH},
		'the walk prunes an explore scratch directory' );
};

done_testing();
