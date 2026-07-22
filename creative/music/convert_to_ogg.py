from subprocess import run
from pathlib import Path


if __name__ == "__main__":
    for wav_file in Path("creation/music").glob("*.wav"):
        ogg_file = wav_file.with_suffix(".ogg")
        if not ogg_file.exists():
            run(["ffmpeg", "-i", str(wav_file), "-c:a", "libvorbis", "-q:a", "7", str(ogg_file)])
