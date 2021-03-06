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
        $job->run;
        if ( $job->has_errors ) {
            $self->error( $job->get_errors );
            $self->error( "Job $job failed, aborting job group" );
            $self->add_output( $job->get_output );
            Log::Log4perl::NDC->pop;
            last;
        }
        elsif ( $job->has_warnings ) {
            $self->warning( $job->get_warnings );
            $self->warning( "Job $job failed, but continue on error requested" );
            $self->add_output( $job->get_output );
        }
        else {
            $self->log->info( "Job $job completed successfully" );
        }
        Log::Log4perl::NDC->pop;
    }

    if ( $self->has_errors and $self->continue_on_error ) {
        $self->add_warning( $self->get_errors );
        $self->clear_errors;
    }
    
    if ( $self->has_errors ) {
        $self->status_message( "JobGroup $self exited with errors" );
        $self->error( $self->status_message  );
    }
    elsif ( $self->has_warnings ) {
        $self->status_message( "JobGroup $self exited with warnings" );
        $self->warning( $self->status_message );
    }
    else {
        $self->status_message( "JobGroup $self completed successfully" );
        $self->log->info( $self->status_message );
    }
}

sub dryrun {
    my $self = shift;

    if ( $self->enabled ) {
        $self->add_output( "Dry-run: $self [" . $self->workdir . "]" );
        for my $job ( $self->get_jobs ) {
            $job->dryrun;
            $self->add_output( $job->get_output );
        }
    }
    else {
        $self->add_output( "Dry-run: $self skipped (job group disabled)" );
    }
}


sub list_jobs {
    my $self = shift;
    my $depth = shift;
    
    [ $self, $depth++ ], map $_->list_jobs($depth), $self->get_jobs;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
