package Rscape::Model::Rscape;
use Moose;
use namespace::autoclean;
use File::Temp qw/ tempfile tempdir /;
use File::Basename;
use File::Copy;
use Sereal::Encoder;

extends 'Catalyst::Model';

has 'dir_path' => (
  isa => 'Str',
  is => 'ro',
);

has 'rscape_dir' => (
  isa => 'Str',
  is => 'ro',
);

has 'gnuplot' => (
  isa => 'Str',
  is => 'ro',
);

has 'gnuplot_ps' => (
  isa => 'Str',
  is => 'ro',
);

sub determine_name_from_sto_file {
  my ($self, $filepath) = @_;
  # R-scape no longer seems to name the files based on the input name, but on
  # the name in the ACC and ID fields of the .sto file. So we need to parse the file
  # and generate the file names, based on that.

  # open file
  open my $upload, '<', $filepath;
  my $id = undef;
  my $acc = undef;

  while (my $row = <$upload>) {
    chomp $row;
    # read ID
    if ($row =~ /^#=GF ID (.*)/) {
      $id = $1;
    }
    # read ACC
    if ( $row =~ /^#=GF AC (.*)/) {
      $acc = $1;
    }
    last if $id && $acc;
  }
  # combine and return
  return "${acc}_$id";
}

sub run {
  my ($self, $opts) = @_;
  mkdir($self->dir_path);
  my $tmp_dir = tempdir( 'XXXXXXXXX', DIR => $self->dir_path );


  # save the file to a name we specify, so that nefarious actors can't
  # upload to a file path we don't expect.
  my $upload_file_path =  $tmp_dir . '/uploaded.sto';

  # save the uploaded file for later use.
  copy($opts->{upload}->tempname, $upload_file_path);

  # check here to see if we have SS_cons present in the upload.
  my $has_ss_cons = 0;
  system("grep '#=GC SS_cons' $upload_file_path > /dev/null");
  if ($? == 0) {
    $has_ss_cons = 1;
  }

  my $upload_name = $self->determine_name_from_sto_file($upload_file_path);

  # save the meta data to disk for later use in the results display.
  my $encoder = Sereal::Encoder->new();
  my $out = $encoder->encode({
    upload_name => $upload_name,
    evalue => $opts->{evalue},
    mode => $opts->{mode},
    has_ss_cons => $has_ss_cons,
  });

  open my $meta, '>', $tmp_dir . '/meta';
  print $meta $out;
  close $meta;

  # mode mapping
  # ============================
  # 1 -> One-set test
  # 2 -> One-set test + report a R-scape structure
  # 3 -> Two-set test
  # 4 -> Two-set test + report a R-scape structure

  # exit early if mode 3/4 are chosen and the upload doesn't contain a nucleotide alignment
  if ($opts->{mode} =~ /^3|4$/) {
    if (!$has_ss_cons) {
      # return error message to trigger redirect.
      return ('alignment_missing');
    }
  }

  # start building the R-scape command to execute
  my $cmd = 'export GNUPLOT='. $self->gnuplot . '; ';
  $cmd   .= 'export GNUPLOT_PS_DIR=' . $self->gnuplot_ps . '; ';
  $cmd   .= 'export RSCAPE_HOME='    . $self->rscape_dir . '; ';

  # modify the command that is run, based on the mode chosen.
  if ($opts->{mode} == 1)    { $cmd .= $self->rscape_dir . '/bin/R-scape           '; }
  elsif ($opts->{mode} == 2) { $cmd .= $self->rscape_dir . '/bin/R-scape --fold    '; }
  elsif ($opts->{mode} == 3) { $cmd .= $self->rscape_dir . '/bin/R-scape -s        '; }
  elsif ($opts->{mode} == 4) { $cmd .= $self->rscape_dir . '/bin/R-scape -s --fold '; }


  if ($opts->{evalue} && $opts->{evalue} =~ /[0-9\.]*/) {
    $cmd .= ' -E ' . $opts->{evalue};
  }

  $cmd .= ' --onemsa --outdir ' . $tmp_dir . ' ' . $upload_file_path;
  $cmd .= ' 2>&1 >> /dev/null';

  if ($ENV{'CATALYST_DEBUG'}) {
    warn "$cmd\n";
  }

  # save the executed cmd for posterity
  open my $cmd_fh, '>', $tmp_dir . '/cmd';
  print $cmd_fh $cmd;
  close $cmd_fh;

  # run it and wait for the output.
  system($cmd);

  return fileparse($tmp_dir);
}

=head1 NAME

Rscape::Model::Rscape - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 AUTHOR

Clements, Jody

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
