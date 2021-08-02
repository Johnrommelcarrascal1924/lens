require "./**"

# Namespace for logic relating to the [GNU Gettext](https://www.gnu.org/software/gettext/) format
#
# Gettext is typically separated into two files: `.po` and `.mo`. Both of these formats are fully supported
# by Lens with either the `Gettext::MOBackend` or `Gettext::POBackend` backends.
#
# For more information, please see their respective documentations.
#
# All functionality (except flags) of Gettext are implemented.
module Gettext
  extend self

  # Gettext message catalogue. Contains methods for handling translations
  #
  # You **should not** be manually creating an instance of this class! Instead let the Gettext backends
  # do it for you! See `Gettext::MOBackend` and `Gettext::POBackend`
  struct Catalogue
    # Returns a hash of the headers
    #
    # ```
    # catalogue = Gettext::MOBackend.new("examples").create["en_US"]
    # catalogue.headers["Plural-Forms"] # => "nplurals=2; plural=(n != 1);"
    # ```
    getter headers : Hash(String, String)
    @plural_interpreter : PluralForm::Interpreter?

    # Returns all messages within the catalogue
    #
    # You should **never** have to deal with this method under normal circumstances.
    # Please use the `#gettext` family of methods to translate your application instead.
    #
    # ```
    # catalogue = Gettext::MOBackend.new("examples").create["en-US"]
    # catalogue.contents # => {...}
    # ```
    getter contents : Hash(String, Hash(Int8, String))

    # Creates a message catalogue from parsed Gettext data
    def initialize(@contents : Hash(String, Hash(Int8, String)))
      @headers = {} of String => String

      headers = [] of String
      @contents[""]?.try &.[0].split("\n") { |v| headers << v if !v.empty? } || nil

      headers.each do |h|
        header = h.split(":", limit: 2)
        next if header.size <= 1
        @headers[header[0]] = header[1].strip
      end

      if plural_form_expression = @headers["Plural-Forms"]?
        # Get interpreter for plural expressions
        expressions = Gettext::PluralForm::Parser.new(plural_form_expression).parse
        @plural_interpreter = Gettext::PluralForm::Interpreter.new(expressions)
      else
        @plural_interpreter = nil
      end
    end

    private def process_plural(n)
      return @plural_interpreter.not_nil!.interpret(n)
    end

    # Fetches the translated message for the specific ID. If none can be found the given ID is returned.
    #
    # ```
    # catalogue = Gettext::MOBackend.new("examples").create["en_US"]
    # catalogue.gettext("A message")     # => "Translated message"
    # catalogue.gettext("I don't exist") # => "I don't exist"
    # ```
    def gettext(id : String)
      begin
        return @contents[id][0]
      rescue KeyError
        return id
      end
    end

    # Fetches the translated message for the specific ID with the correct plural form. Returns either the singular or plural id if none can be found.
    #
    # ```
    # catalogue = Gettext::MOBackend.new("examples").create["en_US"]
    # catalogue.ngettext("I have %d apple", "I have %d apples", 0) # => "Translated message with plural-form 1"
    # catalogue.ngettext("I have %d apple", "I have %d apples", 1) # => "Translated message with plural-form 0"
    #
    # # Not found:
    # catalogue.ngettext("I have %d pear", "I have %d pears", 0) # => "I have %d pears"
    # catalogue.ngettext("I have %d pear", "I have %d pears", 1) # => "I have %d pear"
    # ```
    def ngettext(id : String, plural_id, n)
      if @plural_interpreter.nil?
        return id
      end

      begin
        return @contents[id][self.process_plural(n)]
      rescue KeyError
        if n == 0
          return id
        else
          return plural_id
        end
      end
    end

    # Fetches the translated message for the specific ID that is bound by context. If none can be found the given ID is returned.
    #
    # ```
    # catalogue = Gettext::MOBackend.new("examples").create["en_US"]
    #
    # catalogue.pgettext("CopyPasteMenu", "copy")          # => "Translated copy"
    # catalogue.pgettext("CopyPasteMenu", "I don't exist") # => "I don't exist"
    # ```
    def pgettext(context, id)
      begin
        return @contents["#{context}\u0004#{id}"][0]
      rescue KeyError
        return id
      end
    end

    # Fetches the translated message for the specific ID that is bound by context with the correct plural form.
    #
    # ```
    # catalogue = Gettext::MOBackend.new("examples").create["en_US"]
    # catalogue.npgettext("CopyPasteMenu", "Export %d file", "Export %d files", 0) # => "Translated message with plural-form 1"
    # catalogue.npgettext("CopyPasteMenu", "Export %d file", "Export %d files", 1) # => "Translated message with plural-form 0"
    #
    # # Not found:
    # catalogue.npgettext("CopyPasteMenu", "None", "NonePlural", 0) # => "NonePlural"
    # catalogue.npgettext("CopyPasteMenu", "None", "NonePlural", 1) # => "None"
    # ```
    def npgettext(context, id, plural_id, n)
      if @plural_interpreter.nil?
        return id
      end

      begin
        return @contents["#{context}\u0004#{id}"][self.process_plural(n)]
      rescue KeyError
        if n == 0
          return id
        else
          return plural_id
        end
      end
    end
  end
end
