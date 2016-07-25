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

to put *quantity* of the product with *productid* in your shopping cart (read about form token parameter further down, if working with 'hardened' magento versions, or magento >= 1.8).

    magento_find_product -b https://theshop -s isearchforthisword

to display a table of matching products.

    magento_scrape -b https://theshop -l limit -s startpid

to display *limit* number of products, starting with product id of *startpid*.

The form_token for add_to_cart functionality is necessary for specially 'hardened' magento instances, or magento versions >= 1.8 .  You find it encoded in the URL of any form action that deals with cart additions.  It was only tested for 'ajax' cart actions.

Note that all scripts show you information about possible parameters when invoked with `--help`.

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
