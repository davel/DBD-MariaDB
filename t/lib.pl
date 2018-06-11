use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use vars qw($test_dsn $test_user $test_password);

$| = 1; # flush stdout asap to keep in sync with stderr

$::COL_NULLABLE = 1;
$::COL_KEY = 2;

my $file = "$Bin/MariaDB.mtest";
BAIL_OUT "Cannot execute $file: $@" if -e $file and not eval { require $file };

$::test_dsn      = $::test_dsn      || $ENV{'DBI_DSN'}   || 'DBI:MariaDB:database=test';
$::test_user     = $::test_user     || $ENV{'DBI_USER'}  || '';
$::test_password = $::test_password || $ENV{'DBI_PASS'}  || '';

sub DbiTestConnect {
    my $err;
    my $dbh = eval { DBI->connect(@_) };
    if ( $dbh ) {
        if ( $dbh->{mariadb_serverversion} < 40103 ) {
            $err = "MariaDB or MySQL server version is older then 4.1.3";
        } else {
            my $current_charset = $dbh->selectrow_array('SELECT @@character_set_database');
            my $expected_charset = $dbh->selectrow_array("SHOW CHARSET LIKE 'utf8mb4'") ? 'utf8mb4' : 'utf8';
            if ($current_charset ne $expected_charset) {
                $err = "Database charset is not $expected_charset, but $current_charset";
            }
        }
    } else {
        if ( $@ ) {
            $err = $@;
            $err =~ s/ at \S+ line \d+\.?\s*$//;
        }
        if ( not $err ) {
            $err = $DBI::errstr;
            $err = "unknown error" unless $err;
            my $user = $_[1];
            my $dsn = $_[0];
            $dsn =~ s/^DBI:[^:]+://;
            $err = "DBI connect('$dsn','$user',...) failed: $err";
        }
        my ($func, $file, $line) = caller;
        $err .= " at $file line $line.";
    }
    if ( defined $err ) {
        if ( $ENV{CONNECTION_TESTING} ) {
            BAIL_OUT "no database connection: $err";
        } else {
            plan skip_all => "no database connection: $err";
        }
    }
    return $dbh;
}


#
#   Print a DBI error message
#
# TODO - This is on the chopping block
sub DbiError ($$) {
    my ($rc, $err) = @_;
    $rc ||= 0;
    $err ||= '';
    $::numTests ||= 0;
    print "Test $::numTests: DBI error $rc, $err\n";
}

sub connection_id {
    my $dbh = shift;
    return 0 unless $dbh;

    # Paul DuBois says the following is more reliable than
    # $dbh->{'mariadb_thread_id'};
    my @row = $dbh->selectrow_array("SELECT CONNECTION_ID()");

    return $row[0];
}

# nice function I saw in DBD::Pg test code
sub byte_string {
    my $ret = join( "|" ,unpack( "C*" ,$_[0] ) );
    return $ret;
}

sub SQL_VARCHAR { 12 };
sub SQL_INTEGER { 4 };

=item CheckRoutinePerms()

Check if the current user of the DBH has permissions to create/drop procedures

    if (!CheckRoutinePerms($dbh)) {
        plan skip_all =>
            $dbh->errstr();
    }

=cut

sub CheckRoutinePerms {
    my $dbh = shift @_;

    # check for necessary privs
    local $dbh->{PrintError} = 0;
    if (not eval { $dbh->do('DROP PROCEDURE IF EXISTS testproc') }) {
        return 0 if $dbh->errstr() =~ /alter routine command denied to user/;
        return 0 if $dbh->errstr() =~ /Table 'mysql\.proc' doesn't exist/;
    }

    return 1;
};

1;
