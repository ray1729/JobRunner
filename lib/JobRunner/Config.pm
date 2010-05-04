package JobRunner::Config;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;

use Config::Scoped;
use JobRunner::Schedule;
use JobRunner::JobGroup;
use JobRunner::Job;

has path => (
    is       => 'ro',
    isa      => 'Str',
    required => 1
);

has config => (
    is       => 'ro',
    isa      => 'HashRef',
    lazy_build => 1,
);

sub _build_config {
    my $self = shift;

    Config::Scoped->new( file => $self->path, warnings => { permissions => 'off' } )->parse;
}

has schedule_groups => (
    is      => 'rw',
    isa     => 'HashRef[JobRunner::Schedule]',
    default => sub { {} },
    traits  => [ 'Hash' ],
    handles => {
        set_schedule => 'set',
    },
);

sub get_schedule {
    my ( $self, $schedule_name ) = @_;

    if ( $schedule_name eq '__NOW__' ) {
        my $schedule  = JobRunner::Schedule->new( name => '__NOW__' );
        my $job_group = JobRunner::JobGroup->new( name => 'ONEOFF', workdir => '/' );
        $self->add_jobs( $job_group, [ map { job => $_ }, @ARGV ] );
        $schedule->add_job( $job_group );
        return $schedule;
    }

    $self->schedule_groups->{ $schedule_name };
}

has log4perl => (
    is         => 'rw',
    isa        => 'HashRef[Str]',
    lazy_build => 1,
);

sub _build_log4perl {
    my $self = shift;

    my %log4perl;

    while ( my ( $key, $value ) = each %{ $self->config->{log4perl} } ) {
        $log4perl{ "log4perl.$key" } = $value;
    }

    return \%log4perl;
}

sub parse {
    my $self = shift;
    
    while ( my ( $schedule_name, $schedule_conf ) = each %{ $self->config->{schedule} } ) {
        $self->set_schedule( $schedule_name => $self->build_schedule( $schedule_name, $schedule_conf ) );
    }
    
    return $self;
}

sub build_schedule {
    my ( $self, $schedule_name, $schedule_conf ) = @_;

    my $schedule = JobRunner::Schedule->new( name => $schedule_name );

    if ( defined( my $lockfile = $schedule_conf->{lockfile} ) ) {
        $schedule->lockfile( $lockfile );        
    }

    for my $job_name ( @{ $schedule_conf->{jobs} } ) {
        $schedule->add_job( $self->build_job( $job_name, '/' ) );
    }

    return $schedule;
}

sub build_job {
    my ( $self, $job_name, $default_workdir ) = @_;

    my $job_conf = $self->config->{job}->{ $job_name }
        or confess( "no configuration for job $job_name" );

    $job_conf->{workdir} ||= $default_workdir;

    my $job;
    
    if ( $job_conf->{command} ) {
        $job = JobRunner::Job->new( %{ $job_conf }, name => $job_name );
    }
    elsif ( $job_conf->{job_group} ) {
        $job = JobRunner::JobGroup->new( %{ $job_conf }, name => $job_name );
        $self->add_jobs( $job, $job_conf->{job_group} );
    }
    else {
        confess( "no command or job_group given for $job_name" );
    }

    return $job;
}

sub add_jobs {
    my ( $self, $job_group, $jobs ) = @_;

    for my $job_spec ( @{ $jobs } ) {
        my $job = $self->build_job( $job_spec->{job}, $job_spec->{workdir} || $job_group->workdir );
        $job->continue_on_error( 1 )
            if $job_spec->{continue_on_error};
        $job_group->add_job( $job );
    }
}   

__PACKAGE__->meta->make_immutable;

1;

__END__
