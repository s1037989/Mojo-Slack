package Mojo::Slack::WebHook;
use Mojo::Base 'Mojo::Slack::API';

sub post {
  my $self = shift;
  $self->slack->{webhook_url}
    ? $self->ua->post($self->slack->{webhook_url} => json => shift || {text => 'Hello, World!'})->res
    : $self->no_res;
}

1;
