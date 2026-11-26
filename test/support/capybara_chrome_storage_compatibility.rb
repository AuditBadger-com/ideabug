# Capybara 3.40's Chrome reset clears cookies and localStorage with
# Storage.clearDataForOrigin(origin: "*"). Chrome 158 rejects the wildcard origin, so every
# system test errored in teardown. All system tests run against the single Capybara server
# origin, so clear that origin instead. Drop this once Capybara ships a fix.
require "capybara/selenium/driver"
require "capybara/selenium/driver_specializations/chrome_driver"

module CapybaraChromeStorageCompatibility
  private

  def execute_cdp(cmd, params = {})
    server = Capybara.current_session.server
    if cmd == "Storage.clearDataForOrigin" && params[:origin] == "*" && server
      params = params.merge(origin: server.base_url)
    end

    super
  end
end

Capybara::Selenium::Driver::ChromeDriver.prepend(CapybaraChromeStorageCompatibility)
