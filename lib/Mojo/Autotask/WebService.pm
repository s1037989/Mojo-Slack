package Mojo::Autotask::WebService;
use Mojo::Base -base;

$|=1;

use Carp 'croak';
use Mojo::Log;
use Mojo::Date;
use Mojo::JSON 'j';
use Mojo::Util 'encode';
use Mojo::Collection;

use WebService::Autotask;

has 'format';
has log => sub { Mojo::Log->new };
has backend => sub { die "No backend initialized\n" };
has autotask => sub { die "No autotask configuration defined\n" };
has webservice => sub { state $webservice = WebService::Autotask->new(shift->autotask) };

has e_attr => sub { [qw/Name HasUserDefinedFields UserAccessForCreate UserAccessForQuery UserAccessForUpdate UserAccessForDelete CanCreate CanQuery CanUpdate CanDelete/] };
has f_attr => sub { [qw/Name Label Type Length IsReadOnly IsRequired ReferenceEntityType IsPickList PicklistParentValueField IsReference IsQueryable/] };
has p_attr => sub { [qw/Label Value parentValue SortOrder IsActive IsDefaultValue IsSystem/] };

has cache_time => 3600;
has [qw/quick_cache superquick_cache/];
has cache_basis => sub { {
    Account => 'LastActivityDate',
    AccountNote => 'LastModifiedDate',
    AccountToDo => 'LastModifiedDate',
    Contact => 'LastActivityDate and LastModifiedDate',
    ContractNote => 'LastActivityDate',
    Phase => 'LastActivityDateTime',
    ProjectNote => 'LastActivityDate',
    Service => 'LastModifiedDate',
    ServiceBundle => 'LastModifiedDate',
    ServiceCall => 'LastModifiedDateTime',
    Task => 'LastActivityDateTime',
    TaskNote => 'LastActivityDate',
    Ticket => 'LastActivityDate',
    TicketNote => 'LastAcivityDate',
    TimeEntry => 'LastModifiedDateTime',
    ContractCost => 'StatusLastModifiedDate',
    ProjectCost => 'StatusLastModifiedDate',
    TicketCost => 'StatusLastModifiedDate',
  }
};
has active => sub { [qw(Account ActionType AllocationCode ClassificationIcon Contact Country Currency InstalledProduct InstalledProductType InventoryLocation PaymentTerm Product ProductVendor QuoteTemplate Resource ResourceRole Role Skill TaxCategory TaxRegion)] };

sub _fetch {
  my $self = shift;
  my $cb = pop;
  my $col = Mojo::Collection->with_roles('+Key')->new;
  eval { my $res = $cb->(); push @$col, ref $res eq 'ARRAY' ? @$res : $res; };
  $self->log->error("WebService::Autotask: $@") if $@;
  return $col;
}

sub getThresholdAndUsageInfo {
  my $self = shift;
  my $col = $self->_fetch(sub{ $self->webservice->{at_soap}->getThresholdAndUsageInfo->result });
  if ( $self->format eq 'json' ) {
    return j($col->to_array);
  }
  return $col;
}

sub GetEntityInfo {
  my ($self, $entity) = @_;
  my $col = $self->_fetch(sub{ $self->webservice->{at_soap}->GetEntityInfo->result->{EntityInfo} });
  $col = $col->grepkey('Name', $entity)->sortkey('Name');
  if ( $self->format eq 'json' ) {
    return j($col->to_array);
  } elsif ( $self->format eq 'csv' ) {
    unshift @$col, {map { $_ => $_ } @{$self->e_attr}};
    return $col->map(sub{my $h=$_; $_ = join "\t", map { _tf($h->{$_}) } @{$self->e_attr}})->join("\n");
  }
  return $col;
}

sub GetFieldInfo {
  my ($self, $entity) = @_;
  return unless $entity;
  my $col = $self->_fetch(sub{ $self->webservice->{at_soap}->GetFieldInfo(SOAP::Data->name("psObjectType")->value($entity))->result->{Field} })->sortkey('Label');
  if ( $self->format eq 'json' ) {
    return j($col->to_array);
  } elsif ( $self->format eq 'csv' ) {
    unshift @$col, join "\t", 'Entity', @{$self->f_attr}, 'PickList';
    return $col->map(sub{my $h=$_; $_ = join "\t", $entity, (map { _tf($h->{$_}) } @{$self->f_attr}), $self->_picklist($h)})->join("\n");
  } elsif ( $self->format eq 'sql' ) {
  }
  return $col;
}

sub query {
  my ($self, $entity, $query) = @_;
  return unless $entity && $query;
  my $col = $self->_cache_query($entity, $self->_fetch(sub{ $self->webservice->query({entity => $entity, query => ref $query ? $query : j($query)}) }));
  if ( $self->format eq 'json' ) {
    return j($col->to_array);
  } elsif ( $self->format eq 'csv' ) {
    return $col->map(sub{my $h=$_; $_ = j({map {$_=>$h->{$_}} keys %$h})})->join("\n");
  }
  return $col;
}

sub _cache_query {
  my ($self, $entity, $col) = @_;
  return unless $entity && $col;
  $self->log->debug("No backend registered, skipping") and return $col unless $self->backend;
  $self->log->debug("Backend table $entity not found, skipping") and return $col unless $self->backend->table->{$entity};

  my ($last_id, $last_modified) = $self->backend->last_modified($entity);
  $self->log->debug("Recent refresh on $entity, skipping") and return $col if $self->superquick_cache && !$self->_expired($last_modified);

  foreach my $h ( @{$col->to_array} ) {
    my $h = $_;
    delete $h->{$_} foreach grep { ! length $h->{$_} } keys %$h;
    $h->{local_lastmodified} = 'now()';
    #say Data::Dumper::Dumper($h);
    if ( my ($id, $last_modified) = $self->backend->last_modified($entity, $h->{id}) ) {
      next if $self->quick_cache && !$self->_expired($last_modified);
      eval {
        $self->backend->update($entity, {map {$_ => ref $h->{$_} ? j($h->{$_}) : $h->{$_}} keys %$h}, {id => $h->{id}});
        print ':' if $self->log->is_level('debug');
      };
    } else {
      eval {
        $self->backend->insert($entity, {map {$_ => ref $h->{$_} ? j($h->{$_}) : $h->{$_}} keys %$h}, {returning => 'id'});
        print '.' if $self->log->is_level('debug');
      };
    }
  }

  return $col;
}

sub _expired {
  my ($self, $last_modified) = @_;
  return $last_modified && $last_modified < time - $self->cache_time;
}

sub _tf { encode 'UTF-8', !$_[0] ? '' : lc($_[0]) eq 'true' ? '•' : lc($_[0]) eq 'false' ? '' : $_[0] || '' }
sub _sql {
  my ($self, $hash) = @_;
  #say Data::Dumper::Dumper($hash);
  $hash->{Length} = 1 unless $hash->{Length};
  return sprintf '"%s" integer primary key', $hash->{Name}, if $hash->{Name} eq 'id';
  #return sprintf '%s integer primary key', $hash->{Name}, $hash->{ReferenceEntityType}, if $hash->{IsReference};
  return sprintf '"%s" varchar(%s)', $hash->{Name}, $hash->{Length} if $hash->{Type} eq 'string';
  return sprintf '"%s" real',        $hash->{Name} if $hash->{Type} =~ /^(double|float|decimal)$/;
  return sprintf '"%s" smallint',    $hash->{Name} if $hash->{Type} eq 'short';
  return sprintf '"%s" bigint',      $hash->{Name} if $hash->{Type} eq 'long';
  return sprintf '"%s" timestamp without time zone', $hash->{Name} if $hash->{Type} eq 'datetime';
  return sprintf '"%s" %s',          $hash->{Name}, $hash->{Type}; # integer, date
}
sub _picklist {
  my ($self, $hash) = (shift, shift);
  return unless $hash->{PicklistValues};
  my $p_value  = $hash->{PicklistValues}->{PickListValue} or return;
  my $picklist = Mojo::Collection->with_roles('+Key')
                 ->new(ref $p_value eq "ARRAY" ? @$p_value : ref $p_value eq "HASH" ? $p_value : ())
                 ->map(sub{my $h = $_; join "\\t", map { _tf($h->{$_}) } @{$self->p_attr}})
                 ->join("\\n");
  join "\\n", join("\\t", @{$self->p_attr}), $picklist;
}

1;
