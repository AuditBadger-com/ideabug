require "application_system_test_case"

class SegmentsTest < ApplicationSystemTestCase
  setup do
    @segment = create(:segment, identifier: "plan")
    sign_in_as(create(:user))
  end

  test "visiting the index" do
    visit segments_url
    assert_selector "h1", text: "Segments"
    assert_text "plan"
  end

  test "creating a segment" do
    visit segments_url
    click_on "New segment"

    fill_in "Identifier", with: "region"
    check "Accept new values"
    click_on "Create segment"

    assert_text "Segment was successfully created"
    assert_predicate Segment.find_by!(identifier: "region"), :allow_new_values?
  end

  test "updating a segment" do
    visit segment_url(@segment)
    click_on "Edit", exact: true

    fill_in "Identifier", with: "subscription"
    click_on "Save segment"

    assert_text "Segment was successfully updated"
    assert_equal "subscription", @segment.reload.identifier
  end

  test "destroying a segment" do
    visit segment_url(@segment)
    accept_confirm { click_on "Delete" }

    assert_text "Segment was successfully destroyed"
    assert_not Segment.exists?(@segment.id)
  end
end
