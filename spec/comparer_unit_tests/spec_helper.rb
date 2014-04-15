require 'test_classes'
require 'lib/OHmodule/OhioHealthUtilities'
require 'rspec'
require 'rspec/expectations'

RSpec.configure do |c|
  c.fail_fast = true
  c.formatter = :documentation
end

# file = HL7::FileHandler.new("#{File.dirname(__FILE__)}/test_data.txt")
# $messages = {}
# file.records.map do |record|
  # $messages[record[:PID].patient_name] = record
# end
$criteria = { obx_potassium:Proc.new { |rec| OhioHealthUtilities.is_val?(rec,"obx3","K+^Potassium") },
              obx_sodium:Proc.new { |rec| OhioHealthUtilities.is_val?(rec,"obx3","URNA^Sodium,UR") },
              obx_chloride:Proc.new { |rec| OhioHealthUtilities.is_val?(rec,"obx3","CL^Chloride") },
              obx_fake:Proc.new { |rec| OhioHealthUtilities.is_val?(rec,"obx3","FAKE^Fictitious Analyte") },
              male:Proc.new { |rec| OhioHealthUtilities.is_val?(rec, "pid8", "M") },
              female:Proc.new { |rec| OhioHealthUtilities.is_val?(rec, "pid8", "F") }
            }
$maps = [ RecordCriteriaMap.new($messages["Palmer^Lois^G"], $criteria.clone), 
          RecordCriteriaMap.new($messages["Palmer^Lois^DUPLICATE"], $criteria.clone),
          RecordCriteriaMap.new($messages["Smith^John^W"], $criteria.clone),
          RecordCriteriaMap.new($messages["Palmer^Lois^REDUNDANT"], $criteria.clone)
        ]

# class RecordComparer
  # attr_reader :used_records, :unused_records, :matched_criteria, :minimum_size
# 
  # # add accessors to private functions
  # def call_remove_records_with_duplicate_criteria
    # remove_records_with_duplicate_criteria
  # end
#   
  # def call_remove_redundancies
    # remove_redundancies
  # end
#   
  # def call_supplement_chosen
    # supplement_chosen
  # end
#   
  # def call_unchoose(*records)
    # unchoose(*records)
  # end
# end
# 
# # pass in names as either Last^First^MI or, in the case of the 3 Lois Palmers, as just :DUPLICATE or :REDUNDANT
# def deselect(comparer,*names)
  # names.each do |name| 
    # name !~ /\w+^\w+/ ? key = "Palmer^Lois^#{name}" : key = name
    # comparer.call_unchoose($messages[key]) 
  # end
# end
# 
# def should_only_use_one_of_the_duplicates(results)
  # if results.include?($messages["Palmer^Lois^G"])
    # results.should_not include $messages["Palmer^Lois^DUPLICATE"]
  # else  # results include Lois G Palmer
    # results.should_not include $messages["Palmer^Lois^G"]
  # end
# end