#!/usr/bin/env ruby

require 'json'
require 'time'

class ClaudeStatsAnalyzer
  def initialize(jsonl_files)
    @jsonl_files = jsonl_files.is_a?(Array) ? jsonl_files : [jsonl_files]
    @stats = {
      tool_calls: 0,
      tool_execution_times: [],
      user_prompts: 0,
      claude_iterations_per_prompt: []
    }
    @current_prompt_iterations = 0
    @last_user_message = nil
    @pending_tool_starts = []
    @file_stats = []
  end

  def analyze
    @jsonl_files.each do |jsonl_file|
      analyze_single_file(jsonl_file)
    end
    
    if @jsonl_files.length > 1
      display_aggregate_stats
    else
      display_single_file_stats(@jsonl_files.first)
    end
  end

  private

  def analyze_single_file(jsonl_file)
    file_stats = {
      file: jsonl_file,
      tool_calls: 0,
      tool_execution_times: [],
      user_prompts: 0,
      claude_iterations_per_prompt: []
    }
    
    # Reset per-file state
    @current_prompt_iterations = 0
    @pending_tool_starts = []
    
    File.open(jsonl_file, 'r') do |file|
      file.each_line do |line|
        begin
          record = JSON.parse(line.strip)
          process_record(record, file_stats)
        rescue JSON::ParserError => e
          puts "Warning: Skipping malformed JSON line in #{jsonl_file}: #{e.message}"
        end
      end
    end
    
    # Finalize the last prompt's iteration count for this file
    if @current_prompt_iterations > 0
      file_stats[:claude_iterations_per_prompt] << @current_prompt_iterations
      @stats[:claude_iterations_per_prompt] << @current_prompt_iterations
    end
    
    # Add file stats to global stats
    @stats[:tool_calls] += file_stats[:tool_calls]
    @stats[:tool_execution_times].concat(file_stats[:tool_execution_times])
    @stats[:user_prompts] += file_stats[:user_prompts]
    
    @file_stats << file_stats
  end

  private

  def process_record(record, file_stats)
    case record['type']
    when 'user'
      handle_user_message(record, file_stats)
    when 'assistant'
      handle_assistant_message(record, file_stats)
    end
  end

  def handle_user_message(record, file_stats)
    # Check if this is a tool result (user message with tool_use_id)
    if record['message'] && record['message']['content'].is_a?(Array)
      tool_results = record['message']['content'].select { |item| item['tool_use_id'] }
      if tool_results.any?
        handle_tool_results(record, file_stats)
        return
      end
    end
    
    # Check if this is a user-initiated prompt (not a tool result)
    if record['message'] && record['message']['role'] == 'user'
      # Count as a new prompt if it's a string (direct user input) 
      # or an array without tool_use_id (also direct user input)
      is_tool_result = record['message']['content'].is_a?(Array) && 
                       record['message']['content'].any? { |item| item['tool_use_id'] }
      
      if !is_tool_result
        # Finalize previous prompt's iteration count
        if @current_prompt_iterations > 0
          file_stats[:claude_iterations_per_prompt] << @current_prompt_iterations
          @stats[:claude_iterations_per_prompt] << @current_prompt_iterations
        end
        
        # Start counting iterations for new prompt
        file_stats[:user_prompts] += 1
        @current_prompt_iterations = 0
        @last_user_message = record
      end
    end
  end

  def handle_assistant_message(record, file_stats)
    # Count this as an iteration from Claude
    @current_prompt_iterations += 1
    
    # Count tool calls in this message and track their start times
    if record['message'] && record['message']['content']
      content = record['message']['content']
      if content.is_a?(Array)
        tool_uses = content.select { |item| item['type'] == 'tool_use' }
        file_stats[:tool_calls] += tool_uses.length
        
        # Track tool start times for each tool call
        tool_uses.each do |tool_use|
          @pending_tool_starts << {
            tool_id: tool_use['id'],
            start_time: record['timestamp']
          }
        end
      end
    end
  end

  def handle_tool_results(record, file_stats)
    # Calculate tool execution times based on tool results
    if record['message'] && record['message']['content'].is_a?(Array)
      record['message']['content'].each do |content_item|
        if content_item['tool_use_id']
          # Find the corresponding tool start
          tool_start = @pending_tool_starts.find { |t| t[:tool_id] == content_item['tool_use_id'] }
          if tool_start && record['timestamp']
            start_time = Time.parse(tool_start[:start_time])
            end_time = Time.parse(record['timestamp'])
            execution_time = end_time - start_time
            file_stats[:tool_execution_times] << execution_time
            
            # Remove the processed tool start
            @pending_tool_starts.reject! { |t| t[:tool_id] == content_item['tool_use_id'] }
          end
        end
      end
    end
  end

  def display_single_file_stats(jsonl_file)
    puts "=== Claude Code Trace Analysis ==="
    puts "File: #{jsonl_file}"
    puts
    
    puts "📊 STATISTICS:"
    puts "  • Number of tools called: #{@stats[:tool_calls]}"
    
    if @stats[:tool_execution_times].any?
      avg_tool_time = @stats[:tool_execution_times].sum / @stats[:tool_execution_times].length
      puts "  • Average tool execution time: #{sprintf('%.3f', avg_tool_time)} seconds"
    else
      puts "  • Average tool execution time: Unable to calculate (insufficient timing data)"
    end
    
    puts "  • Number of user prompts: #{@stats[:user_prompts]}"
    
    if @stats[:claude_iterations_per_prompt].any?
      avg_iterations = @stats[:claude_iterations_per_prompt].sum.to_f / @stats[:claude_iterations_per_prompt].length
      puts "  • Average Claude iterations per prompt: #{sprintf('%.2f', avg_iterations)}"
      puts
      puts "📈 DETAILED BREAKDOWN:"
      puts "  • Tool execution times: #{@stats[:tool_execution_times].map { |t| sprintf('%.3f', t) }.join(', ')} seconds" if @stats[:tool_execution_times].any?
      puts "  • Iterations per prompt: #{@stats[:claude_iterations_per_prompt].join(', ')}"
    else
      puts "  • Average Claude iterations per prompt: Unable to calculate"
    end
  end

  def display_aggregate_stats
    puts "=== Claude Code Trace Analysis (#{@jsonl_files.length} files) ==="
    puts
    
    puts "📊 AGGREGATE STATISTICS:"
    puts "  • Total files analyzed: #{@jsonl_files.length}"
    puts "  • Total tools called: #{@stats[:tool_calls]}"
    
    if @stats[:tool_execution_times].any?
      avg_tool_time = @stats[:tool_execution_times].sum / @stats[:tool_execution_times].length
      puts "  • Average tool execution time: #{sprintf('%.3f', avg_tool_time)} seconds"
    else
      puts "  • Average tool execution time: Unable to calculate (insufficient timing data)"
    end
    
    puts "  • Total user prompts: #{@stats[:user_prompts]}"
    
    if @stats[:claude_iterations_per_prompt].any?
      avg_iterations = @stats[:claude_iterations_per_prompt].sum.to_f / @stats[:claude_iterations_per_prompt].length
      puts "  • Average Claude iterations per prompt: #{sprintf('%.2f', avg_iterations)}"
    else
      puts "  • Average Claude iterations per prompt: Unable to calculate"
    end
    
    puts
    puts "📈 PER-FILE BREAKDOWN:"
    @file_stats.each do |file_stat|
      file_name = File.basename(file_stat[:file])
      avg_time = file_stat[:tool_execution_times].any? ? 
                 file_stat[:tool_execution_times].sum / file_stat[:tool_execution_times].length : 0
      avg_iter = file_stat[:claude_iterations_per_prompt].any? ?
                 file_stat[:claude_iterations_per_prompt].sum.to_f / file_stat[:claude_iterations_per_prompt].length : 0
      
      puts "  • #{file_name}:"
      puts "    - Tools: #{file_stat[:tool_calls]}, Avg time: #{sprintf('%.3f', avg_time)}s"
      puts "    - Prompts: #{file_stat[:user_prompts]}, Avg iterations: #{sprintf('%.2f', avg_iter)}"
    end
  end
end

# Main execution
if ARGV.length == 0
  puts "Usage: #{$0} <jsonl_file1> [jsonl_file2] [...]"
  puts "Examples:"
  puts "  #{$0} run/session1.jsonl"
  puts "  #{$0} run/*.jsonl"
  puts "  #{$0} run/session1.jsonl run/session2.jsonl"
  exit 1
end

# Check that all files exist
missing_files = ARGV.reject { |file| File.exist?(file) }
if missing_files.any?
  puts "Error: The following files were not found:"
  missing_files.each { |file| puts "  - #{file}" }
  exit 1
end

analyzer = ClaudeStatsAnalyzer.new(ARGV)
analyzer.analyze