require 'mechanize'
require 'logger'

# The Mech Driver, interacting with a Magento shop page.
# Note that the Mech does not keep too much state, you have to
# care about login etc yourself.
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

  # Log to given file (-like object).
  def log_to! file
    puts @mech.log
    @mech.log = Logger.new file
  end

  # Login to webpage
  def login
    login_with @user, @pass
  end

  # Put stuff in the cart.
  # Returns true if succeeded, false otherwise.
  def add_to_cart product_id, qty
    fail "Empty obligatory parameter" if product_id.nil? || qty.to_i <= 0
    url = "#{@base_uri}/checkout/cart/add?product=#{product_id}&qty=#{qty}"

    # Check the returned page name
    result_page = @mech.get url

    # There are multiple reasons of failure:
    #   * product_id unknown
    #   * product out of stock

    # There are multiple ways to detect failure:
    #   * contains a form with post action ending on product/#{product_id}/
    #   * title is different (stays at product page when failing)
    #   * no success msg div is shown.
    #   * body has a different class.
    #
    # Using the last of these options:
    # return result_page.search('.catalog-product-view').empty?

    return !result_page.search('.success-msg span').empty?
  end

  # Get the current carts contents
  def get_cart_content
    cart_page = @mech.get("#{@base_uri}/checkout/cart/")
    name_links = cart_page.search('td h2 a')
    names = name_links.map &:text
    quantities_inputs = cart_page.search('.qty')
    quantities = quantities_inputs.map {|n| n[:value]}
    names.zip quantities
  end

  # Login with given credentials
  def login_with username, password
    login_page = @mech.get("#{@base_uri}/customer/account/login/")

    form = login_page.form_with(:action => "#{@base_uri}/customer/account/loginPost/")
    form.fields.find{|f| f.name == 'login[username]'}.value = username
    form.fields.find{|f| f.name == 'login[password]'}.value = password
    @mech.submit(form)
  end
end
