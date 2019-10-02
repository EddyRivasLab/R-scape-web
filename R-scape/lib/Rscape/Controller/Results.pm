package Rscape::Controller::Results;
use Moose;
use namespace::autoclean;
use File::Slurp;
use Cwd;
use Sereal::Decoder;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Rscape::Controller::Results - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;
  #process and redirect to results
  $c->forward('process');
}

sub results : Path : Args(1) {
  my ( $self, $c, $dir ) = @_;

  # validate dir here.

  $c->stash->{tmp_id} = $dir;
  my $results_dir = $c->config->{'Model::Rscape'}->{dir_path} . '/' . $dir;

  if (!-e $results_dir) {
    $c->go('not_found');
  }

  $c->forward('read_results', [$results_dir]);

  return;
}

sub r2r_image : Path : Args(2) {
  my ($self, $c, $dir) = @_;
  my $results_dir = $c->config->{'Model::Rscape'}->{dir_path} . '/' . $dir;

  my $orig_dir = getcwd;
  chdir $results_dir;
  my @files = glob '*.R2R.sto.svg';
  my $contents = read_file("$results_dir/" . $files[0]);
  chdir $orig_dir;

  $c->res->content_type('image/svg+xml');
  $c->res->body($contents);
  return;
}

sub dot_plot : Path : Args(3) {
  my ($self, $c, $dir, $type) = @_;
  my $results_dir = $c->config->{'Model::Rscape'}->{dir_path} . '/' . $dir;
  my $orig_dir = getcwd;

  chdir $results_dir;

  my @files = glob '*.dplot.svg';

  if ($type eq "his") {
    @files = glob '*.surv.svg';
  }

  my $contents = read_file("$results_dir/" . $files[0]);

  chdir $orig_dir;



  $c->res->content_type('image/svg+xml');
  $c->res->body($contents);
  return;
}

sub process : Private {
  my ($self, $c) = @_;
  my $tmp_id = undef;
  eval {
    $tmp_id = $c->model('Rscape')->run({
      upload => $c->req->upload('stofile'),
      evalue => $c->req->param('evalue'),
      mode   => $c->req->param('mode'),
    });
  };
  if ($tmp_id) {
    $c->response->redirect($c->uri_for('/results/' . $tmp_id));
  }
  return;
}

sub read_results : Private {
  my ($self, $c, $dir) = @_;

  my $decoder = Sereal::Decoder->new();
  my $encoded_meta = read_file("$dir/meta");

  my $meta = $decoder->decode($encoded_meta);

  $c->stash->{evalue} = $meta->{evalue};

  my $name = $meta->{upload_name};
  $name =~ s/\.[^\.]*$//;

  my $out_path = $dir . '/' . $name . '.out';

  my $output_file = $out_path;

  if (-z $output_file) {
    $c->go('bad_input');
  }

  open my $output, '<', $out_path;

  while (<$output>) {
    next if $_ =~ /^#/;
    my @line = split /\t/, $_;
    push @{$c->stash->{out_file}}, \@line;
  }

  if (!exists $c->stash->{out_file}) {
    $c->go('no_results');
  }

  return;
}

sub bad_input : Private {
  my ($self, $c) = @_;
  $c->stash->{template} = 'bad_input.tt';
  return;
}

sub no_results : Private {
  my ($self, $c) = @_;
  $c->stash->{template} = 'no_results.tt';
  return;
}

sub not_found : Private {
  my ($self, $c) = @_;
  $c->stash->{template} = 'not_found.tt';
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
