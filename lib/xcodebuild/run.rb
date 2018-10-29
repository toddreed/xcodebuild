module XcodeBuild

  def self.quote(s)
    if s.include?(' ')
      "\"#{s}\""
    else
      s
    end
  end

  def self.run(*args, **options)
    printable_args = args.map {|a| quote(a)}.join(' ')
    if STDOUT.tty?
      puts "Running: \033[32m#{printable_args}\033[0m"
    else
      puts "Running: #{printable_args}"
    end

    unless ENV.has_key? 'DRY_RUN'
      unless system(*args, options)
        raise "#{args[0]} return exit status code #{$?.exitstatus}"
      end
    end
  end

end