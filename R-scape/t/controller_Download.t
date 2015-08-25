use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Rscape';
use Rscape::Controller::Download;

ok( request('/download')->is_success, 'Request should succeed' );
done_testing();
