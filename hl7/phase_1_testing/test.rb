require "#{__FILE__}\\..\\hl7_utils.rb"
require './HL7ProcsMod.rb'

# require all utility files, stored in [HEAD]/utilities
DEL = "\\"       # windows-style file path delimiter
pts = __FILE__.split( '/' )
pts.pop(2)
util_path = pts.join( DEL ) + DEL + 'utilities' 
util = Dir.new( util_path )   # all helper functions
util.entries.each{ |f| require util_path + DEL + f if f.include?( '.rb' ) }

# FILE = "C:/Users/Owner/Documents/manifest_lab_out.txt"
FILE = "C:/Users/Owner/Documents/manifest_lab_short_unix.txt"
# FILE = "C:/Users/Owner/Documents/testing_data.txt"
msg = get_hl7( FILE )
all_hl7 = hl7_by_record( msg )

rec = all_hl7[0]
puts HL7Procs::ATT_EQ_REF.call(rec)
# puts HL7Procs::fields_are_same?( rec, "pv17", "pv18" )