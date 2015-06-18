package RNACOV::Controller::Download;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

RNACOV::Controller::Download - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;
  $c->res->redirect($c->uri_for($c->controller('Root')->action_for('index')));
  return;
}

sub tabed_results :Path :Args(1) {
  my ( $self, $c, $dir ) = @_;
  my $results_dir = $c->config->{'Model::RNACOV'}->{dir_path} . '/' . $dir;

  if (!-e $results_dir) {
    $c->go('not_found');
  }

  $c->forward('read_results', [$results_dir]);

  $c->res->header('Content-Disposition' => "attachment; filename=results.csv");
  $c->res->content_type('text/csv');
  $c->response->body($c->stash->{out});
  return;
}

sub read_results : Private {
  my ($self, $c, $dir) = @_;

  open my $output, '<', $dir . '/query.out';

  while (<$output>) {
    next if $_ =~ /^#/;
    $c->stash->{out} .= $_;
  }

  return;
}

=head1 AUTHOR

Clements, Jody

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
