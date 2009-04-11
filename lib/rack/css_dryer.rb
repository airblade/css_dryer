require File.expand_path(File.dirname(__FILE__) + '/../css_dryer/processor')

# Rack::CssDryer is a Rack middleware that serves de-nested nested
# stylesheets (.ncss) if available.
module Rack
  class CssDryer
    include ::CssDryer::Processor
    File = ::File

    # Options:
    #
    # +:url+ the parent URL of the stylesheets.  Defaults to 'css'.  In a Rails app
    # you probably want to set this to 'stylesheets'.
    #
    # +:path+ the file system directory containing your nested stylesheets (.ncss).
    # In a Rails app you probably want to set this to 'app/views/stylesheets'.
    def initialize(app, options = {})
      @app  = app
      @url  = options[:url]  || 'css'
      @path = options[:path] || 'stylesheets'
    end

    def call(env)
      path = env['PATH_INFO']
      if path =~ %r{/#{@url}/}
        file = path.sub("/#{@url}", @path)
        ncss = file.sub(/\.css$/, '.ncss')

        if File.exists?(ncss)
          nested_css = File.read(ncss)
          css = process(nested_css)
          length = ''.respond_to?(:bytesize) ? css.bytesize.to_s : css.size.to_s
          [200, {'Content-Type' => 'text/css', 'Content-Length' => length}, [css]]
        else
          @app.call(env)
        end
      else
        @app.call(env)
      end
    end
  end
end
