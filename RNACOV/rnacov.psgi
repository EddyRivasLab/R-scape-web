use strict;
use warnings;
use lib './lib';

use RNACOV;

my $app = RNACOV->apply_default_middlewares(RNACOV->psgi_app);
$app;

