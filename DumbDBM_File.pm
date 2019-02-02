package DumbDBM_File;

# DumbDBM_File - Portable DBM implementation
#
# Based on Python's dumbdbm / dbm.dumb
#
# Author: Patrick Canterino <patrick@patrick-canterino.de>
# License: 2-Clause BSD License

use strict;

use Carp qw(carp croak);
use Fcntl;

our $VERSION = '0.1';

our $_BLOCKSIZE = 512;

sub _update {
	my $self = shift;
	local *FILE;

	$self->{'_index'} = { };

	open(FILE,'<'.$self->{'_dirfile'}) or carp $!;

	while(<FILE>) {
		my $line = $_;
		$line =~ s/\s+$//g;

		my ($key,@pos_and_siz_pair) = eval($line);
		$self->{'_index'}->{$key} = \@pos_and_siz_pair;
	}
}

sub _commit {
	my $self = shift;

	unlink($self->{'_bakfile'});
	rename($self->{'_dirfile'},$self->{'_bakfile'});

	open(FILE,'>'.$self->{'_dirfile'}) or carp $!;

	while(my($key,$pos_and_siz_pair) = each(%{$self->{'_index'}})) {
		print FILE "'$key', ($pos_and_siz_pair->[0], $pos_and_siz_pair->[1])\n";
	}

	close(FILE);
}

sub _addval {
	my ($self,$val) = @_;
	local *FILE;

	open(FILE,'+<'.$self->{'_datfile'}) or carp $!;
	binmode(FILE);
	seek(FILE,0,2);

	my $pos = tell(FILE);
	my $npos = int(($pos + $_BLOCKSIZE - 1) / $_BLOCKSIZE) * $_BLOCKSIZE;

	print FILE "\0" x ($npos-$pos);

	$pos = $npos;

	print FILE $val;

	close(FILE);

	return ($pos,length($val));
}

sub _setval {
	my ($self,$pos,$val) = @_;
	local *FILE;

	open(FILE,'+<'.$self->{'_datfile'}) or carp $!;
	binmode(FILE);
	seek(FILE,$pos,0);
	print FILE $val;
	close(FILE);

	return ($pos,length($val));
}

sub _addkey {
	my ($self,$key,@pos_and_siz_pair) = @_;
	local *FILE;

	$self->{'_index'}->{$key} = \@pos_and_siz_pair;

	open(FILE,'>>'.$self->{'_dirfile'}) or carp $!;
	print FILE "'$key', ($pos_and_siz_pair[0], $pos_and_siz_pair[1])\n";
	close(FILE);
}

sub TIEHASH {
	my ($class,$file) = @_;
	local *FILE;

	my $hash = { };

	$hash->{'_dirfile'} = $file.'.dir';
	$hash->{'_datfile'} = $file.'.dat';
	$hash->{'_bakfile'} = $file.'.bak';

	$hash->{'_index'}   = { };

	sysopen(FILE,$hash->{'_datfile'},O_RDONLY | O_CREAT) or carp $!;
	close(FILE);

	my $self = bless($hash,$class);
	$self->_update;

	return $self;
}

sub EXISTS {
	my ($self,$key) = @_;
	return exists($self->{'_index'}->{$key});
}

sub FETCH {
	my ($self,$key) = @_;
	local *FILE;

	my $pos = $self->{'_index'}->{$key}->[0];
	my $siz = $self->{'_index'}->{$key}->[1];

	open(FILE,'<'.$self->{'_datfile'}) or carp $!;
	binmode(FILE);
	seek(FILE,$pos,0);
	read(FILE, my $dat, $siz);
	close(FILE);

	return $dat;
}

sub STORE {
	my ($self,$key,$val) = @_;

	if(not exists($self->{'_index'}->{$key})) {
		$self->_addkey($key,$self->_addval($val));
	}
	else {
		my $pos = $self->{'_index'}->{$key}->[0];
		my $siz = $self->{'_index'}->{$key}->[1];

		my $oldblocks = int(($siz + $_BLOCKSIZE -1) / $_BLOCKSIZE);
		my $newblocks = int((length($val) + $_BLOCKSIZE -1) / $_BLOCKSIZE);

		if($newblocks <= $oldblocks) {
			my @pos_and_siz_pair = $self->_setval($pos,$val);
			$self->{'_index'}->{$key} = \@pos_and_siz_pair;
		}
		else {
			my @pos_and_siz_pair = $self->_addval($val);
			$self->{'_index'}->{$key} = \@pos_and_siz_pair;
		}
	}
}

sub FIRSTKEY {
	my $self = shift;
	my $a = keys(%{$self->{'_index'}});
	each %{$self->{'_index'}};
}

sub DELETE {
	my ($self,$key) = @_;
	delete($self->{'_index'}->{$key});
	$self->_commit;
}

sub NEXTKEY {
	my $self = shift;
	each %{$self->{'_index'}};
}

sub UNTIE {
	my $self = shift;
	$self->_commit;

	$self->{'_dirfile'} = undef;
	$self->{'_datfile'} = undef;
	$self->{'_bakfile'} = undef;
}

# it's true, baby ;-)

1;

# Documentation

=pod

=head1 NAME

DumbDBM_File - Portable DBM implementation

=head1 SYNOPSIS

 use DumbDBM_File;

 # Opening a database file called "homer.db"
 # Creating it if necessary

 my %db;
 tie(%db,'DumbDBM_File','homer.db');

 # Assigning some values

 $db{'name'} = 'Homer';
 $db{'wife'} = 'Marge';
 $db{'child'} = 'Bart';
 $db{'neighbor'} = 'Flanders';

 # Print value of "name": Homer

 print $db{'name'};

 # Overwriting a value

 $db{'child'} = 'Lisa';

 # Remove a value
 # The value remains in the database file, just the index entry gets removed,
 # meaning you can't retrieve the value from the database file any more

 delete($db{'neighbor'});

 # Close the database file

 untie %db;

=head1 DESCRIPTION

This is a Perl implementation of Python's C<dumbdbm> / C<dbm.dumb> module. It
provides a simple DBM style database written entirely in Perl, requiring no
external library.

Beware that this module is slow and should only be used as a last resort
fallback when no more robust module like L<DB_File> is available.

This Perl implementation is fully compatible to the original Python one.

=head1 FILES

Consider having a database called example, you have up to three files:

=over 2

=item example.dir

This is an index file containing information for retrieving the values out of
the database. It is a text file containing the key, the file offset and the
size of each value.

=item example.dir.bak

This file B<may> contain a backup of the index file.

=item example.dat

This is the database file containing the values separated by zero bytes.

=back

=head1 BUGS AND PROBLEMS

This module is a direct port of the Python module containing the same bugs and
problems.

- Seems to contain a bug when updating (this information was directly taken
from a comment in C<dumbdbm>'s source code)

- Free space is not reclaimed

- No concurrent access is supported (if two processes access the database, they
may mess up the index)

- This module always reads the whole index file and some updates the whole
index

- No read-only mode

=head1 COPYRIGHT

Copyright (c) 2019, Patrick Canterino, <patrick@patrick-canterino.de>

This Perl module is licensed under the terms of the 2-Clause BSD License, see
file F<LICENSE> or L<https://opensource.org/licenses/BSD-2-Clause> for details.

=head1 AUTHOR

DumbDBM_File was written by Patrick Canterino
L<patrick@patrick-canterino.de|mailto:patrick@patrick-canterino.de>.

L<https://www.patrick-canterino.de/>

If you wonder why I wrote this: I felt boring ;)

=cut

#
### End ###