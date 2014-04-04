require 'mechanize'

# The Mech Driver, interacting with a Magento shop page.
class MagentoMech
  attr_accessor :user
  attr_accessor :pass

  # Create Mech from hash
  # Argument conf
  #   values :base_uri, :user, :pass.
  def self.from_config(conf)
    client = MagentoMech.new(conf[:base_uri])
    client.user = conf[:user]
    client.pass = conf[:pass]
    client
  end

  # Create Mech with base_uri
  def initialize base_uri
    @mech = Mechanize.new
    @mech.user_agent = 'RawBot, Felix sends the Mech.'
    @base_uri = base_uri
  end
end

