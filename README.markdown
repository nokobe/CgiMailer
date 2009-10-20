# Installing CgiMailer

CgiMailer is written in perl and requres the following PERL libraries to be installed
for it to work correctly:

 - MIME::Lite
 - Net::SMTP
 - LWP::UserAgent

Once the PERL libraries are installed, simply add the cgi-mailer.pl script file
into the cgi-bin folder on your webserver.

# How to use CgiMailer

## 1. Creating the HTML form

The form itself should _POST_ to the URL that CgiMailer has been installed:

<pre class="prettyprint lang-html">
    &lt;form method="post" action="http://example.com/cgi-bin/cgi-mailer.pl"&gt;
</pre>

Add a html form to your website with two hidden input fields like the following:

<pre class="prettyprint lang-html">
    &lt;input type="hidden" name="destination" value="johnsmith@example.com"&gt;
    &lt;input type="hidden" name="subject" value="Online feedback form"&gt;
</pre>

Here is an example of a working form:

<pre class="prettyprint lang-html">
    &lt;form method="post" action="http://example.com/cgi-bin/cgi-mailer.pl"&gt;
    &lt;input type="hidden" name="destination" value="destination@example.com"&gt;
    &lt;input type="hidden" name="subject" value="testing cgi-mailer"&gt;
    &lt;b&gt;Name:&lt;/b&gt; &lt;input type="text" name="name" size="30"&gt;&lt;br/&gt;
    &lt;b&gt;Email address:&lt;/b&gt; &lt;input type="text" name="email_address" size="30"&gt;&lt;br/&gt;
    &lt;select name="question"&gt;
        &lt;option value="red"&gt;Feedback&lt;/option&gt;
        &lt;option value="green" selected="selected"&gt;Question&lt;/option&gt;
        &lt;option value="blue"&gt;Other&lt;/option&gt;
    &lt;/select&gt;&lt;br/&gt;
    &lt;textarea name="message"&gt;
    &lt;/textarea&gt;&lt;br/&gt;
    &lt;input type="submit" value="Send message"&gt;
    &lt;/form&gt;
</pre>

## 2. Creating the format file

After creating your web form, you also need to create a _format file_. This _format file_ is
used by CgiMailer to work out how to format the email message it will send to you.

A format file is simply a text file with the contents of the email you want to be sent.
Every time a word starts with $ it will be replaced with the user submitted data.

This example is based upon the example html form above:

<pre>
You have a new message from $name with email address $email_address
--------------------------------
$question
--------------------------------
$message
</pre>

The format file must be uploaded to the same directory as the HTML form,
and with the same name as the form, but with an extension of _.data_.
_i.e._ If your form is _myform.html_, then your
       format file must be called _myform.data_.

## 3. Creating a response file

You may optionally create a response file which contains a web page that
should be displayed to a user who uses your web form.

The response file must be in the same folder on your website
as the HTML form, it must have the same filename as the form,
but with an extension of _.response_.

- The response file can also use _$fieldname_ to display fields that the user filled out.
- You can include other fields such as:
 - $ENV{'REMOTE_HOST'}

## 4. Required fields

If you wish to make the filling out of some of fields in your
form mandatory, you can add a _.required_ file.

Create a file with the extension _.required_, containing one or more
lines of __field-name&lt;tab&gt;Description__. Each field name
will be checked against the input to see if it isn't empty. If
it is, an error will be shown using the Description to instruct
the user to fill in that particular field.

# Further information

## Adding a for to web pages that don't end in .html

In some cases the URL of your form will not end in _.html_ (i.e. where the
URL of the page ends in '/'), in this case you will need to include a hidden
field which specifies the name of the index file:

<pre class="prettyprint lang-html">
&lt;input name="index-file" value="index.html" type="hidden"&gt;
</pre>

Where _index.html_ is the name of the html file containing the form.

## Configuration of "From" address for form submission emails

To facilitate the configuration of auto-responders to form submissions the
"From" address of email submissions can be specified:

<pre class="prettyprint lang-html">
&lt;input type="hidden" name="From" value="bob@example.com" /&gt;
</pre>

If a "From" address is not specified the default email address configured
by the system administrator will be used.

## Default required, data and response files

For cases in which you have multiple forms with the same input fields (eg.
two pages asking for the name and email address of interested parties) it is
possible to set up default files which will be used by all forms.

The default files and html pages with similar forms should all be in the
same directory on the web server, the default file names are as follows:

If you are using long filenames (with the full .html extension) CgiMailer
will look for:

- cgi-mailer-required.default
- cgi-mailer-data.default
- cgi-mailer-response.default

## Sending an email response to the form user

If you want the user of a form to receive the email response
as well as the 'destination' recipients a 'mailtouser' field can be
used, ie:

<pre class="prettyprint lang-html">
&lt;input type="hidden" name="mailtouser" value="UserEmail"/&gt;
&lt;input type="text" name="UserEmail"&gt;<br />
</pre>

The value of the "mailtouser" field specifies the name of the field that
will receive the user's email address.

## Email addresses with special characters

If there are any non-standard characters in the email address it will be
discarded for security reasons. If the user enters a typo in their email
they will not receive the email response.

# Troubleshooting

Other message headers can be set using inputs of the form
<tt>header:&lt;header-name&gt;</tt> For example, to set the
<b>Reply-To:</b> header, use the html &lt;input
name=&quot;header:Reply-To&quot; value=&quot;j.smith@domain.com&quot;
type=&quot;hidden&quot;&gt;.</p>

## Referring URL

CgiMailer depends upon the users web browser sending the _Referring URL_
which indicated which web page the user just visited.

Some older web browsers, proxy servers don't send referring
information. You can add support for these browsers by adding
a field called CgiMailerReferer. Don' forget to make sure you
are using the url to your own form.

<pre class="prettyprint lang-html" style="border: 0 !important;">
&lt;input name="CgiMailerReferer" value="http://www.foo.com/forms/feedback.html" type="hidden" /&gt;
</pre>

## Password or IP restricted forms

If your HTML form and the format file are both in either an IP restricted or
password protected folder on your website, CgiMailer will not work correctly.
In this case, ensure your .htaccess file explicitly allow the IP address of the
server which CgiMailer is installed on.

