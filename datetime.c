// Expose POSIX + GNU timezone functions under strict C99.
#define _GNU_SOURCE
#define _DEFAULT_SOURCE
#define _POSIX_C_SOURCE 200809L
#define _XOPEN_SOURCE 700

#ifdef _WIN32
#include <windows.h>
#endif
#include <getopt.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <errno.h>
#include <stdarg.h>
#include <sys/stat.h>
#include <unistd.h>
#include <ctype.h>

#ifdef __linux__
#include <sys/time.h>
#endif

#include "version.h"

// __version__ = 2.0.<build>  (build = YYYYMMDDhhmmss, generated at compile time)

#ifndef VERSION_BUILD
#define VERSION_BUILD "00000000000000"
#endif

#define VERSION_MAJOR "2"
#define VERSION_MINOR "0"

static int g_debug = 0;
static int g_utc = 0;

static void
debug_log (const char *fmt, ...)
{
  if (!g_debug)
    return;
  va_list ap;
  va_start (ap, fmt);
  fprintf (stderr, "debug: ");
  vfprintf (stderr, fmt, ap);
  fprintf (stderr, "\n");
  va_end (ap);
}

// Option name -> strftime format (legacy).
static const struct
{
  const char *name;
  const char *format;
} formats[] = {
  {"-hr", "%Y-%m-%d %H:%M:%S"},
  {"--human-readable", "%Y-%m-%d %H:%M:%S"},
  {"-c", "%Y%m%dT%H%M%S"},
  {"--compact", "%Y%m%dT%H%M%S"},
  {"iso-basic", "%Y%m%dT%H%M%S"},
  {"-cd", "%Y-%m-%d"},
  {"--calendar-date", "%Y-%m-%d"},
  {"-cdb", "%Y%m%d"},
  {"--calendar-date-base", "%Y%m%d"},
  {"-od", "%Y-%j"},
  {"--ordinal-date", "%Y-%j"},
  {"-odb", "%Y%j"},
  {"--ordinal-date-base", "%Y%j"},
  {"-wd", "%G-W%V-%u"},
  {"--week-date", "%G-W%V-%u"},
  {"-wdb", "%GW%V%u"},
  {"--week-date-basic", "%GW%V%u"},
};

static const char *
match_format (const char *a)
{
  for (size_t i = 0; i < sizeof (formats) / sizeof (formats[0]); i++)
    {
      if (!strcmp (a, formats[i].name))
	return formats[i].format;
    }
  return NULL;
}

/* is_timestamp_binary removed for GNU strict compliance: use --timestamp flag or -DTIMESTAMP compile-time (see Makefile:27) */

static void
print_timezone (void)
{
  time_t now = time (NULL);
  struct tm *ti = localtime (&now);
#ifdef _WIN32
  _tzset ();
  long off = -_timezone;
  const char *zone = _tzname[ti && ti->tm_isdst > 0 ? 1 : 0];
  if (zone && zone[0])
    printf ("Timezone: %s (UTC%+ld)\n", zone, off / 3600);
  else
    printf ("Timezone: unknown\n");
#else
  if (ti && ti->tm_zone)
    printf ("Timezone: %s (UTC%+ld)\n", ti->tm_zone, ti->tm_gmtoff / 3600);
  else
    printf ("Timezone: unknown\n");
#endif
}

static void
print_usage (const char *prog)
{
  printf ("Usage: %s [OPTION]... [+FORMAT]\n"
	  "  or:  %s [OPTION]... [MMDDhhmm[[CC]YY][.ss]]\n"
	  "Display date and time in the given FORMAT.\n"
	  "With -s, or with MMDDhhmm[[CC]YY][.ss], set the date and time first.\n\n",
	  prog, prog);

  fputs
    ("Mandatory arguments to long options are mandatory for short options too.\n"
     "  -d, --date=STRING\n"
     "         display time described by STRING, not 'now'\n"
     "      --debug\n" "         annotate the parsed date,\n"
     "         and warn about questionable usage to standard error\n"
     "  -f, --file=DATEFILE\n"
     "         like --date; once for each line of DATEFILE;\n"
     "         if DATEFILE is -, read names from standard input\n"
     "  -I[FMT], --iso-8601[=FMT]\n"
     "         output date/time in ISO 8601 format.\n"
     "         FMT='date' (default), 'hours', 'minutes', 'seconds', or 'ns'\n"
     "         for date and time to the indicated precision.\n"
     "         Example: 2006-08-14T02:34:56-06:00\n" "      --resolution\n"
     "         output the available resolution of timestamps.\n"
     "         Example: 0.000000001\n" "  -R, --rfc-email\n"
     "         output date and time in RFC 5322 format.\n"
     "         Example: Mon, 14 Aug 2006 02:34:56 +0000\n"
     "      --rfc-3339=FMT\n"
     "         output date/time in RFC 3339 format.\n"
     "         FMT='date', 'seconds', or 'ns'\n"
     "         for date and time to the indicated precision.\n"
     "         Example: 2006-08-14 02:34:56-06:00\n"
     "  -r, --reference=FILE\n"
     "         display the last modification time of FILE\n"
     "  -s, --set=STRING\n" "         set time described by STRING\n"
     "  -u, --utc, --universal\n"
     "         print or set Coordinated Universal Time (UTC)\n"
     "      --help\n" "         display this help and exit\n"
     "      --version\n" "         output version information and exit\n\n"
     "All options that specify the date to display are mutually exclusive.\n"
     "I.e.: --date, --file, --reference, --resolution.\n\n"
     "Legacy output formats (kept for compatibility):\n"
     "  (default)                  YYYYMMDDhhmmss\n"
     "  -hr, --human-readable      YYYY-MM-DD hh:mm:ss\n"
     "  -c, --compact              YYYYMMDDThhmmss   (ISO 8601 basic)\n"
     "  -cd, --calendar-date       YYYY-MM-DD\n"
     "  -cdb, --calendar-date-base YYYYMMDD\n"
     "  -od, --ordinal-date        YYYY-DDD\n"
     "  -odb, --ordinal-date-base  YYYYDDD\n"
     "  -wd, --week-date           YYYY-Www-D\n"
     "  -wdb, --week-date-basic    YYYYWwwD\n"
     "  --timestamp                YYYYMMDDhhmmssZ (UTC/GMT, compact seconds for micro version)\n\n"
     "FORMAT controls the output.  Interpreted sequences are:\n\n"
     "  %%   a literal %\n"
     "  %a   locale's abbreviated weekday name (e.g., Sun)\n"
     "  %A   locale's full weekday name (e.g., Sunday)\n"
     "  %b   locale's abbreviated month name (e.g., Jan)\n"
     "  %B   locale's full month name (e.g., January)\n"
     "  %c   locale's date and time (e.g., Thu Mar  3 23:05:25 2005)\n"
     "  %C   century; like %Y, except omit last two digits (e.g., 20)\n"
     "  %d   day of month (e.g., 01)\n"
     "  %D   date (ambiguous); same as %m/%d/%y\n"
     "  %e   day of month, space padded; same as %_d\n"
     "  %F   full date; like %+4Y-%m-%d\n"
     "  %g   last two digits of year of ISO week number (ambiguous; 00-99); see %G\n"
     "  %G   year of ISO week number; normally useful only with %V\n"
     "  %h   same as %b\n" "  %H   hour (00..23)\n" "  %I   hour (01..12)\n"
     "  %j   day of year (001..366)\n"
     "  %k   hour, space padded ( 0..23); same as %_H\n"
     "  %l   hour, space padded ( 1..12); same as %_I\n"
     "  %m   month (01..12)\n" "  %M   minute (00..59)\n" "  %n   a newline\n"
     "  %N   nanoseconds (000000000..999999999)\n"
     "  %p   locale's equivalent of either AM or PM; blank if not known\n"
     "  %P   like %p, but lower case\n" "  %q   quarter of year (1..4)\n"
     "  %r   locale's 12-hour clock time (e.g., 11:11:04 PM)\n"
     "  %R   24-hour hour and minute; same as %H:%M\n"
     "  %s   seconds since the Epoch (1970-01-01 00:00 UTC)\n"
     "  %S   second (00..60)\n" "  %t   a tab\n"
     "  %T   time; same as %H:%M:%S\n"
     "  %u   day of week (1..7); 1 is Monday\n"
     "  %U   week number of year, with Sunday as first day of week (00..53)\n"
     "  %V   ISO week number, with Monday as first day of week (01..53)\n"
     "  %w   day of week (0..6); 0 is Sunday\n"
     "  %W   week number of year, with Monday as first day of week (00..53)\n"
     "  %x   locale's date (can be ambiguous; e.g., 12/31/99)\n"
     "  %X   locale's time representation (e.g., 23:13:48)\n"
     "  %y   last two digits of year (ambiguous; 00..99)\n" "  %Y   year\n"
     "  %z   +hhmm numeric time zone (e.g., -0400)\n"
     "  %:z  +hh:mm numeric time zone (e.g., -04:00)\n"
     "  %::z  +hh:mm:ss numeric time zone (e.g., -04:00:00)\n"
     "  %:::z  numeric time zone with : to necessary precision (e.g., -04, +05:30)\n"
     "  %Z   alphabetic time zone abbreviation (e.g., EDT)\n\n"
     "By default, date pads numeric fields with zeroes.\n"
     "The following optional flags may follow '%':\n\n"
     "  -  (hyphen) do not pad the field\n"
     "  _  (underscore) pad with spaces\n" "  0  (zero) pad with zeros\n"
     "  +  pad with zeros, and put '+' before future years with >4 digits\n"
     "  ^  use upper case if possible\n"
     "  #  use opposite case if possible\n\n"
     "After any flags comes an optional field width, as a decimal number;\n"
     "then an optional modifier, which is either\n"
     "E to use the locale's alternate representations if available, or\n"
     "O to use the locale's alternate numeric symbols if available.\n\n"
     "Examples:\n"
     "Convert seconds since the Epoch (1970-01-01 UTC) to a date\n"
     "  $ date --date='@2147483647'\n\n"
     "Show the time on the west coast of the US (use tzselect(1) to find TZ)\n"
     "  $ TZ='America/Los_Angeles' date\n\n"
     "Show the local time for 9AM next Friday on the west coast of the US\n"
     "  $ date --date='TZ=\"America/Los_Angeles\" 09:00 next Fri'\n\n",
     stdout);

  print_timezone ();

  printf ("\n"
	  "Report bugs to: bug-coreutils@gnu.org (for GNU compatibility)\n"
	  "datetime %s.%s.%s - local implementation\n",
	  VERSION_MAJOR, VERSION_MINOR, VERSION_BUILD);
}

static void
print_version (void)
{
  printf ("datetime %s.%s.%s\n", VERSION_MAJOR, VERSION_MINOR, VERSION_BUILD);
  print_timezone ();
}

/* ---------- Time helpers ---------- */

static int
get_current_timespec (struct timespec *ts)
{
#ifdef CLOCK_REALTIME
  if (clock_gettime (CLOCK_REALTIME, ts) == 0)
    return 0;
#endif
  ts->tv_sec = time (NULL);
  ts->tv_nsec = 0;
  return 0;
}

static void
trim (char *s)
{
  // trim leading
  char *p = s;
  while (*p && isspace ((unsigned char) *p))
    p++;
  if (p != s)
    memmove (s, p, strlen (p) + 1);
  // trim trailing
  size_t len = strlen (s);
  while (len > 0 && isspace ((unsigned char) s[len - 1]))
    {
      s[len - 1] = '\0';
      len--;
    }
}

/* Escape single quotes for shell: ' -> '\'' */
static void
shell_escape (const char *in, char *out, size_t outsz)
{
  size_t j = 0;
  for (size_t i = 0; in[i] && j + 4 < outsz; i++)
    {
      if (in[i] == '\'')
	{
	  out[j++] = '\'';
	  out[j++] = '\\';
	  out[j++] = '\'';
	  out[j++] = '\'';
	}
      else
	{
	  out[j++] = in[i];
	}
    }
  out[j] = '\0';
}

/* Check TZ= prefix */
static int
has_tz_prefix (const char *s, char *tzbuf, size_t tzsz, const char **rest)
{
  if (strncmp (s, "TZ=", 3) != 0)
    return 0;
  const char *p = s + 3;
  // value may be quoted
  char quote = 0;
  if (*p == '"' || *p == '\'')
    {
      quote = *p;
      p++;
      const char *end = strchr (p, quote);
      if (!end)
	return 0;
      size_t vlen = (size_t) (end - p);
      if (vlen >= tzsz)
	vlen = tzsz - 1;
      memcpy (tzbuf, p, vlen);
      tzbuf[vlen] = '\0';
      p = end + 1;
      // skip whitespace after
      while (*p && isspace ((unsigned char) *p))
	p++;
      // also need to handle optional space before actual date string
      // If after TZ="..." there is still TZ assignment? For now handle single
      *rest = p;
      return 1;
    }
  else
    {
      // unquoted: up to whitespace
      const char *end = p;
      while (*end && !isspace ((unsigned char) *end))
	end++;
      size_t vlen = (size_t) (end - p);
      if (vlen >= tzsz)
	vlen = tzsz - 1;
      memcpy (tzbuf, p, vlen);
      tzbuf[vlen] = '\0';
      while (*end && isspace ((unsigned char) *end))
	end++;
      *rest = end;
      return 1;
    }
}

/* Parse @epoch */
static int
parse_epoch (const char *s, struct timespec *out)
{
  if (s[0] != '@')
    return 0;
  const char *p = s + 1;
  while (*p && isspace ((unsigned char) *p))
    p++;
  if (!*p)
    return 0;

  int is_negative = (*p == '-');

  char *end = NULL;
  const char *dot = strchr (p, '.');
  long long sec = 0;
  long nsec = 0;

  if (dot)
    {
      char secbuf[64];
      size_t slen = (size_t) (dot - p);
      if (slen >= sizeof (secbuf))
	return 0;
      memcpy (secbuf, p, slen);
      secbuf[slen] = '\0';
      errno = 0;
      sec = strtoll (secbuf, &end, 10);
      if (errno || end == secbuf)
	return 0;

      /* fractional part: up to 9 digits, pad right with zeros */
      const char *frac = dot + 1;
      char nbuf[10] = "000000000";
      size_t i = 0;
      while (frac[i] && isdigit ((unsigned char) frac[i]) && i < 9)
	{
	  nbuf[i] = frac[i];
	  i++;
	}
      /* skip any extra digits beyond 9 */
      const char *after = frac + i;
      while (*after && isdigit ((unsigned char) *after))
	after++;
      while (*after && isspace ((unsigned char) *after))
	after++;
      if (*after != '\0')
	return 0;

      nsec = (long) strtol (nbuf, NULL, 10);
    }
  else
    {
      errno = 0;
      sec = strtoll (p, &end, 10);
      if (errno || end == p)
	return 0;
      while (*end && isspace ((unsigned char) *end))
	end++;
      if (*end != '\0')
	return 0;
      nsec = 0;
    }

  if (is_negative && nsec > 0)
    {
      sec = sec - 1;
      nsec = 1000000000L - nsec;
    }

  out->tv_sec = (time_t) sec;
  out->tv_nsec = nsec;
  return 1;
}

/* Try strptime with list of formats */
static int
parse_with_strptime (const char *s, struct timespec *out, int utc)
{
  // List of formats to try; order matters (more specific first)
  const char *fmts[] = {
    "%Y-%m-%dT%H:%M:%S%z",
    "%Y-%m-%dT%H:%M:%S",
    "%Y-%m-%d %H:%M:%S %z",
    "%Y-%m-%d %H:%M:%S",
    "%Y-%m-%d %H:%M",
    "%Y-%m-%d",
    "%Y/%m/%d %H:%M:%S",
    "%Y/%m/%d",
    "%m/%d/%y %H:%M:%S",
    "%m/%d/%y",
    "%m/%d/%Y",
    "%Y%m%d%H%M%S",
    "%Y%m%d",
    "%a %b %d %H:%M:%S %Z %Y",
    "%a, %d %b %Y %H:%M:%S %z",
    "%a, %d %b %Y %H:%M:%S %Z",
    "%d %b %Y %H:%M:%S",
    "%H:%M:%S",
    "%H:%M",
    NULL
  };
  for (int i = 0; fmts[i]; i++)
    {
      struct tm tm = { 0 };
      char *ret = strptime (s, fmts[i], &tm);
      if (ret)
	{
	  // check if fully consumed (allow trailing spaces)
	  while (*ret && isspace ((unsigned char) *ret))
	    ret++;
	  if (*ret != '\0')
	    continue;
	  // handle mktime vs timegm
	  tm.tm_isdst = -1;
	  time_t t;
	  if (utc)
	    {
#ifdef __linux__
	      t = timegm (&tm);
#else
	      // fallback: set TZ=UTC temporarily
	      char *old = getenv ("TZ");
	      char oldbuf[256] = { 0 };
	      if (old)
		{
		  strncpy (oldbuf, old, sizeof (oldbuf) - 1);
		}
	      setenv ("TZ", "UTC", 1);
	      tzset ();
	      t = mktime (&tm);
	      if (old)
		setenv ("TZ", oldbuf, 1);
	      else
		unsetenv ("TZ");
	      tzset ();
#endif
	    }
	  else
	    {
	      t = mktime (&tm);
	    }
	  if (t == (time_t) - 1)
	    continue;
	  out->tv_sec = t;
	  out->tv_nsec = 0;
	  return 1;
	}
    }
  return 0;
}

/* Fallback via GNU date (or gdate on macOS) */
static int
parse_via_gnudate (const char *s, struct timespec *out, int utc)
{
#ifdef _WIN32
  // Windows cmd.exe date is interactive and does not support -d
  (void) s;
  (void) out;
  (void) utc;
  return 0;
#else
  // Build command: LC_ALL=C [gdate|date] [-u] -d 'escaped' '+%s.%N'
  size_t esc_needed = strlen (s) * 4 + 1;
  char *esc = malloc (esc_needed);
  if (!esc)
    return 0;
  shell_escape (s, esc, esc_needed);
  size_t cmd_needed = esc_needed + 128;
  char *cmd = malloc (cmd_needed);
  if (!cmd)
    {
      free (esc);
      return 0;
    }

#ifdef __APPLE__
  // On macOS, Homebrew GNU date is named gdate
  const char *date_cmd = "gdate";
  if (system ("command -v gdate >/dev/null 2>&1") != 0)
    date_cmd = "date";
#else
  const char *date_cmd = "date";
#endif

  if (utc)
    snprintf (cmd, cmd_needed,
	      "LC_ALL=C %s -u -d '%s' '+%%s.%%N' 2>/dev/null", date_cmd, esc);
  else
    snprintf (cmd, cmd_needed,
	      "LC_ALL=C %s -d '%s' '+%%s.%%N' 2>/dev/null", date_cmd, esc);

  FILE *fp = popen (cmd, "r");
  if (!fp)
    {
      free (esc);
      free (cmd);
      return 0;
    }
  char buf[128] = { 0 };
  if (!fgets (buf, sizeof (buf), fp))
    {
      pclose (fp);
      free (esc);
      free (cmd);
      return 0;
    }
  pclose (fp);
  free (esc);
  free (cmd);
  trim (buf);
  if (!buf[0])
    return 0;
  // buf is like "1234567890.123456789"
  char *dot = strchr (buf, '.');
  long long sec = 0;
  long nsec = 0;
  if (dot)
    {
      *dot = '\0';
      sec = atoll (buf);
      char *frac = dot + 1;
      // pad/truncate to 9
      char nbuf[16] = { 0 };
      size_t flen = strlen (frac);
      for (size_t i = 0; i < 9; i++)
	{
	  if (i < flen && isdigit ((unsigned char) frac[i]))
	    nbuf[i] = frac[i];
	  else
	    nbuf[i] = '0';
	}
      nbuf[9] = '\0';
      nsec = atol (nbuf);
    }
  else
    {
      sec = atoll (buf);
      nsec = 0;
    }
  out->tv_sec = (time_t) sec;
  out->tv_nsec = nsec;
  return 1;
#endif
}

static int
parse_day_offset (int day_delta, struct timespec *out, int utc)
{
  time_t now = time (NULL);
  struct tm tm;
  if (utc)
    gmtime_r (&now, &tm);
  else
    localtime_r (&now, &tm);
  tm.tm_hour = 0;
  tm.tm_min = 0;
  tm.tm_sec = 0;
  tm.tm_isdst = -1;
  time_t t = utc ? timegm (&tm) : mktime (&tm);
  t += (time_t) day_delta *86400;
  out->tv_sec = t;
  out->tv_nsec = 0;
  return 1;
}

/* Main parse function */
static int
parse_date_string (const char *orig, struct timespec *out, int utc, int debug)
{
  if (!orig || !*orig)
    return 0;
  // Make mutable copy for trim (dynamic, no arbitrary limit)
  char *buf = strdup (orig);
  if (!buf)
    return 0;
  trim (buf);
  if (!buf[0])
    {
      free (buf);
      return 0;
    }

  debug_log ("parsing date string '%s' (utc=%d)", buf, utc);

  // Handle TZ= prefix
  char tzbuf[256];
  const char *rest = NULL;
  if (has_tz_prefix (buf, tzbuf, sizeof (tzbuf), &rest))
    {
      debug_log ("detected TZ='%s' rest='%s'", tzbuf, rest);
      // Save old TZ
      const char *oldtz = getenv ("TZ");
      char oldcopy[512] = { 0 };
      int had_old = 0;
      if (oldtz)
	{
	  strncpy (oldcopy, oldtz, sizeof (oldcopy) - 1);
	  had_old = 1;
	}
      setenv ("TZ", tzbuf, 1);
      tzset ();
      // If rest is empty, then it's just timezone? Use now
      int res = 0;
      if (!rest || !*rest)
	{
	  // no date part, use now in that timezone
	  get_current_timespec (out);
	  res = 1;
	}
      else
	{
	  res = parse_date_string (rest, out, utc, debug);
	}
      // restore
      if (had_old)
	setenv ("TZ", oldcopy, 1);
      else
	unsetenv ("TZ");
      tzset ();
      if (res)
	{
	  debug_log ("parsed with TZ='%s' -> %ld.%09ld", tzbuf,
		     (long) out->tv_sec, (long) out->tv_nsec);
	}
      free (buf);
      return res;
    }

  // Special strings
  if (!strcmp (buf, "now"))
    {
      get_current_timespec (out);
      free (buf);
      return 1;
    }

  if (!strcmp (buf, "today"))
    {
      parse_day_offset (0, out, utc);
      free (buf);
      return 1;
    }
  if (!strcmp (buf, "yesterday"))
    {
      parse_day_offset (-1, out, utc);
      free (buf);
      return 1;
    }
  if (!strcmp (buf, "tomorrow"))
    {
      parse_day_offset (1, out, utc);
      free (buf);
      return 1;
    }

  if (parse_epoch (buf, out))
    {
      debug_log ("parsed as epoch -> %ld.%09ld", (long) out->tv_sec,
		 (long) out->tv_nsec);
      free (buf);
      return 1;
    }
  if (parse_with_strptime (buf, out, utc))
    {
      debug_log ("parsed via strptime -> %ld.%09ld", (long) out->tv_sec,
		 (long) out->tv_nsec);
      free (buf);
      return 1;
    }
  if (parse_via_gnudate (buf, out, utc))
    {
      debug_log ("parsed via gnudate fallback -> %ld.%09ld",
		 (long) out->tv_sec, (long) out->tv_nsec);
      free (buf);
      return 1;
    }
  if (debug)
    {
      fprintf (stderr, "debug: failed to parse date string '%s'\n", buf);
    }
  free (buf);
  return 0;
}

/* Format time with handling of %N and %q, and custom % handling.
   Returns 0 on success, out is filled.
*/
static int
format_time (const struct timespec *ts, const char *fmt, int utc, char *out,
	     size_t outsz)
{
  if (!fmt || !out || outsz == 0)
    return -1;

  struct tm tm;
  time_t sec = ts->tv_sec;
  if (utc)
    gmtime_r (&sec, &tm);
  else
    localtime_r (&sec, &tm);

  int quarter = (tm.tm_mon / 3) + 1;

  long off = 0;
  if (!utc)
    {
#ifdef _WIN32
      _tzset ();
      off = -_timezone;
#else
      off = tm.tm_gmtoff;
#endif
    }

  char sign = off >= 0 ? '+' : '-';
  long absoff = labs (off);
  long hh = absoff / 3600;
  long mm = (absoff % 3600) / 60;
  long ss = absoff % 60;

  char zbuf[32], zcol1[32], zcol2[32], zcol3buf[32];
  snprintf (zbuf, sizeof (zbuf), "%c%02ld%02ld", sign, hh, mm);
  snprintf (zcol1, sizeof (zcol1), "%c%02ld:%02ld", sign, hh, mm);
  snprintf (zcol2, sizeof (zcol2), "%c%02ld:%02ld:%02ld", sign, hh, mm, ss);
  if (ss != 0)
    snprintf (zcol3buf, sizeof (zcol3buf), "%c%02ld:%02ld:%02ld", sign, hh,
	      mm, ss);
  else if (mm != 0)
    snprintf (zcol3buf, sizeof (zcol3buf), "%c%02ld:%02ld", sign, hh, mm);
  else
    snprintf (zcol3buf, sizeof (zcol3buf), "%c%02ld", sign, hh);

  size_t out_len = 0;
  for (size_t i = 0; fmt[i];)
    {
      if (fmt[i] != '%')
	{
	  if (out_len + 1 >= outsz)
	    {
	      out[outsz - 1] = '\0';
	      return -1;
	    }
	  out[out_len++] = fmt[i++];
	  continue;
	}

      /* fmt[i] == '%' */
      if (fmt[i + 1] == '\0')
	{
	  if (out_len + 1 >= outsz)
	    {
	      out[outsz - 1] = '\0';
	      return -1;
	    }
	  out[out_len++] = '%';
	  i++;
	  break;
	}
      if (fmt[i + 1] == '%')
	{
	  if (out_len + 1 >= outsz)
	    {
	      out[outsz - 1] = '\0';
	      return -1;
	    }
	  out[out_len++] = '%';
	  i += 2;
	  continue;
	}
      if (fmt[i + 1] == 'N')
	{
	  char nbuf[16];
	  int nlen =
	    snprintf (nbuf, sizeof (nbuf), "%09ld", (long) ts->tv_nsec);
	  if (nlen < 0 || out_len + (size_t) nlen >= outsz)
	    {
	      out[outsz - 1] = '\0';
	      return -1;
	    }
	  memcpy (out + out_len, nbuf, (size_t) nlen);
	  out_len += (size_t) nlen;
	  i += 2;
	  continue;
	}
      if (fmt[i + 1] == 'q')
	{
	  if (out_len + 1 >= outsz)
	    {
	      out[outsz - 1] = '\0';
	      return -1;
	    }
	  out[out_len++] = (char) ('0' + quarter);
	  i += 2;
	  continue;
	}
      if (fmt[i + 1] == 's')
	{
	  char sbuf[32];
	  int slen = snprintf (sbuf, sizeof (sbuf), "%ld", (long) ts->tv_sec);
	  if (slen < 0 || out_len + (size_t) slen >= outsz)
	    {
	      out[outsz - 1] = '\0';
	      return -1;
	    }
	  memcpy (out + out_len, sbuf, (size_t) slen);
	  out_len += (size_t) slen;
	  i += 2;
	  continue;
	}
      if (fmt[i + 1] == ':')
	{
	  if (strncmp (&fmt[i], "%:::z", 5) == 0)
	    {
	      size_t l = strlen (zcol3buf);
	      if (out_len + l >= outsz)
		{
		  out[outsz - 1] = '\0';
		  return -1;
		}
	      memcpy (out + out_len, zcol3buf, l);
	      out_len += l;
	      i += 5;
	      continue;
	    }
	  if (strncmp (&fmt[i], "%::z", 4) == 0)
	    {
	      size_t l = strlen (zcol2);
	      if (out_len + l >= outsz)
		{
		  out[outsz - 1] = '\0';
		  return -1;
		}
	      memcpy (out + out_len, zcol2, l);
	      out_len += l;
	      i += 4;
	      continue;
	    }
	  if (strncmp (&fmt[i], "%:z", 3) == 0)
	    {
	      size_t l = strlen (zcol1);
	      if (out_len + l >= outsz)
		{
		  out[outsz - 1] = '\0';
		  return -1;
		}
	      memcpy (out + out_len, zcol1, l);
	      out_len += l;
	      i += 3;
	      continue;
	    }
	}
      if (fmt[i + 1] == 'z')
	{
	  size_t l = strlen (zbuf);
	  if (out_len + l >= outsz)
	    {
	      out[outsz - 1] = '\0';
	      return -1;
	    }
	  memcpy (out + out_len, zbuf, l);
	  out_len += l;
	  i += 2;
	  continue;
	}
      if (utc && fmt[i + 1] == 'Z')
	{
	  if (out_len + 3 >= outsz)
	    {
	      out[outsz - 1] = '\0';
	      return -1;
	    }
	  memcpy (out + out_len, "UTC", 3);
	  out_len += 3;
	  i += 2;
	  continue;
	}
      if (fmt[i + 1] == 'n')
	{
	  if (out_len + 1 >= outsz)
	    {
	      out[outsz - 1] = '\0';
	      return -1;
	    }
	  out[out_len++] = '\n';
	  i += 2;
	  continue;
	}
      if (fmt[i + 1] == 't')
	{
	  if (out_len + 1 >= outsz)
	    {
	      out[outsz - 1] = '\0';
	      return -1;
	    }
	  out[out_len++] = '\t';
	  i += 2;
	  continue;
	}

      /* Standard strftime conversion specifier with optional flags/width/modifiers */
      char token[32];
      size_t start = i;
      i++;			/* skip '%' */
      while (fmt[i] == '-' || fmt[i] == '_' || fmt[i] == '0' || fmt[i] == '^'
	     || fmt[i] == '#' || fmt[i] == '+')
	i++;
      while (isdigit ((unsigned char) fmt[i]))
	i++;
      if (fmt[i] == 'E' || fmt[i] == 'O')
	i++;
      if (fmt[i] != '\0')
	i++;
      size_t tlen = i - start;
      if (tlen >= sizeof (token))
	{
	  out[outsz - 1] = '\0';
	  return -1;
	}
      memcpy (token, &fmt[start], tlen);
      token[tlen] = '\0';

      /* The '+' flag is a GNU date extension that glibc/BSD strftime do not
         understand ('+': pad with zeros, and put '+' before the year once the
         requested width exceeds 4, the natural %Y width).  Emit it for the
         year conversion manually; otherwise strftime leaves '%+4Y' literal. */
      if (tlen >= 2 && token[tlen - 1] == 'Y' && strchr (token, '+') != NULL)
	{
	  const char *tp = token + 1;	/* skip '%' */
	  while (*tp == '-' || *tp == '_' || *tp == '0' || *tp == '^'
		 || *tp == '#' || *tp == '+')
	    tp++;
	  long width = 0;
	  while (isdigit ((unsigned char) *tp))
	    {
	      width = width * 10 + (*tp - '0');
	      tp++;
	    }
	  if (width <= 0)
	    width = 4;
	  long year = (long) tm.tm_year + 1900;
	  char yb[40];
	  if (year >= 0 && width > 4)
	    {
	      snprintf (yb, sizeof (yb), "%0*ld", (int) (width - 1), year);
	      if (out_len + 1 + strlen (yb) >= outsz)
		{
		  out[outsz - 1] = '\0';
		  return -1;
		}
	      out[out_len++] = '+';
	      memcpy (out + out_len, yb, strlen (yb));
	      out_len += strlen (yb);
	    }
	  else
	    {
	      snprintf (yb, sizeof (yb), "%0*ld", (int) width, year);
	      size_t yl = strlen (yb);
	      if (out_len + yl >= outsz)
		{
		  out[outsz - 1] = '\0';
		  return -1;
		}
	      memcpy (out + out_len, yb, yl);
	      out_len += yl;
	    }
	  continue;
	}

      size_t rem = outsz - out_len;
      out[out_len] = '\1';
      size_t written = strftime (out + out_len, rem, token, &tm);
      if (written == 0)
	{
	  if (out[out_len] != '\0')
	    {
	      out[outsz - 1] = '\0';
	      return -1;
	    }
	}
      out_len += written;
    }

  out[out_len] = '\0';
  return 0;
}

static int
is_valid_iso8601_fmt (const char *f)
{
  if (!f)
    return 0;
  return (!strcmp (f, "date") || !strcmp (f, "hours")
	  || !strcmp (f, "minutes") || !strcmp (f, "seconds")
	  || !strcmp (f, "ns"));
}

static int
is_valid_rfc3339_fmt (const char *f)
{
  if (!f)
    return 0;
  return (!strcmp (f, "date") || !strcmp (f, "seconds") || !strcmp (f, "ns"));
}

static int
is_mmdd_format (const char *s)
{
  if (!s)
    return 0;
  size_t len = strlen (s);
  if (len < 8 || len > 15)
    return 0;
  const char *dot = strchr (s, '.');
  const char *num_end = dot ? dot : s + len;
  for (const char *q = s; q < num_end; q++)
    {
      if (!isdigit ((unsigned char) *q))
	return 0;
    }
  if (dot)
    {
      if (strlen (dot + 1) != 2)
	return 0;
      if (!isdigit ((unsigned char) dot[1])
	  || !isdigit ((unsigned char) dot[2]))
	return 0;
    }
  return 1;
}

static void
set_legacy_format (const char *fmt, const char **legacy_fmt,
		   int *use_timestamp, char **iso_fmt, char **rfc3339_fmt,
		   int *rfc_email, char **custom_fmt)
{
  *legacy_fmt = fmt;
  *use_timestamp = 0;
  free (*iso_fmt);
  *iso_fmt = NULL;
  free (*rfc3339_fmt);
  *rfc3339_fmt = NULL;
  *rfc_email = 0;
  free (*custom_fmt);
  *custom_fmt = NULL;
}

struct format_options
{
  const char *iso_fmt;
  const char *rfc3339_fmt;
  int rfc_email;
  const char *custom_fmt;
  const char *legacy_fmt;
  int use_timestamp;
  int utc;
};

static int
format_datetime_output (const struct timespec *ts,
			const struct format_options *opts,
			char *out, size_t outsz)
{
  if (!ts || !opts || !out || outsz == 0)
    return -1;

  if (opts->iso_fmt)
    {
      const char *fmt = NULL;
      if (!strcmp (opts->iso_fmt, "date"))
	fmt = "%Y-%m-%d";
      else if (!strcmp (opts->iso_fmt, "hours"))
	fmt = "%Y-%m-%dT%H%:z";
      else if (!strcmp (opts->iso_fmt, "minutes"))
	fmt = "%Y-%m-%dT%H:%M%:z";
      else if (!strcmp (opts->iso_fmt, "seconds"))
	fmt = "%Y-%m-%dT%H:%M:%S%:z";
      else if (!strcmp (opts->iso_fmt, "ns"))
	fmt = "%Y-%m-%dT%H:%M:%S.%N%:z";
      if (fmt)
	return format_time (ts, fmt, opts->utc
			    || opts->use_timestamp, out, outsz);
      return -1;
    }
  else if (opts->rfc3339_fmt)
    {
      const char *fmt = NULL;
      if (!strcmp (opts->rfc3339_fmt, "date"))
	fmt = "%Y-%m-%d";
      else if (!strcmp (opts->rfc3339_fmt, "seconds"))
	fmt = "%Y-%m-%d %H:%M:%S%:z";
      else if (!strcmp (opts->rfc3339_fmt, "ns"))
	fmt = "%Y-%m-%d %H:%M:%S.%N%:z";
      if (fmt)
	return format_time (ts, fmt, opts->utc, out, outsz);
      return -1;
    }
  else if (opts->rfc_email)
    {
      return format_time (ts, "%a, %d %b %Y %H:%M:%S %z", opts->utc, out,
			  outsz);
    }
  else if (opts->custom_fmt)
    {
      return format_time (ts, opts->custom_fmt, opts->utc, out, outsz);
    }
  else if (opts->legacy_fmt)
    {
      int utc_flag = opts->utc || opts->use_timestamp;
      if (format_time (ts, opts->legacy_fmt, utc_flag, out, outsz) == 0)
	return 0;
      time_t sec = ts->tv_sec;
      struct tm ti;
      if (utc_flag)
	gmtime_r (&sec, &ti);
      else
	localtime_r (&sec, &ti);
      if (strftime (out, outsz, opts->legacy_fmt, &ti))
	return 0;
      return -1;
    }
  else
    {
      const char *def =
	opts->use_timestamp ? "%Y%m%d%H%M%SZ" : "%Y%m%d%H%M%S";
      return format_time (ts, def, opts->utc
			  || opts->use_timestamp, out, outsz);
    }
}

/* ---------------- main ---------------- */

int
main (int argc, char **argv)
{
#ifdef TIMESTAMP
  int use_timestamp = 1;
#else
  int use_timestamp = 0;
#endif
  const char *legacy_fmt = NULL;

  char *date_str = NULL;
  char *file_path = NULL;
  char *reference_path = NULL;
  char *iso_fmt = NULL;
  char *rfc3339_fmt = NULL;
  int rfc_email = 0;
  int resolution = 0;
  char *set_str = NULL;
  char *custom_fmt = NULL;
  int help_flag = 0;
  int version_flag = 0;
  int exit_code = 0;
  FILE *fp = NULL;

  char **filtered_argv = malloc ((argc + 1) * sizeof (char *));
  if (!filtered_argv)
    {
      perror ("malloc");
      return 1;
    }
  int filtered_argc = 1;
  filtered_argv[0] = argv[0];
  for (int i = 1; i < argc; i++)
    {
      const char *a = argv[i];
      if (a[0] == '+' && a[1] != '\0')
	{
	  free (custom_fmt);
	  custom_fmt = strdup (a + 1);
	  if (!custom_fmt)
	    {
	      perror ("strdup");
	      exit_code = 1;
	      goto cleanup;
	    }
	  continue;
	}
      const char *lf = match_format (a);
      if (lf)
	{
	  set_legacy_format (lf, &legacy_fmt, &use_timestamp,
			     &iso_fmt, &rfc3339_fmt, &rfc_email, &custom_fmt);
	  continue;
	}
      if (is_mmdd_format (a))
	{
	  free (set_str);
	  set_str = strdup (a);
	  continue;
	}
      filtered_argv[filtered_argc++] = argv[i];
    }
  filtered_argv[filtered_argc] = NULL;

  static struct option long_options[] = {
    {"date", required_argument, 0, 'd'},
    {"debug", no_argument, 0, 1000},
    {"file", required_argument, 0, 'f'},
    {"iso-8601", optional_argument, 0, 'I'},
    {"resolution", no_argument, 0, 1001},
    {"rfc-email", no_argument, 0, 'R'},
    {"rfc-3339", required_argument, 0, 1002},
    {"reference", required_argument, 0, 'r'},
    {"set", required_argument, 0, 's'},
    {"utc", no_argument, 0, 'u'},
    {"universal", no_argument, 0, 'u'},
    {"help", no_argument, 0, 'h'},
    {"version", no_argument, 0, 'V'},
    {"timestamp", no_argument, 0, 1005},
    {"human-readable", no_argument, 0, 1006},
    {"compact", no_argument, 0, 1007},
    {"calendar-date", no_argument, 0, 1008},
    {"calendar-date-base", no_argument, 0, 1009},
    {"ordinal-date", no_argument, 0, 1010},
    {"ordinal-date-base", no_argument, 0, 1011},
    {"week-date", no_argument, 0, 1012},
    {"week-date-basic", no_argument, 0, 1013},
    {0, 0, 0, 0}
  };
  opterr = 0;
  int c;
  int option_index = 0;
  optind = 1;
  while ((c =
	  getopt_long (filtered_argc, filtered_argv, "d:f:I::Rr:s:uVh",
		       long_options, &option_index)) != -1)
    {
      switch (c)
	{
	case 'd':
	  free (date_str);
	  date_str = strdup (optarg);
	  break;
	case 1000:
	  g_debug = 1;
	  break;
	case 'f':
	  free (file_path);
	  file_path = strdup (optarg);
	  break;
	case 'I':
	  {
	    const char *val = optarg ? optarg : "date";
	    if (!optarg && optind < filtered_argc
		&& filtered_argv[optind][0] != '-'
		&& filtered_argv[optind][0] != '+')
	      {
		if (is_valid_iso8601_fmt (filtered_argv[optind]))
		  {
		    val = filtered_argv[optind++];
		  }
	      }
	    if (optarg && *optarg == '=')
	      val = optarg + 1;
	    if (!is_valid_iso8601_fmt (val))
	      {
		fprintf (stderr,
			 "datetime: invalid argument '%s' for '--iso-8601'\n",
			 val);
		exit_code = 1;
		goto cleanup;
	      }
	    free (iso_fmt);
	    iso_fmt = strdup (val);
	  }
	  break;
	case 1001:
	  resolution = 1;
	  break;
	case 'R':
	  rfc_email = 1;
	  legacy_fmt = NULL;
	  break;
	case 1002:
	  {
	    const char *val = optarg;
	    if (!is_valid_rfc3339_fmt (val))
	      {
		fprintf (stderr,
			 "datetime: invalid argument '%s' for '--rfc-3339'\n",
			 val);
		exit_code = 1;
		goto cleanup;
	      }
	    free (rfc3339_fmt);
	    rfc3339_fmt = strdup (val);
	  }
	  break;
	case 'r':
	  free (reference_path);
	  reference_path = strdup (optarg);
	  break;
	case 's':
	  free (set_str);
	  set_str = strdup (optarg);
	  break;
	case 'u':
	  g_utc = 1;
	  break;
	case 'h':
	  help_flag = 1;
	  break;
	case 'V':
	  version_flag = 1;
	  break;
	case 1005:
	  legacy_fmt = "%Y%m%d%H%M%SZ";
	  use_timestamp = 1;
	  break;
	case 1006:
	  set_legacy_format ("%Y-%m-%d %H:%M:%S", &legacy_fmt, &use_timestamp,
			     &iso_fmt, &rfc3339_fmt, &rfc_email, &custom_fmt);
	  break;
	case 1007:
	  set_legacy_format ("%Y%m%dT%H%M%S", &legacy_fmt, &use_timestamp,
			     &iso_fmt, &rfc3339_fmt, &rfc_email, &custom_fmt);
	  break;
	case 1008:
	  set_legacy_format ("%Y-%m-%d", &legacy_fmt, &use_timestamp,
			     &iso_fmt, &rfc3339_fmt, &rfc_email, &custom_fmt);
	  break;
	case 1009:
	  set_legacy_format ("%Y%m%d", &legacy_fmt, &use_timestamp,
			     &iso_fmt, &rfc3339_fmt, &rfc_email, &custom_fmt);
	  break;
	case 1010:
	  set_legacy_format ("%Y-%j", &legacy_fmt, &use_timestamp,
			     &iso_fmt, &rfc3339_fmt, &rfc_email, &custom_fmt);
	  break;
	case 1011:
	  set_legacy_format ("%Y%j", &legacy_fmt, &use_timestamp,
			     &iso_fmt, &rfc3339_fmt, &rfc_email, &custom_fmt);
	  break;
	case 1012:
	  set_legacy_format ("%G-W%V-%u", &legacy_fmt, &use_timestamp,
			     &iso_fmt, &rfc3339_fmt, &rfc_email, &custom_fmt);
	  break;
	case 1013:
	  set_legacy_format ("%GW%V%u", &legacy_fmt, &use_timestamp,
			     &iso_fmt, &rfc3339_fmt, &rfc_email, &custom_fmt);
	  break;
	case '?':
	  {
	    const char *arg = filtered_argv[optind - 1];
	    const char *lf2 = match_format (arg);
	    if (lf2)
	      {
		set_legacy_format (lf2, &legacy_fmt, &use_timestamp,
				   &iso_fmt, &rfc3339_fmt, &rfc_email,
				   &custom_fmt);
		break;
	      }
	    if (arg[0] == '+')
	      {
		free (custom_fmt);
		custom_fmt = strdup (arg + 1);
		break;
	      }
	    fprintf (stderr, "datetime: unknown option '%s'\n", arg);
	    fprintf (stderr, "Try 'datetime --help' for more information.\n");
	    exit_code = 1;
	    goto cleanup;
	  }
	default:
	  break;
	}
    }

  for (int i = optind; i < filtered_argc; i++)
    {
      const char *a = filtered_argv[i];
      if (a[0] == '+' && a[1] != '\0')
	{
	  free (custom_fmt);
	  custom_fmt = strdup (a + 1);
	  continue;
	}
      const char *lf = match_format (a);
      if (lf)
	{
	  set_legacy_format (lf, &legacy_fmt, &use_timestamp,
			     &iso_fmt, &rfc3339_fmt, &rfc_email, &custom_fmt);
	  continue;
	}
      if (is_mmdd_format (a))
	{
	  free (set_str);
	  set_str = strdup (a);
	  continue;
	}
      fprintf (stderr, "datetime: unknown option '%s'\n", a);
      fprintf (stderr, "Try 'datetime --help' for more information.\n");
      exit_code = 1;
      goto cleanup;
    }

  free (filtered_argv);
  filtered_argv = NULL;

  if (help_flag)
    {
      print_usage (argv[0]);
      exit_code = 0;
      goto cleanup;
    }
  if (version_flag)
    {
      print_version ();
      exit_code = 0;
      goto cleanup;
    }

  int count_exclusive = 0;
  if (date_str)
    count_exclusive++;
  if (file_path)
    count_exclusive++;
  if (reference_path)
    count_exclusive++;
  if (resolution)
    count_exclusive++;
  if (count_exclusive > 1)
    {
      fprintf (stderr,
	       "datetime: the options to specify dates for printing are mutually exclusive\n");
      fprintf (stderr, "Try 'datetime --help' for more information.\n");
      exit_code = 1;
      goto cleanup;
    }

  if (resolution)
    {
      printf ("0.000000001\n");
      if (g_debug)
	fprintf (stderr,
		 "debug: resolution is 0.000000001 seconds (nanoseconds)\n");
      exit_code = 0;
      goto cleanup;
    }

  struct format_options fmt_opts = {
    .iso_fmt = iso_fmt,
    .rfc3339_fmt = rfc3339_fmt,
    .rfc_email = rfc_email,
    .custom_fmt = custom_fmt,
    .legacy_fmt = legacy_fmt,
    .use_timestamp = use_timestamp,
    .utc = g_utc
  };

  if (file_path)
    {
      if (!strcmp (file_path, "-"))
	fp = stdin;
      else
	{
	  fp = fopen (file_path, "r");
	  if (!fp)
	    {
	      fprintf (stderr, "datetime: %s: %s\n", file_path,
		       strerror (errno));
	      exit_code = 1;
	      goto cleanup;
	    }
	}
      char line[4096];
      int line_no = 0;
      while (fgets (line, sizeof (line), fp))
	{
	  line_no++;
	  size_t len = strlen (line);
	  if (len > 0 && line[len - 1] == '\n')
	    line[len - 1] = '\0';
	  if (line[0] == '\0')
	    continue;
	  char *p = line;
	  while (*p && isspace ((unsigned char) *p))
	    p++;
	  if (*p == '\0')
	    continue;
	  size_t pl = strlen (p);
	  while (pl > 0
		 && (p[pl - 1] == '\r'
		     || isspace ((unsigned char) p[pl - 1])))
	    {
	      p[pl - 1] = '\0';
	      pl--;
	    }
	  if (g_debug)
	    fprintf (stderr, "debug: file %s:%d: parsing '%s'\n", file_path,
		     line_no, p);
	  struct timespec ts;
	  if (!parse_date_string (p, &ts, g_utc, g_debug))
	    {
	      fprintf (stderr, "datetime: invalid date '%s'\n", p);
	      exit_code = 1;
	      continue;
	    }
	  char outbuf[8192] = { 0 };
	  if (format_datetime_output (&ts, &fmt_opts, outbuf, sizeof (outbuf))
	      != 0)
	    {
	      if (use_timestamp)
		snprintf (outbuf, sizeof (outbuf), "%ld", (long) ts.tv_sec);
	      else
		{
		  fprintf (stderr, "datetime: failed to format time\n");
		  exit_code = 1;
		  continue;
		}
	    }
	  char *env_var = "_currentdatetime";
#ifdef _WIN32
	  SetEnvironmentVariable (env_var, outbuf);
#else
	  setenv (env_var, outbuf, 1);
#endif
	  printf ("%s\n", outbuf);
	}
      goto cleanup;
    }

  struct timespec ts;
  int have_ts = 0;

  if (set_str)
    {
      if (is_mmdd_format (set_str))
	{
	  char buf[32];
	  strncpy (buf, set_str, sizeof (buf) - 1);
	  buf[sizeof (buf) - 1] = '\0';
	  const char *dot = strchr (set_str, '.');
	  const char *num_end = dot ? dot : set_str + strlen (set_str);
	  size_t len = (size_t) (num_end - set_str);
	  if (len == 8)
	    {
	      char mm[3] = { 0 }, dd[3] = { 0 }, hh[3] = { 0 }, mi[3] = { 0 };
	      memcpy (mm, buf, 2);
	      memcpy (dd, buf + 2, 2);
	      memcpy (hh, buf + 4, 2);
	      memcpy (mi, buf + 6, 2);
	      time_t now = time (NULL);
	      struct tm tm;
	      if (g_utc)
		gmtime_r (&now, &tm);
	      else
		localtime_r (&now, &tm);
	      int year = tm.tm_year + 1900;
	      memset (&tm, 0, sizeof (tm));
	      tm.tm_mon = atoi (mm) - 1;
	      tm.tm_mday = atoi (dd);
	      tm.tm_hour = atoi (hh);
	      tm.tm_min = atoi (mi);
	      tm.tm_sec = dot ? atoi (dot + 1) : 0;
	      tm.tm_year = year - 1900;
	      tm.tm_isdst = -1;
	      time_t t = g_utc ? timegm (&tm) : mktime (&tm);
	      ts.tv_sec = t;
	      ts.tv_nsec = 0;
	      have_ts = 1;
	      debug_log ("parsed MMDDhhmm '%s' -> %s", set_str, ctime (&t));
	    }
	}
      if (!have_ts)
	{
	  if (!parse_date_string (set_str, &ts, g_utc, g_debug))
	    {
	      fprintf (stderr, "datetime: invalid date '%s'\n", set_str);
	      exit_code = 1;
	      goto cleanup;
	    }
	  have_ts = 1;
	}
#ifdef __linux__
      if (have_ts)
	{
	  debug_log ("attempting to set system time to %ld.%09ld",
		     (long) ts.tv_sec, (long) ts.tv_nsec);
	  if (clock_settime (CLOCK_REALTIME, &ts) != 0)
	    {
	      if (g_debug)
		fprintf (stderr,
			 "debug: clock_settime failed: %s (need root)\n",
			 strerror (errno));
	      else if (errno == EPERM)
		{
		  fprintf (stderr,
			   "datetime: cannot set date: Operation not permitted (need root)\n");
		}
	      else
		{
		  fprintf (stderr, "datetime: cannot set date: %s\n",
			   strerror (errno));
		}
	    }
	  else
	    {
	      if (g_debug)
		fprintf (stderr, "debug: system time set successfully\n");
	    }
	}
#else
      if (g_debug)
	fprintf (stderr,
		 "debug: --set not supported on this platform, would set to %ld\n",
		 (long) ts.tv_sec);
#endif
    }
  else if (date_str)
    {
      if (!parse_date_string (date_str, &ts, g_utc, g_debug))
	{
	  fprintf (stderr, "datetime: invalid date '%s'\n", date_str);
	  exit_code = 1;
	  goto cleanup;
	}
      have_ts = 1;
    }
  else if (reference_path)
    {
      struct stat st;
      if (stat (reference_path, &st) != 0)
	{
	  fprintf (stderr, "datetime: %s: %s\n", reference_path,
		   strerror (errno));
	  exit_code = 1;
	  goto cleanup;
	}
      ts.tv_sec = st.st_mtime;
#if defined(__linux__) || defined(__APPLE__) || defined(__FreeBSD__) || defined(__NetBSD__)
#if defined(st_mtim)
      ts.tv_nsec = st.st_mtim.tv_nsec;
#elif defined(st_mtimespec)
      ts.tv_nsec = st.st_mtimespec.tv_nsec;
#else
      ts.tv_nsec = 0;
#endif
#else
      ts.tv_nsec = 0;
#endif
      have_ts = 1;
      debug_log ("reference file '%s' mtime %ld", reference_path,
		 (long) ts.tv_sec);
    }
  else
    {
      get_current_timespec (&ts);
      have_ts = 1;
    }

  char outbuf[8192] = { 0 };
  if (format_datetime_output (&ts, &fmt_opts, outbuf, sizeof (outbuf)) != 0)
    {
      fprintf (stderr, "datetime: failed to format time\n");
      exit_code = 1;
      goto cleanup;
    }

  if (g_debug)
    {
      fprintf (stderr, "debug: output format '%s' -> '%s'\n",
	       iso_fmt ? iso_fmt : rfc3339_fmt ? rfc3339_fmt : custom_fmt ?
	       custom_fmt : legacy_fmt ? legacy_fmt : "default", outbuf);
      if (date_str)
	fprintf (stderr, "debug: input date '%s' parsed as %ld.%09ld\n",
		 date_str, (long) ts.tv_sec, (long) ts.tv_nsec);
      if (reference_path)
	fprintf (stderr, "debug: reference file '%s'\n", reference_path);
    }

  char *env_var = "_currentdatetime";
#ifdef _WIN32
  SetEnvironmentVariable (env_var, outbuf);
#else
  setenv (env_var, outbuf, 1);
#endif

  printf ("%s\n", outbuf);
  exit_code = 0;

cleanup:
  if (fp && fp != stdin)
    fclose (fp);
  free (filtered_argv);
  free (date_str);
  free (file_path);
  free (reference_path);
  free (iso_fmt);
  free (rfc3339_fmt);
  free (set_str);
  free (custom_fmt);
  return exit_code;
}
