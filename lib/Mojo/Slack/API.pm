package Mojo::Slack::API;
use Mojo::Base -base;

use Mojo::Log;
use Mojo::UserAgent;
use Mojo::Message::Response;

has ua => sub { Mojo::UserAgent->new };
has log => sub { Mojo::Log->new };
has slack => sub { die "No Slack configuration specified\n" };
has no_res => sub { Mojo::Message::Response->new(json => {}) };

1;
