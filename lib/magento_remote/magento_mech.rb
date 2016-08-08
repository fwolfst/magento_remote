require 'mechanize'
require 'logger'
require 'json'
require 'uri'

# The Mech Driver, interacting with a Magento shop page.
# Note that the Mech does not keep too much state, you have to
# care about login etc yourself.
class MagentoMech
  attr_accessor :user
  attr_accessor :pass
  attr_accessor :base_uri

  # Create Mech from hash
  # Argument conf
  #   values :base_uri, :user, :pass.
  def self.from_config(conf)
    client = MagentoMech.new(conf[:base_uri] || conf['base_uri'])
    client.user = conf[:user] || conf['user']
    client.pass = conf[:pass] || conf['pass']
    client
  end

  # Create Mech with base_uri
  def initialize base_uri
    @mech = Mechanize.new
    #@mech.user_agent = 'Mac Safari'
    #@mech.user_agent = ''
    @base_uri = base_uri
    @mech.agent.allowed_error_codes = [429]

    @mech.keep_alive = false
    @mech.open_timeout = 5
    @mech.read_timeout = 5
  end

  # Log to given file (-like object) or use logger.
  def log_to! file_or_logger
    if file_or_logger.is_a? Logger
      @mech.log = file_or_logger
    else
      @mech.log = Logger.new file_or_logger
    end
  end

  # Login to webpage
  def login
    login_with @user, @pass
  end

  # See add_to_cart for more notes
  def ajax_add_to_cart product_id, qty, form_token
    if product_id.nil? || qty.to_i <= 0 || form_token.nil?
      fail "Empty obligatory parameter"
    end

    url = URI.join @base_uri, "checkout/cart/add/uenc/#{form_token}/"\
      "product/#{product_id}/?isajaxcart=true&groupmessage=1&minicart=1&ajaxlinks=1"
    result_page = @mech.post url,
      {product: product_id,
       qty: qty}

    result = JSON.parse result_page.content
    return !result["outStock"]
  end

  # Put stuff in the cart.
  # Use the form_token for magento >= 1.8 (or form token enforcing magento
  # installations), otherwise leave it nil.
  #
  # Returns true if succeeded, false otherwise.
  def add_to_cart product_id, qty, form_token=nil
    fail "Empty obligatory parameter" if product_id.nil? || qty.to_i <= 0

    if !form_token.nil?
      return ajax_add_to_cart(product_id, qty, form_token)
    end
    url = URI.join @base_uri, "checkout/cart/add?product=#{product_id}&qty=#{qty}"

    # Check the returned page name
    result_page = @mech.get url

    # There are multiple reasons of failure:
    #   * product_id unknown
    #   * product out of stock
    #   * product does not exist (unhandled response (Mechanize::ResponseCodeError)
    #   )

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
  def add_to_cart! product_id, qty, form_token=nil
    # Try to be a bit clever and early find out whether article
    # is out of stock.
    if add_to_cart(product_id, qty, form_token)
      # to_i
      return qty
    end
    num_ordered = 0
    # Apparently not enough in stock!

    if qty.to_i > 4
      if !add_to_cart(product_id, 1, form_token)
        # out of stock
        return 0
      else
        num_ordered = 1
        qty = qty.to_i - 1
      end
    end
    while qty.to_i > 0 && !add_to_cart(product_id, qty, form_token)
      qty = qty.to_i - 1
    end
    qty.to_i + num_ordered
  end

  # Login and get the current carts contents
  def get_cart_content!
    login
    get_cart_content
  end

  # Get the current carts contents
  # Returns [[name, qty], [name2, qty2] ... ]
  def get_cart_content
    cart_page = @mech.get(URI.join @base_uri, "checkout/cart/")
    name_links = cart_page.search('td h2 a')
    names = name_links.map &:text
    quantities_inputs = cart_page.search('.qty')
    quantities = quantities_inputs.map {|n| n[:value]}
    names.zip quantities
  end

  # Login with given credentials
  def login_with username, password
    login_page = @mech.get(URI.join @base_uri, "customer/account/login/")

    # Probably we could just send the POST directly.
    form = login_page.form_with(:action => "#", :method => 'POST')
    form.action = URI.join @base_uri, "customer/account/loginPost/"
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
  #   sleep_time: Time to sleep after each try
  # returns [[name1, product_id1, instock?1],[name2, p_id2...]...]
  #   or nil if not found.
  # yielding would be nice
  def scrape_products start_pid, limit, sleep_time=0
    products = []
    limit.times do |idx|
      url = relative_url("/catalog/product/view/id/#{start_pid + idx + 1}")
      begin
        @mech.get url
      rescue
        # This is probably a 404
        sleep sleep_time
        next
      end

      if @mech.page.code == '429'
        # Too many requests! Sleep and try again,
        sleep 2

        @mech.get url rescue next
        if @mech.page.code == '429'
          raise "Remote Web Server reports too many requests"
        end
      end

      product_name = @mech.page.search('.product-name .roundall')[0].text
      wishlist_link = @mech.page.search(".link-wishlist")[0]
      wishlist_link.attributes['href'].value[/product\/(\d+)/]
      pid = $1
      products << [product_name, pid]
      if block_given?
        yield [product_name, pid]
      end
      sleep sleep_time
    end

    return products
  end

  # Return list [date, volume, link, id, state] of last orders
  def last_orders
    orders_url = relative_url("/customer/account/")
    @mech.get orders_url
    @mech.page.search('#my-orders-table tbody tr').map do |order_row|
      # We should remove the span labels
      row_columns = order_row.search("td")
      [row_columns[1].text, row_columns[3].text, row_columns[5].search("a").first[:href], row_columns[0].text, row_columns[4].text]
    end
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

  def products_from_order order_id
    order_url = relative_url("/sales/order/view/order_id/#{order_id}/")
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
  #   # TODO use more, and use URI.join
  def relative_url path
    if @base_uri.end_with?('/') && !path.start_with?('/')
      @base_uri + '/' + path
    else
      @base_uri + path
    end
  end
end
