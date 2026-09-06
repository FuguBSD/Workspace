#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Tests for the digest file deps/SHA256.txt against the manifests
# (WS-DEPS-7, WS-DEPS-8).
#
# The digest file records the bytes that each manifest entry
# downloads, and it keys each line on the download URL. The org pack
# of FuguBSD/Tooling must ship the check that reads the file, so this
# test is the only gate on it today. The test reads the files as text,
# so a fault shows at make check, before any download.
#
# The test holds no alias table: the table lives in scripts/deps. A
# digest URL belongs to a manifest entry when the URL of the entry
# matches it, with each placeholder as a wildcard. The test therefore
# cannot count the platforms of one entry, and the register records
# that gap.

use v5.36;
use Test::More;
use FindBin qw($RealBin);

my $root = "$RealBin/../..";

# The manifest environments and types. An unknown word in either
# column hides a line from scripts/deps, so the test names it.
my %ENVIRONMENTS = map { $_ => 1 } qw(tool runtime test develop);
my %TYPES        = map { $_ => 1 } qw(pkg dist cpan bin);

# _lines($path):
#	The lines of one file, or an empty list with a failed assertion.
sub _lines ($path)
{
	open my $fh, '<', $path or do {
		fail("$path is readable");
		return;
	};
	chomp( my @lines = <$fh> );
	close $fh;

	return @lines;
}

# _digests($path):
#	The URLs of the BSD-format digest file, with the digest of
#	each. A malformed line and a duplicate URL each fail one
#	assertion.
sub _digests ($path)
{
	my %digest;
	my $n = 0;
	for my $line ( _lines($path) ) {
		$n++;
		if ( $line !~ /\ASHA256 \(([^()\s]+)\) = ([0-9a-f]{64})\z/ ) {
			fail("$path:$n is a BSD-format sha256 line");
			next;
		}
		my ( $url, $sum ) = ( $1, $2 );
		if ( exists $digest{$url} ) {
			fail("$path:$n names $url one time only");
			next;
		}
		$digest{$url} = $sum;
	}

	return \%digest;
}

# _manifests($dir):
#	Each manifest file of the deps directory. SHA256.txt and the
#	key files are not manifests.
sub _manifests ($dir)
{
	opendir my $dh, $dir or do {
		fail("$dir is readable");
		return;
	};
	my @names = sort grep { /\.txt\z/ && !/\ASHA256\.txt\z/ && !/\AKEYS/ }
	    readdir $dh;
	closedir $dh;

	return @names;
}

# _archive($url):
#	True when the URL names an archive, which needs the file path
#	in the archive as its third word.
sub _archive ($url)
{
	return $url =~ /\.(?:tar\.gz|tgz|zip)\z/;
}

# _scan($dir):
#	Each download of each manifest, and each bad line. An entry
#	holds where it sits, its URL, and one regular expression for
#	that URL. A bin entry names the URL after the command, and a
#	dist entry is the URL. {os} and {arch} each match one asset
#	word.
sub _scan ($dir)
{
	my ( @entries, @bad );
	for my $manifest ( _manifests($dir) ) {
		my $n = 0;
		for my $line ( _lines("$dir/$manifest") ) {
			$n++;
			my ( $env, $type, @rest ) = split ' ', $line;
			next unless defined $env && index( $env, '#' ) != 0;

			my $where = "$manifest:$n";

			# A typo in either word hides the line from
			# scripts/deps, so name it here.
			if ( !$ENVIRONMENTS{ $env // q{} } ) {
				push @bad, "$where: unknown environment: $line";
				next;
			}
			if ( !$TYPES{ $type // q{} } ) {
				push @bad, "$where: unknown type: $line";
				next;
			}
			if ( !@rest ) {
				push @bad, "$where: no name: $line";
				next;
			}
			next unless $type =~ /\A(?:bin|dist)\z/;

			my $url = $type eq 'bin' ? $rest[1] : $rest[0];
			if ( !defined $url || $url !~ m{\A[a-z]+://}i ) {
				push @bad, "$where: no URL: $line";
				next;
			}
			if ( $type eq 'bin'
				&& _archive($url) != defined $rest[2] )
			{
				push @bad,
				    "$where: an archive needs a member: $line";
				next;
			}

			my $pattern = join q{}, map {
				      $_ eq '{os}'   ? '[A-Za-z0-9]+'
				    : $_ eq '{arch}' ? '[A-Za-z0-9_]+'
				    :                  quotemeta
			} split /(\{os\}|\{arch\})/, $url;
			push @entries,
			    {
				where  => "$where: $line",
				url    => $url,
				latest => scalar( $url =~ m{/releases/latest/} ),
				re     => qr/\A$pattern\z/,
			    };
		}
	}

	return ( \@entries, \@bad );
}

my $digests = _digests("$root/deps/SHA256.txt");
my ( $entries, $bad ) = _scan("$root/deps");

ok( scalar %$digests, 'deps/SHA256.txt holds a digest' );
ok( scalar @$entries, 'a manifest holds a download' );
is( scalar @$bad, 0, 'every manifest line is well formed' )
    or diag( join "\n", @$bad );

# Each versioned download has a digest (WS-DEPS-7). A download of the
# latest release has none, because its bytes change with each release
# (WS-DEPS-8).
for my $entry (@$entries) {
	my @urls = grep { $_ =~ $entry->{re} } sort keys %$digests;
	if ( $entry->{latest} ) {
		is( "@urls", q{},
			"no digest for the latest release $entry->{url}" );
		next;
	}
	ok( scalar @urls, "a digest exists for $entry->{where}" );
}

# Each digest belongs to a download. A URL without one is a typo, or a
# leftover of a version bump.
for my $url ( sort keys %$digests ) {
	ok( ( grep { $url =~ $_->{re} } @$entries ),
		"$url belongs to a manifest entry" );
}

done_testing();
