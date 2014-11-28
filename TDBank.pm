#
# Copyright 2014 Rennie deGraaf <rennie.degraaf@gmail.com>
#
# Finance::Quote module to retrieve mutual fund quotes from TD Canada Trust.
# WARNING: The URIs used by this module are not part of a supported public API 
# and may change at any time.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# Get a fund code by symbol:
# $ curl 'https://graphtdam.tdbank.ca/fundSearch.form?appName=TDCT&language=en&term=TDB972' -H 'Host: graphtdam.tdbank.ca' -H 'Accept: application/json'
# Get fund prices by code:
# $ curl 'https://graphtdam.tdbank.ca/getFileDownload.form' -H 'Host: graphtdam.tdbank.ca' -H 'Accept: text/plain' --data 'appName=TDCT&timeFrame=1&chooseActionForm=2&fundOne=11'


package Finance::Quote::TDBank;
require 5.005;
use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common;
use URI::Escape;
use JSON qw(decode_json);

use vars qw($VERSION $CODE_URI $QUOTE_URI);
$VERSION = '1.20';
$CODE_URI='https://graphtdam.tdbank.ca/fundSearch.form?appName=TDCT&language=en&term=';
$QUOTE_URI='https://graphtdam.tdbank.ca/getFileDownload.form?appName=TDCT&timeFrame=1&chooseActionForm=2&fundOne=';

sub methods { return (tdbank => \&tdbank); }
sub labels { return (tdbank => [qw/name symbol date last currency/]); }

sub tdbank
{
    my $quoter = shift;
    my @symbols = @_;
    return unless @symbols;

    my %info;
    my $ua = $quoter->user_agent;

    foreach (@symbols)
    {
        my $symbol = $_;

        # Get the fund code from the symbol
        my $response = $ua->get($CODE_URI.uri_escape($symbol), 'Accept' => 'application/json');
        unless($response->is_success)
        {
            $info{$symbol, 'errormsg'} = 'Error retrieving symbol code';
            $info{$symbol, 'success'} = 0;
            next;
        }
        # If $symbol is ambiguous, $CODE_URI will return multiple responses.
        my @json;
        eval {@json = @{decode_json($response->content)}};
        unless (!$@ && 1 == scalar @json && $json[0]->{'label'} && $json[0]->{'value'} && '' ne $json[0]->{'value'})
        {
            $info{$symbol, 'errormsg'} = 'Could not parse code response';
            $info{$symbol, 'success'} = 0;
            next;
        }
        my $currency;
        if ($json[0]->{'label'} =~ /\(US\$\)/)
        {
            $currency = 'USD';
        }
        else
        {
            $currency = 'CAD';
        }

        # Get the quote from the fund code
        $response = $ua->get($QUOTE_URI.uri_escape($json[0]->{'value'}), 'Accept' => 'text/plain');
        unless ($response->is_success)
        {
            $info{$symbol, 'errormsg'} = 'Error retrieving quote';
            $info{$symbol, 'success'} = 0;
            next;
        }

        # Decode the CSV
        # The first line should be the name of the fund.
        # The second line should be headings (Date,Yield,Distribution).
        # For whatever reason, they add an empty fouth column to data rows.
        my @csv = split('\n', $response->content);
        unless (3 <= scalar @csv)
        {
            $info{$symbol, 'errormsg'} = 'Could not parse CSV header';
            $info{$symbol, 'success'} = 0;
            next;
        }
        my @quote = $quoter->parse_csv($csv[$#csv]);
        unless (4 == scalar @quote && defined $quote[0] && defined $quote[1])
        {
            $info{$symbol, 'errormsg'} = 'Could not parse CSV row';
            $info{$symbol, 'success'} = 0;
            next;
        }

        $quoter->store_date(\%info, $symbol, {usdate => $quote[0]});
        $info{$symbol, 'last'} = ($quote[1] =~ s/^\$//r);
        $info{$symbol, 'currency'} = $currency;
        $info{$symbol, 'symbol'} = ($json[0]->{'label'} =~ s/.* //r);
        $info{$symbol, 'name'} = $csv[0];
        $info{$symbol, 'source'} = 'Finance::Quote::TDBank';
        $info{$symbol, 'success'} = 1;
    }

    return wantarray() ? %info : \%info;
}

__END__

=head1 NAME

Finance::Quote::TDBank                    - Obtain quotes from TD Bank

=head1 SYNOPSIS

  use Finance::Quote;
  my $q = Finance::Quote->new;
  my %quote = $q->fetch('tdbank', 'TDB972');

=head1 DESCRIPTION

Finance::Quote module to retrieve mutual funds quotes from TD Canada Trust.

As symbols, this module accepts either TD's fund codes (eg, 'TDB972') 
or any unambiguous substrings of the fund names (eg, 'Dividend Growth').

=head1 LABELS RETURNED

Information available from TD may include the following labels:  

    name
    symbol
    date
    last
    currency

=head1 SEE ALSO

  Finance::Quote
  TD Canada Trust: https://www.tdcanadatrust.com/

=cut

