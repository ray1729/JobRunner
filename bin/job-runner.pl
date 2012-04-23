#!/usr/bin/env perl
# job-runner.pl --- run jobs, log output
# 
# Created: 02 Feb 2010
#

use strict;
use warnings FATAL => 'all';

use Getopt::Long;
use Log::Log4perl;
use Pod::Usage;
use JobRunner::Config;

{   
    my $action = \&act_run;

    my ( $config_file, $schedule, $dryrun, $now );
    
    GetOptions(
        'help'           => sub { pod2usage( -verbose => 1 ) },
        'man'            => sub { pod2usage( -verbose => 2 ) },
        'config=s'       => \$config_file,
        'schedule=s'     => \$schedule,
        'dryrun|dry-run' => \$dryrun,
        'now'            => \$now,
        'configtest'     => sub { $action = \&act_configtest; $dryrun = 1 },
        'list'           => sub { $action = \&act_list; $dryrun = 1 },
    ) or pod2usage(2);

    my $config = JobRunner::Config->new( path => $config_file )->parse;
    Log::Log4perl->init( $config->log4perl ) unless $dryrun;

    $schedule = '__NOW__' if $now;
    
    $action->( $config, $schedule, $dryrun );
}

sub get_schedule {
    my ( $conf, $schedule_name ) = @_;
    
    pod2usage( "--schedule must be specified" )
        unless defined $schedule_name;

    my $schedule = $conf->get_schedule( $schedule_name )
        or die "Schedule $schedule_name not configured";

    return $schedule;
}

sub act_run {
    my ( $config, $schedule_name, $dryrun ) = @_;

    my $schedule = get_schedule( $config, $schedule_name );

    if ( $dryrun ) {
        $schedule->dryrun;
    }
    else {
        $schedule->run;
    }
}

sub act_configtest {
    my ( $config, $schedule ) = @_;

    # If we got this far, config file was OK
    print "Configuration OK\n";
}

sub act_list {
    my ( $config, $schedule_name ) = @_;

    my $schedule = get_schedule( $config, $schedule_name );   

    for ( $schedule->list_jobs ) {
	my ( $job, $depth ) = @$_;
	my $indent = join '', ( q{  } ) x $depth;
	my $job_str = $job->name;
	$job_str .= " - " . $job->desc
	    if $job->desc;
	$job_str .= " [disabled]"
	    unless $job->enabled;
        print "$indent$job_str\n";
    }
}

__END__

=head1 NAME

job-runner.pl - Describe the usage of script briefly

=head1 SYNOPSIS

  job-runner.pl --config=PATH --configtest

  job-runner.pl --config=PATH [--dry-run] --schedule=NAME

  job-runner.pl --config=PATH --list --schedule=NAME

  job-runner.pl --config=PATH --now JOB [JOB ...]

=head1 OPTIONS

=over 

=item B<--help>

Display a brief usage message.

=item B<--man>

Display the manual page.

=item B<--config>

Specify the path of the configuration file (required).

=item B<--schedule>

Specify the schedule to run.

=item B<--now>

Create a schedule I<now> on the fly from the jobs specified on the
command line and run immediately.

=item B<--dry-run>

Show the jobs that would be run, and the commands that would be issued, but do not actually run any commands.

=item B<--list>

List the jobs in the specified schedule.

=back

=head1 DESCRIPTION

Configurable management of batch jobs with sophisticated log handling
and error reporting.

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
