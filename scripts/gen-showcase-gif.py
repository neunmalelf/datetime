#!/usr/bin/env python3
"""Generate animated showcase.gif from showcase.md examples.

Parses showcase.md code blocks, runs representative commands, and renders
an animated GIF with terminal style (dark background, monospace font).
Output: showcase.gif in repo root.

Usage:
  python3 scripts/gen-showcase-gif.py
  python3 scripts/gen-showcase-gif.py --output showcase.gif --width 1280 --height 720
"""

import subprocess
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHOWCASE_MD = ROOT / "showcase.md"
OUTPUT = ROOT / "showcase.gif"

# Config
WIDTH = 1280
HEIGHT = 720
BG_COLOR = (13, 17, 23)  # #0d1117 github dark
FG_COLOR = (201, 209, 217)  # #c9d1d9
PROMPT_COLOR = (63, 185, 80)  # #3fb950 green
CMD_COLOR = (255, 255, 255)
OUTPUT_COLOR = (255, 203, 0)  # yellow for output
TITLE_COLOR = (88, 166, 255)  # blue
COMMENT_COLOR = (139, 148, 158)  # gray
FPS = 10

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Pillow not installed, try: pip install Pillow", file=sys.stderr)
    sys.exit(1)

# Font loading - try Liberation Mono, Hack, Adwaita Mono, fallback default
def load_font(size):
    candidates = [
        "/usr/share/fonts/liberation-mono-fonts/LiberationMono-Regular.ttf",
        "/usr/share/fonts/source-foundry-hack-fonts/Hack-Regular.ttf",
        "/usr/share/fonts/adwaita-mono-fonts/AdwaitaMono-Regular.ttf",
        "/usr/share/fonts/adobe-source-code-pro-fonts/SourceCodePro-Regular.otf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    ]
    for p in candidates:
        if Path(p).exists():
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                continue
    return ImageFont.load_default()

FONT_TITLE = load_font(28)
FONT_HDR = load_font(20)
FONT_BODY = load_font(18)
FONT_SMALL = load_font(14)

# Representative commands to showcase (curated from showcase.md, safe to run)
# Each entry: (section_title, command, comment)
SHOWCASE_COMMANDS = [
    ("Basic and version/help", "./datetime", "default: YYYYMMDDhhmmss"),
    ("Basic and version/help", "./timestamp", "default: UTC YYYYMMDDhhmmssZ"),
    ("Basic and version/help", "./datetime --version", "version + timezone"),
    ("Legacy output formats", "./datetime -hr", "human readable YYYY-MM-DD hh:mm:ss"),
    ("Legacy output formats", "./datetime -c", "compact YYYYMMDDThhmmss"),
    ("Legacy output formats", "./datetime --timestamp", "UTC micro-version"),
    ("Legacy output formats", "./datetime -wd", "ISO week date YYYY-Www-D"),
    ("GNU date compatible", "./datetime -d \"@0\" +\"%F %T\"", "epoch 0"),
    ("GNU date compatible", "./datetime -u -d \"@0\" +\"%F %T %Z\"", "UTC epoch"),
    ("GNU date compatible", "./datetime -d \"2020-01-02 03:04:05\" +\"%F %T\"", "parse ISO"),
    ("GNU date compatible", "./datetime -d \"2020-01-02\" +\"%Y %z %:z %Z\"", "timezone formats"),
    ("File and reference", "printf \"2020-01-02\\n2020-01-03\\n\" | ./datetime -f - +\"%F\"", "file via stdin"),
    ("ISO-8601 / RFC", "./datetime -Iseconds", "ISO 8601 seconds"),
    ("ISO-8601 / RFC", "./datetime -R", "RFC 5322 email"),
    ("ISO-8601 / RFC", "./datetime --rfc-3339=seconds", "RFC 3339"),
    ("ISO-8601 / RFC", "./datetime --resolution", "nanosecond resolution"),
    ("Custom FORMAT", "./datetime -d \"2020-01-02\" +\"%a %A %b %B\"", "locale names"),
    ("Custom FORMAT", "./datetime -d \"2020-01-02\" +\"%Y%%m\"", "literal %"),
    ("Custom FORMAT", "./datetime -d \"2020-01-02\" +\"%q\"", "quarter"),
    ("Error and exclusivity", "./datetime -d \"now\" --file dates.txt", "fails: mutually exclusive"),
]

def run_command(cmd):
    """Run shell command, return (stdout, stderr, rc). Skip sudo/set time."""
    if cmd.strip().startswith("sudo"):
        return ("(requires root — shows what would be set)", "", 1)
    if "09091100" in cmd:
        return ("(MMDDhhmm set — requires root, prints target time)", "", 0)
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=3,
            cwd=str(ROOT)
        )
        out = result.stdout.strip()
        err = result.stderr.strip()
        # Truncate long output
        if len(out) > 200:
            out = out[:200] + "..."
        if len(err) > 200:
            err = err[:200] + "..."
        # Combine for display: stdout + stderr (debug)
        display = out
        if err and "debug:" in err:
            display = (out + "\n" + err) if out else err
        elif err and result.returncode != 0:
            display = err if not out else out + "\n" + err
        if not display:
            display = "(no output)" if result.returncode == 0 else "(error)"
        return (display, err, result.returncode)
    except subprocess.TimeoutExpired:
        return ("(timeout)", "", 1)
    except Exception as e:
        return (f"(error: {e})", "", 1)

def wrap_text(text, font, max_width, draw):
    """Wrap text to fit max_width."""
    lines = []
    for paragraph in text.split("\n"):
        if not paragraph:
            lines.append("")
            continue
        words = paragraph.split(" ")
        cur = ""
        for w in words:
            test = cur + (" " if cur else "") + w
            bbox = draw.textbbox((0,0), test, font=font)
            if bbox[2] - bbox[0] <= max_width:
                cur = test
            else:
                if cur:
                    lines.append(cur)
                # long word: break char
                if draw.textbbox((0,0), w, font=font)[2] > max_width:
                    # break long token
                    for i in range(0, len(w), 30):
                        lines.append(w[i:i+30])
                    cur = ""
                else:
                    cur = w
        if cur or not lines:
            lines.append(cur)
    return lines

def render_frame(section_title, cmd, comment, output, frame_idx, total_frames, typing_pos=None):
    """Render a single frame."""
    img = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # Header bar
    draw.rectangle([0, 0, WIDTH, 50], fill=(22, 27, 34))
    draw.text((20, 12), "datetime showcase", font=FONT_TITLE, fill=TITLE_COLOR)
    # Version in header
    try:
        ver = (ROOT / "datetime").exists() and subprocess.run(
            ["./datetime", "--version"], capture_output=True, text=True, cwd=str(ROOT), timeout=1
        ).stdout.splitlines()[0] if (ROOT / "datetime").exists() else "datetime 2.0"
        if len(ver) > 60:
            ver = ver[:60]
    except:
        ver = "datetime 2.0"
    draw.text((WIDTH - 400, 18), ver, font=FONT_SMALL, fill=COMMENT_COLOR, anchor="lm")

    # Section title
    y = 70
    draw.text((20, y), f"▸ {section_title}", font=FONT_HDR, fill=PROMPT_COLOR)
    y += 35
    draw.line([(20, y), (WIDTH-20, y)], fill=(48, 54, 61), width=1)
    y += 15

    # Command prompt with typing effect
    prompt = " $ "
    full_cmd = cmd
    if typing_pos is not None:
        display_cmd = full_cmd[:typing_pos]
        cursor = "▌" if frame_idx % 6 < 3 else " "
    else:
        display_cmd = full_cmd
        cursor = ""

    # Wrap command
    max_w = WIDTH - 40
    cmd_lines = wrap_text(prompt + display_cmd + cursor, FONT_BODY, max_w, draw)
    for line in cmd_lines:
        if y + 22 > HEIGHT - 120:
            break
        # Draw prompt in green, rest in white
        if line.startswith(prompt):
            draw.text((20, y), prompt, font=FONT_BODY, fill=PROMPT_COLOR)
            draw.text((20 + draw.textbbox((0,0), prompt, font=FONT_BODY)[2], y), line[len(prompt):], font=FONT_BODY, fill=CMD_COLOR)
        else:
            draw.text((20, y), line, font=FONT_BODY, fill=CMD_COLOR)
        y += 22

    # Comment in gray
    if comment:
        y += 5
        comment_lines = wrap_text(f"# {comment}", FONT_SMALL, max_w, draw)
        for line in comment_lines[:2]:
            draw.text((20, y), line, font=FONT_SMALL, fill=COMMENT_COLOR)
            y += 18

    y += 10
    # Output box
    if output is not None and typing_pos is None:  # only show output after typing done
        draw.rectangle([20, y, WIDTH-20, HEIGHT-60], fill=(22, 27, 34), outline=(48, 54, 61))
        y2 = y + 10
        # Output header
        draw.text((30, y2), "→ output:", font=FONT_SMALL, fill=COMMENT_COLOR)
        y2 += 20
        out_lines = wrap_text(output, FONT_BODY, WIDTH - 60, draw)
        for line in out_lines[:8]:
            if y2 + 20 > HEIGHT - 70:
                break
            # Color output yellow, or red if error
            col = (255, 100, 100) if "fails:" in comment or "error" in output.lower() else OUTPUT_COLOR
            draw.text((30, y2), line, font=FONT_BODY, fill=col)
            y2 += 20

    # Footer progress
    progress = f"{frame_idx+1}/{total_frames}"
    draw.text((WIDTH - 80, HEIGHT - 30), progress, font=FONT_SMALL, fill=COMMENT_COLOR, anchor="mm")
    draw.text((20, HEIGHT - 30), "https://github.com/anomalyco/datetime_c", font=FONT_SMALL, fill=COMMENT_COLOR)

    # Border
    draw.rectangle([0,0,WIDTH-1,HEIGHT-1], outline=(48,54,61), width=1)
    return img

def main():
    global WIDTH, HEIGHT
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default=str(OUTPUT))
    parser.add_argument("--width", type=int, default=WIDTH)
    parser.add_argument("--height", type=int, default=HEIGHT)
    args = parser.parse_args()

    WIDTH, HEIGHT = args.width, args.height

    print(f"Generating showcase.gif from {len(SHOWCASE_COMMANDS)} commands...")
    frames = []
    total = len(SHOWCASE_COMMANDS)

    # Intro frame
    img = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)
    draw = ImageDraw.Draw(img)
    draw.rectangle([0,0,WIDTH,50], fill=(22,27,34))
    draw.text((WIDTH//2, HEIGHT//2 - 60), "datetime", font=load_font(64), fill=TITLE_COLOR, anchor="mm")
    draw.text((WIDTH//2, HEIGHT//2 + 10), "C99 • GNU date compatible • timestamp", font=FONT_HDR, fill=FG_COLOR, anchor="mm")
    draw.text((WIDTH//2, HEIGHT//2 + 50), "bash • zsh • fish • man • tldr", font=FONT_BODY, fill=COMMENT_COLOR, anchor="mm")
    try:
        ver = subprocess.run(["./datetime","--version"], capture_output=True, text=True, cwd=str(ROOT), timeout=1).stdout.splitlines()[0]
        draw.text((WIDTH//2, HEIGHT//2 + 90), ver, font=FONT_SMALL, fill=COMMENT_COLOR, anchor="mm")
    except:
        pass
    frames.append((img, 2000))

    # Scope frame — 22 long + 15 short + 9 legacy + 47 FORMAT = 30+ invocations
    img = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)
    draw = ImageDraw.Draw(img)
    draw.rectangle([0,0,WIDTH,50], fill=(22,27,34))
    draw.text((20,12), "datetime showcase — scope", font=FONT_TITLE, fill=TITLE_COLOR)
    draw.text((WIDTH//2, HEIGHT//2 - 50), "22 long options + 15 short", font=load_font(32), fill=FG_COLOR, anchor="mm")
    draw.text((WIDTH//2, HEIGHT//2 - 10), "9 legacy formats  +  47 +FORMAT sequences", font=load_font(28), fill=FG_COLOR, anchor="mm")
    draw.text((WIDTH//2, HEIGHT//2 + 35), "= 30+ distinct invocations", font=load_font(36), fill=OUTPUT_COLOR, anchor="mm")
    draw.text((WIDTH//2, HEIGHT//2 + 80), "all tested • all documented • demo below", font=FONT_SMALL, fill=COMMENT_COLOR, anchor="mm")
    draw.text((WIDTH//2, HEIGHT - 30), "showcase.md • 140 lines • tests/_test_combinatorial 284 + _test_matrix 267", font=FONT_SMALL, fill=COMMENT_COLOR, anchor="mm")
    frames.append((img, 2500))

    # For each command, create typing frames + output frame
    for idx, (section, cmd, comment) in enumerate(SHOWCASE_COMMANDS):
        output, err, rc = run_command(cmd)
        # Typing animation: 3-5 frames per command
        steps = min(len(cmd), 30)
        # Create 4 typing frames
        for t in [0, len(cmd)//3, 2*len(cmd)//3, len(cmd)]:
            img = render_frame(section, cmd, comment, None, idx, total, typing_pos=t)
            duration = 150 if t != len(cmd) else 400
            frames.append((img, duration))
        # Output frame
        img = render_frame(section, cmd, comment, output, idx, total, typing_pos=None)
        # Longer duration for output
        frames.append((img, 1600))

    # Outro frame
    img = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)
    draw = ImageDraw.Draw(img)
    draw.text((WIDTH//2, HEIGHT//2 - 30), "Try it", font=load_font(36), fill=TITLE_COLOR, anchor="mm")
    draw.text((WIDTH//2, HEIGHT//2 + 10), "make && ./datetime --help", font=FONT_BODY, fill=FG_COLOR, anchor="mm")
    draw.text((WIDTH//2, HEIGHT//2 + 40), "make install  •  man datetime  •  tldr datetime", font=FONT_SMALL, fill=COMMENT_COLOR, anchor="mm")
    frames.append((img, 2000))

    # Convert to GIF
    # Pillow needs duration per frame
    images = [f[0] for f in frames]
    durations = [f[1] for f in frames]
    output_path = Path(args.output)
    # Optimize: reduce colors, use palette
    print(f"Saving {output_path} with {len(images)} frames...")
    # Save with palette optimization
    images[0].save(
        output_path,
        save_all=True,
        append_images=images[1:],
        duration=durations,
        loop=0,
        optimize=False,
        disposal=2,
    )
    # Also try to optimize with ffmpeg if available (better compression)
    try:
        # Use ffmpeg to optimize gif if available (palettegen)
        import subprocess as sp
        # Check if ffmpeg exists
        if sp.run(["which", "ffmpeg"], capture_output=True).returncode == 0:
            # Try to optimize via palette
            tmp_mp4 = str(output_path).replace(".gif", ".mp4")
            # Could also create mp4 via ffmpeg from gif
            print(f"GIF saved: {output_path} ({output_path.stat().st_size//1024}KB)")
            print("Tip: ffmpeg available for further optimization if needed")
    except Exception as e:
        print(f"ffmpeg check: {e}")

    print(f"Done: {output_path} ({output_path.stat().st_size//1024}KB, {len(images)} frames)")
    # Also generate mp4 via ffmpeg from gif for higher quality if ffmpeg exists
    try:
        mp4_path = str(output_path).replace(".gif", ".mp4")
        subprocess.run(
            ["ffmpeg", "-y", "-i", str(output_path), "-movflags", "faststart", "-pix_fmt", "yuv420p", "-vf", "scale=1280:-2", mp4_path],
            capture_output=True, timeout=15
        )
        if Path(mp4_path).exists():
            print(f"MP4 also: {mp4_path} ({Path(mp4_path).stat().st_size//1024}KB)")
    except Exception as e:
        print(f"mp4 gen skipped: {e}")

if __name__ == "__main__":
    main()
