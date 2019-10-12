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

sub svg_images : Path : Args(3) {
  my ($self, $c, $dir, $type) = @_;
  my $results_dir = $c->config->{'Model::Rscape'}->{dir_path} . '/' . $dir;

  # figure out the search mode to return the correct images.
  my $decoder = Sereal::Decoder->new();
  my $encoded_meta = read_file("$results_dir/meta");
  my $meta = $decoder->decode($encoded_meta);
  my $mode = $meta->{mode};

  # default to $type eq 'his'
  my $glob_pattern = '*.surv.svg';

  if ($type eq 'dplot') {
    $glob_pattern = '*.dplot.svg';
  } elsif ($type eq 'r2r') {
    $glob_pattern = '*.R2R.sto.svg';
  }

  my $orig_dir = getcwd;
  chdir $results_dir;
  my @files = glob $glob_pattern;

  if ($mode =~ /^(2|4)$/ && $type =~ /^(dplot|r2r)$/) {
    @files = grep(/\.fold\./, @files);
  } else {
    @files = grep(!/\.fold\./, @files);
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
    if ($tmp_id eq 'alignment_missing') {
      $c->go('alignment_missing');
    } else {
      $c->response->redirect($c->uri_for('/results/' . $tmp_id));
    }
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
  my $mode = $c->stash->{mode} = $meta->{mode};
  my $has_ss_cons = $c->stash->{has_ss_cons} = $meta->{has_ss_cons};

  # read different output files, based on the search mode
  my $out_path = $dir . '/' . $name . '.cov';
  my $power_file_path = $dir . '/' . $name . '.power';

  # open the .fold version of the files if modes 2|4 are selected.
  if ($mode =~ /^(2|4)$/) {
    $out_path = $dir . '/' . $name . '.fold.cov';
    $power_file_path = $dir . '/' . $name . '.fold.power';
  }

  # read data from the *.cov file
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

  close $output;


  # open the power file and place it in the stash for use in the results template.
  open my $power_file_handle, '<', $power_file_path;

  while (<$power_file_handle>) {
    # skip comments and the first blank line.
    next if ($_ =~ /^\#/ || $. < 2);
    my @line = split ' ', $_;
    # if we don't get a * then add a blank line in its' place.
    if (scalar @line < 5) {
      unshift @line, '';
    }
    push @{$c->stash->{power_file}}, \@line;
  }

  close $power_file_handle;

  # show the no result message if we don't have data in the .cov file
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

sub alignment_missing : Private {
  my ($self, $c) = @_;
  $c->stash->{template} = 'alignment_missing.tt';
  return;
};



=head1 AUTHOR

Clements, Jody

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
