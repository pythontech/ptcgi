#=======================================================================
#	User authentication based on text file containing usernames and
#	crypted password.
#=======================================================================
package PythonTech::CryptAuth;
require strict;

sub new {
    my $class = shift;
    my($authfile) = @_;
    my $self = {
	authfile => $authfile,
    };
    bless $self, $class;
    return $self;
}

sub authenticate {
    my $self = shift;
    my($tusername,$tpassword) = @_;
    $tusername ne ''
	or die "BADUSER: No username given\n";
    my($username) = $tusername =~ /^(\w[-\.\w]*)$/
	or die "BADUSER: Invalid user name `$tusername'\n";
    open(CRYPTAUTH,'<',$self->{'authfile'}) ||
	die "SYSERR: Could not open user authentication file\n";
    chomp(my @lines = <CRYPTAUTH>);
    close(CRYPTAUTH);
    foreach my $line (@lines) {
	my($u,$crypted) = split(/:/, $line, 2);
	if ($u eq $username) {
	    my $cp2 = crypt($tpassword,substr($crypted,0,2));
	    if ($cp2 ne $crypted) {
		die "BADPASSWORD: Incorrect password\n";
	    } else {
		return $username;
	    }
	}
    }
    die "BADUSER: No such user `$username'\n";
}

1;
