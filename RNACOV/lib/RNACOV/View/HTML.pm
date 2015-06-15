package RNACOV::View::HTML;
use Moose;
use namespace::autoclean;

extends 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    render_die => 1,
);

=head1 NAME

RNACOV::View::HTML - TT View for RNACOV

=head1 DESCRIPTION

TT View for RNACOV.

=head1 SEE ALSO

L<RNACOV>

=head1 AUTHOR

Clements, Jody

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
