require 'undies/source_stack'
require 'undies/root_node'
require 'undies/api'

module Undies
  class Template
    include API

    # have as many methods on the class level as possible to keep from
    # polluting the public instance methods, the instance scope, and to
    # maximize the effectiveness of the Template#method_missing logic

    def self.flush(template)
      template.__flush
    end

    # Ripped from Rack v1.3.0 ======================================
    # => ripped b/c I don't want a dependency on Rack for just this
    ESCAPE_HTML = {
      "&" => "&amp;",
      "<" => "&lt;",
      ">" => "&gt;",
      "'" => "&#x27;",
      '"' => "&quot;",
      "/" => "&#x2F;"
    }
    ESCAPE_HTML_PATTERN = Regexp.union(*ESCAPE_HTML.keys)
    # Escape ampersands, brackets and quotes to their HTML/XML entities.
    def self.escape_html(string)
      string.to_s.gsub(ESCAPE_HTML_PATTERN){|c| ESCAPE_HTML[c] }
    end
    # end Rip from Rack v1.3.0 =====================================

    def initialize(*args)
      # setup a node stack with the given output obj
      @_undies_io = if args.last.kind_of?(Undies::IO)
        args.pop
      else
        raise ArgumentError, "please provide an IO object"
      end

      # apply any given data to template scope
      data = args.last.kind_of?(::Hash) ? args.pop : {}
      if (data.keys.map(&:to_s) & self.public_methods.map(&:to_s)).size > 0
        raise ArgumentError, "data conflicts with template public methods."
      end
      metaclass = class << self; self; end
      data.each {|key, value| metaclass.class_eval { define_method(key){value} }}

      # setup a source stack with the given source
      source = args.last.kind_of?(Source) ? args.pop : Source.new(Proc.new {})
      @_undies_source_stack = SourceStack.new(source)

      # push a root node onto the IO
      @_undies_io.push!(RootNode.new(@_undies_io)) if @_undies_io.empty?

      # yield to recursivley render the source stack
      __yield

      # flush any elements that need to be built
      __flush
    end

    # call this method to manually push the current scope to the previously
    # cached element (if any)
    # - changes the context of template method calls to operate on that element
    def __push
      @_undies_io.current.push
    end

    # call this method to manually pop the current scope to the previous scope
    # - changes the context of template method calls to operate on the parent
    #   element or root node
    def __pop
      @_undies_io.current.pop
    end

    # call this to manually flush a template
    def __flush
      @_undies_io.current.flush
    end

    # call this to render template source
    # use this method in layouts to insert a layout's content source
    def __yield
      return if (source = @_undies_source_stack.pop).nil?
      if source.file?
        instance_eval(source.data, source.source, 1)
      else
        instance_eval(&source.data)
      end
    end

    # call this to render partial source embedded in a template
    # partial source is rendered with its own scope/data but shares
    # its parent template's output object
    def __partial(source, data={})
      if source.kind_of?(Source)
        Undies::Template.new(source, data, @_undies_io)
      else
        @_undies_io.current.partial(source.to_s)
      end
    end

    # call this to modify element attrs inside a build block.  Once content
    # or child elements have been added, any '__attr' directives will
    # be ignored b/c the elements start_tag has already been flushed
    # to the output
    def __attrs(attrs_hash={})
      @_undies_io.current.attrs(attrs_hash)
    end

  end
end
