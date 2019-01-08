package Kit::Task::ProjectReferenced;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::JSON 'j';

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(project_referenced => sub {
    my ($job, $number) = (shift, pop);
    my %args = @_%2==0 ? @_ : (channel => @_);
    $job->app->log->info("Project Referenced: $number");
    my $project = $job->app->autotask->cache_c->query('Project', [{name => 'ProjectNumber', expressions => [{op => 'Equals', value => $number}]}])->first;
    return unless ref $project eq 'Project';
    $args{attachments} = [
      {
        pretext => "Found reference to Project $project->{ProjectNumber}",
        title => "Project $project->{ProjectNumber}: $project->{ProjectName}",
        title_link => $job->app->autotask->ec->open_project(ProjectID => $project->{id}, AccountID => $project->{AccountID}),
        text => $project->{Description},
        color => '#7CD197',
      },
    ];
    my $res = $job->app->slack->webapi->chat->post_message(%args);
    $job->app->log->error($res->json('/error')) if $res->json('/error');
  });
}

1;
