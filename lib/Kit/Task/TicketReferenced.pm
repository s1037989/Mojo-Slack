package Kit::Task::TicketReferenced;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::JSON 'j';

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(ticket_referenced => sub {
    my ($job, $number) = (shift, pop);
    my %args = @_%2==0 ? @_ : (channel => @_);
    $job->app->log->info("Ticket or Task Referenced: $number");
    if ( my $ticket = $job->app->autotask->cache_c->query('Ticket', [{name => 'TicketNumber', expressions => [{op => 'Equals', value => $number}]}])->first ) {
      return unless ref $ticket eq 'Ticket';
      my $account = $job->app->autotask->cache_c->query('Account');
      $args{attachments} = [
        {
          pretext => "Found reference to Ticket $ticket->{TicketNumber}",
          title => "Ticket $ticket->{TicketNumber}: $ticket->{Title}",
          title_link => $job->app->autotask->ec->open_ticket_detail(TicketNumber => $ticket->{TicketNumber}, AccountID => $ticket->{AccountID}),
          text => $ticket->{Description},
          color => '#7CD197',
          fields => [
            {
              title => "Client",
              value => $account->grep(sub{$ticket->{AccountID} eq $_->{id}})->first->{AccountName},
              short => 0
            }
          ],
        },
      ];
      my $res;
      if ( $args{response_url} ) {
        my $token = $job->app->slack->token->oauth_bot or return $job->app->slack->no_res;
        $res = $job->app->ua->post(delete $args{response_url} => {Authorization => "Bearer $token"} => json => {username => $job->app->config->{slack}->{bot_username}, %args})->res;
      } else {
        $res = $job->app->slack->webapi->chat->post_message(%args);
      }
      $job->app->log->error($res->json('/error')) if $res->json('/error');
    } elsif ( my $task = $job->app->autotask->cache_c->query('Task', [{name => 'TaskNumber', expressions => [{op => 'Equals', value => $number}]}])->first ) {
      return unless ref $task eq 'Task';
      my $project = $job->app->autotask->cache_c->query('Project', [{name => 'id', expressions => [{op => 'Equals', value => $task->{ProjectID}}]}])->first;
      return unless ref $project eq 'Project';
      $args{attachments} = [
        {
          pretext => "Found reference to Project Task $task->{TaskNumber}",
          title => "Task $task->{TaskNumber}: $task->{Title}",
          title_link => $job->app->autotask->ec->open_task_detail(TaskID => $task->{id}, AccountID => $task->{AccountID}),
          text => $task->{Description},
          color => '#7CD197',
        },
        {
          pretext => "Found reference to Project $project->{ProjectNumber}",
          title => "Project $project->{ProjectNumber}: $project->{ProjectName}",
          title_link => $job->app->autotask->ec->open_project(ProjectID => $task->{ProjectID}, AccountID => $task->{AccountID}),
          text => $project->{Description},
          color => '#7CD197',
        },
      ];
      my $res = $job->app->slack->webapi->chat->post_message(%args);
      $job->app->log->error($res->json('/error')) if $res->json('/error');
    }
  });
}

1;
