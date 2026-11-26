require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400] do |options|
    # Browser password prompts can intercept clicks after signing in with test credentials.
    options.add_preference("credentials_enable_service", false)
    options.add_preference("profile.password_manager_enabled", false)
    options.add_preference("profile.password_manager_leak_detection", false)
  end

  def sign_in_as(user)
    visit new_session_url
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: user.password
    click_button "Sign in"
    assert_current_path dashboard_path
    assert_selector "h1", text: "Product pulse"
  end
end
