use strict;
use warnings;
use Test::More;


use Catalyst::Test 'RNACOV';
use RNACOV::Controller::Results;

ok( request('/results')->is_success, 'Request should succeed' );
done_testing();
