# == General tests
shared_examples "every HL7 message" do   
  it "has only one PID segment", :pattern => "only one PID line" do
    logic = Proc.new{ |msg| msg[:PID].size == 1 }
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end
  
  it "has only one PV1 segment", :pattern => "only one PV1 line"  do
    logic = Proc.new{ |msg| msg[:PV1].size == 1 }
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end 
end

# == MSH tests
shared_examples "a normal MSH segment" do
  it "has a valid Message Control ID", :pattern => 'P if the sender is MGH, T otherwise' do
    logic = Proc.new{ |msg|
      msh = msg[:MSH]
      if msh[3].to_s =~ /MGH/ then msh[10] == 'P'
      else msh[10] == 'T'
      end
    }
    
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end
  
  it "has the correct event type", :pattern => 'ORU^R01 for orders, ADT^A08 otherwise' do
    logic = Proc.new{ |msg|
      msh = msg[:MSH]
      if msg.type == :adt then msh.event == 'ADT^A08'
      else msh.event == 'ORU^R01'
      end
    }
    
    @failed = pass?( messages, logic )
    @failed.should be_empty    
  end 
end

# == ORC tests (orders only)
shared_examples "a normal ORC segment" do  
  it "only appears once per message" do
    logic = Proc.new{ |msg| msg[:OBR].size == 1  }
    @failed = pass?( @messages, logic )
    @failed.should be_empty
  end
end
    
# == OBR tests (orders only)
shared_examples "a normal OBR segment" do  
  it "only appears once per message" do
    logic = Proc.new{ |msg| msg[:OBR].size == 1  }
    @failed = pass?( @messages, logic )
    @failed.should be_empty
  end
  
  it "has a valid Control Code", :pattern => "only letters, numbers, and spaces" do
    logic = Proc.new{ |msg| msg[:OBR].control_code =~ /^[A-z0-9][A-z0-9 ]*/ }   
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end
      
  it "has a valid ordering provider", :pattern => 'ID and/or a name, and final field ends with PROV' do
    logic = Proc.new{ |msg|
      prov = msg[:OBR].field(:ordering_provider)
      id = prov[1]      
      if id =~ /\d/
        prov[-1] =~ /\w+PROV$/ && id =~ /^[A-Z]?\d+/
      else
        prov[-1] =~ /\w+PROV$/ && HL7Test.is_name?( prov.components[2..5] )
      end
    }    
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end
  
  it "has a valid Result Status" do
    logic = Proc.new{ |msg| HL7Test::RESULT_STATUS.include? msg[:OBR].result_status }
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end

  it "has a valid observation date/time" do
    logic = Proc.new{ |msg| HL7Test.is_datetime? msg[:OBR].observation_date_time }
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end
end

# == PID tests
shared_examples "a normal PID segment" do |pid|
  it "has a valid patient name" do
    logic = Proc.new{ |msg| HL7Test.is_name? msg[:PID].patient_name }
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end

  it "has a valid patient ID", :pattern => 'begins with digits and ends with characters + "01"' do
    logic = Proc.new{ |msg|
      ptid = msg[:PID].field(:patient_id)
      ptid[1] !~ /\D/ && ptid[-1] =~ /\w+01$/
    }
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end

  it "has a valid patient birthdate" do
    logic = Proc.new{ |msg| HL7Test.is_date? msg[:PID].dob }
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end

  it "has a valid patient sex" do
    logic = Proc.new{ |msg| HL7Test::SEXES.include? msg[:PID].sex }
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end

  it "has a valid SSN", :pattern => '9 digits without dashes' do
    logic = Proc.new{ |msg| msg[:PID].ssn =~ /^\d{9}$/ }
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end  
end

# == ADT PID tests
shared_examples "a PID segment in ADT messages" do |pid|
  it "has a valid race", :pattern => "a number corresponding to a list item" do
    logic = Proc.new{ |msg|
      race = msg[:PID].race
      race.empty? || race =~ /^\d$/
    }
    @failed = pass?( messages, logic )
    @failed.should be_empty 
  end

  it "has a Country Code that matches the Address" do
    logic = Proc.new{ |msg|
      pid = msg[:PID]
      ccd = pid.country_code
      ccd.empty? || ccd == pid.field(:address)[7]
    }
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end

  it "has a valid Language", :pattern => "a three character language code" do
    logic = Proc.new{ |msg|
      lang = msg[:PID].language
      lang.empty? || lang =~ /^[A-z]{3}$/
    }
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end

  it "has a valid Marital Status", :pattern => "a single character" do
    logic = Proc.new{ |msg|
      mar = msg[:PID].marital_status
      mar.empty? || mar =~ /^[A-Z]$/
    }
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end
end

# == PV1 tests
shared_examples "the PV1 visit number and PID account number" do  
  it "have the correct format", :pattern => 'an optional capital letter and numbers' do
    logic = Proc.new{ |msg|
      pv1_visit = msg[:PV1].field(:visit_number)
      pid_acct = msg[:PID].field(:account_number)
      beg = /^[A-Z]?\d+/    
      pv1_visit && pid_acct && pid_acct.first =~ beg && pv1_visit.first =~ beg
    }
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end
  
  it "are the same" do
    logic = Proc.new{ |msg|
      pv1_visit = msg[:PV1].field(:visit_number)
      pid_acct = msg[:PID].field(:account_number)  
      if pv1_visit.nil? && pid_acct.nil?
        true   # there aren't any values, but they are the same!
      else
        pv1_visit && pid_acct && pid_acct.first == pv1_visit.first
      end
    }
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end
end

shared_examples "a PV1 segment in Lab/ADT messages" do
  it "has the same Attending and Referring Doctor", :pattern => 'fields should match unless Referring Doctor is empty' do
    logic = Proc.new{ |msg|
      pv1 = msg[:PV1]
      ref = pv1.referring_doctor
      ref.empty? || pv1.attending_doctor == ref
    }
    @failed = pass?( messages, logic )
    @failed.should be_empty
  end
end
