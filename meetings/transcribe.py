"""
Meeting transcription with speaker diarization.
Usage: python transcribe.py "F:\path\to\audio file.mp3"
"""

import os
import sys
import json
import argparse
from pathlib import Path

# Use bundled ffmpeg from imageio-ffmpeg
import imageio_ffmpeg
_ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
os.environ["PATH"] = os.path.dirname(_ffmpeg_exe) + os.pathsep + os.environ.get("PATH", "")
import shutil, pathlib as _pl
_ffmpeg_link = _pl.Path(_ffmpeg_exe).parent / "ffmpeg.exe"
if not _ffmpeg_link.exists():
    shutil.copy(_ffmpeg_exe, _ffmpeg_link)

import torch
import whisperx

MEETINGS_DIR = Path(__file__).parent
TRANSCRIPTS_DIR = Path(r"F:\Desktop\Magdalena\Minaris\Records")
SPEAKERS_PROFILE = MEETINGS_DIR / "speakers_profile.json"

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
COMPUTE_TYPE = "float16" if DEVICE == "cuda" else "int32"


def load_speakers_profile():
    if SPEAKERS_PROFILE.exists():
        return json.loads(SPEAKERS_PROFILE.read_text())
    return {}


def save_speakers_profile(profile):
    SPEAKERS_PROFILE.write_text(json.dumps(profile, indent=2))


def label_speakers(speaker_ids, profile):
    mapping = {}
    known = list(set(profile.values()))

    print(f"\nFound {len(speaker_ids)} speaker(s): {', '.join(speaker_ids)}")
    if known:
        print(f"Known names from previous meetings: {', '.join(known)}")

    for sid in sorted(speaker_ids):
        sample_lines = [l for l in _current_segments if l.get("speaker") == sid][:1]
        if sample_lines:
            print(f'\n  {sid} sample: "{sample_lines[0]["text"].strip()}"')
        name = input(f"  Who is {sid}? (press Enter to skip): ").strip()
        mapping[sid] = name if name else sid

    return mapping


def format_transcript(segments, speaker_map):
    lines = []
    current_speaker = None
    current_text = []

    for seg in segments:
        speaker_id = seg.get("speaker", "UNKNOWN")
        name = speaker_map.get(speaker_id, speaker_id)
        text = seg["text"].strip()

        if name == current_speaker:
            current_text.append(text)
        else:
            if current_speaker is not None:
                lines.append(f"[{current_speaker}]: {' '.join(current_text)}")
            current_speaker = name
            current_text = [text]

    if current_speaker:
        lines.append(f"[{current_speaker}]: {' '.join(current_text)}")

    return "\n\n".join(lines)


_current_segments = []


def transcribe(audio_path: str, hf_token: str, language: str = "en"):
    global _current_segments
    audio_path = Path(audio_path).resolve()

    if not audio_path.exists():
        print(f"Error: file not found: {audio_path}")
        sys.exit(1)

    name = audio_path.stem
    output_dir = audio_path.parent
    print(f"\nTranscribing: {audio_path.name}")
    print(f"Device: {DEVICE.upper()}  |  Model: large-v2")

    model = whisperx.load_model("large-v2", DEVICE, compute_type=COMPUTE_TYPE, language=language)
    audio = whisperx.load_audio(str(audio_path))

    print("Running transcription...")
    result = model.transcribe(audio, batch_size=16)

    print("Aligning word timestamps...")
    model_a, metadata = whisperx.load_align_model(language_code=result["language"], device=DEVICE)
    result = whisperx.align(result["segments"], model_a, metadata, audio, DEVICE, return_char_alignments=False)

    print("Running speaker diarization...")
    diarize_model = whisperx.diarize.DiarizationPipeline(token=hf_token, device=DEVICE)
    diarize_segments = diarize_model(audio)
    result = whisperx.assign_word_speakers(diarize_segments, result)

    _current_segments = result["segments"]

    speaker_ids = sorted(set(
        seg.get("speaker", "UNKNOWN")
        for seg in result["segments"]
        if seg.get("speaker")
    ))

    profile = load_speakers_profile()
    speaker_map = label_speakers(speaker_ids, profile)

    for sid, sname in speaker_map.items():
        if sname != sid:
            profile[sid] = sname
    save_speakers_profile(profile)

    transcript_text = format_transcript(result["segments"], speaker_map)
    txt_path = output_dir / f"{name}.txt"
    txt_path.write_text(transcript_text, encoding="utf-8")

    print(f"\nDone! Saved: {txt_path}")
    return txt_path


def main():
    # Use sys.argv directly to avoid argparse misreading hyphens in filenames
    args = sys.argv[1:]

    hf_token = None
    language = "en"
    audio_parts = []

    i = 0
    while i < len(args):
        if args[i] == "--hf_token" and i + 1 < len(args):
            hf_token = args[i + 1]
            i += 2
        elif args[i] == "--language" and i + 1 < len(args):
            language = args[i + 1]
            i += 2
        else:
            audio_parts.append(args[i])
            i += 1

    if not audio_parts:
        print("Usage: python transcribe.py \"path\\to\\audio file.mp3\"")
        sys.exit(1)

    # Rejoin in case path was split by shell
    audio_path = " ".join(audio_parts)

    hf_token = hf_token or os.environ.get("HF_TOKEN")
    if not hf_token:
        hf_token = input("Enter your HuggingFace token (or set HF_TOKEN env var): ").strip()

    transcribe(audio_path, hf_token, language)


if __name__ == "__main__":
    main()
