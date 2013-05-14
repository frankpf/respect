module Respect
  # Base class for all object schema.
  #
  # A schema defines the expected structure and format for a given object.
  # It is similar in spirit to {json-schema.org}(http://json-schema.org/)
  # specification but uses Ruby DSL as definition. Using the DSL is not
  # mandatory since you can also defines a schema using its own methods.
  #
  # Almost all {Schema} sub-classes has an associated statement available in
  # the DSL for defining it. This statement is named after the class name
  # (see {Schema.statement_name}). However some classes do not have a statement
  # associated (see {Respect.schema_for}).
  #
  # You can define such a schema using the
  # {define} method. The {#validate} method allow you to check whether
  # the given object is valid according to this schema.
  # Various options can be passed to the schema when initializing it.
  #
  # While validating an object the schema build a sanitized
  # version of this document including all the validated part.
  # The value presents in this sanitized document have generally a
  # type specific to the contents they represents. For instance,
  # a URI would be represented as a string in the original
  # document but as a URI object in the sanitized document.
  # There is a she-bang version of the validation method which
  # update the given document in-place with the sanitized document
  # if the validation succeeded.
  #
  # You can pass several options when creating a Schema:
  # required::  whether this property associated to this schema is
  #             required in the hash schema (+true+ by default).
  # default::   the default value to use for the associated property
  #             if it is not present. Setting a default value make
  #             the property private. (+nil+ by default)
  # doc::       the documentation of this schema (+nil+ by default).
  #             A documentation is composed of a title followed by
  #             an empty line and an optional long description.
  #             If set to false, then this schema is considered
  #             as an implementation details that should not be
  #             publicly documented. Thus, it will not be dumped as
  #             {json-schema.org}[http://json-schema.org/].
  # These options applies to all schema sub-classes.
  #
  # In addition to these options, you can configure any defined
  # {Validator}. Validators are run during validation process by
  # certain schema class like {IntegerSchema}, {StringSchema},
  # etc... They are mostly non-containers schema. In the
  # following code the {GreaterThanValidator} will be run at
  # validation time with the value +o+:
  #
  #   IntegerSchema.define greater_than: 0
  #
  # This class is _abstract_. You cannot instantiate it directly.
  # Use one of its sub-classes instead.
  class Schema

    class << self
      # Make this class abstract.
      private :new

      # If a corresponding _def_ class exists for this class
      # (see {def_class}) it defines a new schema by evaluating the given
      # +block+ in the context of this definition class.  It behaves as an alias
      # for new if no block is given.
      #
      # If there is no associated _def_ class the block is passed to the constructor.
      def define(*args, &block)
        def_class = self.def_class
        if def_class
          if block
            def_class.eval(*args, &block)
          else
            self.new(*args)
          end
        else
          self.new(*args, &block)
        end
      end

      # Return the associated _def_ class name for this class.
      # Example:
      #   ArraySchema.def_class_name  #=> "ArrayDef"
      #   HashSchema.def_class_name #=> "HashDef"
      #   Schema.def_class_name       #=> "SchemaDef"
      def def_class_name
        if self == Schema
          "Respect::SchemaDef"
        else
          self.name.sub(/Schema$/, 'Def')
        end
      end

      # Return the definition class symbol for this schema class or nil
      # if there is no class (see {def_class_name})
      def def_class
        self.def_class_name.safe_constantize
      end

      # Build a statement name from this class name.
      #
      # Example:
      #   Schema.statement_name                 #=> "schema"
      #   HashSchema.statement_name             #=> "hash"
      def statement_name
        self.name.underscore.sub(/^.*\//, '').sub(/_schema$/, '')
      end

      # Return the default options for this schema class.
      # If you overwrite this method in sub-classes, call super and merge the
      # result with your default options.
      def default_options
        {
          required: true,
          default: nil,
          doc: nil,
        }.freeze
      end

      # Un-define default statement for this class in the DSL. Useful when a
      # method is already defined in the DSL but to not serve your purpose.
      # For instance the +hash+ method exists in the DSL because it is inherited
      # from Object. We want to use this method to create {HashSchema} object
      # so we call this method when defining this class.
      def undef_default_statement
        GlobalDef.send :undef_method, statement_name
      end

    end

    # Create a new schema using the given _options_.
    def initialize(options = {})
      @sanitized_object = nil
      @options = self.class.default_options.merge(options)
    end

    def initialize_copy(other)
      @options = other.options.dup
    end

    # Returns the sanitized document. It is +nil+ as long as you have not
    # validated any document. It is overwritten every times you call
    # {#validate}.
    attr_reader :sanitized_object

    # Returns the hash of options.
    attr_reader :options

    # Returns the documentation of this schema.
    def doc
      @options[:doc]
    end

    # Returns the title part of the documentation of this schema
    # (+nil+ if it does not have any).
    def title
      if doc.is_a?(String)
        DocParser.new.parse(doc).title
      end
    end

    # Returns the description part of the documentation of this schema
    # (+nil+ if it does not have any).
    def description
      if doc.is_a?(String)
        DocParser.new.parse(doc).description
      end
    end

    # Returns whether this schema must be documented (i.e. not ignored
    # when dumped).
    def documented?
      @options[:doc] != false
    end

    # Whether this schema is required. (opposite of optional?)
    def required?
      @options[:required] && !has_default?
    end

    # Whether this schema is optional.
    def optional?
      !required?
    end

    # Returns the default value used when this schema is missing.
    def default
      @options[:default]
    end

    # Returns whether this schema has a default value defined.
    def has_default?
      @options[:default] != nil
    end

    # Return whether the given +doc+ validates this schema.
    # You can get the validation error via {#last_error}.
    def validate?(doc)
      begin
        validate(doc)
        true
      rescue ValidationError => e
        @last_error = e
        false
      end
    end

    # Return the last validation error that happens during the
    # validation process. (set by {#validate?}).
    # Reset each time {#validate?} is called.
    attr_reader :last_error

    # Raise a {ValidationError} if the given +doc+ is not validated by this schema.
    # Returns true otherwise. A sanitized version of the document is built during
    # this process and you can access it via {#sanitized_object}.
    # Rewrite it in sub-classes.
    def validate(doc)
      raise NoMethodError, "overwrite me in sub-classes"
    end

    # Return +true+ or +false+ whether this schema validates the given +doc+.
    # If it does the document is updated in-place with the sanitized value.
    # This method does not raise a {ValidationError}. You can access the error
    # using {#last_error}.
    def validate!(doc)
      valid = validate?(doc)
      if valid
        sanitize_doc!(doc)
      end
      valid
    end

    # Sanitize the given +doc+ *in-place* if it validates this schema. The sanitized document
    # is returned. {ValidationError} is raised on error.
    def sanitize!(doc)
      validate(doc)
      sanitize_doc!(doc)
    end

    # A shortcut for {Respect.sanitize_doc!}.
    def sanitize_doc!(doc)
      Respect.sanitize_doc!(doc, self.sanitized_object)
    end

    # Returns a string containing a human-readable representation of this schema.
    def inspect
      "#<%s:0x%x %s>" % [
        self.class.name,
        self.object_id,
        instance_variables.map{|v| "#{v}=#{instance_variable_get(v).inspect}" }.join(", ")
      ]
    end

    # Returns a string containing ruby code defining this schema. Theoretically, you can
    # evaluate it and get the same schema afterward.
    def to_s
      DslDumper.new(self).dump
    end

    # Serialize this schema to a JSON string following the given +format+.
    def to_json(format = :org3)
      case format
      when :org3
        self.to_h(:org3).to_json
      else
        raise ArgumentError, "unknown format '#{format}'"
      end
    end

    # Return the options with no default value.
    # (Useful when writing a dumper)
    def non_default_options
      @options.select{|opt, value| value != self.class.default_options[opt] }
    end

    # Convert this schema to a hash representation following the given
    # +format+.
    def to_h(format = :org3)
      case format
      when :org3
        Org3Dumper.new(self).dump
      else
        raise ArgumentError, "unknown format '#{format}'"
      end
    end

    # Two schema are equal if they have the same type and the set of options.
    # Sub-class definition may include more attributes.
    def ==(other)
      self.class == other.class && @options == other.options
    end

    private

    # Used by sub-classes to update the formatted document.
    attr_writer :sanitized_object

  end
end
