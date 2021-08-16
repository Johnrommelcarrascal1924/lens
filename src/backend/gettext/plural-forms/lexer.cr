require "./ast.cr"
require "./tokens"

module Gettext
  extend self

  # Module for handling the plural-forms header used by Gettext
  #
  # You should **never** have to deal with this module. The Gettext backends automatically
  # calls the required methods here for interpreting plural-forms.
  #
  # [Everything in here is based on the tree-walk interpreter from
  # crafting interpreters](https://www.craftinginterpreters.com/a-tree-walk-interpreter.html)
  #
  # Thanks Robert Nystrom!
  module PluralForm
    extend self

    # A scanner to tokenize a subset of C's grammar
    #
    # Takes a Type (Token) to make the compiler happy
    #
    # Based on https://www.craftinginterpreters.com/scanning.html
    class Scanner < Lens::Base::Lexer(Token)
      # Creates a new scanner instance with the given source
      #
      # ```
      # plural_form_scanner = Gettext::PluralForm::Scanner.new("nplurals=2; plural=(n > 1);")
      # ```
      def initialize(@source : String)
        super
      end

      # Scans a token from the given source
      private def scan_token
        @token = nil
        character = @reader.current_char
        @reader.next_char

        case character
        # Single character tokens
        when '('
          self.add_token(TokenTypes::LEFT_PAREN)
        when ')'
          self.add_token(TokenTypes::RIGHT_PAREN)
        when '*'
          self.add_token(TokenTypes::STAR)
        when '/'
          self.add_token(TokenTypes::SLASH)
        when '%'
          self.add_token(TokenTypes::MOD)
        when '+'
          self.add_token(TokenTypes::PLUS)
        when '-'
          self.add_token(TokenTypes::MINUS)
        when '?'
          self.add_token(TokenTypes::QUESTION)
        when ':'
          self.add_token(TokenTypes::COLON)
        when ';'
          self.add_token(TokenTypes::SEMICOLON)
          # Two character tokens
        when '<'
          self.match('=') ? self.add_token(TokenTypes::LESS_EQUAL) : self.add_token(TokenTypes::LESS)
        when '>'
          self.match('=') ? self.add_token(TokenTypes::GREATER_EQUAL) : self.add_token(TokenTypes::GREATER)
        when '='
          self.match('=') ? self.add_token(TokenTypes::EQUAL_EQUAL) : self.add_token(TokenTypes::EQUAL)
        when '!'
          self.match('=') ? self.add_token(TokenTypes::NOT_EQUAL) : self.add_token(TokenTypes::NOT)
        when '&'
          self.match('&') ? self.add_token(TokenTypes::AND) : nil
        when '|'
          self.match('|') ? self.add_token(TokenTypes::OR) : nil
          # Ignore spaces
        when ' '
        when .number?
          @io << character
          self.handle_number
        else
          if character.alphanumeric?
            @io << character
            self.handle_identifier
          else
            raise LensExceptions::LexError.new("Plural-Forms", "Unexpected character", @source, 1, @reader.pos - 1)
          end
        end
      end

      # Proceses a number token
      private def handle_number
        while !self.at_end_of_source? && @reader.current_char.number?
          self.advance_and_store
        end

        number = @io.to_s
        if number.includes? "."
          self.add_token(TokenTypes::NUMBER, number.to_f)
        else
          self.add_token(TokenTypes::NUMBER, number.to_i)
        end

        @io.clear
      end

      # Processes a variable
      private def handle_identifier
        while !self.at_end_of_source? && @reader.current_char.alphanumeric?
          self.advance_and_store
        end

        self.add_token(TokenTypes::IDENTIFIER, @io.to_s)
        @io.clear
      end

      # Checks to see if the next character equals the given character
      private def match(expected)
        return false if at_end_of_source?
        if @reader.current_char == expected
          @reader.next_char
          return true
        end
      end
    end
  end
end
