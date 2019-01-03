package Kit::Task::AssistanceRequested;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::JSON 'j';

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(assistance_requested => sub {
    my ($job, $args) = (shift, shift);
    my %args = %$args;
    my $number = $args{number};
    $args{notify} = 1;
    $args{channel} = 'AR_'.uc($args{number} =~ s/\./_/gr);
    $args{channel} = 't20181008_0053';
    $job->app->log->info("Ticket or Task Referenced: $number");
    if ( my $ticket = $job->app->autotask->webservice->query('Ticket', {name => 'TicketNumber', expressions => [{op => 'Equals', value => $number}]})->first ) {
      #warn Mojo::Util::dumper($ticket) and return;
      return unless ref $ticket eq 'Ticket';
      # HIGH: Need a proper token type to create a channel
      #my $res = $job->app->slack->webapi->channels->create(name => $args{channel});
      #$job->app->log->error($res->json('/error')) and return if $res->json('/error');
      # HIGH: Invite everyone subscribed to #sme
      #my $res = $job->app->slack->webapi->channels->invite(channel => $args{channel}, user => 'stefan');
      #$job->app->log->error($res->json('/error')) and return if $res->json('/error');
      $args{notify} &&= ' <!channel>';
      $args{attachments} = [
        {
          pretext => "*Assistance Requested*$args{notify}",
          title => "Ticket $ticket->{TicketNumber}: $ticket->{Title}",
          title_link => $job->app->autotask->execute->open_ticket_detail(TicketNumber => $ticket->{TicketNumber}, AccountID => $ticket->{AccountID}),
          text => ":boom: $args{comments}", #$ticket->{Description},
          color => '#7CD197',
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
    } elsif ( my $task = $job->app->autotask->webservice->query('Task', {name => 'TaskNumber', expressions => [{op => 'Equals', value => $number}]})->first ) {
      return unless ref $task eq 'Task';
      my $project = $job->app->autotask->webservice->query('Project', {name => 'id', expressions => [{op => 'Equals', value => $task->{ProjectID}}]})->first;
      return unless ref $project eq 'Project';
      $args{attachments} = [
        {
          pretext => "Found reference to Project Task $task->{TaskNumber}",
          title => "Task $task->{TaskNumber}: $task->{Title}",
          title_link => $job->app->autotask->execute->open_task_detail(TaskID => $task->{id}, AccountID => $task->{AccountID}),
          text => $task->{Description},
          color => '#7CD197',
        },
        {
          pretext => "Found reference to Project $project->{ProjectNumber}",
          title => "Project $project->{ProjectNumber}: $project->{ProjectName}",
          title_link => $job->app->autotask->execute->open_project(ProjectID => $task->{ProjectID}, AccountID => $task->{AccountID}),
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
