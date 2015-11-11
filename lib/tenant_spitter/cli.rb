require 'logger'
require 'optparse'
require 'active_record'
require "tenant_spitter"

module TenantSpitter
  class CLI

    attr_reader :environment

    def parse(args=ARGV)
      setup_options(args)
    end

    def setup_options(args)
      opts = parse_options(args)
      set_environment opts[:environment]
      options.merge!(opts)
    end

    def set_environment(cli_env)
      @environment = cli_env || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
    end

    def run
      boot_system
      launch
    end

    def boot_system
      ENV['RACK_ENV'] = ENV['RAILS_ENV'] = environment
      # Boot Rails Application
      # raise environment.to_s
      require "./config/environment" #if defined?(Rails)
      # require options[:require] if options[:require]

      ActiveRecord::Base.establish_connection
    end

    def launch
      ActiveRecord::Base.logger = nil
      print_welcome
      service = TenantSpitter::Service.new(options)
      service.prepare
      service.dump(destination)
    end

    private

    def parse_options(argv)
      opts = {}

      @parser = ::OptionParser.new do |o|
        o.banner = "Usage: tenant-spitter CLASS_NAME CONDITION [options]"

        o.on '-e', '--environment ENV', "Application environment" do |arg|
          opts[:environment] = arg
        end

        o.on '-f', '--file FILE', "Export File" do |arg|
          opts[:file] = arg
        end

        o.on '-r', '--require PATH', 'path to require file for loading your programs(models)' do |arg|
          opts[:require] = arg
        end

        # o.on '-L', '--logfile PATH', 'path to writable logfile' do |arg|
        #   opts[:logfile] = arg
        # end

        # o.on '-P', '--pidfile PATH', 'path to pidfile' do |arg|
        #   opts[:pidfile] = arg
        # end
      end

      @parser.on_tail '-h', '--help', 'Show help' do
        logger.info @parser
        die 1
      end

      if argv.size < 2
        abort @parser.to_s
      end

      init_opts = argv.shift(2)

      @parser.parse!(argv)

      opts[:initiate_class] = init_opts[0]
      opts[:initiate_condition] = init_opts[1]
      opts
    end

    def print_welcome
    end

    def options
      @options ||= {}
    end

    def destination
      if options[:file]
        File.open(options[:file], 'w+')
      else
        STDOUT
      end
    end

    def logger
      @logger ||= ::Logger.new(STDOUT)
    end
  end
end