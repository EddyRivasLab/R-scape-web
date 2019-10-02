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

sub run {
  my ($self, $opts) = @_;
  mkdir($self->dir_path);
  my $tmp_dir = tempdir( 'XXXXXXXXX', DIR => $self->dir_path );

  my $upload_name = $opts->{upload}->filename;

  my $encoder = Sereal::Encoder->new();
  my $out = $encoder->encode({
    upload_name => $upload_name,
    evalue => $opts->{evalue},
    mode => $opts->{mode},
  });

  open my $meta, '>', $tmp_dir . '/meta';
  print $meta $out;
  close $meta;

  my $upload_file_path =  $tmp_dir . '/' . $opts->{upload}->filename;

  # save the uploaded file for later use.
  copy($opts->{upload}->tempname, $upload_file_path);


  my $cmd = 'export GNUPLOT='. $self->gnuplot . '; ';
  $cmd   .= 'export GNUPLOT_PS_DIR=' . $self->gnuplot_ps . '; ';
  $cmd   .= 'export RSCAPE_HOME='    . $self->rscape_dir . '; ';

  # mode mapping
  # ============================
  # 1 -> One-set test
  # 2 -> One-set test + report a R-scape structure
  # 3 -> Two-set test
  # 4 -> Two-set test + report a R-scape structure

  # exit early if mode 3/4 are chosen and the upload doesn't contain a structure
  if ($opts->{mode} =~ /^3|4$/) {
    use DDP; p $opts;
    system("grep '#=GC SS_cons' $upload_file_path > /dev/null");
    if ($? != 0) {
      # return error message to trigger redirect.
      return ('alignment_missing');
    }
  }

  # modify the command that is run, based on the mode chosen.
  if ($opts->{mode} == 1)    { $cmd .= $self->rscape_dir . '/bin/R-scape           2>&1 >> /dev/null'; }
  elsif ($opts->{mode} == 2) { $cmd .= $self->rscape_dir . '/bin/R-scape --fold    2>&1 >> /dev/null'; }
  elsif ($opts->{mode} == 3) { $cmd .= $self->rscape_dir . '/bin/R-scape -s        2>&1 >> /dev/null'; }
  elsif ($opts->{mode} == 4) { $cmd .= $self->rscape_dir . '/bin/R-scape -s --fold 2>&1 >> /dev/null'; }



  if ($opts->{evalue} && $opts->{evalue} =~ /[0-9\.]*/) {
    $cmd .= ' -E ' . $opts->{evalue};
  }

  $cmd .= ' --onemsa --outdir ' . $tmp_dir . ' ' . $upload_file_path;

  if ($ENV{'CATALYST_DEBUG'}) {
    warn "$cmd\n";
  }

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
