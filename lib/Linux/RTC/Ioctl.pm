package Linux::RTC::Ioctl;

use 5.006;
use strict;
use warnings FATAL => 'all';
use Carp;

require Exporter;
# use AutoLoader;

our @ISA = qw(Exporter);

=head1 NAME

Linux::RTC::Ioctl - Real Time Clock access using the Linux driver ioctl interface

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

    my $foo = Linux::RTC::Ioctl->new($device);
    ...

Where $device can be a device file name, a device number (0, 1, 2..) or empty
(C<undef>), in which case F</dev/rtc> is used.

The Linux driver has built-in locking so that only one process can have the
F</dev/rtc> interface open at a time. You must have permissions to access the
device file, according to the usual file owner and gruop. This usually means
you must be root to access this functionality.

Beware the RTC time runs in the RTC time zone, which is not the same as the 
local time zone of the system, as it can also be GMT. To prevent problems with
the transition to and from daylight saving time, the RTC should run in the GMT
time zone, which is usually the default for the Linux setup. Note there is no
why to retrieve this time zone from the RTC device, the system stores this
information elsewhere. See the manual page for the `hwclock` command for more
details.

Any functionality described here is present only when supported by the RTC
hardware.

All information here is taken from the documentation for Linux RTC driver
provided with the kernel at:

    https://www.kernel.org/doc/Documentation/rtc.txt

from the 'rtc' manual page and from the C header file F<linux/rtc.h>.

=head1 EXPORT

Constants for use with the ioctl() call can be exported with:

    use Linux::RTC::Ioctl qw(:all)

or you can export individual constants by name if you so wish.

=head2 Exportable constants

=head3 ioctl requests:

Enable/disable periodic interrupt. Can be used to generate a periodic signal
between 2Hz and MAX_FREQ.

    RTC_PIE_OFF
    RTC_PIE_ON
    RTC_MAX_FREQ

Enable/disable timer interrupt on every time update. Since the RTC displays
time in seconds, the update interrupt will occur once per second (1Hz)

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

Flag indicating periodic interrupt has occurred:

    RTC_PF

Flag indicating an update interrupt has occurred (current RTC time has just
changed):

    RTC_UF

Flag indicating an alarm interrupt occurrent (the alarm was set and just went off):

    RTC_AF

Flags mask for all 3 of the above:

    RTC_IRQF

=head3 Other constants

These are not documented in the Linux kernel, but are provided to C/C++
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

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

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
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

=head1 METHODS

=head2 new($device)

Creates an RTC object from given device file name, device index, or "/dev/rtc".
Only one process can open the same RTC device at a time. Usually you must be root to access the device.

=cut

sub new
{
    $self = bless 
	{
	    enabled => 0,
	    pending => 0,
	    sec => -1, min => -1, hour => -1, mday => -1, mon => -1, year => -1, wday => -1, yday => -1, isdst => -1
	}, shift;

    $device = shift // '/dev/rtc';

    if ($device =~ m/\d+/)
	$device = '/dev/rtc' . $device;

    open $$self{'device'}, '<', $device or croak "Failed to open RTC device $device: $!"
}

my $alarm_record_size = length(pack'L!', 0);

=head2 wait_for_time_event

Wait for the next timer interrupt (hardware IRQ 8)

Will issue a read from this RTC device. Blocks the current thread, so only use if you set up the alarm and/or you know
it is going to ring soon enough. To avoid blocking the thread for just the RTC device, you can use the $rtc->device
as an open handle in a call to C<select()>.

Returns a bitmask of flags indicating what timmer interrupt has occurred, and a count of all the interrupts since the last read.
See the RTC_PF, RTC_UP, RTC_AF falgs.

=cut

sub wait_for_time_event
{
    $self = shift;
    $alarm_record = "";
    $read_size = read $self->device, $alarm_record, length $alarm_record_size;

    defined($read_size) or croak "Read from RTC device failed: $!";
    $read_size == $alarm_record_size or croak "Unexpected data read from RTC device.";

    $alarm_record = unpack 'L!', $alarm_record;

    $alarm_flags = $alarm_record & 0xFF;    # low-order byte has flags to indicate alarm or periodic-interrupt
    $interrupt_count = $alarm_record >> 8;  # how many times the interrupt triggered since last read;

    return $alarm_flags, $interrupt_count;
}


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

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1; # End of Linux::RTC::Ioctl
