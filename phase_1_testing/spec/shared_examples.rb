# == General tests
shared_examples "General" do |message|  
  it "has only one PID segment", :pattern => '' do
    message[:PID].size.should == 1
  end
  
  it "has only one PV1 segment", :pattern => '' do
    message[:PV1].size.should == 1
  end 
end

# == MSH tests
shared_examples "MSH segment" do |msh|
  it "has a valid Message Control ID", :pattern => 'P if the sender is MGH, T otherwise' do
    msh[10].should == ( msh[3].to_s =~ /MGH/ ? 'P' : 'T' )
  end
  
  it "has the correct event type", :pattern => 'ORU^R01 for orders, ADT^A08 otherwise' do
    msh[8].should == ( msh[2].to_s =~ /LAB|RAD/ ? 'ORU^R01' : 'ADT^A08' )
  end 
end

# == OBR tests (orders only)
shared_examples "OBR segment" do |obr|  
  it "has a Control Code containing only letters, numbers, and spaces", :pattern => '' do
    obr.control_code.should =~ /^[A-Za-z0-9][A-Za-z0-9 ]*/
  end
      
  it "has a valid ordering provider", :pattern => 'ID, then a name, and final field ends with PROV' do
    prov = obr.field(:ordering_provider)
    prov[1].should =~ /^[A-Z]?[0-9]+/
    HL7Test.is_name?( prov.components[1..4] ).should be_true
    prov[-1].should =~ /\w+PROV$/
  end
  
  it "has Result Status in the correct format", :pattern => '' do
    HL7Test::RESULT_STATUS.should include obr.result_status
  end

  it "has a correctly formatted observation date/time", :pattern => '' do
    HL7Test.is_datetime?( obr.observation_date_time ).should be_true
  end
end

# == PID tests
shared_examples "PID segment" do |pid|
  it "has a valid patient name", :pattern => '' do
    HL7Test.is_name?(pid.patient_name)
  end

  it "has a valid patient ID", :pattern => 'begins with digits and ends with characters + "01"' do
    ptid = pid.field(:patient_id)
    ptid[1].should_not =~ /\D/
    ptid[-1].should =~ /\w+01$/
  end

  it "has a valid patient birthdate", :pattern => '' do
    HL7Test.is_date?( pid.dob )
  end

  it "has a valid patient sex", :pattern => '' do
    HL7Test::SEXES.should include pid.sex
  end

  it "has a valid SSN", :pattern => '9 digits without dashes' do
    pid.ssn.should =~ /^\d{9}$/
  end  
end

# == ADT PID tests
shared_examples "ADT PID segment" do |pid|
  it "has a valid race", :pattern => "a number (corresponding to a list item)" do
    race = pid.race
    race.should =~ /^\d$/ unless race.empty? 
  end

  it "has a Country Code that matches the Address", :pattern => "" do
    unless pid.country_code.empty?
      pid.country_code.should == pid.address[7]
    end
  end

  it "has a valid Language", :pattern => "a three character language code" do
    lang = pid.langage
    lang.should =~ /^[A-z]{3}$/ unless lang.empty?
  end

  it "has a valid Marital Status", :pattern => "a single character" do
    mar = pid.marital_status
    mar.should =~ /^[A-Z]$/ unless mar.empty?
  end
end

# == PV1 tests
shared_examples "PV1 and PID segments" do |pv1, pid|
  it "have the correct format", :pattern => 'begin with an optional capital letter + numbers and end with "ACC"' do
    beg = /^[A-Z]?\d+/
    ending = /\w+ACC$/    
    acct = pid.field(:account_number)
    visit = pv1.field(:visit_number)
    
    acct[1].should =~ beg
    visit[1].should =~ beg
    acct[-1].should =~ ending
    visit[-1].should =~ ending
  end
  
  it "show the same visit ID/account number", :pattern => '' do
    pv1.visit_number.should == pid.account_number
  end
end

shared_examples "Lab/ADT PV1 segment" do |pv1|
  it "has the same Attending and Referring Doctor", :pattern => 'fields should match unless Referring Doctor is empty' do
    ref = pv1.referring_doctor
    pv1.attending_doctor.should == ref unless ref.empty?
  end
end