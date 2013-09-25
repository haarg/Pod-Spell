package Pod::Wordlist;
use strict;
use warnings;
use File::Slurp                    qw( read_file );
use Lingua::EN::Inflect            qw( PL        );
use File::ShareDir::ProjectDistDir qw( dist_file );

use Class::Tiny {
    wordlist  => \&_copy_wordlist,
    _is_debug => 0,
};

use constant MAXWORDLENGTH => 50; ## no critic ( ProhibitConstantPragma )

# VERSION

our %Wordlist; ## no critic ( Variables::ProhibitPackageVars )

sub _copy_wordlist { return { %Wordlist } }

foreach ( read_file( dist_file('Pod-Spell', 'wordlist') ) ) {
	chomp( $_ );
	$Wordlist{$_} = 1;
	$Wordlist{PL($_)} = 1;
}

=method learn_stopwords

    $wordlist->learn_stopwords( $text );

Modifies the stopword list based on a text block. See the rules
for <adding stopwords|Pod::Spell/ADDING STOPWORDS> for details.

=cut

sub learn_stopwords {
	my ( $self, $text ) = @_;
	my $stopwords = $self->wordlist;

	while ( $text =~ m<(\S+)>g ) {
		my $word = $1;
		if ( $word =~ m/^!(.+)/s ) {
			# "!word" deletes from the stopword list
			my $negation = $1;
			# different $1 from above
			delete $stopwords->{$negation};
			delete $stopwords->{PL($negation)};
			print "Unlearning stopword $word\n" if $self->_is_debug;
		}
		else {
			$word =~ s{'s$}{}; # we strip 's when checking so strip here, too
			$stopwords->{$word} = 1;
			$stopwords->{PL($word)} = 1;
			print "Learning stopword $word\n" if $self->_is_debug;
		}
	}
	return;
}

=method is_stopword

	if ( $wordlist->is_stopword( $word ) ) { ... }

Returns true if the word is found in the stoplist.

=cut

sub is_stopword {
	my ($self, $word) = @_;
	my $stopwords = $self->wordlist;
	if ( exists $stopwords->{$word} or exists $stopwords->{ lc $word } ) {
		print " [Rejecting \"$word\" as a stopword]\n"
			if $self->_is_debug;
		return 1;
	}
	return;
}

=method strip_stopwords

    my $out = $wordlist->strip_stopwords( $text );

Returns a string with space separated words from the original
text with stopwords removed.

=cut

sub strip_stopwords {
	my ($self, $text) = @_;

	# Count the things in $text
	print "Content: <", $text, ">\n" if $self->_is_debug;

	my $word;
	$text =~ tr/\xA0\xAD/ /d;

	# i.e., normalize non-breaking spaces, and delete soft-hyphens

	my $out = '';

	while ( $text =~ m<(\S+)>g ) {

		# Trim normal English punctuation, if leading or trailing.
		next if length $1 > MAXWORDLENGTH;
		my $word = $self->_extract_word($1);
		next unless length $word;

		if ( _sigil_or_strange( $word ) ) {
			print "rejecting {$word}\n" if $self->_is_debug && $word ne '_';
			next;
		}
		elsif ( length( my $remainder = $self->_strip_a_word($word) ) ) {
			$out .= "$remainder ";
		}
	}

	return $out;
}

sub _extract_word {
	my ($self, $word) = @_;

	# strip trailing punctuation; we don't strip periods so we don't
	# chop abbreviations like "Ph.D."
	$word =~ s/([\)\]\'\"\:\;\,\?\!]+)$//s;

	# strip possessive
	$word =~ s/('s)$//is;

	# strip leading punctuation
	$word =~ s/^([\`\"\'\(\[]+)//s;

	print "Found word: <$word>\n" if length $word && $self->_is_debug;

	return ($word);
}

sub _sigil_or_strange {
	my ($word) = @_;

	my $is_sigil 	= $word =~ m/^[\&\%\$\@\:\<\*\\\_]/s;
	my $is_strange 	= $word =~ m/[\%\^\&\#\$\@\_\<\>\(\)\[\]\{\}\\\*\:\+\/\=\|\`\~]/;
	return $is_sigil || $is_strange;
}

sub _strip_a_word {
	my ($self, $word) = @_;
	my $remainder = '';
	# might have trailing period(s) or an internal dash, so first, just check
	# as is in case that's actually in the word list
	if ($self->is_stopword($word) ) {
		# stopword, so do nothing
	}
	elsif ( $word =~ /-/ ) {
		# check individual parts, keep whatever isn't a stopword
		my @keep;
		for my $part ( split /-/, $word ) {
			push @keep, $part if ! $self->is_stopword( $part );
		}
		$remainder = join("-", @keep) if @keep;
	}
	elsif ( $word =~ m{(.*?)\.+$}) {
		# trailing period could be end of sentence or ellipses
		my $part = $1;
		$remainder = $word if ! $self->is_stopword( $part );
	}
	else {
		$remainder = $word;
	}
	return $remainder;
}

1;

# ABSTRACT: English words that come up in Perl documentation
=pod

=head1 DESCRIPTION

Pod::Wordlist is used by L<Pod::Spell|Pod::Spell>, providing a set of words
that are English jargon words that come up in Perl documentation, but which are
not to be found in general English lexicons.  (For example: autovivify,
backreference, chroot, stringify, wantarray.)

You can also use this wordlist with your word processor by just
pasting C<share/wordlist>'s content into your wordprocessor, deleting
the leading Perl code so that only the wordlist remains, and then
spellchecking this resulting list and adding every word in it to your
private lexicon.

=head1 WORDLIST

Note that the scope of this file is only English, specifically American
English.  (But you may find in useful to incorporate into your own
lexicons, even if they are for other dialects/languages.)

remove any q{'s} before adding to the list.

The list should be sorted and uniqued. The following will work (with GNU
Coreutils ).

	sort share/wordlist -u > /tmp/sorted && mv /tmp/sorted share/wordlist

=attr wordlist

	ref $self->wordlist eq 'HASH'; # true

This is the instance of the wordlist
