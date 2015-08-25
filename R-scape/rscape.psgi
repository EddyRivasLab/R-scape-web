use strict;
use warnings;
use lib './lib';

use Rscape;

my $app = Rscape->apply_default_middlewares(Rscape->psgi_app);
$app;

