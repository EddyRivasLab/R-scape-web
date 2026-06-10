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

  # result ids are the random tempdir basenames generated in the model
  # (9 word chars). reject anything else so '../' can't escape dir_path.
  if ($dir !~ /\A\w{9}\z/) {
    $c->go('not_found');
  }

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

  # reject ids that aren't the random tempdir basenames we generate, so
  # '../' sequences can't escape dir_path when building the file paths below.
  if ($dir !~ /\A\w{9}\z/) {
    $c->go('not_found');
  }

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
    @files = grep(/\.cacofold\./, @files);
  } else {
    @files = grep(!/\.cacofold\./, @files);
  }

  my $contents = read_file("$results_dir/" . $files[0]);
  chdir $orig_dir;

  # R-scape draws its gnuplot figures in layers, and gnuplot's SVG terminal
  # writes each layer as a separate stacked SVG document in the one file (e.g.
  # 6 for the survival plot, 3 for the dot plot). Browsers only render the first
  # document, so merge the layers back under a single <svg> root — the overlay
  # the SVG terminal is meant to produce. Single-document SVGs (the R2R plot)
  # have just one <svg> and are served unchanged.
  if ((() = $contents =~ /<svg\b/g) > 1) {
    my @docs = grep { /\S/ } split /(?=<\?xml)/, $contents;
    my ($svg_open) = $docs[0] =~ /(<svg\b.*?>)/s;
    my @layers;
    for my $doc (@docs) {
      my ($inner) = $doc =~ /<svg\b[^>]*>(.*)<\/svg>/s;
      push @layers, $inner if defined $inner;
    }
    $contents = qq{<?xml version="1.0" encoding="utf-8" standalone="no"?>\n}
              . $svg_open . join("\n", @layers) . "</svg>\n";
  }

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
  $c->go('bad_input');
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

  # open the .cacofold version of the files if modes 2|4 are selected.
  if ($mode =~ /^(2|4)$/) {
    $out_path = $dir . '/' . $name . '.cacofold.cov';
    $power_file_path = $dir . '/' . $name . '.cacofold.power';
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
    if ($_ =~ /^\# (avg|BPAIRS)/) {
      push @{$c->stash->{power_meta}}, $_;
    }
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

  # R-scape 2.6.7 produces the dot-plot and R2R structure plots even for a
  # mode-1 alignment with no input structure, so let the template decide whether
  # to show them from the files R-scape actually wrote rather than has_ss_cons.
  my $cacofold = $mode =~ /^(2|4)$/;
  for my $plot (['has_dplot', '*.dplot.svg'], ['has_r2r', '*.R2R.sto.svg']) {
    my @found = grep { $cacofold ? /\.cacofold\./ : !/\.cacofold\./ } glob "$dir/$plot->[1]";
    $c->stash->{$plot->[0]} = scalar(@found) ? 1 : 0;
  }

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
