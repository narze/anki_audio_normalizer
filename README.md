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

```
-s, --suffix SUFFIX             Suffix to add to normalized files (default: _fixed)
-i, --integrated-loudness LEVEL Integrated loudness target [-70.0..-5.0] (default: -18.0)
-l, --loudness-range RANGE      Loudness range target [1.0..20.0] (default: 12.0)
-t, --true-peak LEVEL           Maximum true peak [-9.0..0.0] (default: -1.0)
-y, --yes                       Skip confirmation prompt
-n, --dry-run                   Show what would be done without making changes
-v, --verbose                   Show verbose output
-h, --help                      Show help message
```

## Troubleshooting

### Common Issues

1. **ffmpeg-lh not found**: Ensure ffmpeg-loudnorm-helper is in your PATH or in the current directory
2. **Very short audio files**: The script includes special handling for very short audio files that might fail with standard normalization
3. **Input encoding errors**: If you see encoding errors during confirmation, use the `-y` option to skip the confirmation prompt

### Debugging Tips

- Use the `-v` (verbose) option to see detailed information about each step
- Check the generated `last_ffmpeg_command.sh` file which contains the last ffmpeg command that was executed
- Examine the raw ffprobe output in verbose mode to diagnose audio level analysis issues

## Credits

This project was inspired by Tim Taurit's blog post ["How to normalize audio volume in your Anki flashcards"](https://taurit.pl/how-to-normalize-audio-volume-in-anki-deck-media-library/), which outlines the problem and provides a solution approach. This script implements the concepts described in the blog post with additional features and improvements.
