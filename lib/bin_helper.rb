# "Helpers" for the binary/programs
module MagentoRemote
  module CLI
    module Options
      # Register customer, password and base-uri options.
      def self.add_shop_options opts, options
        opts.separator "Magento shop options"

        opts.on('-u', '--customer USER',
          'customer/username of shop.') do |u|
          options[:user] = u
        end

        opts.on('-p', '--password PASSWORD',
          'password of customer account.') do |p|
          options[:pass] = p
        end

        opts.on('-b', '--base-uri URI',
          'base URI of shop.') do |b|
          options[:base_uri] = b
        end
      end
      
      # Exit if obligatory options not given.
      def self.exit_obligatory! options
        if !options[:user] || !options[:pass] || !options[:base_uri]
          STDERR.puts "Error: You have to define user, pass and base_uri.  (see --help)"
          exit 1
        end
      end
    end
  end
end
