package Kit::Task::ExtensionCallout;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::JSON 'j';

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(extension_callout => sub {
    my ($job, $args) = (shift, shift);
    my %args = %$args;
    my $number = $args{number};
    $job->app->log->debug($args{number});
    # HIGH: Lookup channel ids for all the live link slack channels for this ticket and archive them each
    #$job->app->slack->webapi->channel->archive(%args);
  });
}

1;
