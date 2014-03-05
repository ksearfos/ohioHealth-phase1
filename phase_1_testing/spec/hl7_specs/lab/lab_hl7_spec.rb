#!/bin/env ruby
@@proj_dir = File.expand_path( "../../../../", __FILE__ )   # phase_1_testing directory
require 'rspec'
require 'rspec/expectations'
require 'spec_helper'
require "#{@@proj_dir}/lib/hl7_utils"
require "#{@@proj_dir}/lib/extended_base_classes"

# == Describe the tests

def test_message( message )

  describe "Ohio Health Lab HL7" do
  
# == General message tests

    include_examples "General", message

# == MSH tests
    # Field names do not work unless converted to HL7::Segment::MSH
    context "MSH segment" do
      msh = message[0]    
      include_examples "MSH segment", msh
    end

# == ORC tests

    context "ORC segment", :pattern => 'any two characters' do
      message.children[:ORC].each do |orc|

        it "has Control ID of two characters" do
          orc.order_control.should match /^\w{2}$/
        end

      end
    end

# == OBR tests
    
    context "OBR segment" do
      message[:OBR].each do |obr|
        include_examples "OBR segment", obr, message
   
# == OBX tests

        context "-- OBX child" do
          obx_children = get_obx_of_obr( obr )
          obx_children.each do |obx|
            include_examples "OBX child", obx, obx.value_type

            # Consider checking elements 1 and 2 of this segment
            it "has Component Id in the correct format", :pattern => 'LA01' do
              obx.observation_id.should match /\^LA01$/
            end

            context "with value type of SN or NM" do
              if obx.value_type =~ /^(SN|NM)$/

                it "has valid Units", :pattern => "units in #{known_units.to_s}" do
                  known_units.should include obx.units
                end

                it "has Reference Range in the correct format", 
                  :pattern => 'a positive or negative number - another number' do
                  obx.references_range.should match /^(-?\d+\.?\d*-\d+\.?\d*)?$/
                end

                it "has a valid Abnormal Flag", :pattern => "a flag in #{abnormal_flags.to_s}" do
                  abnormal_flags.should include obx.abnormal_flags
                end

              end # End obx.value_type if
            end # End Values of Type SN or NM Context
          
          end # End of obx_children.each
        end  # End of OBX context

      end # End of message[:OBR].each
    end # End of OBR context

# == PID tests

    context "PID segment" do

      pid = message.children[:PID][0]
      include_examples "PID segment", pid 

      it "has Visit ID in the correct format", 
          :pattern => 'begins with an optional capital letter followed by numbers and ends with characters followed by "ACC"' do
        pid.account_number.should match /^[A-Z]?\d+\^/
        pid.account_number.should match /\^\w+ACC$/
      end

    end # End of PID Context

# == PV1 tests

    context "PV1 segment" do
      pv1 = message.children[:PV1][0]
      include_examples "PV1 segment", pv1, message.children[:PID][0]

      it "has Visit ID in the correct format", 
          :pattern => 'an optional capital letter followed by digits, ending with characters followed by "ACC"' do
        pv1.visit_number.should match /^[A-Z]?\d+\^/
        pv1.visit_number.should match /\^\w+ACC$/
      end

      it "has an Attending Doctor in the correct format", 
          :pattern => 'begins with an optional P followed by digits (or 000000 if there is no doctor assigned), ends with STARPROV or MGHPROV or MHMPROV' do
        pv1.attending_doctor.should match /^(P?[1-9]\d+|000000)\^/
        pv1.attending_doctor.should match /\^(STAR|MGH|MHM)PROV$/
      end

      it "has the same Attending and Referring Doctor", :pattern => 'fields should match unless Referring Doctor field is empty' do
        pv1.referring_doctor.should eq pv1.attending_doctor unless pv1.referring_doctor.empty?
      end

      it "does not have a single digit Patient Class", :pattern => 'a single digit' do
        pv1.patient_class.should_not match /^\d{1}$/
      end

      it "has a one or two digit Patient Type", :pattern => 'one or two digits' do
        pv1.patient_type.should match /^\d{1,2}$/
      end

      it "does not have a VIP Indicator", :pattern => 'this field should be empty' do
        pv1.vip_indicator.should be_empty
      end

    end # End of PV1 Context

    after(:each) do
      add_description( example.metadata[:full_description] )
      log_example_exception( example, message ) unless example.exception.nil?
    end

  end # End of Describe Ohio Health HL7 Message
end

# == Set up and run the tests

file_to_open = ENV["FILE"]
msg_list = get_test_data file_to_open
make_logger file_to_open, msg_list.size
run_hl7_tests msg_list
