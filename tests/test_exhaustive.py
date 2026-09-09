#!/usr/bin/env python3
"""Exhaustive combinatorial matrix for datetime - covers every option, alias, FMT, mutual exclusivity, FORMAT
Version: 1.0.20260909104500Z
Generated via itertools.product parametrization
"""
import subprocess, os, re, sys, tempfile, pathlib, itertools, unittest

REPO = pathlib.Path(__file__).parent.parent
BIN = REPO / "datetime"

def run(*args, input_text=None):
    result = subprocess.run([str(BIN)] + list(args),
                            input=input_text.encode() if input_text else None,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return result.returncode, result.stdout.decode(errors="ignore"), result.stderr.decode(errors="ignore")

class TestExhaustive(unittest.TestCase):
    def test_legacy_singletons_exhaustive(self):
        opts = ["-hr","--human-readable","-c","--compact","iso-basic","-cd","--calendar-date","-cdb","--calendar-date-base","-od","--ordinal-date","-odb","--ordinal-date-base","-wd","--week-date","-wdb","--week-date-basic","--timestamp"]
        for o in opts:
            with self.subTest(opt=o):
                rc, out, err = run(o)
                self.assertEqual(rc, 0, f"legacy {o} should succeed")

    def test_iso_variants_exhaustive(self):
        for fmt in ["date","hours","minutes","seconds","ns"]:
            with self.subTest(fmt=fmt, style="long"):
                rc, out, _ = run(f"--iso-8601={fmt}")
                self.assertEqual(rc, 0)
                # long form with = is valid
            with self.subTest(fmt=fmt, style="short"):
                # short -I<fmt>
                rc, out, _ = run(f"-I{fmt}")
                self.assertEqual(rc, 0)
        # bare
        for bare in ["-I","--iso-8601"]:
            with self.subTest(bare=bare):
                rc, out, _ = run(bare)
                self.assertEqual(rc, 0)
        # invalid should fail
        rc, _, _ = run("--iso-8601=invalid")
        self.assertNotEqual(rc, 0)
        rc, _, _ = run("-Iinvalid")
        self.assertNotEqual(rc, 0)

    def test_rfc3339_variants_exhaustive(self):
        for fmt in ["date","seconds","ns"]:
            with self.subTest(fmt=fmt):
                rc, out, _ = run(f"--rfc-3339={fmt}")
                self.assertEqual(rc, 0)
                rc, out, _ = run("--rfc-3339", fmt)
                self.assertEqual(rc, 0)
        rc, _, _ = run("--rfc-3339=invalid")
        self.assertNotEqual(rc, 0)
        rc, _, _ = run("--rfc-3339")
        self.assertNotEqual(rc, 0)

    def test_rfc_email_exhaustive(self):
        for opt in ["-R","--rfc-email"]:
            with self.subTest(opt=opt):
                rc, out, _ = run(opt)
                self.assertEqual(rc, 0)
                self.assertRegex(out.strip(), r"^[A-Z][a-z]{2},")

    def test_simple_flags(self):
        for opt in ["--resolution","--help","-h","--version","-V"]:
            with self.subTest(opt=opt):
                rc, _, _ = run(opt)
                self.assertEqual(rc, 0)

    def test_utc_aliases_exhaustive(self):
        for a in ["-u","--utc","--universal"]:
            with self.subTest(alias=a):
                rc, out, _ = run(a, '+%Z')
                self.assertEqual(rc, 0)
                self.assertIn(out.strip(), ["UTC","GMT","CEST","CET","EDT","EST",""])
                # compare alias equivalence
                rc2, out2, _ = run("-u", '+%Z')
                rc3, out3, _ = run(a, '+%Z')
                # all should produce same style (UTC vs local) but -u always UTC; aliases should match -u
                self.assertEqual(out2, out3)

    def test_date_sources_exhaustive(self):
        with tempfile.NamedTemporaryFile(mode="w", delete=False) as tf:
            tf.write("2020-01-02\n2020-01-03\n")
            fname = tf.name
        ref = fname + "_ref"
        pathlib.Path(ref).touch()
        try:
            os.utime(ref, (1577934245,1577934245))
            cases = [
                (["-d","@0"], True),
                (["--date=@0"], True),
                (["-d","2020-01-02"], True),
                (["-d","now"], True),
                (["-d","today"], True),
                (["-d","yesterday"], True),
                (["-d","tomorrow"], True),
                (["-d",'TZ="UTC" 2020-01-02'], True),
                (["-d","@1234567890.123456789"], True),
                (["-f",fname], True),
                (["--file="+fname], True),
                (["-r",ref], True),
                (["--reference="+ref], True),
                (["-s","2020-01-02"], True), # warns but rc 0
                (["--set=2020-01-02"], True),
                (["01010000"], True), # MMDDhhmm
            ]
            for args, should_succeed in cases:
                with self.subTest(args=args):
                    rc, out, err = run(*args)
                    if should_succeed:
                        self.assertEqual(rc, 0, f"{args} should succeed stderr={err}")
                    else:
                        self.assertNotEqual(rc, 0)
            # stdin
            rc, out, _ = run("-f","-", "+%F", input_text="2020-01-02\n")
            self.assertEqual(rc, 0)
            self.assertIn("2020-01-02", out)
        finally:
            os.unlink(fname)
            os.unlink(ref)

    def test_mutual_exclusivity_matrix(self):
        # all 6 pairs among --date, --file, --reference, --resolution must fail
        with tempfile.NamedTemporaryFile(mode="w", delete=False) as tf:
            tf.write("2020-01-02\n")
            fname = tf.name
        ref = fname + "ref"
        pathlib.Path(ref).touch()
        try:
            bases = [
                ["-d","now"],
                ["-f",fname],
                ["-r",ref],
                ["--resolution"],
            ]
            for a,b in itertools.combinations(bases,2):
                with self.subTest(a=a,b=b):
                    rc, _, err = run(*a, *b)
                    self.assertNotEqual(rc, 0, f"pair {a}+{b} should be mutual exclusive, got rc={rc}")
                    self.assertIn("mutually exclusive", err.lower())
            # triples
            for combo in itertools.combinations(bases,3):
                flat = [x for c in combo for x in c]
                with self.subTest(triple=combo):
                    rc, _, _ = run(*flat)
                    self.assertNotEqual(rc, 0)
            # quad
            flat = bases[0]+bases[1]+bases[2]+bases[3]
            rc, _, _ = run(*flat)
            self.assertNotEqual(rc, 0)
        finally:
            os.unlink(fname)
            os.unlink(ref)

    def test_compatible_matrix(self):
        with tempfile.NamedTemporaryFile(mode="w", delete=False) as tf:
            tf.write("2020-01-02\n")
            fname = tf.name
        ref = fname+"ref"
        pathlib.Path(ref).touch()
        try:
            # -u compatible with all
            for base in [["-d","@0"],["-f",fname],["-r",ref],["--resolution"],["-I"],["-R"],["--rfc-3339=seconds"],["-c"]]:
                with self.subTest(u=True, base=base):
                    rc, _, _ = run("-u", *base)
                    self.assertEqual(rc, 0)
            # --debug compatible
            for base in [["-d","@0"],["-f",fname],["-r",ref],["-I"],["-R"]]:
                with self.subTest(debug=True, base=base):
                    rc, _, _ = run("--debug", *base)
                    self.assertEqual(rc, 0)
            # +FORMAT with sources
            for src in [[],["-d","@0"],["-d","2020-01-02"],["-r",ref]]:
                with self.subTest(src=src, fmt="%F"):
                    rc, _, _ = run(*src, "+%F")
                    self.assertEqual(rc, 0)
        finally:
            os.unlink(fname)
            os.unlink(ref)

    def test_format_sequences_exhaustive(self):
        seqs = ["%%","%a","%A","%b","%B","%c","%C","%d","%D","%e","%F","%g","%G","%h","%H","%I","%j","%k","%l","%m","%M","%n","%N","%p","%P","%q","%r","%R","%s","%S","%t","%T","%u","%U","%V","%w","%W","%x","%X","%y","%Y","%z","%:z","%::z","%:::z","%Z"]
        for s in seqs:
            with self.subTest(seq=s, utc=False):
                rc, out, _ = run("-d","@0", "+"+s)
                self.assertEqual(rc, 0, f"seq {s} without -u failed")
            with self.subTest(seq=s, utc=True):
                rc, out, _ = run("-u","-d","@0", "+"+s)
                self.assertEqual(rc, 0, f"seq {s} with -u failed")
        # specific value checks
        rc, out, _ = run("-u","-d","@0", "+%Y%%m")
        self.assertEqual(out.strip(), "1970%m")
        rc, out, _ = run("-u","-d","@0", "+%s")
        self.assertEqual(out.strip(), "0")
        rc, out, _ = run("-u","-d","@0", "+%N")
        self.assertRegex(out.strip(), r"^\d{9}$")

    def test_format_flags_matrix(self):
        # flags: - _ 0 ^ # plus + for %Y, plus width, plus E/O
        base_seq = "%d"  # numeric
        for flag in ["-", "_", "0", "^", "#"]:
            with self.subTest(flag=flag):
                rc, _, _ = run("-d","2020-01-02", "+"+f"%{flag}d")
                self.assertEqual(rc, 0)
        for flag in ["-", "_", "0", "^", "#"]:
            with self.subTest(flag_text=flag):
                rc, _, _ = run("-d","2020-01-02", "+"+f"%{flag}A")
                self.assertEqual(rc, 0)
        rc, _, _ = run("-d","2020-01-02", "+%+4Y")
        self.assertEqual(rc, 0)
        for w in [1,2,5,10]:
            with self.subTest(width=w):
                rc, _, _ = run("-d","2020-01-02", f"+%{w}d")
                self.assertEqual(rc, 0)
        for mod in ["E","O"]:
            with self.subTest(mod=mod):
                rc, _, _ = run("-d","2020-01-02", f"+%{mod}c")
                self.assertEqual(rc, 0)
        # combined
        for fmt in ["%-5d","%_10Y","%05d","%^_10A","%+4Y","%E c".replace(" ",""),"%OY"]:
            with self.subTest(combo=fmt):
                rc, _, _ = run("-d","2020-01-02", "+"+fmt)
                self.assertEqual(rc, 0)

    def test_format_with_date_and_utc_matrix(self):
        for darg in ["@0","2020-01-02","2020-01-02 03:04:05","yesterday","tomorrow",'TZ="UTC" 2020-01-02']:
            for u in [[], ["-u"]]:
                with self.subTest(darg=darg, u=u):
                    rc, out, _ = run(*u, "-d", darg, "+%F")
                    self.assertEqual(rc, 0)

    def test_file_matrix(self):
        with tempfile.NamedTemporaryFile(mode="w", delete=False) as tf:
            tf.write("2020-01-02\n2020-01-03\n")
            fname = tf.name
        try:
            for u in [[], ["-u"]]:
                for dbg in [[], ["--debug"]]:
                    with self.subTest(u=u, dbg=dbg):
                        rc, out, _ = run(*u, *dbg, "-f", fname, "+%F")
                        self.assertEqual(rc, 0)
                        self.assertIn("2020-01-02", out)
        finally:
            os.unlink(fname)

    def test_error_exhaustive(self):
        # missing arg
        for opt in ["-d","--date","-f","--file","-r","--reference","-s","--set","--rfc-3339"]:
            with self.subTest(opt=opt):
                rc, _, _ = run(opt)
                self.assertNotEqual(rc, 0)
        # invalid
        cases = [
            (["--iso-8601=invalid"],),
            (["-Iinvalid"],),
            (["--rfc-3339=invalid"],),
            (["--rfc-3339"],),
            (["-d","not-a-date"],),
            (["-f","/nonexistent_xyz"],),
            (["-r","/nonexistent_xyz"],),
            (["-Z"],),
            (["--unknown"],),
        ]
        for args, in cases:
            with self.subTest(args=args):
                rc, _, _ = run(*args)
                self.assertNotEqual(rc, 0)

    def test_edge_security(self):
        # long file
        with tempfile.NamedTemporaryFile(mode="w", delete=False) as tf:
            tf.write("A"*5000+"\n")
            fname = tf.name
        try:
            rc, _, _ = run("-f", fname)
            # should not crash, may succeed or fail but not segfault (rc defined)
            self.assertIn(rc, [0,1])
        finally:
            os.unlink(fname)
        # injection
        pwn = "/tmp/pwned_exhaustive123"
        if os.path.exists(pwn):
            os.unlink(pwn)
        rc, _, _ = run("-d", "'; touch /tmp/pwned_exhaustive123; echo '")
        self.assertFalse(os.path.exists(pwn))
        # long format
        longfmt = "%Y" * 500
        rc, _, _ = run("-d","@0","-u", "+"+longfmt)
        self.assertIn(rc, [0,1])  # should not crash
        # many specifiers
        fmt = "%Y" * 200
        rc, _, _ = run("-d","@0","-u", "+"+fmt)
        self.assertEqual(rc, 0)

    def test_help_version(self):
        for opt in ["--help","-h"]:
            rc, out, _ = run(opt)
            self.assertEqual(rc, 0)
            self.assertNotIn("\x1b", out)
            self.assertIn("Usage:", out)
        for opt in ["--version","-V"]:
            rc, out, _ = run(opt)
            self.assertEqual(rc, 0)
            self.assertIn("Timezone:", out)

if __name__ == "__main__":
    unittest.main(verbosity=2)
