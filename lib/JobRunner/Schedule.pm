package JobRunner::Schedule;

use Moose;
use Moose::Util::TypeConstraints;
use Fcntl ':flock';
use File::Class;
use File::Path;
use IO::File;
use namespace::autoclean;

with 'JobRunner::Role::Runnable';
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

class_type 'JobRunner::File::Class' => { class => 'File::Class' };

coerce 'JobRunner::File::Class'
    => from 'Str'
    => via { File::Class->new( $_ ) };

has lockfile => (
    is     => 'rw',
    isa    => 'JobRunner::File::Class',
    coerce => 1,
);

has exclusive_lock => (
    is         => 'ro',
    isa        => 'IO::File',
    lazy_build => 1,
);

sub _build_exclusive_lock {
    my $self = shift;

    my $lockfile = $self->lockfile;    

    $self->log->info( "Taking exclusive lock on $lockfile" );

    my $lockdir = $lockfile->up;
    -d $lockdir or File::Path::make_path( $lockdir );

    my $lock_fh = IO::File->new( $lockfile, O_RDWR|O_CREAT, 0644 )
        or confess "create $lockfile: $!";

    flock( $lock_fh, LOCK_EX|LOCK_NB )
        or confess "flock $lockfile: $!";

    return $lock_fh;
}

sub list_jobs {
    my $self = shift;

    map $_->list_jobs( 0 ), $self->get_jobs;
}

sub run {
    my $self = shift;

    Log::Log4perl::NDC->push( $self->name );

    $self->exclusive_lock();
    
    $self->log->info( "Running jobs for schedule " . $self->name );
    
    my %job_for;
    
    for my $job ( $self->get_jobs ) {

        Log::Log4perl::NDC->push( $job->name );

        defined( my $pid = fork() )
            or confess "fork failed: $!";

        if ( $pid == 0 ) {
            $job->run;
            if ( $job->has_errors or $job->has_warnings ) {
	        for ( $job->get_output, $job->get_errors, $job->get_warnings ) {
		    chomp;
	            print STDERR "$_\n";
		}
	        exit 1;
            }
            exit 0;
        }

        $self->log->debug( "Process $pid handling job $job" );

        $job_for{ $pid } = $job;

        Log::Log4perl::NDC->pop;
    }

    my $exit_code = 0;
    
    while ( ( my $pid = wait ) > 0 ) {
        my $job = $job_for{ $pid };
        $job->status( $? );
        if ( $job->exit_code != 0 ) {
            $self->log->error( "Job $job failed" );
            $exit_code++;
        }
        $self->log->info( "Job $job completed successfully" );
    }

    exit $exit_code;
}

sub dryrun {
    my $self = shift;

    for my $job ( $self->get_jobs ) {
        $job->dryrun;
        print STDERR "$_\n" for $job->get_output;
    }
}

__PACKAGE__->meta->make_immutable;

1;

__END__
