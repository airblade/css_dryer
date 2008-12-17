require 'css_dryer/processor'
require 'css_dryer/ncss_handler'

# Register our template handler with Rails.
ActionView::Template.register_template_handler :ncss, CssDryer::NcssHandler
