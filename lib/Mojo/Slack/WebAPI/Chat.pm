package Mojo::Slack::WebAPI::Chat;
use Mojo::Base 'Mojo::Slack::API';

sub postMessage {
  my $self = shift;
  my $token = $self->slack->{oauth_access_token} or return $self->no_res;
  $self->ua->post('https://slack.com/api/chat.postMessage' => {Authorization => "Bearer $token"} => json => {username => 'Mojo', @_})->res;
}

1;
