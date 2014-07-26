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

  # Puts as many items of given product to cart as possible
  # Returns number of items put to cart.
  def add_to_cart! product_id, qty
    # Try to be a bit clever and early find out whether article
    # is out of stock.
    if add_to_cart(product_id, qty)
      return qty
    end
    num_ordered = 0
    # Apparently not enough in stock!

    if qty.to_i > 4
      if !add_to_cart(product_id, 1)
        # out of stock
        return 0
      else
        num_ordered = 1
        qty = qty.to_i - 1
      end
    end
    while qty.to_i > 0 && !add_to_cart(product_id, qty)
      qty = qty.to_i - 1
    end
    qty.to_i + num_ordered
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

  # Search products.
  # Arguments
  #   search_string: sku, name or title, urlencoded for get request.
  # returns [[name1, product_id1, instock?1],[name2, p_id2...]...]
  #   or nil if not found.
  def find_product search_string
    url = relative_url("/catalogsearch/result/index/?limit=all&q=#{search_string}")
    @mech.get url

    product_li = @mech.page.search('.equal-height .item')

    return nil if product_li.empty?

    products = product_li.map do |product|
      # Add to cart button is missing if out of stock.
      buttons = product.search("button")
      stock = buttons && !buttons[0].nil?

      # Find product ID from wishlist link.
      wishlist_link = product.search("ul li a")[0]
      wishlist_link.attributes['href'].value[/product\/(\d+)/]
      pid = $1

      # Find name from heading.
      name = product.search('h2')[0].text
      [name, pid, stock]
    end

    return products
  end

  def find_product_id_from url
    page = @mech.get url
    r_pid = page.search(".//input[@name='product']")[0][:value]
    r_name = page.search(".product-name .roundall")
    [r_pid, r_name.text]
  end

  # Search/scrape products.
  # Arguments
  #   limit: Maximum number of product_ids to check
  #   start_pid: With which product id to start scraping
  # returns [[name1, product_id1, instock?1],[name2, p_id2...]...]
  #   or nil if not found.
  # yielding would be nice
  def scrape_products start_pid, limit
    products = []
    limit.times do |idx|
      url = relative_url("/catalog/product/view/id/#{start_pid + idx + 1}")
      @mech.get url rescue next
      #if @mech.response_code
      product_name = @mech.page.search('.product-name .roundall')[0].text
      wishlist_link = @mech.page.search(".link-wishlist")[0]
      wishlist_link.attributes['href'].value[/product\/(\d+)/]
      pid = $1
      products << [product_name, pid]
      if block_given?
        yield [product_name, pid]
      end
    end

    return products
  end

  # Get products of last order.
  # Arguments
  # returns [[product_name1, product_sku1, qty_ordered1],[name2, sku2...]...]
  #   or empty list if not found.
  def last_order_products
    orders_url = relative_url("/customer/account/")
    @mech.get orders_url
    order_url = @mech.page.search('.a-center a').first.attributes['href']
    @mech.get order_url
    @mech.page.search('tr.border').map do |tr|
      product_name = tr.children[1].children[0].content
      product_sku = tr.children[3].children[0].content
      product_qty = tr.children[7].children[1].content[/\d+/]
      [product_name, product_sku, product_qty]
    end
  end

  private

  # Construct path relative to base uri.
  # Example:
  #   base uri is http://zentimental.net
  #   relative_url 'index.html' # => http://zentimental.net/index.html
  def relative_url path
    if @base_uri.end_with?('/') && !path.start_with?('/')
      @base_uri + '/' + path
    else
      @base_uri + path
    end
  end
end
