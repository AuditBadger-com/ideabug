require "application_system_test_case"

class TicketsTest < ApplicationSystemTestCase
  setup do
    @ticket = create(:ticket, title: "Existing feedback")
    sign_in_as(create(:user))
  end

  test "visiting the index" do
    visit tickets_url
    assert_selector "h1", text: "Feedback inbox"
    assert_text @ticket.title
  end

  test "creating feedback" do
    visit tickets_url
    click_on "Add feedback"

    fill_in "Title", with: "Export feedback"
    fill_in "Description", with: "Allow exporting the feedback list"
    select "Feature request", from: "Type"
    click_on "Add feedback"

    assert_text "Ticket was successfully created"
    assert_predicate Ticket.find_by!(title: "Export feedback"), :feature_request?
  end

  test "updating feedback" do
    visit ticket_url(@ticket)
    click_on "Edit", exact: true

    fill_in "Title", with: "Updated feedback"
    select "In progress", from: "Status"
    click_on "Save changes"

    assert_text "Ticket was successfully updated"
    assert_equal "Updated feedback", @ticket.reload.title
    assert_predicate @ticket, :in_progress_status?
  end

  test "destroying feedback" do
    visit ticket_url(@ticket)
    accept_confirm { click_on "Delete" }

    assert_text "Ticket was successfully destroyed"
    assert_not Ticket.exists?(@ticket.id)
  end
end
