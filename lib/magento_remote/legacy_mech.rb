require 'mechanize'

# The Mech Driver, interacting with a Magento shop page.
class MagentoMech
  attr_accessor :base_uri
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

  # Login to webpage
  def login
    login_with @user, @pass
  end

  def add_to_cart product_id, qty
    url = "#{base_uri}/checkout/cart/add?product=#{product_id}&qty=#{qty}"
    puts
    puts url
    puts

    fail "Empty obligatory parameter" if product_id.nil? || qty.to_i <= 0

    # Check the returned name
    result_page = @mech.get url
    # If failed, contains a form with post action ending on product/#{product_id}/
    # /product/243/
    #
    # also, title is different (it stays at product when fail)
    #
    # and, body has a different class (catalog-product-view ...) instead of ...cms..
    #
    result_page.save_as 'after_addtocart.html'
    return result_page.search('.catalog-product-view').empty?
  end 

  # Order as much as possible, return that number
  # for now, do it stupidly (in 1 step decrements)
  # Later, should employ bisect
  def add_to_cart! product_id, qty
    #fail "Empty obligatory parameter" if product_id.nil? || qty <= 0
    return 0 if qty.to_i <= 0
    if !add_to_cart product_id, qty
      puts "Trying to add ... #{qty.to_i - 1}"
      add_to_cart!(product_id, qty.to_i - 1)
    else
      puts "added .. #{qty.to_i}"
      qty.to_i
    end
  end

  def get_cart_items
    # td h2 oder .product-name
    list_page = @mech.get("#{base_uri}/checkout/cart/")
    #l = list_page.search('.product-name')
    # this really gives the product names!
    l = list_page.search('td h2 a')
    t = l.map &:text
    puts t
    q = list_page.search('.qty')
    v = q.map { |n| n[:value]}
    puts v
    t.zip v
  end

  # page e.g. # https://www.rawliving.eu/catalogsearch/result?q=goji
  def find_product_id_from_url(url)
    page = @mech.get url
    r_pid = page.search(".//input[@name='product']")[0][:value]
    r_name = page.search(".product-name .roundall")
    [r_pid, r_name.text]
  end
  private

  def login_with username, password
    login_page = @mech.get("#{base_uri}/customer/account/login/")

    form = login_page.form_with(:action => "#{base_uri}/customer/account/loginPost/")
    form.fields.find{|f| f.name == 'login[username]'}.value = username
    form.fields.find{|f| f.name == 'login[password]'}.value = password
    page = @mech.submit(form)
    # TODO check if its Mein Benutzerkonto now
    puts "After login, page is: #{page.title}" # "My Account"
  end

end

