#!/usr/bin/env perl
# job-runner.pl --- run jobs, log output
# 
# Created: 02 Feb 2010
#

use strict;
use warnings FATAL => 'all';

use Getopt::Long;
use Log::Log4perl ':levels';
use Pod::Usage;
use JobRunner::Config;

{   
    my $action = \&act_run;
    my $log_level = $WARN;
    my $log_file  = 'STDOUT';
    
    GetOptions(
        'help'          => sub { pod2usage( -verbose => 1 ) },
        'man'           => sub { pod2usage( -verbose => 2 ) },
        'debug'         => sub { $log_level = $DEBUG },
        'verbose'       => sub { $log_level = $INFO },
        'logfile=s'     => sub { $log_file = '>>' . $_[1] },
        'config=s'      => \my $config,
        'schedule=s'    => \my $schedule,
        'configtest'    => sub { $action = \&act_configtest },
        'list'          => sub { $action = \&act_list },
    ) or pod2usage(2);

    Log::Log4perl->easy_init( {
        level  => $log_level,
        layout => '%d [%x] %P %p: %m%n',
        file   => $log_file,
    } );

    Log::Log4perl::NDC->push( $schedule );
    
    $action->( $config, $schedule );
}

sub get_schedule {
    my ( $config_file, $schedule_name ) = @_;
    
    pod2usage( "--schedule must be specified" )
        unless defined $schedule_name;

    my $conf = JobRunner::Config->new( path => $config_file )->parse;

    my $schedule = $conf->get_schedule( $schedule_name )
        or die "Schedule $schedule_name not configured";

    return $schedule;
}

sub act_run {
    my ( $config_file, $schedule_name ) = @_;

    my $schedule = get_schedule( $config_file, $schedule_name );
    $schedule->run();
}

sub act_configtest {
    my ( $config_file, $schedule ) = @_;

    JobRunner::Config->new( path => $config_file )->parse
            and print "Configuration OK\n";
}

sub act_list {
    my ( $config_file, $schedule_name ) = @_;

    my $schedule = get_schedule( $config_file, $schedule_name );   

    for ( $schedule->list_jobs ) {
        print "$_\n";
    }
}

__END__

=head1 NAME

job-runner.pl - Describe the usage of script briefly

=head1 SYNOPSIS

job-runner.pl [options] args

      -opt --long      Option description

=head1 DESCRIPTION

Stub documentation for job-runner.pl, 

=head1 AUTHOR

Ray Miller, E<lt>ray@1729.org.ukE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Ray Miller

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 BUGS

None reported... yet.

=cut
