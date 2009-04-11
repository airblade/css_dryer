# An example Rackup file.

require 'rubygems'
require 'rack'
require 'lib/rack/css_dryer'

use Rack::CssDryer

theapp = Proc.new { |env|
  content = '<h1>Hi!</h1>'
  [200, {'Content-Type' => 'text/html', 'Content-Length' => content.length.to_s}, content]
}

run theapp
