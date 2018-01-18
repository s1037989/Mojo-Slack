package Mojo::Slack;
use Mojo::Base -base;

use Mojo::Log;
use Mojo::Loader 'load_class';

use Mojo::Slack::WebHook;
use Mojo::Slack::WebAPI;
use Mojo::Slack::RealTimeMessagingAPI;

use Scalar::Util 'weaken';

has 'backend';
has log => sub { Mojo::Log->new };
has webhook => sub { Mojo::Slack::WebHook->new(@_) };
has webapi => sub { Mojo::Slack::WebAPI->new(@_) };
has rtmapi => sub { Mojo::Slack::RealTimeMessagingAPI->new(@_) };

sub new {
  my $self = shift->SUPER::new(@_);

  my $backend = shift;
  my $class = 'Mojo::Slack::Backend::' . $backend;
  my $e     = load_class $class;

  if ( $e ) {
    unshift @_, $backend;
  } else {
    $self->backend($class->new(@_));
    weaken $self->backend->slack($self)->{slack};
  }

  return $self;
}

1;
