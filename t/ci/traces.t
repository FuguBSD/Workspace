#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Tests for scripts/traces.pl (WS-SESSION-5, WS-SESSION-6,
# WS-SESSION-7).
#
# The test makes a fixture trace root in a temp tree and runs the
# script with --root and --name. The root holds the checkout, one
# worktree of it, one project clone in it, and one sibling checkout
# that must stay out. No test reads the operator HOME, and no test
# writes outside its temp tree.

use v5.36;
use Test::More;
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
# then two requests. Request A writes three records, because one
# record carries one content block. Its Edit comes before the panel
# launch, so no count takes it. Request B holds the larger context,
# and its two edits come after the launch.
_write(
	"$main/$id.jsonl",
	$json->encode(
		{ type => 'user', timestamp => '2026-09-09T09:59:00.000Z' }
	  )
	    . "\n"
	    . _record( 'req_a', [ 10, 100, 1000 ], 50,
		{ type => 'text', text => 'x' } )
	    . _record( 'req_a', [ 10, 100, 1000 ], 50, _tool('Edit') )
	    . _record(
		'req_a',
		[ 10, 100, 1000 ],
		50,
		_tool( 'Agent', description => 'Panel review member 1' )
	    )
	    . _record( 'req_b', [ 20, 200, 2000 ], 60, _tool('Edit'),
		_tool('Write') )
);

# One sub-agent, with one request over two records.
_write(
	"$main/$id/subagents/agent-a1.jsonl",
	_record( 'req_s', [ 7, 70, 700 ], 5,
		{ type => 'text', text => 'x' } )
	    . _record( 'req_s', [ 7, 70, 700 ], 5, _tool('Read') )
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
is( $field[2], 2,                  'the record count is a request count' );
is( $field[3], 2220,      'the peak is the largest context of one request' );
is( $field[4], 110,       'the output of one request counts one time' );
is( $field[5], 1,         'one panel launch is one round' );
is( $field[6], 2,         'an edit before the launch does not count' );
is( $field[7], 777,       'the sub-agent input counts one time' );
is( $field[8], 5,         'the sub-agent output counts one time' );

like( $out, qr/^22222222/m, 'a worktree of the checkout joins' );
like( $out, qr/^44444444/m, 'a project clone joins' );
unlike( $out, qr/^33333333/m, 'a sibling checkout stays out' );

my ( $none_code, $none_out ) = _traces( $root, 'absent' );
is( $none_code, 0, 'a name with no trace directory exits zero' );
like( $none_out, qr/^no session of absent$/m, 'and it reports none' );

done_testing();
