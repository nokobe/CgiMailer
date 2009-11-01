#!/usr/bin/perl
#
# Copyright (c)2007 The University of Melbourne, Inc. All Rights Reserved.
# 
# THE UNIVERSITY OF MELBOURNE MAKES NO REPRESENTATIONS OR WARRANTIES ABOUT THE
# SUITABILITY OF THE SOFTWARE, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT
# LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE, OR NON-INFRINGEMENT. THE UNIVERSITY OF MELBOURNE SHALL
# NOT BE LIABLE FOR ANY DAMAGES SUFFERED BY LICENSEE AS A RESULT OF USING,
# MODIFYING OR DISTRIBUTING THIS SOFTWARE OR ITS DERIVATIVES.
#
# Redistribution and use in source and binary forms, with or without
# modification, is permitted providing this entire header remains in tact
# unmodified.
#
use MIME::Lite;
use Net::SMTP;
use LWP::UserAgent;

my $version = '2.1';
my $smtp = 'smtp.unimelb.edu.au';
my $from_default = 'cgi-mailer submission <no-reply@unimelb.edu.au>';
my $log = "/var/log/httpd/cgi-mailer.log";
my $local_network = 'unimelb.edu.au$|mu.oz.au$|^128.250.|^192.43.207.|' .
                    '^192.43.209.|^192.101.254.|^202.0.67.|^202.0.68.|' .
                    '^203.0.40.|^203.0.141.|^203.2.80.|^203.3.164.|' .
                    '^203.4.164.|^203.5.64.|^203.9.128.|^203.12.140.|' .
                    '^203.14.107.|^203.16.40.|^203.17.189.|^203.18.231.|' .
                    '^203.22.108.|^203.26.118.|^203.26.134.|^203.28.230.|' .
                    '^203.28.240.|^203.62.232.|^210.8.192.';
my $http_header = "Content-type: text/html\n\n";

my $preamble = '
<html>
<head>
<title>CGI-Mailer Response</title>
<style type="text/css">
	* {font-size: 13px; font-family: Trebuchet MS,Tahoma,Verdana, sans-serif}
	h1,h2 {font-size: 18px; color: #66a; }
</style>
</head>
<body>';

my $footer = '
<p>Further information about <a href="http://www.unimelb.edu.au/cgi-mailer/">cgi mailer</a>.</p>
</body>
</html>';


	%INPUT = &get_input(POST);
	
	# get the format file location
	$url = $INPUT{'CgiMailerReferer'} || $ENV{'HTTP_REFERER'};

	if(! $url) {
		error("Your browser or proxy server is not sending ".
              "a Referer header and CGI-Mailer needs one to ".
              "work. Please notify the maintainer of the form ".
              "and ask them to add the appropriate field to ".
              "the form.");
	}

	$url =~ s/\#.+$//;    # remove named anchor, if any
	$url =~ s/\?.+$//;    # remove query string, if any
	$orig_url = $url;     # store the original page URL for later reference

	# check the domain is OK
	if($local_network) {
		$host = $url;                # get the hostname
		$host =~ s/^\w+:\/\///;      # strip off the leading protocol://
		$host =~ s/([^\/]+)\/.*/$1/; # strip off the trailing /abc/def/xyz.html
		$host =~ s/\:\d+$//;         # strip off the trailing :port, if any

        # Attempt to find the IP address of the host
        @host_gethostbyname = gethostbyname($host);
        if ( $? == 0 ) {
            # We'll take the first address (this does not cater for
            # hosts which have some address inside and some addresses
            # outside the uni network but this is an unlikely scenario
            $host_addr = join ".", unpack('C4', $host_gethostbyname[4]);
        } else {
            # No match (or error in lookup) - just set the 'address'
            # to be the hostname as this will ensure that no 'dummy'
            # value matches a valid local network value
            $host_addr = $host;
        }
	if( $host !~ m/$local_network/i && $host_addr !~ m/$local_network/i ) {
		$local_network =~ s/[\^\$]//g;
		@domains = split(/\|/,$local_network);
		$domains = join(', ',@domains);
		error("cgi-mailer can only be used within the ".
                      "domains $domains");
	}
	}
	$url = $orig_url;
	if($url =~ /\/$/){
		if( $INPUT{'index-file'} ) {
			$orig_url = $orig_url . "/" . $INPUT{'index-file'};
		} else {
			$err_text = "If you want to use cgi-mailer ".
                        "with an index file (i.e. a URL ".
                        "ending with '/'),<br>" .
				        "you must add a hidden field to ".
                        "specify the name of the index file:<br>" .
				        "&lt;input type=&quot;hidden&quot; ".
                        "name=&quot;index-file&quot; " .
				        "value=&quot;index.html&quot;&gt;<br>".
				        "(or the name of your index file if ".
                        "it isn't &quot;index.html&quot;";
			&error($err_text);
		}
	}

	# get the required fields, if any
	$default_url = $url = $orig_url;
	if($url =~ /html$/){
		$url =~ s/html$/required/;
		$default_url =~ s|^(.*)/[^/]*$|$1/cgi-mailer-required.default|;
	} else {
		$url =~ s/htm$/req/;
		$default_url =~ s|^(.*)/[^/]*$|$1/cmail-req.def|;
	}
	$req_url = $url;
	$req = &URLget($url);
	if($req =~ /%%%ERROR%%%/) {
		# Check for default value
		$req = &URLget($default_url);
		$req_url = $default_url;
		$required_fields = 0;
	} else { 		#$req !~ /%%%ERROR%%%/ 
		$required_fields = 1;
		@lines = split(/[\013\015\r\n]+/,$req);
		foreach my $line (@lines) {
			$line =~ s/^\s*$//;
			next if $line =~ /^$/;
			my ($field_name,$description) = split(/\t/,$line,2);
			$required{$field_name} = $description;
			push(@required_fields,$field_name);
		}
	}
	push(@required_fields, 'destination') 
		if(!grep(/^destination$/,@required_fields));

	foreach my $key (keys(%INPUT)) {
		# get the mail headers from the form input
		if($key =~ /header:/i) {
			my $header_name = $key;
			$header_name =~ s/header://i;
			$header_name = &title_case($header_name);
			$headers{$header_name} = $INPUT{$key};
		}
	}
	# check if required fields have been filled in
	foreach my $r_field (@required_fields) {
		my $content = $INPUT{$r_field};
		$content =~ s/^\s*$//;
		if(! $content || length($content) == 0) {
			$data = "  <h2>CGI Mailer: Error</h2>\n" .
			 		"  <p>An error has occurred while ".
					"attempting to submit your form:</p>\n" .
			 		"  <blockquote>The input field ".
					"<strong>$required{$r_field}</strong> " .
					"           is <font color=\"#FF0000\">".
					"required</font>\n" .
					"           and must be filled in before ".
					"you can submit the form.\n" .
					" </blockquote>\n" .
					"  <p>Please go back, fill in the required ".
					"field and re-submit the form.</p>\n";

			select STDOUT;
			print $http_header;
			print $preamble;
			print $data;
			print $footer;
			log_access();
			exit(0);
		}
	}

	# get necessary info for mail headers
	$destination = $INPUT{'destination'};
	if(!$destination) {
		$err_text = "You must add a hidden field to specify ".
					"the destination of the email:<br>" .
					"&lt;input type=&quot;hidden&quot; ".
					"name=&quot;destination&quot; " .
					"value=&quot;foo\@bar.com&quot;&gt;";
		error($err_text);
	}

	# The mailtouser option has been specified and the field specified
	# exists. Test the value and append to the destination if all is well
	if (exists $INPUT{'mailtouser'} && exists $INPUT{$INPUT{'mailtouser'}} ) {
		my $user_addr = $INPUT{$INPUT{'mailtouser'}};
		$user_addr =~ /^\s*([-_\@\w.,]+)\s*$/;
		$destination .= ",${checked_address}";
	}

	$subject = $INPUT{'subject'};

	if ( exists $headers{'Reply-To'} ) {
		$reply_to = $headers{'Reply-To'};
		delete $headers{'Reply-To'};
	} elsif ( exists $INPUT{'replyto'} ) {
		$reply_to = $INPUT{'replyto'};
		delete $INPUT{'replyto'};
	}

	if ( exists $headers{'From'} ) {
		$from_addr = $headers{'From'};
		delete $headers{'From'};
	} elsif ( exists $INPUT{'From'} ) {
		$from_addr = $INPUT{'From'};
	} else {
		# No From address specified, set default address
		$from_addr = $from_default if(! $from_addr);
	}

	$default_url = $url = $orig_url;
	if( $INPUT{'nodata'} ne 'true') {
		# get the location of the format file
		if($url =~ /html$/){
			$url =~ s/html$/data/;
			$default_url =~ s|^(.*)/[^/]*$|$1/cgi-mailer-data.default|;
		} else {
			$url =~ s/htm$/dat/;
			$default_url =~ s|^(.*)/[^/]*$|$1/cmail-dat.def|;
		}
		$format_url = $url;

		# grab the format file
		$format = &URLget($url);

		if ($format =~ /%%%ERROR%%%/ ) {
			# Check default file
			$format = &URLget($default_url);
			$format_url = $default_url;
		}

		error("Couldn't get format file: $url")
			if( $format =~ /%%%ERROR%%%/ );

		# substitute values for variables in the format file
		$format =~ s/\$ENV\{\'?([a-zA-Z0-9\_\-\:]+)\'?\}/$ENV{$1}/g;
		$format =~ s/\$([a-zA-Z0-9\_\-\:]+)/$INPUT{$1}/g;
	}

	$default_url = $url = $orig_url;
	# get the response file if there is one
	if($url =~ /html$/){
		$url =~ s/html$/response/;
		$default_url =~ s|^(.*)/[^/]*$|$1/cgi-mailer-response.default|;
	} else {
		$url =~ s/htm$/res/;
		$default_url =~ s|^(.*)/[^/]*$|$1/cmail-res.def|;
	}
	$response_url = $url;
	$response = &URLget($url);
	if($response =~ /%%%ERROR%%%/) {
		# Check default file
		$response = &URLget($default_url);
		$response_url = $default_url;
	}
	$response =~ s/\$ENV\{\'?([a-zA-Z0-9\_\-\:]+)\'?\}/$ENV{$1}/g;
	$response =~ s/\$([a-zA-Z0-9\_\-\:]+)/$INPUT{$1}/g;

	$default = "true" if($response =~ /%%%ERROR%%%/);

	# if there if no response file, set up the default response
	if($response !~ /%%%ERROR%%%/) {
		$data = $response if($response);
	} else {
		$data = "  <h3>CGI Mailer: Submission Successful</h3>\n" .
			"  <p>Your form has been successfully ".
			"submitted by the server\n </p>";
	}

	if( $INPUT{'nodata'} ne 'true') {
		# mail the formatted message
		my %mail;
		$mail{To} = $destination;
		$mail{From} = $from_addr if $from_addr;
		$mail{"Subject:" } = $subject;
		$mail{"Reply-to:"} = $reply_to if $reply_to;

		foreach (keys(%headers)) {
			my $key = (/:/) ? "$_": "$_ :";
			$mail{$key} = $headers{$_};
		}

		$mail{"X-Generated-By:"} = "CGI-Mailer v$version";
		$mail{"X-Form:"} = $ENV{'HTTP_REFERER'};
		$mail{"Encoding"} = "quoted-printable";
		$mail{"Type"} = "TEXT";

		# Translate (Windows|Unix|Mac) EOL with local EOL
		$format =~ s/(?:\x0d\x0a|\x0a|\x0d)/\n/g;

		my $msg = MIME::Lite->new(%mail, Data=>$format);
		$msg->send('smtp', $smtp);
	}

	log_access();

	select STDOUT;
	print $http_header;
	print $preamble if $default;
	print $data if $default;
	print $response unless $default;
	print $footer if $default;
	exit(0);

sub error {
	my $errstr = pop(@_);
	$data = "  <h2>CGI Mailer: Error</h2>\n" .
			"  <p>An error has occurred while attempting to submit your form:</p>\n" .
			"  <blockquote><b>$errstr</b></blockquote>\n" .
			"  <p>Please report this error to the maintainer of the form</p>\n";

	select STDOUT;
	print $http_header;
	print $preamble;
	print $data;
	print $footer;

	log_access($errstr);

	exit(0);
}

sub get_input{

	$method = pop(@_);
	
	local( $len, $postinput, $param, $value, $item, @INPUT, %INPUT_ARRAY );

	if( $method eq "GET") {
		$QUERY = $ENV{QUERY_STRING};
		$QUERY =~ s/\+/ /g;             # Change +'s to spaces
		$QUERY =~ s/%([\da-f]{1,2})/pack(C,hex($1))/eig;

		@QUERY_LIST = split( /&/, $QUERY);
		foreach $item (@QUERY_LIST) {
			($param, $value) = split( /=/, $item);
			$INPUT_ARRAY{$param} .= $value;
		}
	} elsif( $method eq "POST") {
		$len = $ENV{CONTENT_LENGTH};
		$postinput=<STDIN>;
		$postinput =~ s/\n|\r/ /g;
		$postinput =~ s/\+/ /g;
		@INPUT = split( /&/, $postinput);

		foreach $item (@INPUT) {
			($param, $value) = split( /=/, $item);
			$value =~ s/%([\da-f]{1,2})/pack(C,hex($1))/eig;
			$param =~ s/%([\da-f]{1,2})/pack(C,hex($1))/eig;
			if( $INPUT_ARRAY{$param} ) {
				$INPUT_ARRAY{$param} .= ",$value";
			} else {
				$INPUT_ARRAY{$param} = $value;
			}
		}
	}
	return (%INPUT_ARRAY);
}

sub title_case {
	$_ = pop(@_);
	$_ = "\L$_";
	s/(\b[a-z])/\U$1/g;
	$_;
}

sub URLget {
	my $URL = pop(@_);
	my $ret;

	my $domain = $URL;             # Deconstruct URL
	$domain =~ s/^\w+:\/\///;      # strip off the leading protocol://

	my $path = $domain;
	$domain =~ s/([^\/]+)\/.*/$1/; # strip off the trailing /abc/def/xyz.html
	$path =~ s/[^\/]+(\/.*)$/$1/;

	$domain =~ s/\:\d+$//;         # strip off the trailing :port, if any

	$ua = new LWP::UserAgent;
	$ua->agent("cgi-mailer/$version");
	$ua->timeout(10);
	#$ua->proxy(['http'], 'http://wwwproxy.unimelb.edu.au:8000');

	my $req = new HTTP::Request GET => "$URL";

	$req->header('Accept' => '*/*'); # Required for older versions of Microsoft IIS
	my $res = $ua->request($req);

	if ($res->is_success) {
		$ret = $res->content;
	} else {
		$ret = '%%%ERROR%%%';
	}

	log_access("Remote domain - fetching ${URL}");

	return $ret;
}

sub time_now {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
	my %months = ( '0','Jan', '1','Feb', '2','Mar', '3','Apr',
		'4','May', '5','Jun', '6','Jul', '7','Aug',
		'8','Sep', '9','Oct', '10','Nov', '11','Dec');
	my $now;

	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900; $hour = "0" . $hour if($hour < 10);
	$min = "0" . $min if($min < 10); $sec = "0" . $sec if($sec < 10);

	$now = "$hour:$min:$sec $mday $months{$mon} $year";

	return $now;
}

sub log_access {
	my $errstr = pop(@_);
	my $date;

	$date = &time_now();
	if(open LOG,">> $log") {
		print LOG "[$date] host=[$ENV{'REMOTE_HOST'}] ".
			"referer=[$ENV{'HTTP_REFERER'}] data=[$format_url] " .
			"resp=[$response_url] to=[$destination] subject=[$subject] ".
			"reply-to=[$reply_to]";
		print LOG " ERROR=[$errstr]" if $errstr;
		print LOG " from=[$from_addr]" if $from_addr;
		print LOG "\n";
		close LOG;
	}
}
