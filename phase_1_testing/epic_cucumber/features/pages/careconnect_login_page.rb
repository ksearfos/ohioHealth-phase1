class CareConnectLoginPage
  attr_accessor :user_name, :password, :log_on_button

  URLS = { :login => "http://ccweb" }

  def initialize(browser)
    @browser = browser
    @user_name = @browser.text_field(:name => "user")
    @password = @browser.text_field(:name => "password")
    @log_on_button = @browser.link(:name => "btnLogin")
  end

  def visit
    @browser.goto URLS[:login]
  end

  def login_with(username, password)
    self.user_name.set username
    self.password.set password
    self.log_on_button.click
    ccweb_landing_page = CareConnectLandingPage.new(@browser)
    ccweb_landing_page.username.wait_until_present if WEBDRIVER
    ccweb_landing_page
  end
end
