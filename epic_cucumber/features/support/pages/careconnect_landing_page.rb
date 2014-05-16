class CareConnectLandingPage
  include PageObject
  
  attr_accessor :username, :epic_link

  def initialize(browser)
    @browser = browser
    @username = @browser.span(:id => "username")
    @epic_link = @browser.link(:title => "Hyperspace 2014 - CNV")
  end
end