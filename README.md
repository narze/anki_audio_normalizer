# Anki Audio Normalizer

A Ruby script to normalize audio volume levels in Anki flashcard collections using ffmpeg and ffmpeg-loudnorm-helper.

## Installation

1. Ensure you have Ruby installed

2. Install ffmpeg: `brew install ffmpeg` (macOS) or `apt install ffmpeg` (Linux)

3. Install [ffmpeg-loudnorm-helper](https://github.com/indiscipline/ffmpeg-loudnorm-helper):

```sh
git clone https://github.com/indiscipline/ffmpeg-loudnorm-helper.git
cd ffmpeg-loudnorm-helper
cargo build --release
```

Then add the executable to your PATH or place it in the same directory as this script.

4. Download `anki_audio_normalizer.rb` and make it executable:

```sh
chmod +x anki_audio_normalizer.rb
```

## Usage

Basic usage:

```sh
./anki_audio_normalizer.rb [options] file_or_directory [file_or_directory...]
```

Example:

```sh
./anki_audio_normalizer.rb ~/Anki/User\ 1/collection.media
```

## Features

Anki Audio Normalizer supports:

- Processing multiple audio files at once
- Recursive directory scanning
- Support for MP3, WAV, OGG, M4A, and FLAC audio formats
- Colorized output with detailed status information
- Dry-run mode to preview changes without modifying files

## Output Files

The script preserves the original files and creates new normalized versions:

- Original files remain untouched
- Normalized files are created with a suffix (default: "_fixed")
- The suffix can be customized with the `-s` or `--suffix` option

## Analysis

The script provides comprehensive audio level analysis using ffmpeg's volumedetect filter:

- **Mean Volume**: The average volume level across the entire audio file (in dB)
- **Max Volume**: The highest peak volume in the audio file (in dB)

For each file processed, the script:

1. Analyzes and displays the original audio levels
2. Performs normalization using ffmpeg-loudnorm-helper
3. Analyzes and displays the normalized audio levels
4. Shows a clear before → after comparison

Example output:

```yaml
Original audio levels:
  Mean volume: -28.5 dB
  Max volume: -18.2 dB

Normalized audio levels:
  Mean volume: -16.2 dB
  Max volume: -1.0 dB

Volume change:
  Mean volume: -28.5 dB → -16.2 dB
  Max volume: -18.2 dB → -1.0 dB
```

The color-coded output makes it easy to see the results of the normalization process at a glance.

## Configuration

Command-line options:

```text

```
