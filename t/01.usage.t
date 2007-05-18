#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 25;
use Catalyst::Test 'TestApp';

use Text::Diff;

use FindBin;

my $root = $FindBin::Bin;

my ($stderr, $old_stderr);
BEGIN {
    no warnings 'redefine';

    *Catalyst::Test::local_request = sub {
        my ( $class, $request ) = @_;

        require HTTP::Request::AsCGI;
        my $cgi = HTTP::Request::AsCGI->new( $request, %ENV )->setup;

        $class->handle_request;

        return $cgi->restore->response;
    };
}
#local $SIG{__DIE__} = sub {
#close STDERR;
#open(STDERR, ">&SAVEERR");
#print $stderr . "\n";   
#};
open(SAVEERR, ">&STDERR");
close STDERR or print "cannot close STDERR\n";
open(STDERR, ">", \$stderr) or print "CAnnot open: $!\n";

run_tests();
close STDERR;
open(STDERR, ">&SAVEERR");

sub reset_stderr {
    close STDERR or print "cannot close STDERR\n";
    print "Current stderr: " . $stderr . "\n";
    $stderr = '';
    open(STDERR, ">", \$stderr) or print "CAnnot open: $!\n";
}

sub run_tests {

    # test first available view
    is($stderr, undef, 'empty stderr at start');
    reset_stderr();
    {
        my $expected = '200 request OK';
        my $request  =
          HTTP::Request->new( GET => 'http://localhost:3000/test_ok' );

        ok( my $response = request($request), 'Request' );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->header( 'Content-Type' ), 'text/html; charset=utf-8', 'Content Type' );
        is( $response->code, 200, 'Response Code' );

        is($response->content, $expected, 'Content OK' );
        is( $stderr, '', "No stderr output");
    }
    
    reset_stderr();    
    # Lets test a dying action
    {
        my $expected = qq{500 error happened

* Caught exception in TestApp->test_die "Death by action at $root/lib/TestApp.pm line 33."
};
        my $request  =
          HTTP::Request->new( GET => 'http://localhost:3000/test_die' );

        ok( my $response = request($request), 'Request' );
        ok( ! $response->is_success, 'Response Successful 2xx' );
        is( $response->header( 'Content-Type' ), 'text/html; charset=utf-8', 'Content Type' );
        is( $response->code, 500, 'Response Code' );
        my $content = $response->content;
        
        is( $response->content, $expected, 'Content OK' );
        is( $stderr, '[error] Caught exception in TestApp->test_die "Death by action at ' . $root . '/lib/TestApp.pm line 33."' . "\n");
    }
    reset_stderr();    
    # lets test a dying view
    {
        my $expected = qq{5xx error happened

* Caught exception in TestApp::View::Default->process "Death by view at $root/lib/TestApp/View/Default.pm line 9."
};
        my $request  =
          HTTP::Request->new( GET => 'http://localhost:3000/test_view_death' );

        ok( my $response = request($request), 'Request' );
        ok( ! $response->is_success, 'Response Successful 2xx' );
        is( $response->header( 'Content-Type' ), 'text/html; charset=utf-8', 'Content Type' );
        is( $response->code, 501, 'Response Code' );

        is( $response->content, $expected, 'Content OK' );
        is( $stderr, '', "5xx erros should not be logged");
    }
    reset_stderr();    
    
    # lets try a 4xx error to test fallback
    {
        my $expected = 'Something awfull happened';
        my $request  =
          HTTP::Request->new( GET => 'http://localhost:3000/test_4xx' );

        ok( my $response = request($request), 'Request' );
        ok( ! $response->is_success, 'Response Successful 2xx' );
        is( $response->header( 'Content-Type' ), 'text/html; charset=utf-8', 'Content Type' );
        is( $response->code, 404, 'Response Code' );

        is( $response->content, $expected, 'Content OK' );
        is( $stderr, '[error] Couldn\'t render template "file error - test_4xx: not found"' . "\n", "we cannot render the template");
        
    }
    reset_stderr();    
    
    
}
