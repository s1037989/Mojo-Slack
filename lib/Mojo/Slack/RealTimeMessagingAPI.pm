package Mojo::Slack::RealTimeMessagingAPI;
use Mojo::Base 'Mojo::Slack::API';

sub connect {
  my $self = shift;
  my $oauth_access_token = $self->slack->{oauth_access_token};
  my $rtm_connect_url = 'https://slack.com/api/rtm.connect?token='.$oauth_access_token.'&pretty=1';
  $self->log->info($rtm_connect_url);
  my $connect = $self->ua->get($rtm_connect_url)->res->json;
  $self->log->info($connect->{url});
  $self->ua->websocket($connect->{url} => @_);
}

1;

