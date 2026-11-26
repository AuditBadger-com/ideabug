require "application_system_test_case"

class ContactsTest < ApplicationSystemTestCase
  setup do
    @contact = create(:contact, info_payload: {name: "Jane Customer"})
    sign_in_as(create(:user))
  end

  test "visiting the index" do
    visit contacts_url
    assert_selector "h1", text: "Contacts"
    assert_text "Jane Customer"
  end

  test "viewing contact details" do
    visit contacts_url
    click_on "Jane Customer"

    assert_selector "h1", text: "Jane Customer"
    assert_text @contact.external_id
    assert_text "Contact properties"
  end

  test "destroying a contact" do
    visit contact_url(@contact)
    accept_confirm { click_on "Delete" }

    assert_text "Contact was successfully destroyed"
    assert_not Contact.exists?(@contact.id)
  end
end
