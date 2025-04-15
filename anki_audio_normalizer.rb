#!/usr/bin/env ruby
# anki_audio_normalizer.rb - Normalize audio files in Anki collections

require 'fileutils'
require 'optparse'

class AnkiAudioNormalizer
  AUDIO_EXTENSIONS = %w[.mp3 .wav .ogg .m4a .flac].freeze

  # Map file extensions to ffmpeg codecs
  CODEC_MAP = {
    '.mp3' => 'libmp3lame',
    '.wav' => 'pcm_s16le',
    '.ogg' => 'libvorbis',
    '.m4a' => 'aac',
    '.flac' => 'flac'
  }.freeze

  # ANSI color codes
  COLORS = {
    red: "\e[31m",
    green: "\e[32m",
    yellow: "\e[33m",
    blue: "\e[34m",
    magenta: "\e[35m",
    cyan: "\e[36m",
    bold: "\e[1m",
    reset: "\e[0m"
  }.freeze

  def initialize
    @options = {
      backup_dir: './backup',
      integrated_loudness: '-18.0',
      loudness_range: '12.0',
      true_peak: '-1.0',
      dry_run: false,
      verbose: false
    }

    parse_options
    @processed_files = 0
    @failed_files = 0
    @skipped_files = 0
    @ffmpeg_lh_path = nil
  end

  def parse_options
    OptionParser.new do |opts|
      opts.banner = "Usage: anki_audio_normalizer [options] file_or_directory [file_or_directory...]"

      opts.on("-b", "--backup-dir DIR", "Backup directory (default: ./backup)") do |dir|
        @options[:backup_dir] = dir
      end

      opts.on("-i", "--integrated-loudness LEVEL", "Integrated loudness target [-70.0..-5.0] (default: -18.0)") do |level|
        @options[:integrated_loudness] = level
      end

      opts.on("-l", "--loudness-range RANGE", "Loudness range target [1.0..20.0] (default: 12.0)") do |range|
        @options[:loudness_range] = range
      end

      opts.on("-t", "--true-peak LEVEL", "Maximum true peak [-9.0..0.0] (default: -1.0)") do |level|
        @options[:true_peak] = level
      end

      opts.on("-y", "--yes", "Skip confirmation prompt") do
        @options[:skip_confirm] = true
      end

      opts.on("-n", "--dry-run", "Show what would be done without making changes") do
        @options[:dry_run] = true
      end

      opts.on("-v", "--verbose", "Show verbose output") do
        @options[:verbose] = true
      end

      opts.on("-h", "--help", "Show this help message") do
        puts opts
        exit
      end
    end.parse!

    if ARGV.empty?
      puts "Error: No input files or directories specified"
      exit 1
    end
  end

  def run
    check_dependencies

    files = collect_audio_files(ARGV)

    if files.empty?
      puts "No audio files found in the specified paths."
      exit 0
    end

    confirm_operation(files)
    process_files(files)
    display_report
  end

  def check_dependencies
    unless command_exists?("ffmpeg")
      puts "Error: ffmpeg is not installed or not in PATH"
      exit 1
    end

    # Check for ffmpeg-lh in PATH or locally
    if command_exists?("ffmpeg-lh")
      @ffmpeg_lh_path = "ffmpeg-lh"
    elsif File.exist?("./ffmpeg-lh") && File.executable?("./ffmpeg-lh")
      @ffmpeg_lh_path = "./ffmpeg-lh"
    else
      puts "Error: ffmpeg-loudnorm-helper (ffmpeg-lh) is not installed or not in PATH"
      puts "Please install it from https://github.com/indiscipline/ffmpeg-loudnorm-helper"
      puts "You can also place the executable in the current directory."
      exit 1
    end

    puts "Using ffmpeg-lh: #{@ffmpeg_lh_path}" if @options[:verbose]
  end

  def command_exists?(cmd)
    system("which #{cmd} > /dev/null 2>&1")
  end

  def collect_audio_files(paths)
    files = []

    paths.each do |path|
      if File.directory?(path)
        Dir.glob(File.join(path, "**", "*")).each do |file|
          files << file if File.file?(file) && AUDIO_EXTENSIONS.include?(File.extname(file).downcase)
        end
      elsif File.file?(path) && AUDIO_EXTENSIONS.include?(File.extname(path).downcase)
        files << path
      else
        puts "Warning: #{path} is not a valid file or directory, or not an audio file"
        @skipped_files += 1
      end
    end

    files.uniq
  end

  def confirm_operation(files)
    puts "Found #{files.size} audio files to normalize."
    puts "First few files:" if @options[:verbose]
    files.first(5).each { |f| puts "  - #{f}" } if @options[:verbose]
    puts "..." if files.size > 5 && @options[:verbose]

    unless @options[:dry_run] || @options[:skip_confirm]
      print "Proceed with normalization? This will modify the files. (y/n): "
      STDOUT.flush # Ensure prompt is displayed

      begin
        # Try to read from STDIN explicitly
        response = STDIN.gets

        # If immediate return or nil, try alternative approach
        if response.nil? || response.empty?
          puts "\nCouldn't read input properly. Please enter 'y' or 'n':"
          STDOUT.flush
          # Try with alternative method
          require 'io/console'
          response = STDIN.getch
          puts response # Echo the character
        else
          response = response.chomp
        end

        # Convert to lowercase if possible
        response = response.downcase rescue response

        unless response == 'y' || response == 'yes'
          puts "Operation cancelled."
          exit 0
        end
      rescue => e
        puts "Error reading input: #{e.message}"
        puts "Assuming 'n' for safety. Operation cancelled."
        exit 0
      end
    end
  end

  # Get the volume level of an audio file using ffmpeg's volumedetect filter
  def get_audio_levels(file)
    puts "#{COLORS[:blue]}Analyzing audio levels for: #{file}#{COLORS[:reset]}" if @options[:verbose]

    # Use ffmpeg's volumedetect filter to get mean and max volume
    cmd = %{ffmpeg -i "#{file}" -filter:a volumedetect -f null /dev/null 2>&1}

    puts "#{COLORS[:cyan]}Running volume detection:#{COLORS[:reset]}"
    puts "#{COLORS[:bold]}#{COLORS[:yellow]}#{cmd}#{COLORS[:reset]}"

    result = `#{cmd}`
    success = $?.success?

    puts "#{COLORS[:cyan]}Raw output:#{COLORS[:reset]}"
    puts "#{COLORS[:yellow]}#{result}#{COLORS[:reset]}"

    if !success || result.empty?
      puts "#{COLORS[:red]}Warning: Could not analyze audio levels for #{file}#{COLORS[:reset]}"
      return { mean_volume: "N/A", max_volume: "N/A" }
    end

    begin
      # Extract mean and max volume using regex
      mean_volume = result.match(/mean_volume: ([-\d.]+) dB/)&.captures&.first || "N/A"
      max_volume = result.match(/max_volume: ([-\d.]+) dB/)&.captures&.first || "N/A"

      # Convert to numeric if possible
      mean_volume = mean_volume.to_f if mean_volume != "N/A"
      max_volume = max_volume.to_f if max_volume != "N/A"

      puts "#{COLORS[:green]}Successfully extracted audio levels#{COLORS[:reset]}" if @options[:verbose]

      return {
        mean_volume: mean_volume,
        max_volume: max_volume
      }
    rescue => e
      puts "#{COLORS[:red]}Warning: Error parsing audio levels for #{file}: #{e.message}#{COLORS[:reset]}"
      puts "#{COLORS[:red]}Error backtrace: #{e.backtrace.join("\n")}#{COLORS[:reset]}" if @options[:verbose]
      return { mean_volume: "N/A", max_volume: "N/A" }
    end
  end

  def process_files(files)
    FileUtils.mkdir_p(@options[:backup_dir]) unless @options[:dry_run]

    files.each_with_index do |file, index|
      begin
        # Define temp_file as nil initially to avoid reference errors
        temp_file = nil

        puts "[#{index + 1}/#{files.size}] Processing: #{file}"

        # Measure audio levels before normalization
        before_levels = get_audio_levels(file)
        puts "#{COLORS[:cyan]}Original audio levels:#{COLORS[:reset]}"
        puts "  #{COLORS[:bold]}Mean volume: #{before_levels[:mean_volume]} dB#{COLORS[:reset]}"
        puts "  #{COLORS[:bold]}Max volume: #{before_levels[:max_volume]} dB#{COLORS[:reset]}"

        # Generate backup path
        backup_path = File.join(@options[:backup_dir], File.basename(file))

        if @options[:dry_run]
          puts "  [DRY RUN] Would backup to: #{backup_path}"
          puts "  [DRY RUN] Would normalize audio using ffmpeg-lh"
          @processed_files += 1
          next # Skip the rest of the loop in dry run mode
        end

        # Check if backup already exists
        if File.exist?(backup_path)
          puts "#{COLORS[:yellow]}Backup already exists: #{backup_path}, skipping backup#{COLORS[:reset]}"
        else
          # Create backup
          FileUtils.cp(file, backup_path)
          puts "  Backed up to: #{backup_path}" if @options[:verbose]
        end

        # Determine appropriate codec based on file extension
        ext = File.extname(file).downcase
        codec = CODEC_MAP[ext] || 'copy'

        # Create a temporary file with the same extension
        temp_file = "#{file}.processing#{ext}"

        # Generate ffmpeg-lh command for debugging
        ffmpeg_lh_cmd = %{#{@ffmpeg_lh_path} "#{file}" --i #{@options[:integrated_loudness]} --lra #{@options[:loudness_range]} --tp #{@options[:true_peak]}}

        # Run ffmpeg-lh separately first to see its output
        puts "#{COLORS[:cyan]}Executing ffmpeg-lh command:#{COLORS[:reset]}"
        puts "#{COLORS[:bold]}#{COLORS[:yellow]}#{ffmpeg_lh_cmd}#{COLORS[:reset]}"

        ffmpeg_lh_output = `#{ffmpeg_lh_cmd} 2>&1`
        ffmpeg_lh_success = $?.success?

        if !ffmpeg_lh_success
          puts "#{COLORS[:red]}Error running ffmpeg-lh:#{COLORS[:reset]}"
          puts "#{COLORS[:red]}#{ffmpeg_lh_output}#{COLORS[:reset]}"
          @failed_files += 1
          next
        end

        puts "#{COLORS[:green]}ffmpeg-lh output:#{COLORS[:reset]}"
        puts "#{COLORS[:yellow]}#{ffmpeg_lh_output}#{COLORS[:reset]}"

        # Parse the output to get just the filter line, which is usually the last line
        # This handles cases where there are warnings like "Not enough headroom!"
        filter_line = ffmpeg_lh_output.strip.lines.last.strip

        # If filter line starts with '-af', it's the correct line
        if filter_line.start_with?('-af')
          puts "#{COLORS[:green]}Extracted filter command: #{filter_line}#{COLORS[:reset]}"

          # Check if the filter line contains "-inf" values which can cause errors
          if filter_line.include?("measured_I=-inf") || filter_line.include?("offset=inf")
            puts "#{COLORS[:yellow]}Detected -inf values in the filter, fixing them#{COLORS[:reset]}"

            # Fix -inf values with reasonable defaults that are within acceptable ranges
            filter_line = filter_line.gsub(/measured_I=-inf/, "measured_I=-70")
                                    .gsub(/offset=inf/, "offset=0")
                                    .gsub(/measured_TP=-inf/, "measured_TP=-20")
                                    .gsub(/measured_thresh=-inf/, "measured_thresh=-70")

            puts "#{COLORS[:green]}Fixed filter command: #{filter_line}#{COLORS[:reset]}"
          end
        else
          puts "#{COLORS[:yellow]}Warning: Could not find filter line, using full output#{COLORS[:reset]}"
          filter_line = ffmpeg_lh_output.strip
        end

        # Handle the case of very short audio files directly with a simplified approach if needed
        if filter_line.include?("-inf") || !filter_line.start_with?('-af')
          puts "#{COLORS[:yellow]}Using direct gain adjustment for very short audio#{COLORS[:reset]}"
          # Use a simple volume filter as a fallback for very short files
          filter_line = "-af volume=#{@options[:integrated_loudness].to_f - (-23)}dB"
          puts "#{COLORS[:green]}Fallback filter: #{filter_line}#{COLORS[:reset]}"
        end

        # Full ffmpeg command with proper codec (not copy)
        normalize_command = %{ffmpeg -i "#{file}" -c:a #{codec} -y #{filter_line} "#{temp_file}"}

        puts "#{COLORS[:cyan]}Executing ffmpeg command:#{COLORS[:reset]}"
        puts "#{COLORS[:bold]}#{COLORS[:yellow]}#{normalize_command}#{COLORS[:reset]}"

        # Save command to file for manual debugging if needed
        File.write('last_ffmpeg_command.sh', normalize_command)
        puts "#{COLORS[:blue]}Command saved to last_ffmpeg_command.sh#{COLORS[:reset]}"

        # Execute ffmpeg command
        ffmpeg_output = `#{normalize_command} 2>&1`
        ffmpeg_success = $?.success?

        if ffmpeg_success
          # Verify the output file exists and is valid
          if File.exist?(temp_file) && File.size(temp_file) > 0
            FileUtils.mv(temp_file, file)
            puts "#{COLORS[:green]}Successfully normalized: #{file}#{COLORS[:reset]}"

            # Measure audio levels after normalization
            after_levels = get_audio_levels(file)
            puts "#{COLORS[:cyan]}Normalized audio levels:#{COLORS[:reset]}"
            puts "  #{COLORS[:bold]}Mean volume: #{after_levels[:mean_volume]} dB#{COLORS[:reset]}"
            puts "  #{COLORS[:bold]}Max volume: #{after_levels[:max_volume]} dB#{COLORS[:reset]}"

            # Show a clear volume change summary
            puts "#{COLORS[:cyan]}Volume change:#{COLORS[:reset]}"
            mean_before = before_levels[:mean_volume].is_a?(Numeric) ? "#{before_levels[:mean_volume]} dB" : before_levels[:mean_volume]
            mean_after = after_levels[:mean_volume].is_a?(Numeric) ? "#{after_levels[:mean_volume]} dB" : after_levels[:mean_volume]
            max_before = before_levels[:max_volume].is_a?(Numeric) ? "#{before_levels[:max_volume]} dB" : before_levels[:max_volume]
            max_after = after_levels[:max_volume].is_a?(Numeric) ? "#{after_levels[:max_volume]} dB" : after_levels[:max_volume]

            puts "  #{COLORS[:bold]}Mean volume: #{mean_before} → #{mean_after}#{COLORS[:reset]}"
            puts "  #{COLORS[:bold]}Max volume: #{max_before} → #{max_after}#{COLORS[:reset]}"

            @processed_files += 1
          else
            puts "#{COLORS[:red]}Error: Output file is missing or empty, skipping: #{file}#{COLORS[:reset]}"
            puts "#{COLORS[:red]}ffmpeg output: #{ffmpeg_output}#{COLORS[:reset]}"
            @failed_files += 1
          end
        else
          puts "#{COLORS[:red]}Error normalizing: #{file}#{COLORS[:reset]}"
          puts "#{COLORS[:red]}ffmpeg output: #{ffmpeg_output}#{COLORS[:reset]}"

          # If the error is due to -inf, try a fallback approach
          if ffmpeg_output.include?("Value -inf") || ffmpeg_output.include?("Result too large")
            puts "#{COLORS[:yellow]}Attempting fallback method for very short audio...#{COLORS[:reset]}"
            fallback_command = %{ffmpeg -i "#{file}" -c:a #{codec} -y -af volume=#{@options[:integrated_loudness].to_f - (-23)}dB "#{temp_file}"}

            puts "#{COLORS[:cyan]}Executing fallback command:#{COLORS[:reset]}"
            puts "#{COLORS[:bold]}#{COLORS[:yellow]}#{fallback_command}#{COLORS[:reset]}"

            fallback_output = `#{fallback_command} 2>&1`
            fallback_success = $?.success?

            if fallback_success && File.exist?(temp_file) && File.size(temp_file) > 0
              FileUtils.mv(temp_file, file)
              puts "#{COLORS[:green]}Successfully normalized using fallback method: #{file}#{COLORS[:reset]}"
              @processed_files += 1
            else
              puts "#{COLORS[:red]}Fallback method also failed: #{file}#{COLORS[:reset]}"
              puts "#{COLORS[:red]}Fallback output: #{fallback_output}#{COLORS[:reset]}"
              @failed_files += 1
            end
          else
            @failed_files += 1
          end
        end
      rescue => e
        puts "#{COLORS[:red]}Error processing #{file}: #{e.message}#{COLORS[:reset]}"
        puts "#{COLORS[:red]}#{e.backtrace.join("\n")}#{COLORS[:reset]}" if @options[:verbose]
        @failed_files += 1
      ensure
        # Clean up temp file if it exists - safely check for nil
        if temp_file && File.exist?(temp_file)
          FileUtils.rm(temp_file)
          puts "#{COLORS[:blue]}Cleaned up temporary file#{COLORS[:reset]}" if @options[:verbose]
        end
      end
    end
  end

  def display_report
    puts "\nNormalization complete!"
    puts "Total files: #{@processed_files + @failed_files + @skipped_files}"
    puts "Successfully processed: #{@processed_files}"
    puts "Failed: #{@failed_files}"
    puts "Skipped: #{@skipped_files}"

    unless @options[:dry_run]
      puts "\nBackups were saved to: #{@options[:backup_dir]}"
    end
  end
end

# Run the program if this file is executed directly
if __FILE__ == $PROGRAM_NAME
  normalizer = AnkiAudioNormalizer.new
  normalizer.run
end
