#
# Copyright 2014 Rennie deGraaf <rennie.degraaf@gmail.com>
#
# Finance::Quote module to retrieve stock and fund quotes from Google Finance.
# WARNING: The Google Finance API is deprecated and may be discontinued at any 
# time.
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


# To get a fund quote:
# $ curl 'https://www.google.com/finance/info?q=TDB972,GOOG' -H 'Host: www.google.com' -H 'Accept: application/json'

# TDB972: TD Dividend Growth
# TDB162: TD Canadian Bond.  Google uses TDB030
# TDB622: TD Monthly Income.  Google uses CTI16


package Finance::Quote::Google;
require 5.005;
use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common;
use URI::Escape;
use JSON qw(decode_json);

use vars qw($VERSION $QUOTE_URI);
$VERSION = '1.20';
$QUOTE_URI='https://www.google.com/finance/info?q=';

sub methods { return (google => \&google); }
sub labels { return (google => [qw/method exchange name nav date isodate price/]); } # TODO

sub get_currency_by_exchange
{
    my $exchange = shift;

    # WARNING: These lists are extremely incomplete!
    foreach (qw(MUTF NASDAQ NYSE))
    {
        return 'USD' if ($_ eq $exchange);
    }
    foreach (qw(MUTF_CA))
    {
        return 'CAD' if ($_ eq $exchange);
    }
    foreach (qw(LON))
    {
        return 'GBP' if ($_ eq $exchange);
    }
}

sub google
{
    my $quoter = shift;
    my @symbols = @_;
    return unless @symbols;

    my %info;
    my $ua = $quoter->user_agent;

    # Request quotes for the given symbols.
    # This is a really terrible API: 
    #   * It sometimes translates one symbol to another, but since callers can 
    #     request more than one symbol at once, they have no way to know which 
    #     symbol in the request maps to which symbol in the response.
    #   * It doesn't unambiguously indicate the currency.  The 'l_cur' field 
    #     contains a currency indicator, but it uses '$' for both CAD and USD.
    #   * It provides conflicting information about the time zone.  The 
    #     timestamp in 'lt_dts' has a 'Z' suffix indicating UTC, but the 
    #     correct time zone is actually the one in 'ltt' and 'lt'.
    # It's disappointing that Google deprecated it instead of fixing it.
    my $response = $ua->get($QUOTE_URI. uri_escape(join(',', @symbols)));
    if ($response->is_success)
    {
        # Strip off the leading '// ' so that we have valid JSON
        my $json = ($response->content =~ s/^[^[{]*//r);

        # Decode the JSON
        my @quotes;
        eval {@quotes = @{decode_json($json)}};
        unless (!$@)
        {
            foreach (@symbols)
            {
                $info{$_, 'errormsg'} = 'Error parsing response';
                $info{$_, 'success'} = 0;
            }
        }

        # Convert the array of quotes to a map.
        my %quote_map;
        foreach (@quotes)
        {
            if ($_->{'t'})
            {
                $quote_map{$_->{'t'}} = $_;
            }
        }
        
        foreach (@symbols)
        {
            # Make sure that we have a quote with the required fields
            unless (defined $quote_map{$_})
            {
                $info{$_, 'errormsg'} = 'No response received';
                $info{$_, 'success'} = 0;
                next;
            }
            my $quote = $quote_map{$_};
            unless ($quote->{'l'} && '' ne $quote->{'l'} && $quote->{'lt_dts'} && $quote->{'e'})
            {
                $info{$_, 'errormsg'} = 'Missing or invalid fields in response';
                $info{$_, 'success'} = 0;
                next;
            }
            
            # Parse fields before we set anything in the response
            # lt_dts is a timestamp of the form YYYY-mm-DDTHH:MM:SSZ
            (my $date, my $time) = ($quote->{'lt_dts'} =~ /^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}):\d{2}Z$/);
            # l_cur may contain a currency symbol, but it's ambiguous.
            # So we guess the currency based on the exchange.
            my $currency = get_currency_by_exchange($quote->{'e'});
            unless ($date && $time && $currency)
            {
                $info{$_, 'errormsg'} = 'Missing or invalid fields in response';
                $info{$_, 'success'} = 0;
                next;
            }

            $info{$_, 'last'} = $quote->{'l'};
            $quoter->store_date(\%info, $_, {isodate => $date});
            $info{$_, 'time'} = $time;
            if ($quote->{'ltt'})
            {
                # ltt is a timestamp of the form H:MMPP ZZ
                ($info{$_, 'timezone'}) = ($quote->{'ltt'} =~ /^\d{1,2}:\d{2}[AP]M ([A-Z]+)$/);
            }
            $info{$_, 'currency'} = $currency;
            $info{$_, 'symbol'} = $_;
            $info{$_, 'exchange'} = $quote->{'e'};
            $info{$_, 'method'} = 'Google';
            $info{$_, 'source'} = 'Finance::Quote::Google';
            $info{$_, 'success'} = 1;
        }
    }
    else
    {
        foreach (@symbols)
        {
            $info{$_, 'errormsg'} = 'Error retrieving quotes';
            $info{$_, 'success'} = 0;
        }
    }

    return wantarray() ? %info : \%info;
}

1;

__END__

=head1 NAME

Finance::Quote::Google             - Obtain quotes from Google Finance

=head1 SYNOPSIS

  use Finance::Quote;
  my $q = Finance::Quote->new;
  my %quote = $q->fetch('google', 'GOOG');

=head1 DESCRIPTION

Finance::Quote module to retrieve stock quotes from Google Finance.

=head1 LABELS RETURNED

Information available from TD may include the following labels:  

    symbol
    exchange
    date
    time
    timezone
    last
    currency

=head1 SEE ALSO

  Finance::Quote
  Google Finance: https://www.google.com/finance
  http://m.blog.csdn.net/blog/solaris_navi/6730464

=cut
