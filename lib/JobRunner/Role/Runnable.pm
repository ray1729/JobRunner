package JobRunner::Role::Runnable;

use MooseX::Role::WithOverloading;
#use Log::Log4perl::NDC;

with 'MooseX::Log::Log4perl';

requires qw( run list_jobs );

use overload (
    q{""}    => 'as_string',
    fallback => 1
);

has name => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

sub as_string {
    shift->name;
}

has output => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    traits  => [ 'Array' ],
    handles => {
        add_output => 'push',
        get_output => 'elements',
    }
);

has enabled => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has desc => (
    is      => 'ro',
    isa     => 'Str',
    default => '',
);

has continue_on_error => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has workdir => (
    is  => 'rw',
    isa => 'Str',
);

has warnings => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    traits  => [ 'Array' ],
    handles => {
        add_warning  => 'push',
        has_warnings => 'count',
        get_warnings => 'elements'
    }
);

has errors => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    traits  => [ 'Array' ],
    default => sub { [] },
    handles => {
        add_error    => 'push',
        has_errors   => 'count',
        get_errors   => 'elements',
        clear_errors => 'clear',
    }
);

has status => (
    is        => 'rw',
    isa       => 'Int',
    predicate => 'has_status',
);

before status => sub {
    my $self = shift;
    confess( "status not set" )
        unless @_ or $self->has_status;
};

sub exit_code {
    shift->status >> 8;
}

sub signal {
    shift->status & 128;
}

has status_message => (
    is         => 'rw',
    isa        => 'Str',
    lazy_build => 1,
);

sub _build_status_message {
    my $self = shift;

    my $mesg = "Child exited " . $self->exit_code;
    if ( my $signal = $self->signal ) {
        $mesg .= " (killed by signal $signal)";
    }

    return $mesg;
}

sub warning {
    my ( $self, $mesg ) = @_;
    $self->log->warn( $mesg );
    $self->add_warning( $mesg );
}

sub error {
    my ( $self, $mesg ) = @_;
    $self->log->error( $mesg );
    $self->add_error( $mesg );
}

sub _out_err_callback {
    my $self = shift;
    my $tag = shift;
    my $ndc = Log::Log4perl::NDC->get;
    for ( @_ ) {
        $self->log->info( "$tag $_" );
        $self->add_output( "[$ndc] $tag $_" );
    }
}   

sub stderr_callback {
    my $self = shift;
    $self->_out_err_callback( 'STDERR', map { split "\n" } @_ );
}

sub stdout_callback {
    my $self = shift;
    $self->_out_err_callback( 'STDOUT', map { split "\n" } @_ );
}

around run => sub {
    my $orig = shift;
    my $self = shift;

    unless ( $self->enabled ) {
	$self->add_warning( "Skipping disabled job $self" );
	return;
    }

    $self->log->debug( "Running $self" );
    $self->$orig( @_ );
};

1;

__END__
