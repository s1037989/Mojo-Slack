package Kit::Task::InformationRequested;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::JSON 'j';

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(information_requested => sub {
    my ($job, $args) = (shift, shift);
    my %args = %$args;
    my $number = $args{number};
    $args{notify} ||= 0;
    $args{channel} = 'rfi_'.lc($args{number} =~ s/\./_/gr);
    $job->app->log->info("Ticket or Task Referenced: $number");
    if ( my $ticket = $job->app->autotask->cache_c->query('Ticket', [{name => 'TicketNumber', expressions => [{op => 'Equals', value => $number}]}])->first ) {
      #warn Mojo::Util::dumper($ticket) and return;
      return unless ref $ticket eq 'Ticket';
      my $sme_channel = $job->app->slack->webapi->channels->info(channel => 'CF0GWGQ90'); # MED: pull this from config
      $job->app->log->error($sme_channel->json('/error')) and return if $sme_channel->json('/error');
      # HIGH: allow users to approve the app and store the auth code for creating a channel in the resource's name
      #       this would be the time to also map their AT id to Slack id
      # HIGH: unarchive channel if it's archived
      # HIGH: lookup slack id from DB based on primary resource on ticket
      my $join_channel = $job->app->slack->webapi->channels->join(name => $args{channel});
      $job->app->log->error($join_channel->json('/error')) and return if $join_channel->json('/error');
      foreach my $sme ( grep { $join_channel->json->{channel}->{creator} ne $_ } @{$sme_channel->json->{channel}->{members}} ) {
        warn "Inviting $sme";
        my $invite_sme = $job->app->slack->webapi->channels->invite(channel => $join_channel->json->{channel}->{id}, user => $sme);
        $job->app->log->error($invite_sme->json('/error')) and return if $invite_sme->json('/error');
      }
      if ( $args{doc} ) {
        $args{notify} &&= ' <!channel>';
        $args{attachments} = [
          {
            pretext => "*Request for Information* -- cannot find in CMDB$args{notify}",
            title => "Ticket $ticket->{TicketNumber}: $ticket->{Title}",
            title_link => $job->app->autotask->ec->open_ticket_detail(TicketNumber => $ticket->{TicketNumber}, AccountID => $ticket->{AccountID}),
            text => ":boom: $args{comments}", #$ticket->{Description},
            color => '#7CD197',
            fields => [
              {
                title => "Issue",
                value => $ticket->{IssueType_name},
                short => 1,
              },
              {
                title => "Sub-Issue",
                value => $ticket->{SubIssueType_name},
                short => 1,
              },
              {
                title => "Priority",
                value => $ticket->{Priority_name},
                short => 1,
              },
              {
                title => "Queue",
                value => $ticket->{QueueID_name},
                short => 1,
              },
            ],
          },
        ];
        # MED: Also send a note to Autotask that information could not be found in CMDB and a discussion has occurred in Slack.
        #$job->app->autotask->webservice->at->create('TicketNote'...)
        # LOW: What about Slack buttons like "Yes / No?"
        # LOW: What about a Slack button to get more info, maybe a summary?  (Why, when there's a link?  I guess for mobile users...)
        # LOW: What about a note field when yes to also add an internal note to the ticket?
        # LOW: What about a button to take ticket which, if SD, would place it in T4 and add the slack user as a secondary?
        # LOW: What about a command that can send a specific message or the entire history as a note to the ticket?
      } else {
        # LOW: @mention the autotask user that did not search
        $args{attachments} = [
          {
            pretext => "Request for Information denied",
            title => 'Information has _not_ been searched in IT Glue',
            text => 'Dig a little deeper.',
            color => '#7CD197',
          },
        ];
      }
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
