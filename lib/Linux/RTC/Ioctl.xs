#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <sys/ioctl.h>
#include <linux/rtc.h>

#include "const-c.inc"

MODULE = Linux::RTC::Ioctl		PACKAGE = Linux::RTC::Ioctl		

INCLUDE: const-xs.inc
