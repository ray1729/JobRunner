package JobRunner::Schedule;

use Moose;
use namespace::autoclean;

use JobRunner::Role::Runnable;
use Log::Log4perl;

with 'MooseX::Log::Log4perl';

has name => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has jobs => (
    is       => 'rw',
    isa      => 'ArrayRef[JobRunner::Role::Runnable]',
    default  => sub { [] },
    traits   => [ 'Array' ],
    handles  => {
        add_job  => 'push',
        get_jobs => 'elements',
    }
);

sub list_jobs {
    my $self = shift;

    map $_->list_jobs, $self->get_jobs;
}

sub run {
    my $self = shift;
    
    $self->log->info( "Running jobs for schedule " . $self->name );
    
    my %job_for;
    
    for my $job ( $self->get_jobs ) {

        Log::Log4perl::NDC->push( $job->name );

        defined( my $pid = fork() )
            or confess "fork failed: $!";

        if ( $pid == 0 ) {
            $job->run;
            if ( $job->has_errors or $job->has_warnings ) {
                $job->dump_output;
                exit 1;
            }
            exit 0;
        }

        $self->log->debug( "Process $pid handling job $job" );

        $job_for{ $pid } = $job;

        Log::Log4perl::NDC->pop;
    }

    while ( ( my $pid = wait ) > 0 ) {
        my $job = $job_for{ $pid };
        $job->status( $? );
        Log::Log4perl::NDC->push( $job->name );
        $self->log->info( $job->status_message );
        Log::Log4perl::NDC->pop;
    }
}

__PACKAGE__->meta->make_immutable;

1;

__END__
