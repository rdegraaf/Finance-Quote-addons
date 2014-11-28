#!/usr/bin/env perl

require 5.005;
use strict;
use warnings;

use Finance::Quote;
use Finance::Quote::Google;
use File::Temp;
use File::Spec;
use URI::file;

my $tmpdir = File::Temp->newdir();
my $quoter = Finance::Quote->new;
my $fail_count = 0;
$| = 1; # auto-flush stdout

# 
# Test the Google plugin for Finance::Quote
# Arguments:
#   A string describing the test.  Must not end with newline.
#   An array of quote configurations.  Each is a map with following fields:
#       'symbol': the symbol to lookup
#       'response': a QUOTE_URI response, or undef to use a live server 
#           response
#       'results': a map of success conditions.  Each key is a response field; 
#           values can be undef to require no value in the field, '' to require 
#           an unspecified value in the field, or a specific value.
# This function cannot use live server responses for some symbols and given 
# responses for others; if a response is given for any symbol in the array, 
# then one must be given for all symbols.
#
sub test_Google
{
    my $str = shift;
    my $response = shift;
    my $config = shift;
    if (0 == scalar @{$config})
    {
        print STDERR "Error: config list is empty\n";
        return;
    }

    print('Testing '.$str.'... ');

    my @args = ('google');
    my $quote_uri = $Finance::Quote::Google::QUOTE_URI;
    my $responses = 0;
    my $filename = '';
    my $filedata = "// [\n";

    foreach (@{$config})
    {
        my %item = %{$_};
        push(@args, $item{'symbol'});

        # If a response was provided, build the file name.
        if (defined $response)
        {
            if (0 != $responses)
            {
                $filename .= ',';
            }
            $filename .= $item{'symbol'};
            ++$responses;
        }
    }
    
    if (defined $response)
    {
        $Finance::Quote::Google::QUOTE_URI = URI::file->new($tmpdir->dirname()).'/';

        open(my $file, '>'.File::Spec->catfile($tmpdir->dirname(), $filename)) or die("Error opening file");
        print $file $response;
        close($file);
        #print File::Spec->catfile($tmpdir->dirname(), $filename)."\n";
        #sleep(15);
    }

    # Obtain a quote
    my %quote = $quoter->fetch(@args);

    # Check that all success conditions were met.
    my $success = 1;
    foreach (@{$config})
    {
        my $symbol = $_->{'symbol'};
        while ((my $field, my $value) = each %{$_->{'results'}})
        {
            if (defined $value)
            {
                if ("" eq $value)
                {
                    if (not defined $quote{$symbol, $field})
                    {
                        $success = 0;
                        #print "$symbol, $field should have a value\n";
                        last;
                    }
                }
                elsif ($value ne $quote{$symbol, $field})
                {
                    $success = 0;
                    #print "$symbol, $field should be $value but is $quote{$symbol, $field}\n";
                    last;
                }
            }
            else
            {
                if (defined $quote{$symbol, $field})
                {
                    $success = 0;
                    #print "$symbol, $field be undef but is $quote{$symbol, $field}\n";
                    last;
                }
            }
        }
        print "$symbol: $quote{$symbol, 'errormsg'}\n" if (0 == $success && 0 == $quote{$symbol, 'success'});
    }

    # Restore the quote URI
    $Finance::Quote::Google::QUOTE_URI = $quote_uri;

    print $success ? "success.\n" : "FAILURE.\n";
    ++$fail_count if (!$success);
}

my $google_quote_tdb972 = '{'."\n".
                          '"id": "909930995949109"'."\n".
                          ',"t" : "TDB972"'."\n".
                          ',"e" : "MUTF_CA"'."\n".
                          ',"l" : "75.23"'."\n".
                          ',"l_fix" : "75.23"'."\n".
                          ',"l_cur" : "$75.23"'."\n".
                          ',"s": "0"'."\n".
                          ',"ltt":"4:30PM EST"'."\n".
                          ',"lt" : "Nov 26, 4:30PM EST"'."\n".
                          ',"lt_dts" : "2014-11-26T16:30:00Z"'."\n".
                          ',"c" : "+0.13"'."\n".
                          ',"c_fix" : "0.13"'."\n".
                          ',"cp" : "0.17"'."\n".
                          ',"cp_fix" : "0.17"'."\n".
                          ',"ccol" : "chg"'."\n".
                          ',"pcls_fix" : "75.23"'."\n".
                          '}'."\n";
my $google_quote_msft = '{'."\n".
                        '"id": "358464"'."\n".
                        ',"t" : "MSFT"'."\n".
                        ',"e" : "NASDAQ"'."\n".
                        ',"l" : "47.75"'."\n".
                        ',"l_fix" : "47.75"'."\n".
                        ',"l_cur" : "47.75"'."\n".
                        ',"s": "2"'."\n".
                        ',"ltt":"4:08PM EST"'."\n".
                        ',"lt" : "Nov 26, 4:08PM EST"'."\n".
                        ',"lt_dts" : "2014-11-26T16:08:07Z"'."\n".
                        ',"c" : "+0.28"'."\n".
                        ',"c_fix" : "0.28"'."\n".
                        ',"cp" : "0.59"'."\n".
                        ',"cp_fix" : "0.59"'."\n".
                        ',"ccol" : "chg"'."\n".
                        ',"pcls_fix" : "47.47"'."\n".
                        ',"el": "47.79"'."\n".
                        ',"el_fix": "47.79"'."\n".
                        ',"el_cur": "47.79"'."\n".
                        ',"elt" : "Nov 26, 7:56PM EST"'."\n".
                        ',"ec" : "+0.04"'."\n".
                        ',"ec_fix" : "0.04"'."\n".
                        ',"ecp" : "0.08"'."\n".
                        ',"ecp_fix" : "0.08"'."\n".
                        ',"eccol" : "chg"'."\n".
                        ',"div" : "0.31"'."\n".
                        ',"yld" : "2.60"'."\n".
                        '}'."\n";


# Test well-formed responses
test_Google('well-formed response', 
            "// [\n$google_quote_tdb972]\n",
            [{'symbol' => 'TDB972', 
              'results' => {'success' => 1, 'last' => '75.23', 'date' => '11/26/2014', 'time' => '16:30', 'timezone' => 'EST', 'currency' => 'CAD'}}]);
test_Google('well-formed response for multiple symbols', 
            "[\n$google_quote_tdb972,$google_quote_msft]\n",
            [{'symbol' => 'TDB972', 
              'results' => {'success' => 1, 'last' => '75.23', 'date' => '11/26/2014', 'time' => '16:30', 'timezone' => 'EST', 'currency' => 'CAD'}},
             {'symbol' => 'MSFT', 
              'results' => {'success' => 1, 'last' => '47.75', 'date' => '11/26/2014', 'time' => '16:08', 'timezone' => 'EST', 'currency' => 'USD'}}]);
test_Google('unrequested symbol in response', 
            "// [\n$google_quote_msft]\n",
            [{'symbol' => 'TDB972', 
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'time' => undef, 'timezone' => undef, 'currency' => undef}}]);

# Test malformed QUOTE_URI responses
test_Google('empty response',
            '',
            [{'symbol' => 'TDB972',
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'time' => undef, 'timezone' => undef, 'currency' => undef}}]);
test_Google('non-JSON response',
            '<!DOCTYPE html><html><body><h1>Go away</h1></body></html>',
            [{'symbol' => 'TDB972',
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'time' => undef, 'timezone' => undef, 'currency' => undef}}]);
test_Google('non-array JSON response',
            $google_quote_msft,
            [{'symbol' => 'TDB972',
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'time' => undef, 'timezone' => undef, 'currency' => undef}}]);
test_Google('empty array JSON response',
            '[]',
            [{'symbol' => 'TDB972',
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'time' => undef, 'timezone' => undef, 'currency' => undef}}]);
test_Google('missing symbol in response',
            '[{"e" : "MUTF_CA","l" : "75.23","ltt":"4:30PM EST","lt_dts" : "2014-11-26T16:30:00Z"}]',
            [{'symbol' => 'TDB972',
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'time' => undef, 'timezone' => undef, 'currency' => undef}}]);
test_Google('empty symbol in response',
            '[{"t" : "","e" : "MUTF_CA","l" : "75.23","ltt":"4:30PM EST","lt_dts" : "2014-11-26T16:30:00Z"}]',
            [{'symbol' => 'TDB972',
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'time' => undef, 'timezone' => undef, 'currency' => undef}}]);
test_Google('missing price in response',
            '[{"t" : "TDB972","e" : "MUTF_CA","ltt":"4:30PM EST","lt_dts" : "2014-11-26T16:30:00Z"}]',
            [{'symbol' => 'TDB972',
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'time' => undef, 'timezone' => undef, 'currency' => undef}}]);
test_Google('empty price in response',
            '[{"t" : "TDB972","e" : "MUTF_CA","l" : "","ltt":"4:30PM EST","lt_dts" : "2014-11-26T16:30:00Z"}]',
            [{'symbol' => 'TDB972',
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'time' => undef, 'timezone' => undef, 'currency' => undef}}]);
test_Google('missing timestamp in response',
            '[{"t" : "TDB972","e" : "MUTF_CA","l" : "75.23","ltt":"4:30PM EST"}]',
            [{'symbol' => 'TDB972',
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'time' => undef, 'timezone' => undef, 'currency' => undef}}]);
test_Google('empty timestamp in response',
            '[{"t" : "TDB972","e" : "MUTF_CA","l" : "75.23","ltt":"4:30PM EST","lt_dts" : ""}]',
            [{'symbol' => 'TDB972',
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'time' => undef, 'timezone' => undef, 'currency' => undef}}]);
test_Google('invalid timestamp in response',
            '[{"t" : "TDB972","e" : "MUTF_CA","l" : "75.23","ltt":"4:30PM EST","lt_dts" : "ZZZZ-11-26T16:30:00Z"}]',
            [{'symbol' => 'TDB972',
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'time' => undef, 'timezone' => undef, 'currency' => undef}}]);
test_Google('missing time zone in response',
            '[{"t" : "TDB972","e" : "MUTF_CA","l" : "75.23","lt_dts" : "2014-11-26T16:30:00Z"}]',
            [{'symbol' => 'TDB972',
              'results' => {'success' => 1, 'last' => '75.23', 'date' => '11/26/2014', 'time' => '16:30', 'timezone' => undef, 'currency' => 'CAD'}}]);
test_Google('empty time zone in response',
            '[{"t" : "TDB972","e" : "MUTF_CA","l" : "75.23","ltt":"","lt_dts" : "2014-11-26T16:30:00Z"}]',
            [{'symbol' => 'TDB972',
              'results' => {'success' => 1, 'last' => '75.23', 'date' => '11/26/2014', 'time' => '16:30', 'timezone' => undef, 'currency' => 'CAD'}}]);
test_Google('invalid time zone in response',
            '[{"t" : "TDB972","e" : "MUTF_CA","l" : "75.23","ltt":"ZZZZZZ","lt_dts" : "2014-11-26T16:30:00Z"}]',
            [{'symbol' => 'TDB972',
              'results' => {'success' => 1, 'last' => '75.23', 'date' => '11/26/2014', 'time' => '16:30', 'timezone' => undef, 'currency' => 'CAD'}}]);
test_Google('missing exchange in response',
            '[{"t" : "TDB972","l" : "75.23","ltt":"4:30PM EST","lt_dts" : "2014-11-26T16:30:00Z"}]',
            [{'symbol' => 'TDB972',
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'time' => undef, 'timezone' => undef, 'currency' => undef}}]);
test_Google('empty exchange in response',
            '[{"t" : "TDB972","e" : "","l" : "75.23","ltt":"4:30PM EST","lt_dts" : "2014-11-26T16:30:00Z"}]',
            [{'symbol' => 'TDB972',
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'time' => undef, 'timezone' => undef, 'currency' => undef}}]);
test_Google('unrecognized exchange in response',
            '[{"t" : "TDB972","e" : "ZZZZZZ","l" : "75.23","ltt":"4:30PM EST","lt_dts" : "2014-11-26T16:30:00Z"}]',
            [{'symbol' => 'TDB972',
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'time' => undef, 'timezone' => undef, 'currency' => undef}}]);



# '[{"t" : "TDB972","e" : "MUTF_CA","l" : "75.23","ltt":"4:30PM EST","lt_dts" : "2014-11-26T16:30:00Z"}]',

# Unrequested symbol in response

# Test live server responses
test_Google('live server', 
            undef,
            [{'symbol' => 'TDB972', 
              'results' => {'success' => 1, 'last' => '', 'date' => '', 'time' => '', 'timezone' => '', 'currency' => 'CAD'}}]);
test_Google('live server with multiple symbols', 
            undef,
            [{'symbol' => 'MSFT', 
              'results' => {'success' => 1, 'last' => '', 'date' => '', 'time' => '', 'timezone' => '', 'currency' => 'USD'}},
             {'symbol' => 'TDB972', 
              'results' => {'success' => 1, 'last' => '', 'date' => '', 'time' => '', 'timezone' => '', 'currency' => 'CAD'}}]);
test_Google('invalid symbol', 
            undef,
            [{'symbol' => 'ZZZ999', 
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'time' => undef, 'timezone' => undef, 'currency' => undef}}]);
test_Google('mixed valid and invalid symbols',
            undef,
            [{'symbol' => 'MSFT',
              'results' => {'success' => 1, 'last' => '', 'date' => '', 'time' => '', 'timezone' => '', 'currency' => 'USD'}},
             {'symbol' => 'ZZZ999',
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'time' => undef, 'timezone' => undef, 'currency' => undef}}]);


if (0 == $fail_count)
{
    print "All tests succeeded.\n";
}
else
{
    print "Total failures encountered: $fail_count.\n";
}

#my %quote = $quoter->fetch('google', 'MSFT', 'TDB972');
#print $quote{'TDB972', 'last'}."\n";

