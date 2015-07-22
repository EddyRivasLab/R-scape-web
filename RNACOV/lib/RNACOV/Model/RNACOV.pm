package RNACOV::Model::RNACOV;
use Moose;
use namespace::autoclean;
use File::Temp qw/ tempfile tempdir /;
use File::Basename;
use File::Copy;

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
  my $upload_file_path =  $tmp_dir . '/query';

  # save the uploaded file for later use.
  copy($opts->{upload}->tempname, $upload_file_path);

  my $cmd = 'export GNUPLOT='. $self->gnuplot . '; ';
  $cmd .= 'export R2RDIR=' . $self->r2rdir . '; ';
  $cmd .= 'export FASTTREEDIR='. $self->fasttree . '; ';
  $cmd .= $self->exec_path . ' 2>&1 >> /tmp/rnacov/output';


  if ($opts->{evalue} && $opts->{evalue} =~ /[0-9\.]*/) {
    $cmd .= ' -E ' . $opts->{evalue};
  }


  $cmd .= ' --outdir ' . $tmp_dir . ' ' . $upload_file_path;

  if ($ENV{'CATALYST_DEBUG'}) {
    warn "$cmd\n";
  }

  system($cmd);

  return fileparse($tmp_dir);
}

=head1 NAME

RNACOV::Model::RNACOV - Catalyst Model

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
