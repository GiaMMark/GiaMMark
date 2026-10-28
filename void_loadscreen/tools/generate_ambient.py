#!/usr/bin/env python3
"""Generate VOID's original seamless ambient loop; Python stdlib + ffmpeg.

This is a synthesised track, not a sample or a third-party recording.
Run from any directory: python3 tools/generate_ambient.py
"""
from array import array
import argparse
import math
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import wave


def generate(output: Path, duration=40):
    rate = 24000
    tau = math.tau
    # Every oscillator completes an integer number of cycles: seamless at loop.
    pitches = [(55.0, .30), (65.41, .16), (82.41, .15), (110, .08), (164.81, .035)]
    oscillators = [(round(freq * duration) / duration, gain) for freq, gain in pitches]
    samples = array('h')
    for i in range(rate * duration):
        t = i / rate
        slow = .64 + .16 * math.cos(tau * t / duration)
        tone = sum(gain * math.sin(tau * freq * t) for freq, gain in oscillators)
        air = .018 * math.sin(tau * (round(329.63 * duration) / duration) * t) * (.5 + .5 * math.sin(tau * 2 * t / duration))
        samples.append(round(32767 * .35 * (tone * slow + air)))
    if sys.byteorder != 'little':
        samples.byteswap()
    ffmpeg = shutil.which('ffmpeg')
    if not ffmpeg:
        raise SystemExit('ffmpeg is required to encode the OGG output.')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='void-ambient-') as temp:
        wav = Path(temp) / 'ambient.wav'
        with wave.open(str(wav), 'wb') as stream:
            stream.setnchannels(1)
            stream.setsampwidth(2)
            stream.setframerate(rate)
            stream.writeframes(samples.tobytes())
        subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-i', str(wav),
                        '-codec:a', 'libvorbis', '-q:a', '4', '-metadata', 'title=VOID / SIGNAL 01',
                        '-metadata', 'artist=VOID', str(output)], check=True)
    print(f'Generated original ambient loop: {output} ({output.stat().st_size} bytes, {duration}s)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] / 'web/media/void-ambient.ogg')
    args = parser.parse_args()
    generate(args.output)
