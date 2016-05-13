# include <sys/ioctl.h>
# include <linux/rtc.h>

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#if defined(read) || defined(ioctl)
# warning "POSIX read/ioctl re-defined"
# include "src/IoctlNative.h"
#else
# define linux_rtc_native_read read
# define linux_rtc_native_ioctl ioctl
#endif

#include "const-c.inc"

static const char
    invalidHandleMsg[] = "Invalid device file handle.",
    missingDeviceFileMsg[] = "No device file given.",
    rtcRecordSizeMsg[] = "Unexpected end of file from real time clock device %s.",
    invalidRTCAccessMsg[] = "Access to real time clock device %s failed.",
    unsignedParamMsg[] = "Unsigned number parameter expected.",
    numericParamMsg[] = "Numeric parameter expected.",
    hashAccessFailedMsg[] = "Failed to access $rtc object hash keys.",
    objectFieldsMissingMsg[] = "Member field \"%s\" is missing or is non-numeric in RTC object.";

MODULE = Linux::RTC::Ioctl		PACKAGE = Linux::RTC::Ioctl		

INCLUDE: const-xs.inc

void
wait_for_timer(HV *rtc)
    PROTOTYPE: \%
    PPCODE:
	int fd = -1;
	char const *node = "";
	unsigned long record = 0;
	ssize_t read_size = -1;
	SV **device = hv_fetch(rtc, "device", 6, 0);

	{
	    SV **nodename = hv_fetch(rtc, "nodename", 8, 0);

	    if (nodename && (node = SvPV_nolen(*nodename), SvPOK(*nodename)))
		;
	    else
		node = "";
	}

	if (device)
	{
	    IO *file_io = sv_2io(*device);

	    if (file_io)
	    {
		PerlIO *device_perlio = IoIFP(file_io);

		if (device_perlio)
		{
		    fd = PerlIO_fileno(device_perlio);

		    if (fd < 0)
			croak(invalidHandleMsg);
		}
		else
		    croak(invalidHandleMsg);
	    }
	    else
		croak(invalidHandleMsg);
	}
	else
	    croak(missingDeviceFileMsg);

	read_size = linux_rtc_native_read(fd, &record, sizeof record);

	if (read_size == sizeof record)
	{
	    EXTEND(SP, 2);
	    PUSHs(sv_2mortal(newSVuv(record & ((1 << CHAR_BIT) - 1))));
	    PUSHs(sv_2mortal(newSVuv(record >> CHAR_BIT)));
	    XSRETURN(2);
	}
	else
	    if (read_size >= 0)
		croak(rtcRecordSizeMsg, node);
	    else
		croak(invalidRTCAccessMsg, node);

#if defined(RTC_IRQP_SET) && defined(RTC_IRQP_READ)

void
periodic_frequency(HV *rtc, ...)
    PROTOTYPE: \%;$
    PPCODE:
	int fd = -1;
	char const *node = "";
	SV **device = hv_fetch(rtc, "device", 6, 0);;
	
	{
	    SV **nodename = hv_fetch(rtc, "nodename", 8, 0);

	    if (nodename && (node = SvPV_nolen(*nodename), SvPOK(*nodename)))
		;
	    else
		node = "";
	}

	if (device)
	{
	    IO *file_io = sv_2io(*device);

	    if (file_io)
	    {
		PerlIO *device_perlio = IoIFP(file_io);

		if (device_perlio)
		{
		    fd = PerlIO_fileno(device_perlio);

		    if (fd < 0)
			croak(invalidHandleMsg);
		}
		else
		    croak(invalidHandleMsg);
	    }
	    else
		croak(invalidHandleMsg);
	}
	else
	    croak(missingDeviceFileMsg);

	if (items > 1)
	{
	    IV freq = SvIV(ST(1));

	    if (SvIOK(ST(1)) && freq > 0)
	    {
		unsigned long frequency = freq;

		if (ioctl(fd, RTC_IRQP_SET, frequency) < 0)
		    croak(invalidRTCAccessMsg, node);

		XSRETURN_EMPTY;
	    }
	    else
		croak(unsignedParamMsg);
	}
	else
	{
	    unsigned long frequency;

	    if (ioctl(fd, RTC_IRQP_READ, &frequency) < 0)
		croak(invalidRTCAccessMsg, node);

	    mXPUSHs(newSVuv(frequency));
	    XSRETURN(1);
	}

#endif

#if defined(RTC_PIE_ON) && defined(RTC_PIE_OFF)

void
periodic_interrupt(HV *rtc, bool fEnable)
    PROTOTYPE: \%$
    PPCODE:
	int fd = -1;
	char const *node = "";
	SV **device = hv_fetch(rtc, "device", 6, 0);;
	
	{
	    SV **nodename = hv_fetch(rtc, "nodename", 8, 0);

	    if (nodename && (node = SvPV_nolen(*nodename), SvPOK(*nodename)))
		;
	    else
		node = "";
	}

	if (device)
	{
	    IO *file_io = sv_2io(*device);

	    if (file_io)
	    {
		PerlIO *device_perlio = IoIFP(file_io);

		if (device_perlio)
		{
		    fd = PerlIO_fileno(device_perlio);

		    if (fd < 0)
			croak(invalidHandleMsg);
		}
		else
		    croak(invalidHandleMsg);
	    }
	    else
		croak(invalidHandleMsg);
	}
	else
	    croak(missingDeviceFileMsg);

	if (ioctl(fd, fEnable ? RTC_PIE_ON : RTC_PIE_OFF, 0) < 0)
	    croak(invalidRTCAccessMsg, node);

	XSRETURN_EMPTY;

#endif

#if defined(RTC_UIE_ON) && defined(RTC_UIE_OFF)

void
update_interrupt(HV *rtc, bool fEnable)
    PROTOTYPE: \%$
    PPCODE:
	int fd = -1;
	char const *node = "";
	SV **device = hv_fetch(rtc, "device", 6, 0);;
	
	{
	    SV **nodename = hv_fetch(rtc, "nodename", 8, 0);

	    if (nodename && (node = SvPV_nolen(*nodename), SvPOK(*nodename)))
		;
	    else
		node = "";
	}

	if (device)
	{
	    IO *file_io = sv_2io(*device);

	    if (file_io)
	    {
		PerlIO *device_perlio = IoIFP(file_io);

		if (device_perlio)
		{
		    fd = PerlIO_fileno(device_perlio);

		    if (fd < 0)
			croak(invalidHandleMsg);
		}
		else
		    croak(invalidHandleMsg);
	    }
	    else
		croak(invalidHandleMsg);
	}
	else
	    croak(missingDeviceFileMsg);

	if (ioctl(fd, fEnable ? RTC_UIE_ON : RTC_UIE_OFF, 0) < 0)
	    croak(invalidRTCAccessMsg, node);

	XSRETURN_EMPTY;

#endif

#if defined(RTC_AIE_ON) && defined(RTC_AIE_OFF)

void
alarm_interrupt(HV *rtc, bool fEnable)
    PROTOTYPE: \%$
    PPCODE:
	int fd = -1;
	char const *node = "";
	SV **device = hv_fetch(rtc, "device", 6, 0);;
	
	{
	    SV **nodename = hv_fetch(rtc, "nodename", 8, 0);

	    if (nodename && (node = SvPV_nolen(*nodename), SvPOK(*nodename)))
		;
	    else
		node = "";
	}

	if (device)
	{
	    IO *file_io = sv_2io(*device);

	    if (file_io)
	    {
		PerlIO *device_perlio = IoIFP(file_io);

		if (device_perlio)
		{
		    fd = PerlIO_fileno(device_perlio);

		    if (fd < 0)
			croak(invalidHandleMsg);
		}
		else
		    croak(invalidHandleMsg);
	    }
	    else
		croak(invalidHandleMsg);
	}
	else
	    croak(missingDeviceFileMsg);

	if (ioctl(fd, fEnable ? RTC_AIE_ON : RTC_AIE_OFF, 0) < 0)
	    croak(invalidRTCAccessMsg, node);

	XSRETURN_EMPTY;

#endif

#if defined(RTC_RD_TIME)

void
read_time(HV *rtc)
    PROTOTYPE: \%
    PPCODE:
	struct rtc_time tm = { 0, 0, 0,  0, 0, 0,  -1, -1, -1 };
	int fd = -1;
	char const *node = "";
	SV **device = hv_fetch(rtc, "device", 6, 0);;
	
	{
	    SV **nodename = hv_fetch(rtc, "nodename", 8, 0);

	    if (nodename && (node = SvPV_nolen(*nodename), SvPOK(*nodename)))
		;
	    else
		node = "";
	}

	if (device)
	{
	    IO *file_io = sv_2io(*device);

	    if (file_io)
	    {
		PerlIO *device_perlio = IoIFP(file_io);

		if (device_perlio)
		{
		    fd = PerlIO_fileno(device_perlio);

		    if (fd < 0)
			croak(invalidHandleMsg);
		}
		else
		    croak(invalidHandleMsg);
	    }
	    else
		croak(invalidHandleMsg);
	}
	else
	    croak(missingDeviceFileMsg);

	if (ioctl(fd, RTC_RD_TIME, &tm) < 0)
	    croak(invalidRTCAccessMsg, node);

	if (G_ARRAY == GIMME_V)
	{
	    /* called in list context, push time members on stack and do not store them. */
	    EXTEND(SP, 9);
	    mPUSHi(tm.tm_sec);
	    mPUSHi(tm.tm_min);
	    mPUSHi(tm.tm_hour);

	    mPUSHi(tm.tm_mday);
	    mPUSHi(tm.tm_mon);
	    mPUSHi(tm.tm_year);

	    mPUSHi(tm.tm_wday);
	    mPUSHi(tm.tm_yday);
	    mPUSHi(tm.tm_isdst);
	    XSRETURN(9);
	}
	else
	{
	    /* called in void (or scalar) context, save members in the perl object. */
	    SV **val = hv_fetch(rtc, "sec", 3, !0);

	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_sec));
	    else
		croak(hashAccessFailedMsg);

	    val = hv_fetch(rtc, "min", 3, !0);
	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_min));
	    else
		croak(hashAccessFailedMsg);

	    val = hv_fetch(rtc, "hour", 4, !0);
	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_hour));
	    else
		croak(hashAccessFailedMsg);

	    val = hv_fetch(rtc, "mday", 4, !0);
	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_mday));
	    else
		croak(hashAccessFailedMsg);

	    val = hv_fetch(rtc, "mon", 3, !0);
	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_mon));
	    else
		croak(hashAccessFailedMsg);

	    val = hv_fetch(rtc, "year", 4, !0);
	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_year));
	    else
		croak(hashAccessFailedMsg);

	    val = hv_fetch(rtc, "wday", 4, !0);
	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_wday));
	    else
		croak(hashAccessFailedMsg);

	    val = hv_fetch(rtc, "yday", 4, !0);
	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_yday));
	    else
		croak(hashAccessFailedMsg);

	    val = hv_fetch(rtc, "isdst", 5, !0);
	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_isdst));
	    else
		croak(hashAccessFailedMsg);

	    XSRETURN_EMPTY;
	}

#endif

#if defined(RTC_SET_TIME)

void
set_time(HV *rtc, ...)
    PROTOTYPE: \*%;$$$$$$$$$
    PPCODE:
	int args_count = items;
	struct rtc_time tm = { 0, 0, 0,  0, 0, 0,  -1, -1, -1 };
	int fd = -1;
	char const *node = "";
	SV **device = hv_fetch(rtc, "device", 6, 0);;
	
	{
	    SV **nodename = hv_fetch(rtc, "nodename", 8, 0);

	    if (nodename && (node = SvPV_nolen(*nodename), SvPOK(*nodename)))
		;
	    else
		node = "";
	}

	if (device)
	{
	    IO *file_io = sv_2io(*device);

	    if (file_io)
	    {
		PerlIO *device_perlio = IoIFP(file_io);

		if (device_perlio)
		{
		    fd = PerlIO_fileno(device_perlio);

		    if (fd < 0)
			croak(invalidHandleMsg);
		}
		else
		    croak(invalidHandleMsg);
	    }
	    else
		croak(invalidHandleMsg);
	}
	else
	    croak(missingDeviceFileMsg);

	if (args_count > 10)
	    args_count = 10;

	switch (args_count)
	{
	case 10:
	    if (tm.tm_isdst = SvIV(ST(9)), SvIOK(ST(9)))
		;
	    else
		croak(numericParamMsg);
	    // fall-through
	case 9:
	    if (tm.tm_yday = SvIV(ST(8)), SvIOK(ST(8)))
		;
	    else
		croak(numericParamMsg);
	    // fall-through
	case 8:
	    if (tm.tm_wday = SvIV(ST(7)), SvIOK(ST(7)))
		;
	    else
		croak(numericParamMsg);
	    // fall-through
	case 7:
	    if (tm.tm_year = SvIV(ST(6)), SvIOK(ST(6)))
		;
	    else
		croak(numericParamMsg);
	    // fall-through
	case 6:
	    if (tm.tm_mon = SvIV(ST(5)), SvIOK(ST(5)))
		;
	    else
		croak(numericParamMsg);
	case 5:
	    if (tm.tm_mday = SvIV(ST(4)), SvIOK(ST(4)))
		;
	    else
		croak(numericParamMsg);
	    // fall-through
	case 4:
	    if (tm.tm_hour = SvIV(ST(3)), SvIOK(ST(3)))
		;
	    else
		croak(numericParamMsg);
	    // fall-through
	case 3:
	    if (tm.tm_min = SvIV(ST(2)), SvIOK(ST(2)))
		;
	    else
		croak(numericParamMsg);
	    // fall-through
	case 2:
	    if (tm.tm_sec = SvIV(ST(1)), SvIOK(ST(1)))
		;
	    else
		croak(numericParamMsg);
	    break;
	case 1:
	    {
		SV **val = hv_fetch(rtc, "isdst", 5, 0);

		if (*val && (tm.tm_isdst = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "isdst");

		val = hv_fetch(rtc, "yday", 4, 0);
		if (*val && (tm.tm_yday = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "yday");

		val = hv_fetch(rtc, "wday", 4, 0);
		if (*val && (tm.tm_wday = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "wday");

		val = hv_fetch(rtc, "year", 4, 0);
		if (*val && (tm.tm_year = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "year");

		val = hv_fetch(rtc, "mon", 3, 0);
		if (*val && (tm.tm_mon = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "mon");

		val = hv_fetch(rtc, "mday", 4, 0);
		if (*val && (tm.tm_mday = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "mday");

		val = hv_fetch(rtc, "hour", 4, 0);
		if (*val && (tm.tm_hour = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "hour");

		val = hv_fetch(rtc, "min", 3, 0);
		if (*val && (tm.tm_min = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "min");

		val = hv_fetch(rtc, "sec", 3, 0);
		if (*val && (tm.tm_sec = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "sec");

		break;
	    }
	}

	if (ioctl(fd, RTC_SET_TIME, &tm) < 0)
	    croak(invalidRTCAccessMsg, node);

	XSRETURN_EMPTY;

#endif

#if defined(RTC_ALM_READ)

void
read_alarm(HV *rtc)
    PROTOTYPE: \%
    PPCODE:
	struct rtc_time tm = { 0, 0, 0,  0, 0, 0,  -1, -1, -1 };
	int fd = -1;
	char const *node = "";
	SV **device = hv_fetch(rtc, "device", 6, 0);;
	
	{
	    SV **nodename = hv_fetch(rtc, "nodename", 8, 0);

	    if (nodename && (node = SvPV_nolen(*nodename), SvPOK(*nodename)))
		;
	    else
		node = "";
	}

	if (device)
	{
	    IO *file_io = sv_2io(*device);

	    if (file_io)
	    {
		PerlIO *device_perlio = IoIFP(file_io);

		if (device_perlio)
		{
		    fd = PerlIO_fileno(device_perlio);

		    if (fd < 0)
			croak(invalidHandleMsg);
		}
		else
		    croak(invalidHandleMsg);
	    }
	    else
		croak(invalidHandleMsg);
	}
	else
	    croak(missingDeviceFileMsg);

	if (ioctl(fd, RTC_ALM_READ, &tm) < 0)
	    croak(invalidRTCAccessMsg, node);

	if (G_ARRAY == GIMME_V)
	{
	    /* called in list context, push time members on stack and do not store them. */
	    EXTEND(SP, 9);
	    mPUSHi(tm.tm_sec);
	    mPUSHi(tm.tm_min);
	    mPUSHi(tm.tm_hour);

	    mPUSHi(tm.tm_mday);
	    mPUSHi(tm.tm_mon);
	    mPUSHi(tm.tm_year);

	    mPUSHi(tm.tm_wday);
	    mPUSHi(tm.tm_yday);
	    mPUSHi(tm.tm_isdst);
	    XSRETURN(9);
	}
	else
	{
	    /* called in void (or scalar) context, save members in the perl object. */
	    SV **val = hv_fetch(rtc, "sec", 3, !0);

	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_sec));
	    else
		croak(hashAccessFailedMsg);

	    val = hv_fetch(rtc, "min", 3, !0);
	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_min));
	    else
		croak(hashAccessFailedMsg);

	    val = hv_fetch(rtc, "hour", 4, !0);
	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_hour));
	    else
		croak(hashAccessFailedMsg);

	    val = hv_fetch(rtc, "mday", 4, !0);
	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_mday));
	    else
		croak(hashAccessFailedMsg);

	    val = hv_fetch(rtc, "mon", 3, !0);
	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_mon));
	    else
		croak(hashAccessFailedMsg);

	    val = hv_fetch(rtc, "year", 4, !0);
	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_year));
	    else
		croak(hashAccessFailedMsg);

	    val = hv_fetch(rtc, "wday", 4, !0);
	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_wday));
	    else
		croak(hashAccessFailedMsg);

	    val = hv_fetch(rtc, "yday", 4, !0);
	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_yday));
	    else
		croak(hashAccessFailedMsg);

	    val = hv_fetch(rtc, "isdst", 5, !0);
	    if (*val)
		sv_setiv(*val, (IV)(tm.tm_isdst));
	    else
		croak(hashAccessFailedMsg);

	    XSRETURN_EMPTY;
	}

#endif


#if defined(RTC_ALM_SET)

void
set_alarm(HV *rtc, ...)
    PROTOTYPE: \*%;$$$$$$$$$
    PPCODE:
	int args_count = items;
	struct rtc_time tm = { 0, 0, 0,  0, 0, 0,  -1, -1, -1 };
	int fd = -1;
	char const *node = "";
	SV **device = hv_fetch(rtc, "device", 6, 0);;
	
	function_code:
	{
	    SV **nodename = hv_fetch(rtc, "nodename", 8, 0);

	    if (nodename && (node = SvPV_nolen(*nodename), SvPOK(*nodename)))
		;
	    else
		node = "";
	}

	if (device)
	{
	    IO *file_io = sv_2io(*device);

	    if (file_io)
	    {
		PerlIO *device_perlio = IoIFP(file_io);

		if (device_perlio)
		{
		    fd = PerlIO_fileno(device_perlio);

		    if (fd < 0)
			croak(invalidHandleMsg);
		}
		else
		    croak(invalidHandleMsg);
	    }
	    else
		croak(invalidHandleMsg);
	}
	else
	    croak(missingDeviceFileMsg);

	if (args_count > 10)
	    args_count = 10;

	switch (args_count)
	{
	case 10:
	    if (tm.tm_isdst = SvIV(ST(9)), SvIOK(ST(9)))
		;
	    else
		croak(numericParamMsg);
	    // fall-through
	case 9:
	    if (tm.tm_yday = SvIV(ST(8)), SvIOK(ST(8)))
		;
	    else
		croak(numericParamMsg);
	    // fall-through
	case 8:
	    if (tm.tm_wday = SvIV(ST(7)), SvIOK(ST(7)))
		;
	    else
		croak(numericParamMsg);
	    // fall-through
	case 7:
	    if (tm.tm_year = SvIV(ST(6)), SvIOK(ST(6)))
		;
	    else
		croak(numericParamMsg);
	    // fall-through
	case 6:
	    if (tm.tm_mon = SvIV(ST(5)), SvIOK(ST(5)))
		;
	    else
		croak(numericParamMsg);
	case 5:
	    if (tm.tm_mday = SvIV(ST(4)), SvIOK(ST(4)))
		;
	    else
		croak(numericParamMsg);
	    // fall-through
	case 4:
	    if (tm.tm_hour = SvIV(ST(3)), SvIOK(ST(3)))
		;
	    else
		croak(numericParamMsg);
	    // fall-through
	case 3:
	    if (tm.tm_min = SvIV(ST(2)), SvIOK(ST(2)))
		;
	    else
		croak(numericParamMsg);
	    // fall-through
	case 2:
	    if (tm.tm_sec = SvIV(ST(1)), SvIOK(ST(1)))
		;
	    else
		croak(numericParamMsg);
	    break;
	case 1:
	    {
		SV **val = hv_fetch(rtc, "isdst", 5, 0);

		if (*val && (tm.tm_isdst = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "isdst");

		val = hv_fetch(rtc, "yday", 4, 0);
		if (*val && (tm.tm_yday = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "yday");

		val = hv_fetch(rtc, "wday", 4, 0);
		if (*val && (tm.tm_wday = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "wday");

		val = hv_fetch(rtc, "year", 4, 0);
		if (*val && (tm.tm_year = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "year");

		val = hv_fetch(rtc, "mon", 3, 0);
		if (*val && (tm.tm_mon = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "mon");

		val = hv_fetch(rtc, "mday", 4, 0);
		if (*val && (tm.tm_mday = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "mday");

		val = hv_fetch(rtc, "hour", 4, 0);
		if (*val && (tm.tm_hour = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "hour");

		val = hv_fetch(rtc, "min", 3, 0);
		if (*val && (tm.tm_min = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "min");

		val = hv_fetch(rtc, "sec", 3, 0);
		if (*val && (tm.tm_sec = SvIV(*val), SvIOK(*val)))
		    ;
		else
		    croak(objectFieldsMissingMsg, "sec");

		break;
	    }
	}

	if (ioctl(fd, RTC_ALM_SET, &tm) < 0)
	    croak(invalidRTCAccessMsg, node);

	XSRETURN_EMPTY;

#endif
