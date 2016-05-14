package Linux::RTC::Ioctl;

use 5.006;
use strict;
use warnings FATAL => 'all';
use Carp;
use Cwd "realpath";

require Exporter;
# use AutoLoader;

our @ISA = qw(Exporter);

=head1 NAME

Linux::RTC::Ioctl - Real Time Clock access using the Linux driver ioctl interface.

=head1 VERSION

Version 0.08

=cut

our $VERSION = '0.08';


=head1 SYNOPSIS

Provides access to the Linux RTC driver (Real Time Clock), using one of
the RTC device files in a Linux system:

    - /dev/rtc
    - /dev/rtc0
    - /dev/rtc1
    - ...

Note F</dev/rtc> is now usually a symlink to F</dev/rtc0>.

Usage:

    use Linux::RTC::Ioctl;

    my $rtc = Linux::RTC::Ioctl->new($device);

    $sec, $min, $hour, $mday, $mon, $year = $rtc->read_time;

    # or:
    $rtc->read_time;
    $sec, $min, $hour = $rtc->{sec}, $rtc->{min}, $rtc->{hour};

    $rtc->{year} += 1;
    $rtc->set_time;	# Set RTC time one year in the future
    $rtc->set_time($sec, $min, $hour, $mday, $mon, $year+1);

    $enable = !0;

    $rtc->update_interrupt($enable);

    $freq = 20;
    $rtc->periodic_frequency($freq);
    $freq = $rtc->periodic_frequency;
    $rtc->periodic_interrupt($enable);

    $rtc->read_alarm
    $rtc->set_alarm($sec, $min, $hour, $mday, $mon, $year);
    $rtc->read_wakup_alarm
    $rtc->set_wakeup_alarm($sec, $min, $hour, $mday, $mon, $year);
    $rtc->alarm_interrupt($enable);

=head1 DESCRIPTION

C<$device> can be a device file name, a device number (0, 1, 2..) or empty
(C<undef>), in which case F</dev/rtc> is used.

The Linux driver has built-in locking so that only one process can have the
F</dev/rtc> interface open at a time. You must have permissions to access the
device file, according to the usual file owner and group.

Beware the RTC time runs in the RTC time zone, which is not the same as the 
local time zone of the system, as it can also be GMT. To prevent problems with
the transition to and from daylight saving time, the RTC should run in the GMT
time zone, which is usually the default for the Linux setup. Note there is no
why to retrieve this time zone from the RTC device, the system stores this
information elsewhere. See the manual page for the `hwclock` command for more
details.

Any functionality described here is present only when supported by the RTC
hardware.

All methods can take the date-time components from:

    * the argument list (if arguments are passed)
    * the $rtc object (empty arguments list)

All methods can return the date-time components as:

    * function result (in list context)
    * the $rtc object (in scalar or void context)

All information here is taken from the documentation for Linux RTC driver
provided with the kernel at:

    L<https://www.kernel.org/doc/Documentation/rtc.txt>

from the 'rtc' manual page and from the C header file <F<linux/rtc.h>>.

=cut

# This allows declaration	use Linux::RTC::Ioctl ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	RTC_AF
	RTC_AIE_OFF
	RTC_AIE_ON
	RTC_ALM_READ
	RTC_ALM_SET
	RTC_EPOCH_READ
	RTC_EPOCH_SET
	RTC_IRQF
	RTC_IRQP_READ
	RTC_IRQP_SET
	RTC_MAX_FREQ
	RTC_PF
	RTC_PIE_OFF
	RTC_PIE_ON
	RTC_PLL_GET
	RTC_PLL_SET
	RTC_RD_TIME
	RTC_SET_TIME
	RTC_UF
	RTC_UIE_OFF
	RTC_UIE_ON
	RTC_VL_CLR
	RTC_VL_READ
	RTC_WIE_OFF
	RTC_WIE_ON
	RTC_WKALM_RD
	RTC_WKALM_SET
	RTC_RECORD_SIZE
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

=head1 METHODS

=head2 my $rtc = Linux::RTC::Ioctl->new($device)

Creates an RTC object from given open file handle, device file name, device index, or C</dev/rtc> by default.

If an open file handle is given, it must represent a device file on the platform, that supportes the RTC ioctl commands.
Binary mode will be turned on for the open handle

Only one process can open the same RTC device at a time.

=cut

sub new($;$)
{
    my $self = bless 
	{
	    enabled => 0,
	    pending => 0,
	    sec => -1, min => -1, hour => -1, mday => -1, mon => -1, year => -1, wday => -1, yday => -1, isdst => -1
	}, shift;

    my $device = (shift // '/dev/rtc');

    my $fd = fileno($device);

    if (defined($fd) && $fd >= 0)
    {
	binmode $device;

	$self->{device} = $device;

	# poor attempt to get a file name from the file handle, Linux only
	$self->{nodename} = "/proc/$$/fd/$fd";
	if (-e $self->{nodename})
	{
	    $self->{nodename} = Cwd::realpath $self->{"nodename"};
	}
	else
	{
	    $self->{nodename} = undef;
	}
    }
    else
    {
	
	$device = '/dev/rtc' . $device if ($device =~ m/^\d+$/);

	open $$self{'device'}, '<:unix:raw', $device or croak "Failed to open real time clock device $device: $!";
	binmode $self->{'device'};

	$self->{nodename} = $device;
    }

    return $self;
}

=head2 $rtc->nodename

The name of the device file that is used by this C<$rtc> object. This is given (or implied) by the argument passed to the C<new()> constructor.

If the C<new()> constructor is given an open file handle (no file name), the nodename will be C<undef>, unless (on most Linux platforms) the file
name can still be found using procfs at a path of the form: C<< /proc/<PID>/fd/<fd> >>.

=cut

sub nodename(\%)
{
    return $_[0]->{nodename};
}

=head2 $rtc->device

An open file handle for the RTC device file represented by this C<$rtc> object. This is a read-only character device that will block on read
until the next timer event occurs (either a time update interrupt, a periodic timer interrupt, or an alarm interrupt; timers use IRQ 8).
Usually you need to enable the timer interrupts before you can read from this file.

When the event occurs, a block of fixed size (given by C<RTC_RECORD_SIZE>, which is the size of an unsigned long on the native platform) can
be read, of which the low order byte is a bitmask of flags choosen from C<RTC_PF> (for periodic interrupt), C<RTC_UF> (time update interrupt) and
C<RTC_AF> (alarm interrupt), and the remaining bytes are a count of interrupts that occurred since the last read.

You can also use the file handle in calls to C<select()> to avoid completely blocking the current thread on the RTC device file only.

Example for reading the device file:

    my $rtc_record = pack 'L!', 0;
    my $record_size = length $rtc_record;   # length also given as the package constant RTC_RECORD_SIZE
    my $size = sysread $rtc->device, $rtc_record, $record_size;	# blocks until next timer event occurs

    defined $size or die("Access to real time clock device failed: $!");
    $size == $record_size or die("Unexpected end of file reading RTC device.");

    $rtc_record = unpack 'L!', $rtc_record;

    # Event flags and the interrupt count are now available
    $timer_flags = $rtc_record & 0xFF;
    $timer_count = $rtc_record >> 8;

Or you can use the $rtc->wait_for_timer() method, which natively does about the same as the above.

=cut

sub device(\%)
{
    return $_[0]->{device};
}

=head2 $rtc->rtctime

    $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst = $rtc->rtctime
    $rtc->rtctime($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)

Similar to C<localtime> and C<gmtime>, C<< $rtc->rtctime >> returns a list of the the broken-down time components stored in the C<$rtc> object.
You can also pass such a list to this method to populate the C<$rtc> object.

There is no calendar time alternative to these components, measured as seconds from the begining of the Unix epoch. To build one you would need to
know the RTC time zone first (either GMT or the local time zone) which the RTC device does not know. The Linux system stores this information
elsewhere, see the manual page for the C<hwclock> command.

The time components stored in the C<$rtc> device are used by the C<set_time>, C<set_alarm> and C<set_wakeup_alarm> methods when they are called
without any arguments. The time components are also populated by the C<read_time>, C<read_alarm> and C<read_wakeup_alarm> methods when they
are called in void or scalar context. When such methods are called in list context, the time components are returned as usual and are NOT stored
in the C<$rtc> object.


Note that the corresponding calendar time (sencods since the epoch) depends on the RTC time zone, which the RTC device does not know.
The platform stores the time zone difference between the local time zone and the RTC elsewhere, see the manual page for the C<hwclock>
command.

Note the RTC device does not use the last 3 time components: C<$wday>, C<$yday>, C<$isdst>.

=cut

sub rtctime(\%;$$$$$$$$$)
{
    my $self = shift;

    if (scalar(@_) > 0)
    {
	$self->{sec} = shift;

	if (scalar(@_) > 0)
	{
	    $self->{min} = shift;

	    if (scalar(@_) > 0)
	    {
		$self->{hour} = shift;

		if (scalar(@_) > 0)
		{
		    $self->{mday} = shift;

		    if (scalar(@_) > 0)
		    {
			$self->{mon} = shift;

			if (scalar(@_) > 0)
			{
			    $self->{year} = shift;

			    if (scalar(@_) > 0)
			    {
				$self->{wday} = shift;

				if (scalar(@_) > 0)
				{
				    $self->{yday} = shift;

				    if (scalar(@_) > 0)
				    {
					$self->{isdst} = shift;
				    }
				}
			    }
			}
		    }
		}
	    }
	}
    }

    if (wantarray())
    {
	return $self->{sec}, $self->{min}, $self->{hour}, $self->{mday}, $self->{mon}, $self->{year}, $self->{wday}, $self->{yday}, $self->{isdst};
    }
}

=head2 $rtc->wait_for_timer

    $event_flags, $event_count = $rtc->wait_for_timer()

Wait for the next timer event.

Will issue a read from this RTC device. Blocks the current thread, so only use if you set up the alarm and/or you know
it is going to ring soon enough. To avoid blocking the thread for just the RTC device, you can use the $rtc->device
as an open handle in a call to C<select()>.

Returns a bitmask of flags indicating what timer events have occurred, and a count of all the events since the last read.
See the RTC_PF, RTC_UP, RTC_AF falgs.


=head2 $rtc->periodic_frequency

    $rtc->periodic_frequency($frequncy)
    $frequency = $rtc->periodic_frequency;

Sets up the the requency for periodic RTC events (interrupts). The frequency must be a power of 2 between 2 and C<RTC_MAX_FREQ>.
After setting the frequency you should also enable the periodic interrupt. Maximum frequency for a non-root user (usually 64)
can be read from file C</sys/class/rtc/rtc0/max-user-freq>.

=head2 $rtc->periodic_interrupts($enable)

Sets up the RTC device to emit or not periodic (frequncy) timer events (IRQ 8 interrupts). Enable or disable the periodic interrupts.

=head2 $rtc->update_interrupts($enable)

Sets up the RTC device to emit or not update timer events (whenever the current time changes). Enable or disable the update interrupts.

=head2 $rtc->alarm_interrupts($enable)

Sets up the RTC device to emit or not timer events (IRQ 8 interrupts). Enable or disable the alarm interrupts.

=head2 $rtc->read_time

=head2 $rtc->set_time

    $rtc->read_time
    $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst = $rtc->read_time
    
    $rtc->set_time
    $rtc->set_time($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)

Sets or reads the RTC date and time in the RTC time zone. Uses the members in C<$rtc>: C<< $rtc->{sec} >>, C<< $rtc->{min} >>
C<< $rtc->{hour} >>, C<< $rtc->{mday} >>, C<< $rtc->{mon} >>, C<< $rtc->year >>, C<< $rtc->{wday} >> (not used), C<< $rtc->{yday} >>
(not used), C<< $rtc->isdst >> (not used). These fields are similar to the components return from C<gmtime> or C<localtime>: mon begins
with 0 for january, year begins with 0 for 1900.

=head2 $rtc->read_alarm

=head2 $rtc->set_alarm

    $rtc->read_alarm
    $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst = $rtc->read_alarm
    
    $rtc->set_alarm
    $rtc->set_alarm($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)

Sets or reads the RTC date and time in the RTC time zone. Uses the members in C<$rtc>: C<< $rtc->{sec} >>, C<< $rtc->{min} >>
C<< $rtc->{hour} >>, C<< $rtc->{mday} >>, C<< $rtc->{mon} >>, C<< $rtc->year >>, C<< $rtc->{wday} >> (not used), C<< $rtc->{yday} >>
(not used), C<< $rtc->isdst >> (not used). These fields are similar to the components return from C<gmtime> or C<localtime>: mon begins
with 0 for january, year begins with 0 for 1900.

=head2 $rtc->close

Closes the underlaying device in C<< $rtc->device >> (like C</dev/rtc>). The C<$rtc> object should no longer be used after calling this method.

=cut

sub close(\%)
{
    close $_[0]->{device};
}

=head1 EXPORT

Constants for use with the C<ioctl()> call can be exported with:

    use Linux::RTC::Ioctl qw(:all)

or you can export individual constants by name if you so wish.

=head2 Exportable constants

Each of the following constants is exported only if the platform defines it.

=head3 ioctl requests:

Enable/disable periodic interrupt. Can be used to generate a periodic signal
with any power of 2 frequency between 2Hz and C<RTC_MAX_FREQ> for root user
(usually max 64Hz for non-root). Using the maximum frequency is likely to
consume CPU time resources on your target machine.

    RTC_PIE_OFF
    RTC_PIE_ON
    RTC_MAX_FREQ

Enable/disable timer interrupt on every time update. Since the RTC displays
time in seconds, the interrupt will occur once per second (1Hz)

    RTC_UIE_ON
    RTC_UIE_OFF

Enable/disable timer interrupt when the alarm rings.

    RTC_AIE_ON
    RTC_AIE_OFF

Enabled/disable timer interrupt when the wake-up alarm rings. With most hardware
this alarm can also wake the computer from sleep (stand-by), hibernate or even
shutdown.

    RTC_WIE_OFF
    RTC_WIE_ON

Read and set current RTC date and time.

    RTC_RD_TIME
    RTC_SET_TIME

Read and set the RTC time since the RTC epoch. This is not the same as the
Unix epoch normally used by the system.

    RTC_EPOCH_READ
    RTC_EPOCH_SET

Read or set the alarm time. Usually only hour, minutes and seconds are
supported.

    RTC_ALM_READ
    RTC_ALM_SET

Read or set the wake-up alarm time. Supports both date and time.

    RTC_WKALM_RD
    RTC_WKALM_SET

=head3 Flags for records read from the RTC device file

Record size (records from RTC device files are fixed-length), always defined as the native size of an unsigned long:

    RTC_RECORD_SIZE

Flag indicating periodic interrupt has occurred:

    RTC_PF

Flag indicating an update interrupt has occurred (current RTC time has just
changed):

    RTC_UF

Flag indicating an alarm interrupt occurrent (the alarm was set and just went off):

    RTC_AF

Flags mask for any of the above:

    RTC_IRQF

=head3 Other constants

These are not documented in the Linux kernel, but are exposed to C/C++
programs in the system headers.

Read / set IRQ rate:

    RTC_IRQP_READ
    RTC_IRQP_SET

Read / set PLL correction (like the RTC used in Q40/Q60 computers):

    RTC_PLL_GET
    RTC_PLL_SET

Read voltage low detector / clear voltage low information:

    RTC_VL_READ
    RTC_VL_CLR

=cut

=head1 AUTHOR

Timothy Madden, C<< <terminatorul at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-linux-rtc-ioctl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Linux-RTC-Ioctl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Linux::RTC::Ioctl


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Linux-RTC-Ioctl>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Linux-RTC-Ioctl>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Linux-RTC-Ioctl>

=item * Search CPAN

L<http://search.cpan.org/dist/Linux-RTC-Ioctl/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2016 Timothy Madden.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.


=cut

sub AUTOLOAD
{
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&Linux::RTC::Ioctl::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
	no strict 'refs';
	*$AUTOLOAD = sub { $val };
    }
    goto &$AUTOLOAD;
}

require XSLoader;
XSLoader::load('Linux::RTC::Ioctl', $VERSION);

1; # Successfull return after loading Linux::RTC::Ioctl module
