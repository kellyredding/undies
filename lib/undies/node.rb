module Undies

  class Node

    # have as many methods to the class level as possilbe to keep from
    # polluting the public instance methods and to maximize the effectiveness
    # of the Element#method_missing logic

    def self.content(node)
      node.instance_variable_get("@content")
    end

    def self.start_tag(node); nil; end
    def self.end_tag(node);   nil; end

    def initialize(content)
      @content = content
    end

    def ==(other_node)
      self.class.content(self) == other_node.class.content(other_node) &&
      self.class.start_tag(self) == other_node.class.start_tag(other_node) &&
      self.class.end_tag(self) == other_node.class.end_tag(other_node)
    end

    def to_s
      [ self.class.start_tag(self),
        self.class.content(self),
        self.class.end_tag(self)
      ].compact.map{ |item| item.to_s }.join
    end

  end
end
