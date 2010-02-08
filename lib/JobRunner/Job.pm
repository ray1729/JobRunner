package JobRunner::Job;

use Moose;
use namespace::autoclean;

use IO::Pipe;
use IO::Select;

with 'JobRunner::Role::Runnable';

has command => (
    is       => 'ro',
    isa      => 'Str',
    required => 1
);

sub run {
    my $self = shift;

    my ( $pid, $out, $err ) = $self->exec_child;

    $self->log->info( "$pid running $self" );
    
    my $select = IO::Select->new;
    for ( $err, $out ) {
        $select->add($_);
    }

    while ( my @ready = $select->can_read ) {
        for my $fh (@ready) {
            if ( defined( my $line = $fh->getline ) ) {
                if ( $fh == $err ) {
                    $self->stderr_callback( $line );
                }
                else {
                    $self->stdout_callback( $line );
                }
            }
            else {
                $select->remove($fh);
            }
        }
    }

    waitpid( $pid, 0 ) > 0
      or confess("failed to reap child");
    
    $self->status( $? );

    if ( $self->exit_code != 0 ) {
        if ( $self->continue_on_error ) {
            $self->warning( $self->status_message );
        }
        else {
            $self->error( $self->status_message );
        }
    }
    else {
        $self->log->info( $self->status_message );
    }
}

sub exec_child {
    my $self = shift;

    my $out = IO::Pipe->new();
    my $err = IO::Pipe->new();

    defined( my $pid = fork() )
      or confess "fork failed: $!";

    if ( $pid == 0 ) {    # child
        $out->writer;
        $err->writer;
        open( STDOUT, '>&' . $out->fileno )
          or confess "dup STDOUT: $!";
        open( STDERR, '>&' . $err->fileno )
          or confess "dup STDERR: $!";
        open( STDIN, '</dev/null' )
          or confess "dup STDIN: $!";
        chdir( $self->workdir )
            or confess "chdir " . $self->workdir . ": $!";
        exec( '/bin/bash', '-c', $self->command )
            or confess "failed to exec bash: $!";
    }
    
    $out->reader;
    $err->reader;

    return ( $pid, $out, $err );
}

sub dryrun {
    my $self = shift;

    if ( $self->enabled ) {  
        $self->add_output( "Dry-run: $self [" . $self->workdir . "]" );
        $self->add_output( $self->command );
    }
    else {
        $self->add_output( "Dry-run: $self skipped (job disabled)" );        
    }
}
    
sub list_jobs {
    my ( $self, $depth ) = @_;
    return [ $self, $depth ];
}

__PACKAGE__->meta->make_immutable;

1;
