#------------------------------------------
#
# MODULE: HL7
#
# CLASS: HL7::Message
#
# DESC: Defines a single HL7 message
#       A message is all lines of text between a header (MSH segment) and some final segment of varying types.
#         A message comprises multiple lines of text, broken into segments and then fields.
#       The message class keeps track of the full text of the message, as well as breaking it into the various segments
#         as Segment objects. All Segments of the same type can be accessed by the type, as message[:TYPE]. 
#       A single message will always contain a single MSH (header) segment, and will generally contain a single PID
#         (patient info) segment and a single PV1 (visit info) segment. In addition there will be other segment types, often
#         at least one of which will occur multiple times.
#
# EXAMPLE: Message => "MSH|...\nPID|...\nPV1|...\nOBX|1|...\nOBX|2|..." / {:MSH=>Seg1,:PID=>Seg2,:PV1=>Seg3,:OBX=>Seg4}
#
# CLASS VARIABLES: none; uses HL7::SEG_DELIM
#
# READ-ONLY INSTANCE VARIABLES: segs lines msg id
#    @original_text [String]: stores entire message text
#    @lines [Array]: stores segment types in the order in which the lines appear in the message, e.g. [:MSH,:PID,:PV1,:OBX,:OBX]
#    @segments [Hash]: stores each segment as a Segment object linked to by type, e.g. { :MSH=>Seg1, :PID=>Seg2, ... }
#               ====>  will actually be objects of one of the Segment child classes
#    @id [String]: stores the message ID, also known as the message control ID or MSH.9
#
# CLASS METHODS: none
#
# INSTANCE METHODS:
#    new(message_text): creates new Message object based off of given text
#    to_s: returns String form of Message
#    [](key): returns Segment of given type
#    each(&block): loops through each segment type-object pair, executing given code
#    each_segment(&block): loops through each segment object, executing given code
#    method_missing: tries to call method on @segments (Hash)
#                    then tries to call method on @segments.values (Array)
#                    then tries to call method on @original_text (String)
#                    then gives up and throws exception
#    header: returns the message header, e.g. the MSH segment object
#    view_details: prints summary of important message information, such as message ID and patient name
#    encounter_details(section): returns details about the encounter referenced in this message, or just one section of the details
#    view_segments: displays readable version of the segments, headed by the type of the segment
#    important_details(type): allows quick access to the most commonly referenced message pieces
#    fetch_field(field): returns the value of the segment and field specified -- fetch_field("abc1") ==> self[:ABC][1]
#    segment_before(seg): returns name/type of the segment occurring directly before the one specified
#    segment_after(seg): returns the name/type of the segment occurring directly after the one specified
#
# CREATED BY: Kelli Searfos
#
# LAST UPDATED: 3/10/14 11:09 AM
#
# LAST TESTED: 3/4/14
#
#------------------------------------------

module HL7Test
   
  class Message  
    attr_accessor :segments, :lines, :original_text, :id

    # NAME: new
    # DESC: creates a new HL7::Message object from its original text
    # ARGS: 1
    #  message_text [String] - the text of the message
    # RETURNS:
    #  [HL7::Message] newly-created Message
    # EXAMPLE:
    #  HL7::Message.new( "MSH|a|b|c\nPID|a|b|c\nPV1|a|b|c\n" ) => new Message with MSH, PID, and PV1 segments 
    def initialize( message_text )
      @original_text = message_text
      @lines = []            # list of lines by their segment types => [ :MSH, :PID, :PV1, :OBX, :OBX, :OBX ]
      @segments = {}         # { :SEG_TYPE => Segment object }

      break_into_segments    # sets @lines, @segments
      
      @id = header.message_control_id
    end  

    # NAME: to_s
    # DESC: returns the message as a String object
    # ARGS: none 
    # RETURNS:
    #  [String] the message in textual form
    # EXAMPLE:
    #  message.to_s => "MSH|a|b|c\nPID|a|b|c\nPV1|a|b|c\n"      
    def to_s
      @original_text
    end

    # NAME: []
    # DESC: returns Segment of given type
    # ARGS: 1
    #  key [Symbol] - the type of segment, a key in the @segments hash
    # RETURNS:
    #  [Segment] the segment object -- generally actually in object of one of the Segment child classes
    # EXAMPLE:
    #  segment[:PID] => PID object      
    def []( key )
      @segments[key]
    end

    # NAME: each
    # DESC: performs actions for each segment type-object pair
    # ARGS: 1
    #  [code block] - the code to execute on each pair
    # RETURNS: nothing, unless specified in the code block
    # EXAMPLE:
    #  message.each{ |k,v| print k + ":" + v.to_s + " & "} => MSH:a|b|c & PID:a|b|c & PV1:a|b|c   
    def each
      @segments.each_pair{ |seg_type,seg_obj| yield(seg_type,seg_obj) }  
    end

    # NAME: each_segment
    # DESC: performs actions for each segment in the message
    # ARGS: 1
    #  [code block] - the code to execute on each line
    # RETURNS: nothing, unless specified in the code block
    # EXAMPLE:
    #  message.each_segment{ |s| print s[5] + ' & ' } => msh5 & pid5 & pv15   
    def each_segment
      @segments.each_value{ |seg_obj| yield(seg_obj) }  
    end

    # NAME: method_missing
    # DESC: handles methods not defined for the class
    # ARGS: 1+
    #  sym [Symbol] - symbol representing the name of the method called
    #  *args - all arguments passed to the method call
    #  [code block] - optional code block passed to the method call
    # RETURNS: depends on handling
    #     ==>  first checks @segments for a matching method
    #     ==>  second checks @segments.values for a matching method
    #     ==>  third checks @original_text for a matching method
    #     ==>  then gives up and throws an Exception
    # EXAMPLE:
    #  message.size => 3 (calls @segments.size)
    #  message.index(PIDobject) => 1 (calls @segments.values.index)
    #  message.gsub( "*", "\n|^" ) => "MSH*a*b*c*PID*a*b*c*PV1*a*b*c" (calls @original_text.gsub)
    #  message.fake_method => throws NoMethodError    
    def method_missing( sym, *args, &block )
      if Hash.method_defined?( sym )
        @segments.send( sym, *args )
      elsif Array.method_defined?( sym )
        @segments.values.send( sym, *args )
      elsif String.method_defined?( sym )
        @original_text.send( sym, *args )
      else
        super
      end
    end

    # NAME: header
    # DESC: returns the message header (the MSH segment) as a string
    # ARGS: none
    # RETURNS:
    #  [String] the text of the header
    # EXAMPLE:
    #  message.header => "MSH|^~\&|HLAB|RMH|||20140128041144||ORU^R01|201401280411444405|T|2.4" 
    def header
      @segments[:MSH]
    end

    # NAME: view_details
    # DESC: displays crucial information about the message, clearly labelled
    # ARGS: none
    # RETURNS: nothing; writes to stdout
    # EXAMPLE:
    #  message.view_details => Message ID: 12345
    #                          Sent at: 05/15/2013 11:45 AM
    #                          Patient ID: 12345
    #                          Patient Name: John W Smith
    #                          Visit Number: 12345
    def view_details
      puts "Message ID: " + @id
      puts "Sent at: " + header.date_time.as_datetime
      puts "Patient ID: " + important_details( :patient_id )
      puts "Patient Name: " + important_details( :patient_name )
      puts "Visit Number: " + important_details( :visit_number )
      puts ""
    end

    # NAME: encounter_details
    # DESC: collects crucial information about the visit described in the message
    # ARGS: 0-1
    #  section [Symbol] - identifier of the specific type of details desired (optional) 
    # RETURNS:
    #  [Hash or String] full details, in a hash linking to the detail type (if no section specified), or
    #                   just the specific section desired, as a string -- returns full details (Hash) by default
    # EXAMPLE:
    #  message.encounter_details() => { :ID => "12345", :NAME => "SMITH^JOHN", :VISIT => "01834" }
    #  message.encounter_details(:ID) => "12345"
    def encounter_details( section = "" )
      me = { :ID => important_details( :patient_id ),
             :NAME => important_details( :patient_name ),
             :VISIT => important_details( :visit_number ) }
             
      ( section.empty? ? me : me[section.to_sym] )
    end

    # NAME: view_segments
    # DESC: displays readable version of the segments, headed by the type of the segment
    # ARGS: none
    # RETURNS: nothing; writes to stdout
    # EXAMPLE:
    #  message.view_segments => MSH: ^~\&|sys|org|||201401281346
    #                           PID: abc|123456||SMITH^JOHN^^IV|||19840106
    #                           PV1: |O|^^||||12345^Doe^Doug^E^^Dr|12345^Doe^Doug^E^^Dr
    #                           OBX: 1|TX|||I like chocolate this much:
    #                           OBX: 2|TX|||<-------------------------->                        
    def view_segments
      each{ |type,obj| 
        obj.lines.each{ |line| puts type.to_s + ": " + line }
      }
    end

    # NAME: fetch_field
    # DESC: returns array of fields at given index of given segment (in all segments of this type!)
    # ARGS: 1
    #  field [String] - the 3-letter segment type followed by the index of the field, e.g. "pid5"
    # RETURNS:
    #  [Array] the values of the fields for each line of the segment type
    #      ==> this was created for easy handling of segments that have more than one occurrence in a message
    # EXAMPLE:
    #  1-line segment: message.fetch_field("pid1") => [ "12345" ]
    #  2-line segment: message.fetch_field("obx2") => [ "20131223", "20131211" ]
    def fetch_field( field )
      seg = field[0...3]   # first three charcters, the name of the segment - have to do it this way for PV1 etc.
      f = field[3..-1]     # remaining 1-3 characters, the number of the field

      seg_obj = @segments[seg.upcase.to_sym]  # segment expected to be an uppercase symbol
      return [] if seg_obj.nil?
      seg_obj.all_fields( f.to_i )
    end

    # NAME: important_details
    # DESC: grabs specified info from collection of the most commonly referenced message pieces
    # ARGS: 1
    #  type [Symbol] - the type of information desired
    # RETURNS:
    #  [String] the value requested -- if type is not recognized, returns nil and outputs message to stdout
    #       ==> recognizes :patient_id, :patient_name, :visit_number, :message_header, :message_id
    #       ==> this was created to quickly reference to important data without having to know the segment type/field ID
    # EXAMPLE:
    #  message.important_details(:patient_name) => "John W Smith"
    #  message.important_details(:favorite_color) => nil; stdout shows 'I don't know where to look to find the favorite_color.'
    def important_details( type )
      case type
        when :patient_id then @segments[:PID][3].first
        when :patient_name then @segments[:PID][5].as_name
        when :visit_number then @segments[:PV1][19].first
        when :message_header then header
        when :message_id then @id
        else
          puts "I don't know where to look in the message to find the #{type}."
          return nil
      end
    end

    # NAME: segment_before
    # DESC: identifies type of segment occurring in the message directly before (all lines of) the specified type
    # ARGS: 1
    #  seg [Symbol] - the segment whose predecessor we seek
    # RETURNS:
    #  [Symbol] the type of the preceeding segment
    # EXAMPLE:
    #  message.segment_before(:PID) => :MSH  
    def segment_before( seg )
      i = @lines.index( seg )
      @lines[i-1]
    end

    # NAME: segment_after
    # DESC: identifies type of segment occurring in the message directly after (all lines of) the specified type
    # ARGS: 1
    #  seg [Symbol] - the segment whose successor we seek
    # RETURNS:
    #  [Symbol] the type of the succeeding segment
    # EXAMPLE:
    #  message.segment_after(:PID) => :PV1    
    def segment_after( seg )
      sinel = @lines.clone.reverse   # yeah, super-clever name, I know
      i = sinel.index( seg )
      sinel[i-1]    # before seg in reverse array == after the seg in original array
    end
    
    private
    
    def break_into_segments    
      segs = @original_text.split( SEG_DELIM )    # all segments, including the type found in field 0
      text = {}
      segs.each{ |seg|
        end_of_type = seg.index( FIELD_DELIM )    # first occurrence of delimiter => end of the type field
        type = seg[0...end_of_type]
        body = seg[end_of_type+1..-1]
        is_hdr = ( type =~ HDR )                  # is this a header line?        
        type = ( is_hdr ? :MSH : type.upcase.to_sym )
        
        # save order of original segments as @lines
        #+  e.g. [:MSH, :PID, :PV1, :OBR, :OBX, :NTE]
        @lines << type
        
        text[type] ? text[type] << body : text[type] = [body]
      }

      @lines.uniq!
      
      # now convert text into segment object of specific type (child class) and add to @segments
      #+  e.g. { :MSH => mshObj, :PID => pidObj, :OBX => obxObj }
      # let objects track multiple occurrences -- 7 obx segments is still 1 OBX object
      text.each{ |type,body|
        line = body.join( SEG_DELIM )
        cl = HL7.const_get( type )
        @segments[type] = cl.new( line )  
      }
    end
  end
end