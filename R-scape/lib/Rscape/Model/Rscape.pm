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

has 'exec_path' => (
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

has 'r2rdir' => (
  isa => 'Str',
  is => 'ro',
);

has 'fasttree' => (
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
  });

  open my $meta, '>', $tmp_dir . '/meta';
  print $meta $out;
  close $meta;

  my $upload_file_path =  $tmp_dir . '/' . $opts->{upload}->filename;

  # save the uploaded file for later use.
  copy($opts->{upload}->tempname, $upload_file_path);

  my $cmd = 'export GNUPLOT='. $self->gnuplot . '; ';
  $cmd .= 'export GNUPLOT_PS_DIR=' . $self->gnuplot_ps . '; ';
  $cmd .= 'export R2RDIR=' . $self->r2rdir . '; ';
  $cmd .= 'export FASTTREEDIR='. $self->fasttree . '; ';
  $cmd .= $self->exec_path . ' 2>&1 >> /dev/null';


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
