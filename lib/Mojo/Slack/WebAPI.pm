package Mojo::Slack::WebAPI;
use Mojo::Base 'Mojo::Slack::API';

use Mojo::Slack::WebAPI::Chat;

has chat => sub { Mojo::Slack::WebAPI::Chat->new(@_) };

1;
