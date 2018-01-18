package Mojo::Autotask::Backend;
use Mojo::Base -base;

use Carp 'croak';

has [qw/autotask config/];

has table_prefix => 'at_';
has table => sub { {} };

sub is_table { shift->{+shift()} }
sub last_modified { croak 'Method "lastmodified" not implemented by subclass' }

sub delete { croak 'Method "delete" not implemented by subclass' }
sub insert { croak 'Method "insert" not implemented by subclass' }
sub select { croak 'Method "select" not implemented by subclass' }
sub update { croak 'Method "update" not implemented by subclass' }

1;
