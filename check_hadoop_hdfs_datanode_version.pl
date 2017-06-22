#!/usr/bin/perl -T
# nagios: -epn
#
#  Author: Hari Sekhon
#  Date: 2013-02-11 12:59:27 +0000 (Mon, 11 Feb 2013)
#
#  https://github.com/harisekhon/nagios-plugins
#
#  License: see accompanying LICENSE file
#

our $DESCRIPTION = "Nagios Plugin to check a Hadoop HDFS DataNode's version via the NameNode's /jmx page

Tested on Apache Hadoop NameNode 2.5.2, 2.6.4, 2.7.2.
";

$VERSION = "0.1";

use strict;
use warnings;
BEGIN {
    use File::Basename;
    use lib dirname(__FILE__) . "/lib";
}
use HariSekhonUtils;
use Data::Dumper;
use LWP::Simple qw/get $ua/;

set_port_default(50070);
env_creds(["HADOOP_NAMENODE", "NAMENODE", "HADOOP"], "Hadoop NameNode");

my $bean = "Hadoop:service=NameNode,name=NameNodeInfo";
my $metrics = "LiveNodes";
my $node;
my $expected;

%options = (
    %hostoptions,
    "N|node=s"      => [ \$node,         "Node name to check" ],
    "e|expected=s"  => [ \$expected,     "Expected version (regex, optional)" ],
);

@usage_order = qw/host port expected/;
get_options();

$host   = validate_host($host);
$host   = validate_resolvable($host);
$port   = validate_port($port);
my $url = "http://$host:$port/jmx?qry=$bean";
if(not defined($node)){
    usage "node not defined";
}
$expected = validate_regex($expected) if defined($expected);

vlog2;
set_timeout();
set_http_timeout($timeout - 1);

$status = "OK";

# ============================================================================ #

my $content = curl_json $url, "Hadoop daemon $host:$port";

my @beans = get_field_array("beans");

sub get_bean($){
    my $bean = shift;
    #my @beans = get_field_hash("beans");
    foreach(@beans){
        isHash($_) or quit "UNKNOWN", "invalid bean found, not a hash! $nagios_plugins_support_msg_api";
        if(get_field2($_, "name") eq $bean){
            return $_;
        }
    }
    quit "UNKNOWN", "failed to find bean with name '$bean'. $nagios_plugins_support_msg_api";
}

vlog2 "parsing JMX from '$host:$port'\n";

my $section = get_bean($bean);

my $livenodes = get_field2($section, "LiveNodes");

$json = isJson($livenodes);

if(!$json){
    quit "CRITICAL", "failed to parse json from LiveNodes metric in bean '$bean'. $nagios_plugins_support_msg_api";
}

vlog3 Dumper($json);

my @nodes = grep { $_ =~ /^$node(?::\d+)?$/ } keys %{$json};
if(not @nodes){
    quit "CRITICAL", "datanode '$node' not found in NameNode JMX";
}
if(scalar @nodes > 1){
    quit "CRITICAL", "more than one node matched!! $nagios_plugins_support_msg";
}

my $version = get_field2($json->{$nodes[0]}, "version");

if(!isVersion($version)){
    quit "CRITICAL", "unrecognized version '$version'. Format may have changed. $nagios_plugins_support_msg";
}

$msg = "Hadoop DataNode '$node' version = $version";
check_regex($version, $expected) if defined($expected);

quit $status, $msg;
