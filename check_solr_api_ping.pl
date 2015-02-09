#!/usr/bin/perl -T
# nagios: -epn
#
#  Author: Hari Sekhon
#  Date: 2014-06-07 18:29:01 +0100 (Sat, 07 Jun 2014)
#
#  http://github.com/harisekhon
#
#  License: see accompanying LICENSE file
#

$DESCRIPTION = "Nagios Plugin to check Solr availability via the in-built Solr API Ping

Optional warning/critical thresholds apply to query response time (QTime field)

Tested on Solr 3.1, 3.6.2 and Solr / SolrCloud 4.x";

$VERSION = "0.2";

use strict;
use warnings;
BEGIN {
    use File::Basename;
    use lib dirname(__FILE__) . "/lib";
}
use HariSekhonUtils qw/:DEFAULT :time/;
use HariSekhon::Solr;

$ua->agent("Hari Sekhon $progname $main::VERSION");

set_threshold_defaults(50, 1000);

my $api_ping;

%options = (
    %solroptions,
    %solroptions_collection,
    %thresholdoptions,
);
splice @usage_order, 6, 0, qw/collection/;

get_options();

$host       = validate_host($host);
$port       = validate_port($port);
unless(defined($collection)){
    $collection = "collection1";
}
$collection = validate_collection($collection);
validate_thresholds(0, 0, { 'simple' => 'upper', 'positive' => 1, 'integer' => 1 });
validate_ssl();

vlog2;
set_timeout();

$status = "OK";

list_solr_collections();

$url = "solr/$collection/admin/ping?distrib=false";

$json = curl_solr $url;

my $qstatus = get_field("status");
unless($qstatus eq "OK"){
    critical;
}
$msg .= "Solr API ping of collection '$collection' " . ( $verbose ? "(" . get_field("responseHeader.params.q") . ") " : "") . "returned $qstatus, query time ${query_time}ms";
check_thresholds($query_time);
$msg .= " | ";

$msg .= sprintf('query_time=%dms', $query_time);
msg_perf_thresholds();

quit $status, $msg;
