

# Anki Audio Normalizer

A Ruby script to normalize audio volume levels in Anki flashcard collections using ffmpeg and ffmpeg-loudnorm-helper.

## Installation

1. Ensure you have Ruby installed
2. Install ffmpeg: `brew install ffmpeg` (macOS) or `apt install ffmpeg` (Linux)
3. Install [ffmpeg-loudnorm-helper](https://github.com/indiscipline/ffmpeg-loudnorm-helper):
   ```
   git clone https://github.com/indiscipline/ffmpeg-loudnorm-helper.git
   cd ffmpeg-loudnorm-helper
   cargo build --release
   ```
   Then add the executable to your PATH or place it in the same directory as this script.
4. Download `anki_audio_normalizer.rb` and make it executable:
   ```
   chmod +x anki_audio_normalizer.rb
   ```

## Usage

Basic usage:
```
./anki_audio_normalizer.rb [options] file_or_directory [file_or_directory...]
```

Example:
```
./anki_audio_normalizer.rb ~/Anki/User\ 1/collection.media
```

## Features

Anki Audio Normalizer supports:

- Processing multiple audio files at once
- Recursive directory scanning
- Support for MP3, WAV, OGG, M4A, and FLAC audio formats
- Colorized output with detailed status information
- Dry-run mode to preview changes without modifying files

## Backup

The script automatically creates backups of all files before processing them. By default, backups are stored in the `./backup` directory.

- Backups are not overwritten if they already exist
- The backup directory can be customized with the `-b` or `--backup-dir` option

## Analysis

The script provides detailed audio level analysis:

- Measures integrated loudness (LUFS), true peak (dBTP), and loudness range (LU)
- Shows before and after measurements for each file
- Calculates and displays the difference between original and normalized audio
- Color-codes output to highlight significant changes

## Configuration

Command-line options:

```
-b, --backup-dir DIR            Backup directory (default: ./backup)
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