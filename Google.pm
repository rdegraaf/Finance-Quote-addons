# Google.pm

package Finance::Quote::Google;
require 5.004;

use strict;

use vars qw($VERSION $GOOGLE_URI);
use LWP::UserAgent;
use HTTP::Request::Common;
use JSON qw(decode_json);

$VERSION = '1.20';

$GOOGLE_URI=("https://www.google.com/finance/info?q=");

sub methods { return (google => \&google); }

sub labels { return (google => [qw/method exchange name nav date isodate price/]); }

sub get_currency_by_exchange
{
    my $exchange = shift;

    if ("MUTF" eq $exchange || "NASDAQ" eq $exchange || "NYSE" eq $exchange)
    {
        return "USD";
    }
    if ("MUTF_CA" eq $exchange)
    {
        return "CAD";
    }
}

sub google
{
    my $quoter = shift;
    my @symbols = @_;
    return unless @symbols;

    my($ua, $response, %info, $json, @data, $date, $time, $currency);

    $ua = $quoter->user_agent;
    $response = $ua->request(GET $GOOGLE_URI. join(",", @symbols));

    if ($response->is_success)
    {
        # Filter out the leading '// '
        $json = $response->content;
        $json =~ s/.*(?=[[{])//;

        # Decode the JSON
        #print $json;
        @data = @{decode_json($json)};
        foreach (@data)
        {
            my $symbol = $_->{"t"};
            $info{$symbol, 'success'} = 1;
            $info{$symbol, 'symbol'} = $symbol;
            $info{$symbol, 'last'} = $_->{"l"};
            $info{$symbol, 'price'} = $_->{"l"};
            $info{$symbol, 'timezone'} = "UTC";
            $date = $_->{"lt_dts"};
            $date =~ s/T.*//;
            $quoter->store_date(\%info, $symbol, {isodate => $date});
            $time = $_->{"lt_dts"};
            $time =~ s/.*T//;
            $time =~ s/:[0-9]{2}Z$//;
            $info{$symbol, 'time'} = $time;
            $info{$symbol, 'method'} = "Google";
            $currency = get_currency_by_exchange($_->{"e"});
            if ("" ne $currency)
            {
                $info{$symbol, 'currency'} = $currency;
            }
        }
    }

    return wantarray() ? %info : \%info;
}

1;

__END__

=head1 NAME

Finance::Quote::Google		- Obtain quotes from Google Finance

=head1 SYNOPSIS

=head1 DESCRUPTION

=head1 LABELS RETURNED

=head1 SEE ALSO

=cut

