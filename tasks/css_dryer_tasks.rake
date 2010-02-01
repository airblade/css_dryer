require 'erb'

namespace :css_dryer do

  task :to_css do
    require File.join(RAILS_ROOT, 'app', 'helpers', 'stylesheets_helper')
    include StylesheetsHelper

    require File.join(File.dirname(__FILE__), '..', 'lib', 'css_dryer', 'processor')
    include CssDryer::Processor

    Dir.glob(File.join(RAILS_ROOT, 'app', 'views', 'stylesheets', '*')).each do |ncss|
      @output_buffer = ''
      ::ERB.new(File.read(ncss), nil, '-', '@output_buffer').result(binding)
      File.open(File.join(RAILS_ROOT, 'public', 'stylesheets', File.basename(ncss, '.ncss')), 'w') do |f|
        f.write process(@output_buffer)
      end
    end
  end

end
