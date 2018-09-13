package Logger;

use  Log::Log4perl;

################################################################################
#  Logger.pm
#
#  Description: A message logger object implementing Log4Perl 
################################################################################

our $logger;
our %counter;

################################################################################
################################################################################
#   Public Methods
################################################################################
################################################################################
sub new {
  my $class = shift; 
  my $self = {@_};
	
  bless($self, $class);
  $self->_init($class); 
  return $self;
}

sub trace {
  my $class = shift; 
  my $message = shift; 
  _count('TRACE'); 
	$logger->trace($message);
}

sub debug {
  my $class = shift; 
  my $message = shift; 
  _count('DEBUG'); 
	$logger->debug($message);
}

sub info {
  my $class = shift; 
  my $message = shift; 
  _count('INFO'); 
	$logger->info($message);
}

sub warn{
  my $class = shift; 
  my $message = shift; 
  _count('WARN'); 
	$logger->warn($message);
}

sub error{
  my $class = shift; 
  my $message = shift; 
  _count('ERROR'); 
	$logger->error($message);
}

sub error_die{
  my $class = shift; 
  my $message = shift; 
  _count('ERROR'); 
	$logger->error_die($message);
}

sub fatal{
  my $class = shift; 
  my $message = shift; 
  _count('FATAL'); 
	$logger->fatal($message);
}

sub carp{
  my $class = shift; 
  my $message = shift; 
  _count('WARN'); 
	$logger->logcarp($message);
}

sub cluck{
  my $class = shift; 
  my $message = shift; 
  _count('WARN'); 
	$logger->logcluck($message);
}

sub croak{
  my $class = shift; 
  my $message = shift; 
  _count('ERROR'); 
	$logger->logcroak($message);
}

sub confess{
  my $class = shift; 
  my $message = shift; 
  _count('ERROR'); 
	$logger->logconfess($message);
}

sub get_count {
  my $class = shift; 
  my $all_level = shift;
  my $total = 0;

	@levels = split(/,/,$all_level);
	foreach my $level (@levels)
	{
  	$level = uc($level);
  	chomp $level;
  	$level =~ s/^\s+|\s+$//g;
  
 		if(defined($counter{$level}))
		{
			$total += $counter{$level};
		}
	}
  return $total;
}

################################################################################
################################################################################
#   Private Methods
################################################################################
################################################################################
sub _init {
  my $self=shift;
  my $class = shift; 

	# Retrieve Logger
	$logger = Log::Log4perl::get_logger($class);

	my $level = uc($ENV{'LOG_LEVEL'});
	
	if ($level =~ /.conf$/)
	{
		Log::Log4perl::init_once($level);
	}
	else
	{	
		if ($level ne 'ALL' && $level ne 'OFF' && $level ne 'TRACE' && $level ne 'DEBUG' && $level ne 'INFO' && $level ne 'WARN' && $level ne 'ERROR' && $level ne 'FATAL')
		{
			$level = 'INFO';
		}
    # Configuration in a string ...
  	my $conf = "log4perl.rootLogger              = $level, Screen\n";
    $conf .= "log4perl.appender.Screen         = Log::Log4perl::Appender::Screen\n";
    $conf .= "log4perl.appender.Screen.stderr  = 0\n";
		$conf .= "log4perl.appender.Screen.layout = \\ \n";
		$conf .= "    Log::Log4perl::Layout::PatternLayout\n"; 
		$conf .= "log4perl.appender.Screen.layout.ConversionPattern = %d [%p] %F %m{chomp} %n\n";
		
		# ... passed as a reference to init()
		Log::Log4perl::init_once( \$conf );
		#This is set to prevent all messages from giving the source as the wrapper.
		$Log::Log4perl::caller_depth = 1;
	}
}

sub _count {
  my $level = shift; 
	
	if(defined($counter{$level}))
	{
		$counter{$level} += 1;
	}
	else
	{
		$counter{$level} = 1;
	}
}

1;


