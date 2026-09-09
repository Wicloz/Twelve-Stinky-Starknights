from subprocess import run
from pathlib import Path


if __name__ == "__main__":
    for wav_file in sorted(Path("creative/music").glob("*.wav")):
        ogg_file = wav_file.with_suffix(".ogg")
        run(["ffmpeg", "-i", str(wav_file),"-c:a", "libvorbis", "-q:a", "7","-bitexact",str(ogg_file)])
