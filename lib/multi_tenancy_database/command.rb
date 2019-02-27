require 'optparse'
require 'multi_tenancy_database'
require 'multi_tenancy_database/version'
require 'multi_tenancy_database/default'

module MultiTenancyDatabase
  class Command
    def initialize(args)
      args << '-h' if args.empty?
      @args    = args
      @options = {}
    end

    def run
      @opts = OptionParser.new(&method(:set_opts))
      @opts.parse!(@args)
      check_missing_requirement_options
      process!
      exit 0
    rescue Exception => ex
      raise ex if @options[:trace] || SystemExit === ex
      $stderr.print "#{ex.class}: " if ex.class != RuntimeError
      $stderr.puts ex.message
      $stderr.puts '  Use --trace for backtrace.'
      exit 1
    end

    protected
    def check_missing_requirement_options
      mandatory = [:name, :adapter]
      @options[:adapter] = MultiTenancyDatabase::ADAPTER
      missing = mandatory.select{ |param| @options[param].nil? } 
      if !missing.empty?
        puts "Missing options: #{missing.join(', ')}"
        puts @opts.help
        exit
      end
    end

    def command_name
      @command_name ||= 'multi_tenancy_database'
    end

    def set_opts(opts)
      opts.banner = "Usage: #{command_name} [options]"

      opts.on('--trace', :NONE, 'Show a full traceback on error') do
        @options[:trace] = true
      end

      opts.on('-n', '--name=db_name', 'Database name') do |name|
        @options[:name] = name.gsub(/^\=+/, '')
      end

      opts.on('-a', '--adapter=postgresql|mysql', 'Adapter type, default will postgresql') do |adapter|
        @options[:adapter] = adapter.gsub(/^\=+/, '')
      end

      opts.on_tail('-v', '--version', 'Print version') do
        puts "#{command_name} #{MultiTenancyDatabase::VERSION}"
        exit
      end

      opts.on_tail('-h', '--help', 'Show this message') do
        puts opts
        exit
      end
    end

    def process!
      args = @args.dup
      MultiTenancyDatabase.generator!(@options)
    end
  end  
end
