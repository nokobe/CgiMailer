#!/usr/local/bin/perl
### ---------------------------------------------------------------------- ###
#
# CGI Mailer - a CGI program to send formatted email from HTML forms
# 
# *Requires* perl 5.001 or greater and the LWP module.
#
# *Requires* the MailTools module if you want to use Mail::Send
# *Requires* the libnet module if you want to use Net::SMTP
#
# (c) Copyright The University of Melbourne, 1996-1999
# Author: Martin Gleeson, <gleeson@unimelb.edu.au>
#
# This program is provided free of charge provided the Copyright notice
# remains intact. Commercial organisations should contact the author for
# licensing details if you wish to modify the source code in any form
# other than to set configuration options as directed in the Administrator
# Documentation. <http://www.unimelb.edu.au/cgi-mailer/>
# No warranty is made, either expressed or implied. USE AT YOUR OWN RISK.
#
### ---------------------------------------------------------------------- ###
#
use lib '/servers/web/lib/perl5/site_perl/5.005';
use MIME::Lite;
use Email::Valid;

my $version = '$Revision: 1.52 $';
($version) = $version =~ / (\d+\.\d+) /;
#
# Created: 23 April 1996
#
# Change logs removed
#
### ---------------------------------------------------------------------- ###
#
# Configurable settings - change these to reflect your local setup
#
### ---------------------------------------------------------------------- ###
# Do you want to use the Net::SMTP module rather than sendmail directly?

# $net_smtp = "yes";

# You will also need to set a mailhost to use to send the message if you
# use this option

# $mailhost = "mailhost.wherever.com";

### ---------------------------------------------------------------------- ###
# Do you want to use the Mail::Send module rather than sendmail directly?

# $mail_send = "yes";

### ---------------------------------------------------------------------- ###
# Default from address if non is specified:
my $from_default = 'cgi-mailer submission <http@myriad.its.unimelb.edu.au>';

### ---------------------------------------------------------------------- ###
# If you're not using the Mail::Send module or the Net::SMTP, then you'll
# need to set the full path to sendmail on your machine
my $sendmail = "/usr/sbin/sendmail";

### ---------------------------------------------------------------------- ###
# If you're using sendmail directly but your line length may exceed 1000

my $mail_mimelite = "yes";

### ---------------------------------------------------------------------- ###
# Full path to log file (for logging cgi-mailer usage).

my $log = "/var/log/apache/web/cgi-mailer.log";

### ---------------------------------------------------------------------- ###
# Domain name(s) of your local network
#
# This restricts the use of cgi-mailer to those within your organisation,
# or the domains named. Syntax is 'domain.abc.xyz$' or '^128.250.' or
# 'domain.one.xyz$|domain.two.xyz$|^128.250.|domain.four.xyz$', etc
#
# comment the line out if you don't want to restrict access (not recommended)

my $local_network = 'unimelb.edu.au$|mu.oz.au$|^128.250.|^192.43.207.|' .
                    '^192.43.209.|^192.101.254.|^202.0.67.|^202.0.68.|' .
                    '^203.0.40.|^203.0.141.|^203.2.80.|^203.3.164.|' .
                    '^203.4.164.|^203.5.64.|^203.9.128.|^203.12.140.|' .
                    '^203.14.107.|^203.16.40.|^203.17.189.|^203.18.231.|' .
                    '^203.22.108.|^203.26.118.|^203.26.134.|^203.28.230.|' .
                    '^203.28.240.|^203.62.232.|^210.8.192.';

### ---------------------------------------------------------------------- ###
# Alternate paths/urls to cgi-mailer configuration information
# This is required because of the behaviour of the local director - 
# servers on the same segment behind the localdirector cannot access
# addresses hosted by the director on that segment - ie www.unimelb.edu.au
# _cannot_ access the address www.its.unimelb.edu.au.
# For locally hosts virtual servers, the files will be obtained locally.
# For other machines on this segment the real machine name will be used.

# Base of localy hosted domains
my $domain_base = "/servers/http";

# Apache domain config base
my $apache_domain_config_base = "/etc/apache/Domains";

# Local domains need to be dealt with specially because we can't access
# local domains via the network (due to the local director).
# If the domain is hosted on the main web server, retrieve the files
# via the local filesystem

# The local domains are found from the localfile system
opendir(DIR, $domain_base) or die "Can't read directory: $domain_base";
my @local_domains = grep {!/^\.*$/} readdir(DIR);
closedir DIR;

# In addition there are server aliases in action, these need to be
# treated slightly differently.
my %local_serveraliases = ();
opendir(DIR, $apache_domain_config_base) or 
                     die "Can't read directory: $apache_domain_config_base";

for my $conf_file (readdir(DIR)) {
	my $servername;
	my $serveralias;

	# Read file, determine server name from ServerName directive
	open FILE, "< $apache_domain_config_base/$conf_file" or next;
	while (<FILE>) {
		next unless /^ServerName/i;
		/^ServerName\s+(\S+)$/i;
		$servername = $1;
	}
	close FILE;

	# Check if there was no server name (this would be 
        # bad, but just in case)
	next unless $servername;

	# Read file, for each ServerAlias directive add an 
        # entry to the server alias hash
	open FILE, "< $apache_domain_config_base/$conf_file" or next;
	while (<FILE>) {
		next unless /^ServerAlias/i;
		/^ServerAlias\s+(\S+)$/i;
		$serveralias = $1;
		$local_serveraliases{$serveralias} = $servername;
	}
	close FILE;
}
closedir DIR;

# Webraft details
my $webraft_url = "webraft.its.unimelb.edu.au";
my $webraft_server = "suske.its.unimelb.edu.au";

### ---------------------------------------------------------------------- ###
#   End of configurable settings - no editing required below this line.
### ---------------------------------------------------------------------- ###

### ---------------------------------------------------------------------- ###

### ---------------------------------------------------------------------- ###
#
# Header for default CGI response page

my $preamble = '
<html>
 <head>
  <title>CGI-Mailer Response
 </title>
</head>
 <body bgcolor="#FFFFFF">
  <h2>CGI-Mailer Response
 </h2>
';

### ---------------------------------------------------------------------- ###
# Footer for default CGI response page

my $footer = '
  <!-- =================================================================== -->
  <hr>
  <p>Produced by <a href="http://martin.gleeson.com/cgi-mailer/">cgi-mailer.</a>
 </p>
  <!-- =================================================================== -->
  <hr>
 </body>
</html>
';

# $debug=1;

use LWP::UserAgent;

my $http_header = "Content-type: text/html\n\n";

my $method = $ENV{REQUEST_METHOD};

if( $method eq "GET" )
{
	my $data = "  <h2>Incorrect METHOD</h2>\n" .
		"  <p>This CGI Program should be referenced with \n" .
	        "     a METHOD of POST.</p>\n";
	print $http_header;
	print $preamble;
	print $data;
	print $footer;
	exit(0);

}
elsif( $method eq "POST" )
{
	%INPUT = &get_input(POST);
	
	# get the format file location
	#$url = $ENV{'HTTP_REFERER'} || $INPUT{'CgiMailerReferer'};
	$url = $INPUT{'CgiMailerReferer'} || $ENV{'HTTP_REFERER'};


	if(! $url) {
		error("Your browser or proxy server is not sending ".
                      "a Referer header and CGI-Mailer needs one to ".
                      "work. Please notify the maintainer of the form ".
                      "and ask them to add the appropriate field to ".
                      "the form.");
	}

	# remove named anchor, if any
	$url =~ s/\#.+$//;

	# remove query string, if any
	$url =~ s/\?.+$//;

	# store the original page URL for later reference
	$orig_url = $url;

	# check if user is mistakenly using page on local hard disk
	&error("The form you are submitting is on your hard disk.
		It needs to be on a web server for cgi-mailer to work.\n")
		if( $url =~ /^file:\/\/\//i);

	# check the domain is OK
	if($local_network) {
		# get the hostname
		$host = $url;
		# strip off the leading protocol://
		$host =~ s/^\w+:\/\///;
		# strip off the trailing /abc/def/xyz.html
		$host =~ s/([^\/]+)\/.*/$1/;
		# strip off the trailing :port, if any
		$host =~ s/\:\d+$//;
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
	}
	else { 		#$req !~ /%%%ERROR%%%/ 
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
			$data = "  <h2>Error.</h2>\n" .
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
			&log_access();
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

	if (   exists $INPUT{'mailtouser'} 
            && exists $INPUT{$INPUT{'mailtouser'}} ) {
		# The mailtouser option has been specified 
                # and the field specified exists - Test the 
                # value and append to the destination if all is well
		my $user_addr = $INPUT{$INPUT{'mailtouser'}};
		$user_addr =~ /^\s*([-_\@\w.,]+)\s*$/;
		if ( my $checked_address = Email::Valid->address( -address=> $1, 
                                                          -mxcheck => 1 ) ) {
			$destination .= ",${checked_address}";
		} else {
			$err_text = "Detected mailtouser option and value but email value was invalid!<br>" . 
                        "(Error note: ${Email::Valid::Details})";
		    error($err_text);
		}
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
		# TODO 10/10/2001 bjdean:
		# Add this error in later - need to let users of 
                # cgi-mailer know about change
		# &error("You must specify a From address using ".
                #        "the field name <font colour=\"#FF0000\">".
                #        "header:From</font>")
		#
		# In the meantime:

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
		$data = "  <h3>Submission Successful</h3>\n" .
		        "  <p>Your form has been successfully ".
                        "submitted by the server\n </p>";
	}

	if( $INPUT{'nodata'} ne 'true') {
		# mail the formatted message
		if($mail_send) {
			use Mail::Send;
			use Mail::Mailer;

			$msg = new Mail::Send Subject=>$subject, 
                                              To=>$destination;

			$msg->add('From',$from_addr);

			$msg->add('Reply-To',$reply_to) if($reply_to);

			foreach my $header (keys(%headers)) {
				$msg->set($header, $headers{$header});
			}
			$msg->set("X-Generated-By",
                                  "CGI-Mailer v$version: ".
                                  "http://www.unimelb.edu.au/cgi-mailer/");
			$msg->set("X-Form","$ENV{'HTTP_REFERER'}");

			# Launch mailer and set headers. 
			$fh = $msg->open;
			print $fh $format;
			# complete the message and send it
			$fh->close;

		} elsif($net_smtp) {
			use Net::SMTP;

			$smtp = Net::SMTP->new($mailhost);

			$smtp->mail($from_addr) if $from_addr;
			$smtp->to($destination);

			$smtp->data();
			$smtp->datasend("To: $destination\n");
			foreach $header (keys(%headers)) {
				$smtp->datasend("$header: $headers{$header}\n");
			}
			$smtp->datasend("Subject: $subject\n");
			$smtp->datasend("X-Generated-By: CGI-Mailer ".
                                     "v$version: ".
                                     "http://www.unimelb.edu.au/cgi-mailer/\n");
			$smtp->datasend("X-Form: $ENV{'HTTP_REFERER'}\n");
			$smtp->datasend("\n");
			for ($i = 0; $i <= length($format); $i += 999) {
				$smtp->datasend(substr($format, $i, 999) . "\r");
			}
			$smtp->dataend();

			$smtp->quit;
		} elsif($mail_mimelite) {
                        my %mail;
                        $mail{To}           = $destination;
                        $mail{From}         = $from_addr if $from_addr;
                        $mail{"Subject:" } = $subject;
                        $mail{"Reply-to:"} = $reply_to if $reply_to;

			foreach (keys(%headers))
			{
				my $key = (/:/) ? "$_": "$_ :";
				$mail{$key} = $headers{$_};
			}

			$mail{"X-Generated-By:"} = "CGI-Mailer v$version: ".
                                     "http://www.unimelb.edu.au/cgi-mailer/";
			$mail{"X-Form:" }  = $ENV{'HTTP_REFERER'};
			$mail{"Encoding"} = "quoted-printable";
			$mail{"Type"    } = "TEXT";

			# Translate (Windows|Unix|Mac) EOL with local EOL
			$format =~ s/(?:\x0d\x0a|\x0a|\x0d)/\n/g;

			my $msg = MIME::Lite->new(%mail, Data=>$format);
			if( ! -e "$sendmail") { 
                                error("Couldn't find sendmail ".
                                      "[$sendmail]: $!"); 
                        }

			open(MAIL,"| $sendmail -t") or 
                                 error("Couldn't open sendmail process: $!");
			$msg->print(\*MAIL);
			close MAIL;
		} else {
			if( ! -e "$sendmail") { 
                                error("Couldn't find sendmail ".
                                      "[$sendmail]: $!"); 
                        }

			open(MAIL,"| $sendmail -t") or 
                                 error("Couldn't open sendmail process: $!");
			select MAIL;
			print "To: $destination\n";
			print "Subject: $subject\n";
			print "From: $from_addr\n" if $from_addr;
			print "Reply-to: $reply_to\n" if $reply_to;
			foreach $header (keys(%headers)) {
				print "$header: $headers{$header}\n";
			}
			print "X-Generated-By: CGI-Mailer v$version: ".
                              "http://www.unimelb.edu.au/cgi-mailer/\n";
			print "X-Form: $ENV{'HTTP_REFERER'}\n";
			print "\n";
			print "$format";
			close MAIL;
		}
	}

	&log_access();

	select STDOUT;
	print $http_header;
	print $preamble if $default;
	print $data if $default;
	print $response unless $default;
	print $footer if $default;
	exit(0);
}
### ---------------------------------------------------------------------- ###
sub error {
	my $errstr = pop(@_);
	$data = "  <h2>Error.</h2>\n" .
	        "  <p>An error has occurred while attempting to submit your form</p>\n" .
	        "  <p>The Error is: </p>\n<blockquote><b>$errstr</b></blockquote>\n" .
	        "  <p>Please report this error to the maintainer of the form</p>\n";

	select STDOUT;
	print $http_header;
	print $preamble;
	print $data;
	print $footer;

	&log_access($errstr);

	exit(0);
}
### ---------------------------------------------------------------------- ###
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
### ---------------------------------------------------------------------- ###
sub title_case {
	$_ = pop(@_);
	$_ = "\L$_";
	s/(\b[a-z])/\U$1/g;
	$_;
}
### ---------------------------------------------------------------------- ###
sub URLget{
	my $URL = pop(@_);
	my $ret;

	# Deconstruct URL
	my $domain = $URL;
	# strip off the leading protocol://
	$domain =~ s/^\w+:\/\///;

	my $path = $domain;
	# strip off the trailing /abc/def/xyz.html
	$domain =~ s/([^\/]+)\/.*/$1/;
	$path =~ s/[^\/]+(\/.*)$/$1/;

	# strip off the trailing :port, if any
	$domain =~ s/\:\d+$//;

	# Data aquisition is dependant on the destination. Due to the local
	# director restrictions, the web server cannot access any of the
	# virtual servers or the webraft address because they are on the
	# same segment behind the local director.
	#
	# If the data is on a locally hosted domain, get the file contents
	# from the local filesystem.
	#
	# If the data is on webraft rewrite the url to go direct to the
	# webraft server name.

	if ( grep {/$domain/} (@local_domains) ) {
		# Construct file location
		my $local_file = "${domain_base}/${domain}/docs${path}";

		open FILE, "<${local_file}" or return '%%%ERROR%%%';
		my $ret = "";
		while (<FILE>) {
			$ret .= $_;
		}

		log_access("Locally hosted domain - fetching ${local_file}");

		return $ret;
	} elsif ( grep {/$domain/} (keys %local_serveraliases) ) {
		# Construct file location using actual server directory
		my $local_file = "${domain_base}/".
                                 "$local_serveraliases{$domain}/docs${path}";

		open FILE, "<${local_file}" or return '%%%ERROR%%%';
		my $ret = "";
		while (<FILE>) {
			$ret .= $_;
		}

		log_access("Locally hosted ServerAlias domain - ".
                           "fetching ${local_file}");
		return $ret;
	} else {
		# Rewrite URL to webraft server if necessary
		if ( $URL =~ /$webraft_url/ ) {
			$URL =~ s/$webraft_url/$webraft_server/;
		}

		# Create a user agent object
		$ua = new LWP::UserAgent;
		$ua->agent("cgi-mailer.pl/$version " . $ua->agent);
	
		# Create a request
		my $req = new HTTP::Request GET => "$URL";
	
		# Accept all data types. This is specifically for Microsloth's
		# IIS, which won't properly default to */* and throws a 406.
		$req->header('Accept' => '*/*');
	
		# Pass request to the user agent and get a response back
		my $res = $ua->request($req);
	
		# Check the outcome of the response
		if ($res->is_success) {
			$ret = $res->content;
		} else {
			$ret = '%%%ERROR%%%';
		}

		log_access("Remote domain - fetching ${URL}");

		return $ret;
	}

}
### ---------------------------------------------------------------------- ###
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
### ---------------------------------------------------------------------- ###
sub log_access {
	my $errstr = pop(@_);
	my $date;

	# log the access
	$date = &time_now();
	open LOG,">> $log" or die(" Couldn't open log file [$log]: $!");
	print LOG "[$date] host=[$ENV{'REMOTE_HOST'}] ".
                  "referer=[$ENV{'HTTP_REFERER'}] data=[$format_url] " .
		  "resp=[$response_url] to=[$destination] subject=[$subject] ".
                  "reply-to=[$reply_to]";
	print LOG " ERROR=[$errstr]" if $errstr;
	print LOG " from=[$from_addr]" if $from_addr;
	print LOG "\n";
	close LOG;

	return;
}
