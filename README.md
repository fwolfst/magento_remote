# MagentoRemote

Interact with a specific but defaultish Magento shop via its webpage.

## Installation

Add this line to your application's Gemfile:

    gem 'magento_remote'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install magento_remote

## Usage

Call 

    magento_add_to_cart -u customerlogin -p customerpassword -b https://theshop -w productid -q quantity -c

to put <quantity> of the product with <productid> in your shopping cart.

Note that you should work with

    bundle exec

and

    bundle console

while developing.

## Contributing

1. Fork it ( https://github.com/[my-github-username]/magento_remote/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
