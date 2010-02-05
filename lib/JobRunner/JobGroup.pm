package JobRunner::JobGroup;

use Moose;
use namespace::autoclean;

use Log::Log4perl;
with 'JobRunner::Role::Runnable';

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

sub run {
    my $self = shift;

    $self->log->info( "Running job group $self" );

    for my $job ( $self->get_jobs ) {
        Log::Log4perl::NDC->push( $job->name );
        $job->workdir( $self->workdir || '/' )
            unless $job->workdir;
        $job->run();
        $self->add_output( $job->get_output );
        if ( $job->has_errors ) {
            $self->error( "Job failed, aborting job group" );
            last;
        }
        elsif ( $job->has_warnings ) {
            $self->warning( "Job failed, but continue on error requested" );
        }
        else {
            $self->log->info( "Job completed successfully" );
        }
    }
    continue {
        Log::Log4perl::NDC->pop;
    }

    if ( $self->has_errors and $self->continue_on_error ) {
        $self->add_warning( $self->get_errors );
        $self->clear_errors;
    }
    
    if ( $self->has_errors ) {
        $self->status_message( "JobGroup exited with errors" );
        $self->error( $self->status_message  );
    }
    elsif ( $self->has_warnings ) {
        $self->status_message( "JobGroup exited with warnings" );
        $self->warning( $self->status_message );
    }
    else {
        $self->status_message( "JobGroup completed successfully" );
        $self->log->info( $self->status_message );
    }
}

sub list_jobs {
    my $self = shift;
    
    map $_->list_jobs, $self->get_jobs;
}

__PACKAGE__->meta->make_immutable;

1;

__END__