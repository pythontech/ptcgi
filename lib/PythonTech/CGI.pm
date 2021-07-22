#=======================================================================
#	$Id: CGI.pm,v 1.1 2005/05/04 11:58:59 pythontech Exp $
#	Extension of CGI class which handles response cookies better
#	Copyright (C) 2004  Python Technology Limited
#
#	This program is free software; you can redistribute it and/or
#	modify it under the terms of the GNU General Public License
#	as published by the Free Software Foundation; either version 2
#	of the License, or (at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program; if not, write to the Free Software
#	Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  
#	02111-1307, USA.
#=======================================================================
package PythonTech::CGI;
use strict;
use CGI;
use CGI::Session;

use vars qw(@ISA $request $response $server $session);

@ISA = qw(CGI);

#-----------------------------------------------------------------------
#	my($req,$resp,$serv,$sess) = new PythonTech::CGI;
#-----------------------------------------------------------------------
sub new {
    my $class = shift;
    $request = new CGI(@_);
    bless $request, $class;

    if (wantarray) {
	$response = new PythonTech::CGI::Response({Request => $request});
	$server = new PythonTech::CGI::Server();
	$session = new PythonTech::CGI::Session($server, $request);
#	$session = new PythonTech::CGI::PHPSession($server, $request);
	my $sessid = $session->id;
	unless ($request->cookie('CGISESSID') eq $sessid) {
	    $response->set_cookie(-name => 'CGISESSID',
				  -value => $sessid);
	}

	return ($request, $response, $server, $session);
    } else {
	return $request;
    }
}

#-----------------------------------------------------------------------
#	Return extended objects
#-----------------------------------------------------------------------
sub response {return $response;}
sub server   {return $server;  }
sub session  {return $session; }

sub require_login {
    my $self = shift;
    return $session->require_login(@_);
}

#=======================================================================
#	Response object
#=======================================================================
package PythonTech::CGI::Response;
use PythonTech::Conv;

sub new {
    my($class) = shift;
    my($args) = @_;
    my $self = {
	cgi => $args->{'Request'},
	type => 'text/html',
	headers => [],
    };
    bless $self, $class;
    return $self;
}

sub set_type {
    my $self = shift;
    my($type) = @_;
    $self->{'type'} = $type;
}

sub set_header {
    my $self = shift;
    my($name,$value) = @_;
    push @{$self->{'headers'}}, $name, $value;
}

sub set_cookie {
    my $self = shift;
    my @args = @_;
    my $cookie = $self->{'cgi'}->cookie(@args);
    push @{$self->{'cookies'}}, $cookie;
}

# Write response content, prefixed by header unless already done
sub write {
    my $self = shift;
    unless ($self->{'done_header'}) {
	print $self->{'cgi'}->header(-type => $self->{'type'},
				     -cookie => $self->{'cookies'},
				     @{$self->{'headers'}});
	$self->{'done_header'} = 1;
    }
    print @_;
}

#-----------------------------------------------------------------------
#	Send rediriction back to user
#-----------------------------------------------------------------------
sub redirect {
    my $self = shift;
    my @args;
    if (@_ == 1) {
	@args = (-uri => $_[0]);
    } else {
	@args = @_;
    }
    unless ($self->{'done_header'}) {
	$::PythonTech::CGI::session->flush;
	print $self->{'cgi'}->redirect(-cookie => $self->{'cookies'}, 
				       @args);
	$self->{'done_header'} = 1;
    }
}

#-----------------------------------------------------------------------
#	After post, 'see other'.
#	N.B. Older browsers e.g. Netscape 4 do not recognise the 303
#	status, so give them a page with an explicit link.
#-----------------------------------------------------------------------
sub see_other {
    my($self, $url,@args) = @_;
    unless ($self->{'done_header'}) {
	$::PythonTech::CGI::session->flush;
	print $self->{'cgi'}->header(-status => '303 See Other',
				     -location => $url,
				     -cookie => $self->{'cookies'},
				     @args);
	print "<html><head>",
	  "<meta http-equiv=\"Refresh\" content=\"0; URL=".$url."\">",
	    "<title>Now go here</title>",
	      "</head>",
	"<body>Continue <a href=\"",&PythonTech::Conv::html_escape($url),"\">here</a></body></html>";
	$self->{'done_header'} = 1;
    }
}

#=======================================================================
#	Server object
#=======================================================================
package PythonTech::CGI::Server;
use PythonTech::Conv;

sub new {
    my $class = shift;
    my $self = {
       };
    bless $self, $class;
    return $self;
}

#-----------------------------------------------------------------------
#	Get a server property.  These are found via the defs defined
#	in the Local.pm file in the same directory as the invoking
#	CGI script.
#-----------------------------------------------------------------------
sub get {
    my $self = shift;
    my($prop) = @_;
    require Local;
    return $::Local::defs{$prop};
}

#-----------------------------------------------------------------------
#	Escape arbitrary text for use as part of a URL, e.g. the
#	value of a query parameter.
#-----------------------------------------------------------------------
sub url_escape {
    my($self,$text) = @_;
    return &PythonTech::Conv::uri_escape($text);
}

#-----------------------------------------------------------------------
#	Excape arbitrary text so that it can be included in HTML
#-----------------------------------------------------------------------
sub html_escape {
    my($self,$text) = @_;
    return &PythonTech::Conv::html_escape($text);
}

#=======================================================================
#	Session object.
#	For now, just inherit from CGI::Session.  Later, migrate to
#	PHP::Session so we can interoperate with PHP scripts (i.e
#	share login panel).
#=======================================================================
package PythonTech::CGI::Session;
use strict;

sub new {
    my $class = shift;
    my($server,$request) = @_;
    my $sessiondir = $server->get('SESSIONDIR') || '/tmp';
    my $self = {
	server => $server,
	cgisess => new CGI::Session(undef, $request,
				    {Directory => $sessiondir}),
    };
    bless $self, $class;
}

sub id {
    my($self) = @_;
    return $self->{'cgisess'}->id;
}

sub flush {
    my($self) = @_;
    $self->{'cgisess'}->flush;
}

sub clear {
    my $self = shift;
    $self->{'cgisess'}->clear(@_);
}

#-----------------------------------------------------------------------
#	Get or set a session property
#-----------------------------------------------------------------------
sub get {
    my($self, $prop) = @_;
    return $self->{'cgisess'}->param($prop);
}

sub set {
    my($self, $prop,$value) = @_;
    $self->{'cgisess'}->param($prop, $value);
}

sub param {
    my $self = shift;
    return $self->{'cgisess'}->param(@_);
}

#-----------------------------------------------------------------------
#	Record that the user is now logged in.
#	Typically called from the 'login' script, though may be also
#	from a registration page etc.
#-----------------------------------------------------------------------
sub login {
    my($self, $username) = @_;
    $self->set('userName' => $username);
    $self->set('loggedIn' => 1);
}

#-----------------------------------------------------------------------
#	Check that the user is logged in and, if not, redirect them to
#	a page where they can authenticate themselves.
#-----------------------------------------------------------------------
sub require_login {
    my($self, $afterpage) = @_;
    if (! $self->get('loggedIn')) {
	my $myurl = defined($afterpage) ? $afterpage :
	  $::PythonTech::CGI::request->self_url;
	my $loginurl = $self->{'server'}->get('LOGINURL');
	die "No login URL\n" unless $loginurl;
	$self->set('afterLogin' => $myurl);
	$::PythonTech::CGI::response->redirect($loginurl);
	$self->flush;
	exit 0;
    }
    my $user = $self->get('userName');
#    print STDERR "user=$user\n";
    return $user;
}

#=======================================================================
#	Session object using PHP::Session
#	Session is portable across PHP and Perl scripts
#=======================================================================
package PythonTech::CGI::PHPSession;
use strict;

sub new {
    my $class = shift;
    my($server,$request) = @_;
    require PHP::Session;
    #--- Find existing session id, or start a new one
    my $claimed_id = $request->cookie('PHPSESSID') || undef;
    my $ip = $request->remote_addr;
    my $session;
    if (defined $claimed_id) {
	# Check if session exists and is valid
	$session = eval {new PHP::Session($claimed_id)};
	if ($session && $session->get('_ip') eq $ip) {
	    # IP matches.  Now check if session has expired
	    if ($session->get('_expiry') < time) {
		$session->destroy;
		$session = undef;
	    }
	} else {
	    # Trying to pinch somebody else's session, or 
	    # (typically) dial-up reconnected with different IP address
	    $session = undef;
	}
    }
    unless ($session) {
	# Assign a new session
	require Digest::MD5;
	do {
	    my $id = &Digest::MD5::md5_hex(rand().rand());
	    my $umask = umask(077);
	    $session = new PHP::Session($id, {create => 1});
	    umask($umask);
	    if (defined($session->get('_ip'))) {
		# Chanced upon another existing session - try again
		$session = undef;
	    }
	} until ($session);
	$session->set('_ip', $ip);
	$PythonTech::CGI::response->set_cookie('PHPSESSID', $session->id);
    }
    # Keep session alive for 1 hour
    $session->set('_expiry', time + 3600);
    my $self = {
	server => $server,
	phpsess => $session,
    };
    bless $self, $class;
    return $self;
}

sub id {
    my($self) = @_;
    return $self->{'phpsess'}->id;
}

sub flush {
    my($self) = @_;
    $self->{'phpsess'}->save;
}

sub clear {
    my($self,$varlist) = @_;
    foreach (@$varlist) {
	$self->{'phpsess'}->set($_ => undef);
    }
}

#-----------------------------------------------------------------------
#	Get or set a session property
#-----------------------------------------------------------------------
sub get {
    my($self, $prop) = @_;
    return $self->{'phpsess'}->get($prop);
}

sub set {
    my($self, $prop,$value) = @_;
    $self->{'phpsess'}->set($prop, $value);
}

sub param {
    my $self = shift;
    if (@_ > 1) {
	$self->set(@_);
    } else {
	return $self->get(@_);
    }
}

#-----------------------------------------------------------------------
#	Record that the user is now logged in.
#	Typically called from the 'login' script, though may be also
#	from a registration page etc.
#-----------------------------------------------------------------------
sub login {
    my($self, $username) = @_;
    $self->set('userName' => $username);
    $self->set('loggedIn' => 1);
}

#-----------------------------------------------------------------------
#	Check that the user is logged in and, if not, redirect them to
#	a page where they can authenticate themselves.
#-----------------------------------------------------------------------
sub require_login {
    my($self, $afterpage) = @_;
    if (! $self->get('loggedIn')) {
	my $myurl = defined($afterpage) ? $afterpage :
	    $::PythonTech::CGI::request->self_url;
	my $loginurl = $self->{'server'}->get('LOGINURL');
	die "No login URL\n" unless $loginurl;
	$self->set('afterLogin' => $myurl);
	$::PythonTech::CGI::response->redirect($loginurl);
	$self->flush;
	exit 0;
    }
    my $user = $self->get('userName');
#    print STDERR "user=$user\n";
    return $user;
}

1;
