#!/bin/env ruby

require 'rspec'
require 'hl7_utils'
require 'extended_base_classes'

describe File do
  before(:all) do
    raw_hl7 = ""
    File.open( "../../resources/manifest_lab_out_short", 'rb' ) do |f|
      #blank lines cause HL7 Parse Error...
      #and ASCII line endings cause UTF-8 Error..
      while s = f.gets do
        t = s.force_encoding("binary").encode('utf-8', 
            :invalid => :replace, :undef => :replace)
        raw_hl7 << t.chomp + "\n"
      end
    end

    @msg_list = hl7_by_record raw_hl7
  end
  
  it 'has MSH segments with the correct Event format' do
    @msg_list.each do |message|
      puts "Message: \n" + message.to_s
      p message.to_s
      message[:MSH].each do |s|
          puts s.to_s
          puts s.e8.to_s
          s.e9.should match /ORU\^R01/
      end
    end
  end
  
  it 'has PID segments with the correct Patient ID format' do
    @msg_list.each do |message|
      message.children[:PID].each do |s|
        s.e3.should match /^\d*\^/
        s.e3.should match /\^\w+01$/
      end
    end
  end

  it 'has ORC segments with Control ID of two characters' do
    @msg_list.each do |message|
      children[:ORC].each do |s|
        s.e1.should match /^\w{2}$/
      end
    end
  end

  it 'has OBR Control Code containing only letters, numbers, and spaces' do
    @msg_list[:OBR].each do |s|
      s.e3.should match /^[A-Za-z0-9 ]*/
    end
  end

  it 'has OBR Procedure ID in the correct format' do
    @msg[:MSH].each do |s|
      #p s.to_s
      fail
    end
  end

  after(:each) do
    puts "\nTest executed!"
  end
end
