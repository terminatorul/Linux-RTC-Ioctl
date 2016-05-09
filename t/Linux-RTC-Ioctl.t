# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Linux-RTC-Ioctl.t'

#########################

# change 'tests => 2' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 2;
BEGIN { use_ok('Linux::RTC::Ioctl', qw(:all)) };


my $fail = 0;
foreach my $constname (qw(
	RTC_AF RTC_AIE_OFF RTC_AIE_ON RTC_ALM_READ RTC_ALM_SET RTC_EPOCH_READ
	RTC_EPOCH_SET RTC_IRQF RTC_IRQP_READ RTC_IRQP_SET RTC_MAX_FREQ RTC_PF
	RTC_PIE_OFF RTC_PIE_ON RTC_PLL_GET RTC_PLL_SET RTC_RD_TIME RTC_SET_TIME
	RTC_UF RTC_UIE_OFF RTC_UIE_ON RTC_VL_CLR RTC_VL_READ RTC_WIE_OFF
	RTC_WIE_ON RTC_WKALM_RD RTC_WKALM_SET)) {
  next if (eval "my \$a = $constname; 1");
  if ($@ =~ /^Your vendor has not defined Linux::RTC::Ioctl macro $constname/) {
    print "# pass: $@";
  } else {
    print "# fail: $@";
    $fail = 1;
  }

}

ok( $fail == 0 , 'Constants' );
#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

