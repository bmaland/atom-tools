require "rexml/document"

require "atom/xml"
require "atom/element"
require "atom/content"

module Atom
  NS = "http://www.w3.org/2005/Atom"
  class Entry < Atom::Element
    # the master list of standard children and the types they map to
    element :id, String, true
    element :title, Atom::Text, true
    element :content, Atom::Content, true
    
    element :icon, String
    element :logo, String

    element :generator, String # uri and version attributes
    element :rights, Atom::Text
    
    element :authors, Atom::Multiple(Atom::Author)
    element :contributors, Atom::Multiple(Atom::Contributor)
    
    element :categories, Atom::Multiple(Atom::Category)
    element :links, Atom::Multiple(Atom::Link)
    
    element :published, Atom::Time
    element :updated, Atom::Time
    
    element :subtitle, Atom::Text
    element :summary, Atom::Text

    def inspect
      "#<Atom::Entry id=#{self.id}>"
    end

    def update!
      self.updated = Time.now
    end

    # tag with a space-separated string (adds bits as atom:categories)
    #   not exactly core functionality, but it's trivial
    def tag_with string
      return if string.nil?

      string.split.each do |tag|
        categories.new["term"] = tag
      end
    end

    # XXX this needs a test suite before it can be trusted.
    def valid?
      self.class.required.each do |element|
        unless instance_variable_get "@#{element}"
          return [ false, "required element atom:#{element} missing" ]
        end
      end

      if @authors.length == 0
        return [ false, "required element atom:author missing" ]
      end

      alternates = @links.find_all do |link|
        link["rel"] == "alternate"
      end

      unless @content or alternates
          return [ false, "no atom:content or atom:link[rel='alternate']" ]
      end

      alternates.each do |link|
        if alternates.find do |x|
          not x == link and 
            x["type"] == link["type"] and 
            x["hreflang"] == link["hreflang"]
          end
         
          return [ false, 'more than one atom:link with a rel attribute value of "alternate" that has the same combination of type and hreflang attribute values.' ]
        end
      end

      type = @content["type"]

      base64ed = (not ["", "text", "html", "xhtml"].member? type) and 
        type.match(/^text\/.*/).nil? and  # not text
        type.match(/.*[\+\/]xml$/).nil?   # not XML

      if (@content["src"] or base64ed) and not summary
        return [ false, "out-of-line or base64ed atom:content and no atom:summary" ]
      end

      true
    end

    # turns the whole thing into a REXML::Element
    def to_element
      root = super
      root.add_namespace Atom::NS
      root
    end

    # guess.
    def to_xml
      doc = REXML::Document.new
      doc << to_element
      doc
    end
    
    # you're not even trying now.
    def to_s
      to_xml.to_s
    end

    # backwards compatibility
    def a_id
      @id
    end

    def a_id= it
      @id = it 
    end
  end
end