#!/bin/env ruby

$proj_dir = File.expand_path( "../../../", __FILE__ )   # phase_1_testing directory
require 'rspec'
require "#{$proj_dir}/lib/hl7_utils"
require "#{$proj_dir}/lib/extended_base_classes"
require 'set'


# == Methods and Objects we will use
puts DateTime.parse('20010203040506').to_s + "HAHA"
sleep 10

known_units = ["","%","/hpf","/lpf","/mcL","IU/mL","K/mcL","M/mcL","PG",
               "U","U/L","U/mL","fL","g/dL","h","lbs","log IU/mL",
               "mIU/mL","mL","mL/min/1.73 m2","mcIU/mL","mcg/dL",
               "mcg/mL FEU","mg/24 h","mg/L","mg/dL","mg/g crea",
               "mlU/mL","mm Hg","mm/hr","mmol/L","ng/dL","ng/mL",
               "nmol/L","pH units","pg/mL","seconds","titer",
               "weeks","years"]

abnormal_flags = ["","I","CH","CL","H","L","A","U","N","C"]

def get_obx_of_obr( obr )
  obr.children.select { |s|
          s.is_a? HL7::Message::Segment::OBX }
end

# == Describe the tests

describe "Ohio Health HL7" do

# == Get data to test

  raw_hl7 = ""
  File.open( "#{$proj_dir}/resources/manifest_lab_out_short", "rb" ) do |f|
    #blank lines cause HL7 Parse Error...
    #and ASCII line endings cause UTF-8 Error..
    while s = f.gets do
      t = s.force_encoding("binary").encode("utf-8", 
          :invalid => :replace, :undef => :replace)
      raw_hl7 << t.chomp + "\n"
    end
  end

  msg_list = orig_hl7_by_record raw_hl7

# == Loop through each message and test the data

  msg_list.each do |message|

# == General message tests

    it "has only one PID per message" do
      message.children[:PID].size.should == 1
    end

    it "has only one PV1 per message" do
      message.children[:PV1].size.should == 1
    end

# == MSH tests
    # Field names do not work unless converted to HL7::Segment::MSH
    context "MSH segment" do
      msh = message[0]

      it "has MSH segments with the correct Event format" do
        msh.e8.should match /^ORU\^R01$/
      end

      it "has a valid Message Control ID" do
        if msh.e3 =~ /MGH/
          msh.e10.should match /^P$/
        else
          msh.e10.should match /^T$/
        end
      end

      it "has the correct Processing ID" do
        if msh.e3 =~ /MGH/
          msh.e11.should match /^2.3$/
        else
          msh.e11.should match /^2.4$/
        end
      end

    end

# == ORC tests

    context "ORC segment" do
      message[:ORC].each do |orc|

        it "has Control ID of two characters" do
          orc.order_control.should match /^\w{2}$/
        end

      end
    end

# == OBR tests
    
    context "OBR segment" do
      message[:OBR].each do |obr|

        it "has Control Code containing only letters, numbers, and spaces" do
          obr.filler_order_number.should match /^[A-Za-z0-9 ]+/
        end

        it "has Procedure ID in the correct format" do
          obr.universal_service_id.should match /^[A-Z0-9]+\^/
          if message[0].e3 =~ /MGH/
            obr.universal_service_id.should match /\^ECAREEAP$/
          else
            obr.universal_service_id.should match /\^OHHOREAP$/
          end
        end
      
        # Consider adding test for provider title e.g. MD, DO, etc...
        it "has Ordering Provider in the correct format" do
          obr.ordering_provider.should match /^[A-Z0-9]+\^[A-Z a-z\-]+\^[A-Z a-z]+\^[A-Z]?\^/
          obr.ordering_provider.should match /\^\w+PROV$/
        end

        # Make sure all possible status markers are in regex
        it "has Result Status in the correct format" do
          obr.result_status.should match /^[DFNOSWPCXRUI]$/
        end

        it "has Date/Time values in the correct format" do
          # yyyyMMddHHmm
          obr.observation_date.should match /^(19|20)\d\d(0[1-9]|1[012])(0[1-9]|[12][0-9]|3[01])((0|1)[0-9]|2[0-3])(0[0-9]|[1-5][0-9])$/
        end

        it "has Results Status Date that is the same as the Observation Date?" do
          obr.results_status_change_date.should eq obr.observation_date
        end
   
# == OBX tests

        context "-- OBX child" do
          obx_children = get_obx_of_obr( obr )
          obx_children.each do |obx|

            # Consider checking elements 1 and 2 of this segment
            it "has Component Id in the correct format" do
              obx.observation_id.should match /\^LA01$/
            end

            value_type = obx.value_type
            it "has an appropriate Observation Value for Value Type #{value_type}" do
              if value_type =~ /^SN$/
                  obx.observation_value.should match /^[-<>]?[=]? ?[\+-]? ?\d+[\.\+\/:-]?\d* ?$/
              elsif value_type =~ /^NM$/
                  obx.observation_value.should match /^ ?[\+-]? ?\d+\.?\d* ?$/
              elsif value_type =~ /^TX$/
                obx.observation_value.should_not match /^[<>]?[=]? ?[\+-]? ?\d+[\.\+\/:-]?\d* ?$/
              elsif value_type =~ /^TS$/
                # MM-dd-yyyy hh:mm
                obx.observation_value.should match /^(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])-(19|20)\d\d ((0|1)[0-9]|2[0-3]):(0[0-9]|[1-5][0-9]) $/
              else
                fail
              end
            end

            context "with value type of SN or NM" do
              if obx.value_type =~ /^(SN|NM)$/

                it "has valid Units" do
                  known_units.should include obx.units
                end

                it "has Reference Range in the correct format" do
                  obx.references_range.should match /^(-?\d+\.?\d*-\d+\.?\d*)?$/
                end

                it "has a valid Abnormal Flag" do
                  abnormal_flags.should include obx.abnormal_flags
                end

              end # End obx.value_type if
            end # End Values of Type SN or NM Context
          
          end # End of obx_children.each
        end  # End of OBR context

      end # End of message[:OBR].each
    end # End of OBR context

# == PID tests

    context "PID segment" do
      pid = message[:PID][0]

      it "has PID segments with the correct Patient ID format" do
        pid.patient_id_list.should match /^\d*\^/
        pid.patient_id_list.should match /\^\w+01$/
      end

      it "has Patient Name in the correct format" do
        # Lastname^Firstname^I^JR.|SR.|RomanNumeral
        pid.patient_name.should match /^\w+([- ]{1}\w+)*\^\w+(\^|\^[A-Z])?(\^((JR|SR)\.|((II|III|IV|V))))?$/
      end

      it "has Date of Birth in the correct format" do
        # yyyyMMdd
        pid.patient_dob.should match /^(19|20)\d\d(0[1-9]|1[012])(0[1-9]|[12][0-9]|3[01])$/
      end

      it "has Sex in the correct format" do
        # F|M|O|U|A|N|C
        pid.admin_sex.should match /^[FMOUANC]$/
      end

      it "has Visit ID in the correct format" do
        pid.account_number.should match /^[A-Z]?\d+\^/
        pid.account_number.should match /\^\w+ACC$/
      end

      it "has SSN in the correct format" do
        pid.social_security_num.should match /^\d{9}$/
      end

    end # End of PID Context

# == PV1 tests

    context "PV1 segment" do
       pv1 = message.children[:PV1][0]

      it "has Visit ID in the correct format" do
        pv1.visit_number.should match /^[A-Z]?\d+\^/
        pv1.visit_number.should match /\^\w+ACC$/
      end

      it "has Visit ID that matches PID Visit ID" do
        pid = message.children[:PID][0]
        pv1.visit_number.should eq pid.account_number 
      end

      it "has an Attending Doctor in the correct format" do
        pv1.attending_doctor.should match /^P?[1-9]\d+\^/
        pv1.attending_doctor.should match /\^(STAR|MGH|MHM)PROV$/
      end

      it "has the same Attending and Referring Doctor" do
        pv1.referring_doctor.should eq pv1.attending_doctor unless pv1.referring_doctor.empty?
      end

      it "does not have a single digit Patient Class" do
        pv1.patient_class.should_not match /^\d{1}$/
      end

      it "has a one or two digit Patient Type" do
        pv1.patient_type.should match /^\d{1,2}$/
      end

      it "does not have a VIP Indicator" do
        pv1.vip_indicator.should be_empty
      end

    end # End of PV1 Context

    after(:each) do
      #puts "\nTest executed!"
      #puts "\nError found in:
            #{example.example_group.description} while testing it #{example.description}.
           # Message Tested:\n #{message.to_s}" unless example.exception.nil?
    end
    
  end # End of msg_list.each
end # End of Describe Ohio Health HL7 Message


# == Helper methods 

def get_units( obx_list )
  unit_set = Set.new
  obx_list.each do |obx|
    if obx.value_type =~ /^(SN|NM)$/
      unit_set.add obx.units.to_s
    end
  end
  unit_set.each do |unit|
    puts unit.to_s
  end
  unit_set
end
