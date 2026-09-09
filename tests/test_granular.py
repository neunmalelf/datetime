#!/usr/bin/env python3
"""Granular Python tests for datetime - mirrors bash suite but with more checks
Version: 1.0.20260909101500Z
"""
import subprocess, os, re, sys, tempfile, pathlib, time, stat, unittest

REPO = pathlib.Path(__file__).parent.parent
BIN = REPO / "datetime"
if not BIN.exists():
    BIN = REPO / "timestamp"

def run(*args, input_text=None, env=None):
    # Use LC_ALL=C for deterministic? But we test local; for UTC tests we pass -u
    result = subprocess.run([str(BIN)] + list(args),
                            input=input_text.encode() if input_text else None,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            env=env)
    return result.returncode, result.stdout.decode(errors="ignore"), result.stderr.decode(errors="ignore")

class TestDatetimeOptions(unittest.TestCase):
    def test_default(self):
        rc, out, err = run()
        self.assertEqual(rc, 0)
        self.assertRegex(out.strip(), r"^[0-9]{14}$")
    def test_help_no_esc(self):
        rc, out, err = run("--help")
        self.assertEqual(rc, 0)
        self.assertNotIn("\x1b", out)
        self.assertIn("Usage:", out)
    def test_version(self):
        rc, out, err = run("--version")
        self.assertEqual(rc, 0)
        self.assertIn("datetime 2.", out)
    def test_legacy(self):
        for args, pattern in [
            (["-hr"], r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$"),
            (["-c"], r"^\d{8}T\d{6}$"),
            (["-cd"], r"^\d{4}-\d{2}-\d{2}$"),
            (["-cdb"], r"^\d{8}$"),
            (["-od"], r"^\d{4}-\d{3}$"),
            (["-odb"], r"^\d{7}$"),
            (["-wd"], r"^\d{4}-W\d{2}-[1-7]$"),
            (["-wdb"], r"^\d{4}W\d{2}[1-7]$"),
            (["--timestamp"], r"^\d{14}Z$"),
        ]:
            with self.subTest(args=args):
                rc, out, _ = run(*args)
                self.assertEqual(rc, 0)
                self.assertRegex(out.strip(), pattern)
    def test_utc(self):
        rc, out, _ = run("-u", '+%Z')
        self.assertIn(out.strip(), ["UTC", "GMT"])
    def test_format_epoch(self):
        rc, out, _ = run("-u", "-d", "@0", '+%Y-%m-%d %H:%M:%S')
        self.assertEqual(out.strip(), "1970-01-01 00:00:00")
        rc, out, _ = run("-u", "-d", "@2147483647", '+%Y-%m-%d %H:%M:%S')
        self.assertEqual(out.strip(), "2038-01-19 03:14:07")
        rc, out, _ = run("-u", "-d", "@-1", '+%Y-%m-%d %H:%M:%S')
        self.assertEqual(out.strip(), "1969-12-31 23:59:59")
        rc, out, _ = run("-u", "-d", "@-0.5", '+%Y-%m-%d %H:%M:%S.%N')
        self.assertEqual(out.strip(), "1969-12-31 23:59:59.500000000")
    def test_format_sequences(self):
        checks = [
            (["-d", "2020-01-02", "+%A"], "Thursday"),
            (["-d", "2020-01-02", "+%a"], "Thu"),
            (["-d", "2020-01-02", "+%B"], "January"),
            (["-d", "2020-01-02", "+%F"], "2020-01-02"),
            (["-d", "2020-01-02", "+%q"], "1"),
            (["-d", "2020-05-15", "+%q"], "2"),
        ]
        for args, expected in checks:
            rc, out, _ = run(*args)
            self.assertEqual(rc, 0)
            self.assertIn(expected, out)
    def test_iso(self):
        for fmt, pat in [
            ("date", r"^\d{4}-\d{2}-\d{2}$"),
            ("hours", r"^\d{4}-\d{2}-\d{2}T\d{2}[+-]\d{2}:\d{2}$"),
            ("minutes", r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}[+-]\d{2}:\d{2}$"),
            ("seconds", r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$"),
            ("ns", r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{9}[+-]\d{2}:\d{2}$"),
        ]:
            rc, out, _ = run(f"--iso-8601={fmt}")
            self.assertEqual(rc, 0, fmt)
            self.assertRegex(out.strip(), pat)
        rc, out, _ = run("-I")
        self.assertRegex(out.strip(), r"^\d{4}-\d{2}-\d{2}$")
    def test_rfc3339(self):
        for fmt, pat in [
            ("date", r"^\d{4}-\d{2}-\d{2}$"),
            ("seconds", r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$"),
            ("ns", r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{9}[+-]\d{2}:\d{2}$"),
        ]:
            rc, out, _ = run(f"--rfc-3339={fmt}")
            self.assertRegex(out.strip(), pat)
    def test_rfc_email(self):
        rc, out, _ = run("-R")
        self.assertRegex(out.strip(), r"^[A-Z][a-z]{2}, \d{2} [A-Z][a-z]{2} \d{4} \d{2}:\d{2}:\d{2} [+-]\d{4}$")
    def test_resolution(self):
        rc, out, _ = run("--resolution")
        self.assertEqual(out.strip(), "0.000000001")
    def test_date_parsing(self):
        rc, out, _ = run("-u", "-d", "2020-01-02 03:04:05", "+%F %T")
        self.assertEqual(out.strip(), "2020-01-02 03:04:05")
        rc, out, _ = run("-d", "today", "+%F")
        self.assertRegex(out.strip(), r"^\d{4}-\d{2}-\d{2}$")
        rc, out, _ = run("-d", "yesterday", "+%F")
        self.assertRegex(out.strip(), r"^\d{4}-\d{2}-\d{2}$")
    def test_debug(self):
        rc, out, err = run("--debug", "-d", "2020-01-02", "+%F")
        self.assertEqual(rc, 0)
        self.assertIn("debug:", err)
        self.assertIn("parsed", err)
    def test_file(self):
        with tempfile.NamedTemporaryFile(mode="w", delete=False) as tf:
            tf.write("2020-01-02\n2020-01-03\n")
            tf.flush()
            fname = tf.name
        try:
            rc, out, _ = run("-f", fname, "+%F")
            lines = out.strip().splitlines()
            self.assertEqual(lines[0], "2020-01-02")
            self.assertEqual(lines[1], "2020-01-03")
            # stdin
            rc, out, _ = run("-f", "-", "+%F", input_text="2020-01-02\n")
            self.assertIn("2020-01-02", out)
        finally:
            os.unlink(fname)
    def test_reference(self):
        with tempfile.NamedTemporaryFile(delete=False) as tf:
            fname = tf.name
        try:
            os.utime(fname, (1577934245, 1577934245)) # 2020-01-02 03:04:05?
            # Use touch -d for precise? set via python
            rc, out, _ = run("-r", fname, "+%Y-%m-%d")
            self.assertEqual(rc, 0)
            self.assertRegex(out.strip(), r"^\d{4}-\d{2}-\d{2}$")
        finally:
            os.unlink(fname)
    def test_set_warn(self):
        rc, out, err = run("--set", "2020-01-02")
        self.assertIn("cannot set date", err)
        self.assertEqual(rc, 0)  # still prints time
    def test_mutual_exclusive(self):
        with tempfile.NamedTemporaryFile(mode="w", delete=False) as tf:
            tf.write("2020-01-02\n")
            fname = tf.name
        try:
            rc, _, _ = run("--date", "now", "--file", fname)
            self.assertNotEqual(rc, 0)
            rc, _, _ = run("-d", "now", "-r", fname)
            self.assertNotEqual(rc, 0)
        finally:
            os.unlink(fname)
    def test_unknown(self):
        rc, _, _ = run("--unknown-option")
        self.assertNotEqual(rc, 0)
    def test_security_shell_escape(self):
        # Ensure no file created via injection
        pwn = "/tmp/pwned_test123"
        if os.path.exists(pwn):
            os.unlink(pwn)
        rc, out, err = run("-d", "'; touch /tmp/pwned_test123; echo '")
        self.assertFalse(os.path.exists(pwn))
    def test_long_input(self):
        long_str = "A"*5000
        rc, out, err = run("-d", long_str)
        # should fail but not crash
        self.assertNotEqual(rc, 0)
    def test_nanoseconds(self):
        rc, out, _ = run("-u", "-d", "@0", "+%N")
        self.assertEqual(out.strip(), "000000000")
        rc, out, _ = run("-u", "-d", "@123.456789123", "+%s.%N")
        # our parse of @ with fractional?
        # @123.456789123 should give 123 sec + fractions
        # Check via -d
        rc, out, _ = run("-u", "-d", "@1234567890.123456789", "+%s.%N")
        self.assertEqual(out.strip(), "1234567890.123456789")
    def test_tz_prefix(self):
        rc, out, _ = run("--date", 'TZ="UTC" 2020-01-02 03:04:05', "-u", "+%H:%M:%S")
        self.assertEqual(out.strip(), "03:04:05")
        rc, out, _ = run("--date", 'TZ="America/Los_Angeles" 09:00 next Fri', "+%u")
        self.assertEqual(out.strip(), "5")
    def test_format_flags(self):
        self.assertEqual(run("-d", "2020-01-02", "+%_d")[1].rstrip("\n"), " 2")
        self.assertEqual(run("-d", "2020-01-02", "+%5d")[1].strip(), "00002")
        self.assertEqual(run("-d", "2020-01-02", "+%-d")[1].strip(), "2")
        # '+' flag (GNU extension, manually handled for %Y)
        self.assertEqual(run("-u", "-d", "@0", "+%+4Y")[1].strip(), "1970")
        self.assertEqual(run("-u", "-d", "@0", "+%+5Y")[1].strip(), "+1970")
        self.assertEqual(run("-u", "-d", "@0", "+%+6Y")[1].strip(), "+01970")
    def test_percent_escapes(self):
        rc, out, _ = run("+%%")
        self.assertEqual(out.strip(), "%")

if __name__ == "__main__":
    unittest.main(verbosity=2)
