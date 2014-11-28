#!/usr/bin/env perl

require 5.005;
use strict;
use warnings;

use Finance::Quote;
use Finance::Quote::TDBank;
use File::Temp;
use File::Spec;
use URI::file;

my $tmpdir = File::Temp->newdir();
my $quoter = Finance::Quote->new;
my $fail_count = 0;
$| = 1; # auto-flush stdout

# 
# Test the TDBank plugin for Finance::Quote
# Arguments:
#   A string describing the test.  Must not end with newline.
#   An array of quote configurations.  Each is a map with following fields:
#       'symbol': the symbol to lookup
#       'code': the code number for the symbol
#       'code_response': a CODE_URI response, or undef to use a live server 
#           response
#       'quote_response': a QUOTE_URI response, or undef to use a live server 
#           response
#       'results': a map of success conditions.  Each key is a response field; 
#           values can be undef to require no value in the field, '' to require 
#           an unspecified value in the field, or a specific value.
# This function cannot use live server responses for some symbols and given 
# responses for others; if a code_response or quote_response is given for any 
# symbol in the array, then one must be given for all symbols.
#
sub test_TDBank
{
    my $str = shift;
    my $config = shift;
    if (0 == scalar @{$config})
    {
        print STDERR "Error: config list is empty\n";
        return;
    }

    print('Testing '.$str.'... ');

    my @args = ('tdbank');
    my $code_uri = $Finance::Quote::TDBank::CODE_URI;
    my $quote_uri = $Finance::Quote::TDBank::QUOTE_URI;
    my $code_responses = 0;
    my $quote_responses = 0;

    foreach (@{$config})
    {
        my %item = %{$_};
        push(@args, $item{'symbol'});

        # If a JSON response was provided, use it instead of a response from the live server.
        if (defined $item{'code_response'})
        {
            $Finance::Quote::TDBank::CODE_URI = URI::file->new($tmpdir->dirname()).'/';
    
            open(my $file, '>'.File::Spec->catfile($tmpdir->dirname(), $item{'symbol'})) or die("Error opening file");
            print $file $item{'code_response'};
            close($file);
            ++$code_responses;
        }

        # If a CSV response was provided, use it instead of a response from the live server.
        if (defined $item{'quote_response'})
        {
            $Finance::Quote::TDBank::QUOTE_URI = URI::file->new($tmpdir->dirname()).'/';

            open(my $file, '>'.File::Spec->catfile($tmpdir->dirname(), $item{'code'})) or die("Error opening file");
            print $file $item{'quote_response'};
            close($file);
            ++$quote_responses;
        }
    }
    
    if (0 != $code_responses && scalar @{$config} != $code_responses)
    {
        print STDERR "Error: mixed code_response configurations\n";
        return;
    }
    if (0 != $quote_responses && scalar @{$config} != $quote_responses)
    {
        print STDERR "Error: mixed quote_response configurations\n";
        return;
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
                        last;
                    }
                }
                elsif ($value ne $quote{$symbol, $field})
                {
                    $success = 0;
                    last;
                }
            }
            else
            {
                if (defined $quote{$symbol, $field})
                {
                    $success = 0;
                    last;
                }
            }
        }
    }

    # Restore the code and quote URIs
    $Finance::Quote::TDBank::CODE_URI = $code_uri;
    $Finance::Quote::TDBank::QUOTE_URI = $quote_uri;

    print $success ? "success.\n" : "FAILURE.\n";
    ++$fail_count if (!$success);
}


my $tdbank_code_tdb972 = '[{"value":"11","label":"TD Dividend Growth Fund- I TDB972"}]';
my $tdbank_quote_tdb972 = "TD Dividend Growth Fund - I\n".
                          "Date,Yield,Distribution\n".
                          "11-18-2014,\$74.47,0.00,\n".
                          "11-19-2014,\$74.77,0.00,\n".
                          "11-20-2014,\$75.04,0.00,\n".
                          "11-21-2014,\$75.05,0.00,\n";
my $tdbank_code_tdb218 = '[{"value":"1978","label":"TD Dow Jones Industrial Average Index Fund (US$) - I TDB218"}]';
my $tdbank_quote_tdb218 = "TD Dow Jones Industrial Average Index Fund (US\$) - I".
                          "Date,Yield,Distribution\n".
                          "11-18-2014,\$11.37,0.00,\n".
                          "11-19-2014,\$11.37,0.00,\n".
                          "11-20-2014,\$11.39,0.00,\n".
                          "11-21-2014,\$11.45,0.00,\n";

# Test well-formed responses
test_TDBank('well-formed response', 
            [{'symbol' => 'TDB972', 
              'code' => 11, 
              'code_response' => $tdbank_code_tdb972, 
              'quote_response' => $tdbank_quote_tdb972, 
              'results' => {'success' => 1, 'last' => '75.05', 'date' => '11/21/2014', 'currency' => 'CAD'}}]);
test_TDBank('well-formed response for multiple symbols', 
            [{'symbol' => 'TDB972', 
              'code' => 11, 
              'code_response' => $tdbank_code_tdb972, 
              'quote_response' => $tdbank_quote_tdb972, 
              'results' => {'success' => 1, 'last' => '75.05', 'date' => '11/21/2014', 'currency' => 'CAD'}},
             {'symbol' => 'TDB218', 
              'code' => 1978, 
              'code_response' => $tdbank_code_tdb218, 
              'quote_response' => $tdbank_quote_tdb218, 
              'results' => {'success' => 1, 'last' => '11.45', 'date' => '11/21/2014', 'currency' => 'USD'}}]);

# Test malformed CODE_URI responses
test_TDBank('empty code response',
            [{'symbol' => 'TDB972',
              'code' => 11,
              'code_response' => '',
              'quote_response' => undef,
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);
test_TDBank('non-JSON code response',
            [{'symbol' => 'TDB972',
              'code' => 11,
              'code_response' => '<!DOCTYPE html><html><body><h1>Go away</h1></body></html>',
              'quote_response' => undef,
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);
test_TDBank('non-array JSON code response',
            [{'symbol' => 'TDB972',
              'code' => 11,
              'code_response' => '{"value":11,"label":"TD Dividend Growth Fund- I TDB972"}',
              'quote_response' => undef,
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);
test_TDBank('empty array JSON code response',
            [{'symbol' => 'TDB972',
              'code' => 11,
              'code_response' => '[]',
              'quote_response' => undef,
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);
test_TDBank('missing value in JSON code response',
            [{'symbol' => 'TDB972',
              'code' => 11,
              'code_response' => '[{"label":"TD Dividend Growth Fund- I TDB972"}]',
              'quote_response' => undef,
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);
test_TDBank('missing label in JSON code response',
            [{'symbol' => 'TDB972',
              'code' => 11,
              'code_response' => '[{"value":11,"foo":"TD Dividend Growth Fund- I TDB972"}]',
              'quote_response' => undef,
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);
test_TDBank('empty value in JSON code response',
            [{'symbol' => 'TDB972',
              'code' => 11,
              'code_response' => '[{"value":"","foo":"TD Dividend Growth Fund- I TDB972"}]',
              'quote_response' => undef,
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);
test_TDBank('mixed valid and invalid JSON code responses',
            [{'symbol' => 'TDB972',
              'code' => 11,
              'code_response' => '[{"value":"","foo":"TD Dividend Growth Fund- I TDB972"}]',
              'quote_response' => '',
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}},
             {'symbol' => 'TDB218', 
              'code' => 1978, 
              'code_response' => $tdbank_code_tdb218, 
              'quote_response' => $tdbank_quote_tdb218, 
              'results' => {'success' => 1, 'last' => '11.45', 'date' => '11/21/2014', 'currency' => 'USD'}}]);
test_TDBank('multiple JSON code responses',
            [{'symbol' => 'TDB972',
              'code' => 11,
              'code_response' => '[{"value":11,"label":"TD Dividend Growth Fund- I TDB972"}, {}]',
              'quote_response' => undef,
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);
test_TDBank('invalid code',
            [{'symbol' => 'TDB972',
              'code' => 9999,
              'code_response' => '[{"value":"9999","foo":"TD Dividend Growth Fund- I TDB972"}]',
              'quote_response' => undef,
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);

# Test malformed QUOTE_URI responses
test_TDBank('empty quote response',
            [{'symbol' => 'TDB972',
              'code' => 11,
              'code_response' => $tdbank_code_tdb972,
              'quote_response' => '',
              'result' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);
test_TDBank('single-line CSV quote response',
            [{'symbol' => 'TDB972',
              'code' => 11,
              'code_response' => $tdbank_code_tdb972,
              'quote_response' => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAa",
              'result' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);
test_TDBank('two-line CSV quote response',
            [{'symbol' => 'TDB972',
              'code' => 11,
              'code_response' => $tdbank_code_tdb972,
              'quote_response' => "TD Dividend Growth Fund - I\nDate,Yield,Distribution\n",
              'result' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);
test_TDBank('incorrect number of columns in CSV quote response',
            [{'symbol' => 'TDB972',
              'code' => 11,
              'code_response' => $tdbank_code_tdb972,
              'quote_response' => "TD Dividend Growth Fund - I\nDate,Yield,Distribution\n11-18-2014,\$74.47",
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);
test_TDBank('empty date in CSV quote response',
            [{'symbol' => 'TDB972',
              'code' => 11,
              'code_response' => $tdbank_code_tdb972,
              'quote_response' => "TD Dividend Growth Fund - I\nDate,Yield,Distribution\n,\$74.47,0.00,\n",
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);
test_TDBank('empty price in CSV quote response',
            [{'symbol' => 'TDB972',
              'code' => 11,
              'code_response' => $tdbank_code_tdb972,
              'quote_response' => "TD Dividend Growth Fund - I\nDate,Yield,Distribution\n11-18-2014,,0.00,\n",
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);
# Finance::Quote doesn't check for invalid dates; it will accept things like 
# '32-32-0001' or even 'foobar' as dates.
#test_TDBank('invalid date in CSV quote response',
#            [{'symbol' => 'TDB972',
#              'code' => 11,
#              'code_response' => $tdbank_code_response,
#              'quote_response' => "TD Dividend Growth Fund - I\nDate,Yield,Distribution\n32-32-0001,\$74.47,0.00,\n",
#              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);
# Finance::Quote doesn't check for invalid prices; it will accept things like 
# '1.1.1.1' or even 'foobar' as prices.
#test_TDBank('invalid price in CSV quote response',
#            [{'symbol' => 'TDB972',
#              'code' => 11,
#              'code_response' => $tdbank_code_response,
#              'quote_response' => "TD Dividend Growth Fund - I\nDate,Yield,Distribution\n11-18-2014,\$foobar,0.00,\n",
#              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);
test_TDBank('mixed valid and invalid CSV quote responses',
            [{'symbol' => 'TDB218', 
              'code' => 1978, 
              'code_response' => $tdbank_code_tdb218, 
              'quote_response' => $tdbank_quote_tdb218, 
              'results' => {'success' => 1, 'last' => '11.45', 'date' => '11/21/2014', 'currency' => 'USD'}},
             {'symbol' => 'TDB972',
              'code' => 11,
              'code_response' => $tdbank_code_tdb972,
              'quote_response' => "TD Dividend Growth Fund - I\nDate,Yield,Distribution\n11-18-2014,,0.00,\n",
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);

# Test live server responses
test_TDBank('live server', 
            [{'symbol' => 'TDB972', 
              'code' => 11, 
              'code_response' => undef, 
              'quote_response' => undef, 
              'results' => {'success' => 1, 'last' => '', 'date' => '', 'currency' => 'CAD'}}]);
test_TDBank('live server with multiple symbols', 
            [{'symbol' => 'TDB972', 
              'code' => 11, 
              'code_response' => undef, 
              'quote_response' => undef, 
              'results' => {'success' => 1, 'last' => '', 'date' => '', 'currency' => 'CAD'}},
             {'symbol' => 'TDB218', 
              'code' => 1978, 
              'code_response' => undef, 
              'quote_response' => undef, 
              'results' => {'success' => 1, 'last' => '', 'date' => '', 'currency' => 'USD'}}]);
test_TDBank('invalid symbol', 
            [{'symbol' => 'ZZZ999', 
              'code' => 0, 
              'code_response' => undef, 
              'quote_response' => undef, 
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);
test_TDBank('mixed valid and invalid symbols',
            [{'symbol' => 'TDB972',
              'code' => 11,
              'code_response' => undef,
              'quote_response' => undef,
              'results' => {'success' => 1, 'last' => '', 'date' => '', 'currency' => 'CAD'}},
             {'symbol' => 'foobar',
              'code' => 999999,
              'code_response' => undef,
              'quote_response' => undef,
              'results' => {'success' => 0, 'last' => undef, 'date' => undef, 'currency' => undef}}]);

if (0 == $fail_count)
{
    print "All tests succeeded.\n";
}
else
{
    print "Total failures encountered: $fail_count.\n";
}

#my %quote = $quoter->fetch('tdbank', 'TDB972');
#print $quote{'TDB972', 'last'}."\n";


