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

    Config::Scoped->new( file => $self->path )->parse;
}

has schedule_groups => (
    is      => 'rw',
    isa     => 'HashRef[JobRunner::Schedule]',
    default => sub { {} },
    traits  => [ 'Hash' ],
    handles => {
        set_schedule => 'set',
        get_schedule => 'get',
    },
);

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

    for my $job_name ( @{ $schedule_conf->{jobs} } ) {
        $schedule->add_job( $self->build_job( $job_name  ) );
    }

    return $schedule;
}

sub build_job {
    my ( $self, $job_name ) = @_;

    my $job_conf = $self->config->{job}->{ $job_name }
        or confess( "no configuration for job $job_name" );

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
        my $job = $self->build_job( $job_spec->{job} );
        $job->continue_on_error( 1 )
            if $job_spec->{continue_on_error};
        $job_group->add_job( $job );
    }
}   

__PACKAGE__->meta->make_immutable;

1;

__END__
