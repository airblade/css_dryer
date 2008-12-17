# Handler for DRY stylesheets which can be registered with Rails
# as a new templating system.
#
# DRY stylesheets are piped through ERB and then CssDryer#process.
module CssDryer

  class NcssHandler < ActionView::TemplateHandlers::ERB
    include CssDryer::Processor
    # In case user doesn't have helper or hasn't run generator yet.
    include StylesheetsHelper rescue nil

    def compile(template)
      temp = super
      temp + "; @output_buffer = CssDryer::NcssHandler.new.process(@output_buffer)"
    end
  end

end
