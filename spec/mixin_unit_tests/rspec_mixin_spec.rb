# passed testing 4/7
$LOAD_PATH.unshift File.expand_path("../../..", __FILE__)   # project directory
$LOAD_PATH.unshift File.dirname(__FILE__)
require 'spec_helper'

describe "RSpecMixin" do
  
  before(:all) do
  	@test_runner = SpecHelperRspecClass.new
  	errors = %w(error1 error2)
  	$flagged = { $lab_message => errors }
  	@records_array = @test_runner.compile_flagged_records_into_array
  end
  
  describe "#compile_flagged_records_into_array" do
    it "creates an array of spreadsheet rows", :detail => "an Array of Arrays" do
      @records_array.should be_a Array
      @records_array.first.should be_a Array
    end
    
    it "has a header and one row for each message" do
      @records_array.size.should == 2
    end
    
    context "the header row" do
      expected_header = ["MRN", "PATIENT NAME", "DOB", "ACCOUNT #", "PROCEDURE NAME", "DATE/TIME", "ERROR1", "ERROR2"] 
      it "is #{expected_header}" do
        @records_array.first.should == expected_header
      end  
    end
    
    context "a message row" do
      it "contains message information and exception information", :detail => "PASSED/FAILED" do
        row = @records_array.last
        row.each { |element| element.should be_a String }
        row[6..-1].each { |element| (element == "PASSED" || element == "FAILED").should be_true }
      end
      
      it "has 6 columns of record information and 2 columns of error information", :detail => "8 columns" do
        @records_array.last.size.should == 8
      end
    end    
  end

end
