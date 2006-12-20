require 'erb'

# Converts DRY stylesheets into normal CSS ones.
module CssDryer

  VERSION = '0.0.5'

  class StyleHash < Hash  #:nodoc:
    attr_accessor :multiline
    def initialize *a, &b
      super
      multiline = false
    end
    def has_non_style_hash_children
      value.each { |elem| return true unless elem.kind_of? StyleHash }
      false
    end
    # We only ever have one key and one value
    def key
      self.keys.first
    end
    def key=(key)
      self.keys.first = key
    end
    def value
      self.values.first
    end
    def value=(value)
      self.values.first = value
    end
  end

  # Converts a stylesheet with nested styles into a flattened,
  # normal CSS stylesheet.  The original whitespace is preserved
  # as much as possible.
  #
  # For example, the following DRY stylesheet:
  #
  #   div {
  #     font-family: Verdana;
  #     #content {
  #       background-color: green;
  #       p { color: red; }
  #     }
  #   }
  #
  # is converted into this CSS:
  #
  #   div {
  #     font-family: Verdana;
  #   }
  #   div #content {
  #     background-color: green;
  #   }
  #   div #content p { color: red; }
  #
  # Note, though, that @media blocks are preserved.  For example:
  #
  #   @media screen, projection {
  #     div {font-size:100%;}
  #   }
  #
  # is left unchanged.
  #
  # Styles may be nested to an arbitrary level.
  def process(nested_css, indent = 2)  #:doc:
    structure_to_css(nested_css_to_structure(nested_css), indent)
  end

  def nested_css_to_structure(css)  #:nodoc:
    # Implementation notes:
    # - ironically there is a degree of repetition here
    document = []
    selectors = []
    media_block = false
    css.each do |line|
      depth = selectors.length
      case line.chomp!
      # Media block (multiline) opening - treat as plain text but start
      # watching for close of media block.
      # Assume media blocks are never themselves nested.
      # (This must precede the multiline selector condition.)
      when /^(\s*@media.*)[{]\s*$/
        media_block = true
        document << line if depth == 0
      # Media block inline
      # Assume media blocks are never themselves nested.
      when /^\s*@media.*[{].*[}]\s*$/
        document << line if depth == 0
      # Multiline selector opening
      when /^\s*([^{]*?)\s*[{]\s*$/
        hsh = StyleHash[ $1 => [] ]
        hsh.multiline = true
        if depth == 0
          document << hsh
        else
          prev_hsh = selectors.last
          prev_hsh.value << hsh
        end
        selectors << hsh
      # Neither opening nor closing - 'plain text'
      when /^[^{}]*$/
        if depth == 0
          document << line
        else
          hsh = selectors.last
          hsh.value << (depth == 1 ? line : line.strip)
        end
      # Multiline selector closing
      when /^([^{]*)[}]\s*$/
        if media_block
          media_block = false
          if depth == 0
            document << line
          else
            hsh = selectors.last
            hsh.value << line
          end
        else
          selectors.pop
        end
      # Inline selector
      when /^([^{]*?)\s*[{]([^}]*)[}]\s*$/
        key = (depth == 0 ? $1 : $1.strip)
        hsh = StyleHash[ key => [ $2 ] ]
        if depth == 0
          document << hsh
        else
          prev_hsh = selectors.last
          prev_hsh.value << hsh
        end
      end
    end
    document
  end

  def structure_to_css(structure, indent = 2)  #:nodoc:
    # Implementation note: the recursion and the formatting
    # ironically both feel repetitive; DRY them.
    indentation = ' ' * indent
    css = ''
    structure.each do |elem|
      # Top-level hash
      if elem.kind_of? StyleHash
        set_asides = []
        key = elem.key
        if elem.has_non_style_hash_children
          css << "#{key} {"
          css << (elem.multiline ? "\n" : '')
        end
        elem.value.each do |v|
          # Nested hash, depth = 1
          if v.kind_of? StyleHash
            # Set aside
            set_asides << set_aside(combo_key(key, v.key), v.value, v.multiline)
          else
            css << (elem.multiline ? "#{v}" : v)
            css << (elem.multiline ? "\n" : '')
          end
        end
        css << "}\n" if elem.has_non_style_hash_children
        # Now write out the styles that were nested in the above hash
        set_asides.flatten.each { |hsh|
          css << "#{hsh.key} {"
          css << (hsh.multiline ? "\n" : '')
          hsh.value.each { |item|
            css << (hsh.multiline ? "#{indentation}#{item}" : item)
            css << (hsh.multiline ? "\n" : '')
          }
          css << "}\n"
        }
        set_asides.clear
      else
        css << "#{elem}\n"
      end
    end
    css
  end

  def set_aside(key, value, multiline)  #:nodoc:
    flattened = []
    hsh = StyleHash[ key => [] ]
    hsh.multiline = multiline
    flattened << hsh
    value.each { |val|
      if val.kind_of? StyleHash
        flattened << set_aside(combo_key(key, val.key), val.value, val.multiline)
      else
        hsh[key] << val
      end
    }
    flattened
  end

  def combo_key(branch, leaf) #:nodoc:
    (leaf =~ /\A[.:#\[]/) ? "#{branch}#{leaf}" : "#{branch} #{leaf}"
  end
  private :combo_key

  # Handler for DRY stylesheets which can be registered with Rails
  # as a new templating system.
  #
  # DRY stylesheets are piped through ERB and then CssDryer#process.
  class NcssHandler
    include CssDryer
    include ERB::Util

    def initialize(view)
      @view = view
    end

    def render(template, local_assigns)
      @view.controller.headers["Content-Type"] = 'text/css'
      b = binding
  
      local_assigns.stringify_keys!
      local_assigns.each { |key, value| eval "#{key} = local_assigns[\"#{key}\"]", b }
      
      # Evaluate with ERB
      dry_css = ERB.new(template).result(b)
      
      # Flatten
      process(dry_css)
    end
  end
end
