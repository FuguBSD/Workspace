#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Tests for scripts/traces.pl (WS-SESSION-5, WS-SESSION-6,
# WS-SESSION-7, WS-SESSION-8).
#
# The test makes a fixture trace root in a temp tree and runs the
# script with --root and --name. The root holds the checkout, one
# worktree of it, one project clone in it, and one sibling checkout
# that must stay out. The checkout holds one session with no request,
# and two sessions that hold a scratch path. The last test copies the
# script into a nested marker path and runs it with --root only, which
# reaches the name derivation. No test reads the operator HOME, and no
# test writes outside its temp tree.

use v5.36;
use Test::More;
use Cwd        qw(abs_path);
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use FindBin    qw($RealBin);
use JSON::PP   ();

my $script = "$RealBin/../../scripts/traces.pl";
my $json   = JSON::PP->new->canonical;

# _write($path, $text):
#	Write one file, and make its parent directories.
sub _write ( $path, $text )
{
	make_path( $path =~ s{/[^/]+\z}{}r );
	open my $fh, '>', $path or die "write $path: $!";
	print {$fh} $text;
	close $fh;
}

# _tool($name, %input):
#	One tool_use content block.
sub _tool ( $name, %input )
{
	return {
		type  => 'tool_use',
		id    => "toolu_$name",
		name  => $name,
		input => {%input},
	};
}

# _record($req, $context, $out, @blocks):
#	One assistant record. $context holds the three input counts,
#	which the script adds together.
sub _record ( $req, $context, $out, @blocks )
{
	return $json->encode(
		{
			type      => 'assistant',
			timestamp => '2026-09-09T10:00:00.000Z',
			requestId => $req,
			message   => {
				role  => 'assistant',
				usage => {
					input_tokens => $context->[0],
					cache_creation_input_tokens =>
					    $context->[1],
					cache_read_input_tokens =>
					    $context->[2],
					output_tokens => $out,
				},
				content => [@blocks],
			},
		}
	) . "\n";
}

# _meta($path, $tool):
#	The meta file of one sub-agent trace. It carries the
#	identifier of the tool_use block that launched the sub-agent.
sub _meta ( $path, $tool )
{
	_write( $path, $json->encode( { toolUseId => $tool } ) . "\n" );
}

# _session($id):
#	A one-request trace, as the smallest session that gets a row.
sub _session ($id)
{
	return _record( "req_$id", [ 1, 2, 3 ], 4,
		{ type => 'text', text => 'x' } );
}

# _traces($root, $name):
#	Run the script against the fixture root. The exit code and the
#	output.
sub _traces ( $root, $name )
{
	my $out = qx("$^X" "$script" --root "$root" --name "$name" 2>&1);

	return ( $? >> 8, $out );
}

my $root = tempdir( CLEANUP => 1 );
my $main = "$root/fixture";
my $id   = '11111111-1111-1111-1111-111111111111';

# The main session: one leading record that carries the start time,
# then three requests. Request A writes three records, because one
# record carries one content block. Its first two records carry a
# partial count, and its last record carries the full count, which
# holds the peak of the file. Its Edit comes before the panel launch,
# so no count takes it. Request B holds two edits after the launch.
# Request C writes two files under scratch/, one path relative and one
# path absolute, which no count takes.
_write(
	"$main/$id.jsonl",
	$json->encode(
		{ type => 'user', timestamp => '2026-09-09T09:59:00.000Z' }
	  )
	    . "\n"
	    . _record( 'req_a', [ 1, 20, 300 ], 5,
		{ type => 'text', text => 'x' } )
	    . _record( 'req_a', [ 2, 30, 400 ], 10, _tool('Edit') )
	    . _record(
		'req_a',
		[ 30, 300, 3000 ],
		70,
		_tool( 'Agent', description => 'Panel review member 1' )
	    )
	    . _record( 'req_b', [ 20, 200, 2000 ], 60, _tool('Edit'),
		_tool('Write') )
	    . _record(
		'req_c',
		[ 5, 50, 500 ],
		10,
		_tool( 'Write', file_path => 'scratch/review/ledger.md' ),
		_tool(
			'NotebookEdit',
			notebook_path => "$main/scratch/note.ipynb"
		)
	    )
);

# Two sub-agents of the session. Agent A1 is the panel member: its
# meta file names the launch of request A, and _tool gives that block
# the identifier toolu_Agent. A1 holds two requests, one of them over
# two records, so its peak is smaller than its input total. Agent A2
# holds the larger peak, and its meta file names another launch, so
# rev-peak must leave A2 out.
_write(
	"$main/$id/subagents/agent-a1.jsonl",
	_record( 'req_s1', [ 7, 70, 700 ], 5,
		{ type => 'text', text => 'x' } )
	    . _record( 'req_s1', [ 7, 70, 700 ], 5, _tool('Read') )
	    . _record( 'req_s2', [ 8, 80, 800 ], 6, _tool('Read') )
);
_meta( "$main/$id/subagents/agent-a1.meta.json", 'toolu_Agent' );

_write( "$main/$id/subagents/agent-a2.jsonl",
	_record( 'req_t', [ 90, 900, 9000 ], 7, _tool('Read') ) );
_meta( "$main/$id/subagents/agent-a2.meta.json", 'toolu_other' );

# A session that holds records but no assistant record never reached
# the model, so it gets no row (WS-SESSION-5).
my $quiet = $json->encode(
	{ type => 'user', timestamp => '2026-09-09T10:01:00.000Z' } );
_write( "$main/77777777-7777.jsonl", "$quiet\n$quiet\n" );

# Two more sessions of the checkout, each one with a panel launch and
# then the writes of a scratch path. Session 8 holds the two files that
# .gitignore covers, and the edits column must take neither one.
# Session 9 holds three near misses, and it must take every one: the
# name must start a path segment, and a scratchpad must end the path
# (WS-SESSION-8).
_write(
	"$main/88888888-8888.jsonl",
	_record( 'req_p1', [ 1, 2, 3 ], 4,
		_tool( 'Agent', description => 'Panel review member 1' ) )
	    . _record( 'req_p2', [ 1, 2, 3 ], 4,
		_tool( 'Write', file_path => 'SCRATCHPAD-1.md' ),
		_tool( 'Write', file_path => "$main/SCRATCHPAD-2.md" ) )
);
_write(
	"$main/99999999-9999.jsonl",
	_record( 'req_n1', [ 1, 2, 3 ], 4,
		_tool( 'Agent', description => 'Panel review member 1' ) )
	    . _record( 'req_n2', [ 1, 2, 3 ], 4,
		_tool( 'Write', file_path => 'myscratch/x.md' ),
		_tool( 'Write', file_path => 'NOTSCRATCHPAD.md' ),
		_tool( 'Write', file_path => 'SCRATCHPAD-3.md.bak' ) )
);

# One worktree of the checkout, one project clone in it, and one
# sibling checkout that the match must reject.
_write( "$root/fixture--claude-worktrees-w1/22222222-2222.jsonl",
	_session('w') );
_write( "$root/fixture-backup/33333333-3333.jsonl", _session('b') );
_write( "$root/fixture-Projects-Tooling/44444444-4444.jsonl",
	_session('p') );

my ( $code, $out ) = _traces( $root, 'fixture' );
is( $code, 0, 'traces exits zero' );

my ($row) = grep { /^11111111\b/ } split /\n/, $out;
ok( $row, 'the main session gets a row' ) or diag $out;
my @field = split q{ }, $row // q{};

is( $field[1], '2026-09-09T09:59', 'the start time is the first record' );
is( $field[2], 3,                  'the record count is a request count' );
is( $field[3], 3330,      'the peak reads the last record of a request' );
is( $field[4], 140,       'the output reads the last record of a request' );
is( $field[5], 1,         'one panel launch is one round' );
is( $field[6], 2,
	'an edit before the launch, and a write under scratch/, do not count' );
is( $field[7], 11655,     'the sub-agent input counts one time' );
is( $field[8], 18,        'the sub-agent output counts one time' );
is( $field[9], 888,       'rev-peak reads the peak of the panel member' );

like( $out, qr/^22222222/m, 'a worktree of the checkout joins' );
like( $out, qr/^44444444/m, 'a project clone joins' );
unlike( $out, qr/^33333333/m, 'a sibling checkout stays out' );

unlike( $out, qr/^77777777/m, 'a session with no request gets no row' );

my @pad  = split q{ }, ( grep { /^88888888\b/ } split /\n/, $out )[0] // q{};
my @near = split q{ }, ( grep { /^99999999\b/ } split /\n/, $out )[0] // q{};
is( $pad[6], 0, 'a SCRATCHPAD*.md write is not an edit' ) or diag $out;
is( $near[6], 3, 'a near miss of the scratch pattern is an edit' )
	or diag $out;

my ( $none_code, $none_out ) = _traces( $root, 'absent' );
is( $none_code, 0, 'a name with no trace directory exits zero' );
like( $none_out, qr/^no session of absent$/m, 'and it reports none' );

# Without --name, the script derives the name from its own path, cut
# at the last .claude/worktrees/ marker (WS-SESSION-6, WS-HOOKS-4).
# The copy sits under two markers. The last marker names the inner
# checkout, and the first one names the outer checkout, whose trace
# directory must stay out.
my $nest = tempdir( CLEANUP => 1 );
my $deep = "$nest/.claude/worktrees/a/.claude/worktrees/b";
make_path("$deep/scripts");
copy( $script, "$deep/scripts/traces.pl" ) or die "copy: $!";

my $outer = abs_path($nest) =~ s/[^A-Za-z0-9-]/-/gr;
my $inner = abs_path("$nest/.claude/worktrees/a") =~ s/[^A-Za-z0-9-]/-/gr;
_write( "$nest/traces/$inner/55555555-5555.jsonl", _session('n') );
_write( "$nest/traces/$outer/66666666-6666.jsonl", _session('o') );

my $deep_out =
	qx("$^X" "$deep/scripts/traces.pl" --root "$nest/traces" 2>&1);
is( $? >> 8, 0, 'the derived name exits zero' );
like( $deep_out, qr/^55555555/m, 'the derivation cuts at the last marker' )
	or diag $deep_out;
unlike( $deep_out, qr/^66666666/m, 'and the outer checkout stays out' );

done_testing();
