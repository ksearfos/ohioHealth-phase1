#------------------------------------------
#
# MODULE: HL7
#
# CLASS: HL7::Segment
#
# DESC: Defines a segment in a HL7 message
#       A segment is essentially a single line of text, headed with a type (3 capital letters, e.g. 'PID')
#         and separated into fields with pipes (|)
#       The segment class keeps track of the full text of the segment minus the type, an array of its fields,
#         and any "child" segments described as segments of the same type. A single segment object will exist
#         for each line in the message, but the Message itself will only link to the first segment of any
#         given type--subsequent lines will be treated as children and manipulated through the parent segment
#       For example, if there are 4 OBX segments in one message: MESSAGE => OBX1 => OBX2, OBX3, OBX4
#       A segment will generally contain multiple fields
#
# EXAMPLE: PID => "|12345||SMITH^JOHN||19631017|M|||" / [,"12345",,"SMITH^JOHN",,"19631017","M",,]
#
# READ-ONLY INSTANCE VARIABLES:
#    @original_text [String]: stores all lines of this segment as they were originally, e.g. "|12345||SMITH^JOHN||19631017|M|||"
#    @fields [Array]: stores each field in the segment as a HL7::Field object, e.g. [nil,F1,nil,F2,nil,F3,F4,nil,nil]
#             ====>   one array per line, so a 2-line segment would have @fields [ [F1,nil,F2,F3], [F1,F2,F3,F4] ]
#    @lines [Array]: stores the original text for each line containing a segment of this type, minus the type itself
#             ====>  for example, for 2 OBX segments: @lines = [ "1|TX|My favorite number is:", "2|NM|42" ]
#    @size [Integer]: the number of lines/segments of this type in the message; basically @lines.size
#
# PRIVATE INSTANCE VARIABLES:
#    @default [Hash]: stores the default values of @lines/@fields to use in certain cases
#             ====>   this is always the first such value, e.g. { [:text] = @lines[0], [:fields] = @fields[0] }
#
# CLASS METHODS: none
#
# INSTANCE METHODS:
#    new(segment_text): creates new Segment object based off of given text
#    to_s: returns String form of Segment (including child segments)
#    [](which): returns Field with given name or at given index - count starts at 1
#    field(which): alias for []
#    each(&block): if there is >1 line in the segment, loops through each line in the segment, executing given code
#                  otherwise loops through each field, executing given code
#             ==>  for most Segments, this will do the same thing as each_field
#    each_line(&block): loops through each line, executing given code
#    each_field(&block): loops through each field in the first line, executing given code
#    every_field(&block): loops through each field in the entire segment, executing given code
#    method_missing: tries to reference a field with the name of the method, if segment has a type
#                    then tries to call method on @fields[0] (Array)
#                    then tries to call method on @lines[0] (String)
#                    then gives up and throws exception
#    view: prints fields to stdout in readable form, headed by component index
#
# CREATED BY: Kelli Searfos
#
# LAST UPDATED: 3/6/14 9:38 AM
#
# LAST TESTED: 3/4/14
#
#------------------------------------------

module HL7Test 

  # has value of first segment in record of this type
  # if there are others, those are saved as Segment objects in @child_segs
  # e.g. if there are 3 OBX segments,
  #   self = Segment( obx1 )
  #   self.child_segs = [ Segment(obx2), Segment(obx3) ]  
  class Segment    
    @@no_index_val = -1
    
    attr_reader :lines, :original_text, :size, :fields
    
    # NAME: new
    # DESC: creates a new HL7::Segment object from its original text
    # ARGS: 1
    #  segment_text [String] - the text of the segment, with or without its Type field
    # RETURNS:
    #  [HL7::Segment] newly-created Segment
    # EXAMPLE:
    #  HL7::Segment.new( "PID|a|b|c" ) => new Segment with text "a|b|c" and fields ["a","b","c"]
    def initialize( segment_text )
      @original_text = segment_text
      @lines = @original_text.split( SEG_DELIM )    # an array of strings
      @lines.map!{ |l| l = remove_name_field(l) }   # remove type fields, if present, for standardized format
      @size = @lines.size
      
      @fields = []          # all fields in each line, as objects, e.g. [ [f1,nil,f2,nil,f3], [f1,f2,f3,nil,f4] ]
      break_into_fields     # sets @fields
      @default = { :text => @lines.first, :fields => @fields.first }    
    end
    
    def to_s
      @original_text
    end
    
    # NAME: each
    # DESC: performs actions for each line--if there are more than 1--or each field
    # ARGS: 1
    #  [code block] - the code to execute on each line
    # RETURNS: nothing, unless specified in the code block
    # EXAMPLE:
    #  1-line segment: segment.each{ |s| print s + ' & ' } => a & b & c
    #  2-line segment: segment.each{ |s| print s + ' & ' } => a|b|c & a2|b2|c2 
    def each(&block)
      @size == 1 ? each_field(&block) : each_line(&block)  
    end
    
    # NAME: each_line
    # DESC: performs actions for each line of the segment
    # ARGS: 1
    #  [code block] - the code to execute on each line
    # RETURNS: nothing, unless specified in the code block
    # EXAMPLE:
    #  segment.each_line{ |l| print l.to_s + ' & ' } => a|b|c & a2|b2|c2 & a3|b3|c3 
    def each_line
      @lines.each{ |l| yield(l) }
    end

    # NAME: each_field
    # DESC: performs actions for each field of the first line of the segment
    # ARGS: 1
    #  [code block] - the code to execute on each line
    # RETURNS: nothing, unless specified in the code block
    # EXAMPLE:
    #  segment.each_field{ |f| print f.to_s + ' & ' } => a & b & c     
    def each_field
      @default[:fields].each{ |f_obj| yield(f_obj) }
    end

    # NAME: every_field
    # DESC: performs actions for each field of each line of the segment
    # ARGS: 1
    #  [code block] - the code to execute on each line
    # RETURNS: nothing, unless specified in the code block
    # EXAMPLE:
    #  segment.every_field{ |f| print f.to_s + ' & ' } => a & b & c & a2 & b2 & c2     
    def every_field
      @fields.flatten.each{ |f_obj| yield(f_obj) }
    end

    # NAME: []
    # DESC: returns field at given index (in this line only!)
    # ARGS: 1
    #  index [Integer/Symbol/String] - the index or name of the field we want -- count starts at 1
    # RETURNS:
    #  [String] the value of the field
    # EXAMPLE:
    #  segment[2] => "b"
    #  segment[:beta] => "b"  
    # ALIASES: field()  
    def [](which)
      field(which)
    end
    
    # NAME: field
    # DESC: returns field at given index (in this line only!)
    # ARGS: 1
    #  index [Integer/Symbol/String] - the index or name of the field we want -- count starts at 1
    # RETURNS:
    #  [String] the value of the field
    # EXAMPLE:
    #  segment.field(2) => "b"
    #  segment.field(:beta) => "b" 
    def field( which )
      i = field_index(which)
      i == @@no_index_val ? nil : @default[:fields][i]
    end
    
    # NAME: all_fields
    # DESC: returns array of fields at given index (in this line and all children!)
    # ARGS: 1
    #  index [Integer/Symbol/String] - the index or name of the field we want -- count starts at 1
    # RETURNS:
    #  [Array] the value of the field for each line
    #      ==>  if there is only one line of this segment's type, returns field() IN AN ARRAY
    # EXAMPLE:
    #  segment.all_fields(2) => [ "b", "b2", "b3" ]
    #  segment.all_fields(:beta) => [ "b", "b2", "b3" ] 
    def all_fields( which )
      i = field_index(which)
      
      all = []
      all << @fields.map{ |row| row[i] } if i != @@no_index_val
      all
    end
    
    # NAME: method_missing
    # DESC: handles methods not defined for the class
    # ARGS: 1+
    #  sym [Symbol] - symbol representing the name of the method called
    #  *args - all arguments passed to the method call
    #  [code block] - optional code block passed to the method call
    # RETURNS: depends on handling
    #     ==>  first tries to call the method for @fields
    #     ==>  then gives up and throws an Exception
    # EXAMPLE:
    #  segment.patient_name => "SMITH^JOHN" (calls field(:patient_name) )
    #  segment.5 => throws NoMethodError (5 is a value in @@fields_by_index, NOT a key)
    #  segment.fake_method => throws NoMethodError
    def method_missing( sym, *args, &block )
      if self.class.is_eigenclass? && field_index_maps.has_key?( sym )
          field( sym )
      elsif Array.method_defined?( sym )       # a Segment is generally a group of fields
        @default[:fields].send( sym, *args )
      elsif String.method_defined?( sym )   # but we might just want String stuff, like match() or gsub
        @default[:text].send( sym, *args )
      else
        super
      end
    end

    # NAME: view
    # DESC: displays the fields, for each line, clearly enumerated
    # ARGS: none
    # RETURNS: nothing; writes to stdout
    # EXAMPLE:
    #  1-line segment: segment.view => 1:a, 2:b, 3:c
    #  2-line segment: segment.view => 1:a, 2:b, 3:c
    #                                  1:a2, 2:b2, 3:c2
    def view
      @fields.each{ |row|
        for i in 1..row.size
          val = row[i-1] 
          print "#{i}:"
          print val if val    # not nil
          print ", " unless i == row.size
        end
        
        puts ""
      }
    end
    
    private
    
    def break_into_fields
      @lines.each{ |l|
        field_ary = l.split( FIELD_DELIM )
        @fields << field_ary.map{ |f| f.empty? ? nil : Field.new( f ) }   # an array of arrays
      }
    end

    def remove_name_field( field_text )
        i = field_text.index( /^#{type}\|/ )
        
        # i is either 0 (found a name field) or nil (no name field)
        # if there is a name field, the rest of the text starts at index 4 -- it's preceded by 'XYZ|'
        i ? field_text[4..-1] : field_text
    end
    
    # NAME: field_index
    # DESC: returns index for given field
    # ARGS: 1
    #  which [Integer/Symbol/String] - the index or name of the field we want -- count starts at 1
    # RETURNS:
    #  [String] the index of the field
    # EXAMPLE:
    #  self.field_index(2) => 1
    #  self.field_index(:beta) => 1 
    def field_index( which )
      if which.is_a?( Integer )
        which - 1     # field count starts at 1, but array index starts at 0
      elsif ( which.is_a?(String) || which.is_a?(Symbol) ) && self.class.is_eigenclass?
        s = which.downcase.to_sym
        i = field_index_maps[s]
        i ? i - 1 : @@no_index_val
      else
        puts "Cannot find field of type #{which.class}"
        @@no_index_val
      end
    end
    
  end

end