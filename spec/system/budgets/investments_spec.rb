require "rails_helper"
require "sessions_helper"

describe "Budget Investments" do
  let(:author)  { create(:user, :level_two, username: "Isabel") }
  let(:budget)  { create(:budget, name: "Big Budget") }
  let(:other_budget) { create(:budget, name: "What a Budget!") }
  let(:group) { create(:budget_group, name: "Health", budget: budget) }
  let!(:heading) { create(:budget_heading, name: "More hospitals", price: 666666, group: group) }

  # it_behaves_like "milestoneable", :budget_investment

  xcontext "Concerns" do
    it_behaves_like "notifiable in-app", :budget_investment
    it_behaves_like "relationable", Budget::Investment
    it_behaves_like "remotely_translatable",
                    :budget_investment,
                    "budget_investments_path",
                    { budget_id: "budget_id" }

    it_behaves_like "remotely_translatable",
                    :budget_investment,
                    "budget_investment_path",
                    { budget_id: "budget_id", id: "id" }
    it_behaves_like "flaggable", :budget_investment
  end

  context "Load" do
    let(:investment) { create(:budget_investment, heading: heading) }

    before do
      budget.update!(slug: "budget_slug")
      heading.update!(slug: "heading_slug")
    end

    scenario "finds investment using budget slug" do
      visit budget_investment_path("budget_slug", investment)

      expect(page).to have_content investment.title
    end

    scenario "finds investment using heading slug" do
      visit budget_investment_path(budget, investment, heading_id: "heading_slug")

      expect(page).to have_content investment.title
    end
  end

  xscenario "Index" do
    budget.update!(phase: "valuating")

    investments = [create(:budget_investment, heading: heading),
                   create(:budget_investment, heading: heading),
                   create(:budget_investment, :feasible, heading: heading)]

    unfeasible_investment = create(:budget_investment, :unfeasible, heading: heading)

    visit budget_path(budget)
    click_link "See all investments"

    expect(page).to have_selector("#budget-investments .budget-investment", count: 3)
    investments.each do |investment|
      within("#budget-investments") do
        expect(page).to have_content investment.title
        expect(page).to have_css("a[href='#{budget_investment_path(budget, id: investment.id)}']", text: investment.title)
        expect(page).not_to have_content(unfeasible_investment.title)
      end
    end

    click_link "Go back"

    expect(page).to have_current_path budget_path(budget)
  end

  xscenario "Index view mode" do
    investments = [create(:budget_investment, heading: heading),
                   create(:budget_investment, heading: heading),
                   create(:budget_investment, heading: heading)]

    visit budget_investments_path(budget, heading_id: heading)

    click_button "View mode"
    click_link "List"

    investments.each do |investment|
      within("#budget-investments") do
        expect(page).to     have_link investment.title
        expect(page).not_to have_content(investment.description)
      end
    end

    click_button "View mode"
    click_link "Cards"

    investments.each do |investment|
      within("#budget-investments") do
        expect(page).to have_link investment.title
        expect(page).to have_content(investment.description)
      end
    end
  end

  xscenario "Index should show investment descriptive image only when is defined" do
    investment = create(:budget_investment, heading: heading)
    investment_with_image = create(:budget_investment, :with_image, heading: heading)

    visit budget_investments_path(budget, heading_id: heading.id)

    within("#budget_investment_#{investment.id}") do
      expect(page).not_to have_css("div.with-image")
    end
    within("#budget_investment_#{investment_with_image.id}") do
      expect(page).to have_css("img[alt='#{investment_with_image.image.title}']")
    end
  end

  xscenario "Index should show a map if heading has coordinates defined" do
    create(:budget_investment, heading: heading)
    visit budget_investments_path(budget, heading_id: heading.id)
    within("#sidebar") do
      expect(page).to have_css(".map_location")
    end

    unlocated_heading = create(:budget_heading, name: "No Map", price: 500, group: group,
                               longitude: nil, latitude: nil)
    create(:budget_investment, heading: unlocated_heading)
    visit budget_investments_path(budget, heading_id: unlocated_heading.id)
    within("#sidebar") do
      expect(page).not_to have_css(".map_location")
    end
  end

  xscenario "Index filter by status" do
    budget.update!(phase: "finished")

    create(:budget_investment, heading: heading, title: "Unclassified investment")
    create(:budget_investment, :feasible, heading: heading, title: "Feasible investment")
    create(:budget_investment, :unfeasible, heading: heading, title: "Unfeasible investment")
    create(:budget_investment, :unselected, heading: heading, title: "Unselected investment")
    create(:budget_investment, :selected, heading: heading, title: "Selected investment")
    create(:budget_investment, :winner, heading: heading, title: "Winner investment")

    visit budget_investments_path(budget, heading_id: heading.id)

    expect(page).to have_content "FILTERING PROJECTS BY"

    click_link "Unfeasible"

    expect(page).to have_content "Unfeasible investment"
    expect(page).to have_css ".budget-investment", count: 1

    click_link "Not selected for the final voting"

    expect(page).to have_css ".budget-investment", count: 3
    expect(page).to have_content "Unselected investment"
    expect(page).to have_content "Unclassified investment"
    expect(page).to have_content "Feasible investment"

    click_link "Winners"

    expect(page).to have_css ".budget-investment", count: 1
    expect(page).to have_content "Winner investment"
  end

  context("Search") do
    xscenario "Search by text" do
      investment1 = create(:budget_investment, heading: heading, title: "Get Schwifty")
      investment2 = create(:budget_investment, heading: heading, title: "Schwifty Hello")
      investment3 = create(:budget_investment, heading: heading, title: "Do not show me")

      visit budget_investments_path(budget, heading_id: heading.id)

      within "#search_form" do
        fill_in "search", with: "Schwifty"
        click_button "Search"
      end

      expect(page).to have_content "containing the term 'Schwifty'"

      within("#budget-investments") do
        expect(page).to have_css(".budget-investment", count: 2)

        expect(page).to have_content(investment1.title)
        expect(page).to have_content(investment2.title)
        expect(page).not_to have_content(investment3.title)
      end
    end

    xscenario "Advanced search combined with filter by status" do
      budget.update!(phase: "valuating")

      create(:budget_investment, :feasible, heading: heading, title: "Feasible environment")
      create(:budget_investment, :feasible, heading: heading, title: "Feasible health")
      create(:budget_investment, :unfeasible, heading: heading, title: "Unfeasible environment")
      create(:budget_investment, :unfeasible, heading: heading, title: "Unfeasible health")

      visit budget_investments_path(budget, heading: heading)

      click_button "Advanced search"
      fill_in "With the text", with: "environment"
      select "Last 24 hours", from: "By date"
      click_button "Filter"

      expect(page).to have_content "There is 1 investment"
      expect(page).to have_css ".budget-investment", count: 1
      expect(page).to have_content "Feasible environment"
      expect(page).not_to have_content "containing the term"
      expect(page).not_to have_content "Feasible health"
      expect(page).not_to have_content "Unfeasible environment"
      expect(page).not_to have_content "Unfeasible health"

      click_link "Unfeasible"

      expect(page).not_to have_content "Feasible environment"
      expect(page).to have_content "There is 1 investment"
      expect(page).to have_css ".budget-investment", count: 1
      expect(page).to have_content "Unfeasible environment"
      expect(page).not_to have_content "containing the term"
      expect(page).not_to have_content "Feasible health"
      expect(page).not_to have_content "Unfeasible health"
    end

    xscenario "Advanced search without search terms" do
      create(:budget_heading, group: heading.group)
      create(:budget_investment, heading: heading, title: "Old thing", created_at: 2.years.ago)
      create(:budget_investment, heading: heading, title: "Newest thing", created_at: 1.hour.ago)

      visit budget_investments_path(budget, heading: heading)

      click_button "Advanced search"
      select "Last year", from: "By date"
      click_button "Filter"

      expect(page).to have_content "There is 1 investment"
      expect(page).to have_content "Newest thing"
      expect(page).not_to have_content "Old thing"
      within("main") { expect(page).not_to have_content "Participatory budgeting" }
    end
  end

  context("Filters") do
    xscenario "by unfeasibility" do
      budget.update!(phase: "valuating")

      investment1 = create(:budget_investment, :unfeasible, :finished, heading: heading)
      investment2 = create(:budget_investment, :feasible, heading: heading)
      investment3 = create(:budget_investment, heading: heading)
      investment4 = create(:budget_investment, :feasible, heading: heading)

      visit budget_investments_path(budget, heading_id: heading.id, filter: "unfeasible")

      within("#budget-investments") do
        expect(page).to have_css(".budget-investment", count: 1)

        expect(page).to have_content(investment1.title)
        expect(page).not_to have_content(investment2.title)
        expect(page).not_to have_content(investment3.title)
        expect(page).not_to have_content(investment4.title)
      end
    end

    context "Results Phase" do
      before { budget.update(phase: "finished", results_enabled: true) }

      xscenario "show winners by default" do
        investment1 = create(:budget_investment, :winner, heading: heading)
        investment2 = create(:budget_investment, :selected, heading: heading)

        visit budget_investments_path(budget, heading_id: heading)

        within("#budget-investments") do
          expect(page).to have_css(".budget-investment", count: 1)
          expect(page).to have_content(investment1.title)
          expect(page).not_to have_content(investment2.title)
        end

        visit budget_results_path(budget)
        click_link "List of all investment projects"

        within("#budget-investments") do
          expect(page).to have_css(".budget-investment", count: 1)
          expect(page).to have_content(investment1.title)
          expect(page).not_to have_content(investment2.title)
        end
      end

      xscenario "unfeasible" do
        investment1 = create(:budget_investment, :unfeasible, :finished, heading: heading)
        investment2 = create(:budget_investment, :feasible, heading: heading)

        visit budget_results_path(budget)
        click_link "List of all unfeasible investment projects"

        within("#budget-investments") do
          expect(page).to have_css(".budget-investment", count: 1)
          expect(page).to have_content(investment1.title)
          expect(page).not_to have_content(investment2.title)
        end
      end

      xscenario "unselected" do
        investment1 = create(:budget_investment, :unselected, heading: heading)
        investment2 = create(:budget_investment, :selected, heading: heading)

        visit budget_results_path(budget)
        click_link "List of all investment projects not selected for balloting"

        within("#budget-investments") do
          expect(page).to have_css(".budget-investment", count: 1)
          expect(page).to have_content(investment1.title)
          expect(page).not_to have_content(investment2.title)
        end
      end
    end
  end

  context "Orders" do
    before { budget.update(phase: "selecting") }
    let(:per_page) { Budgets::InvestmentsController::PER_PAGE }

    xscenario "Default order is random" do
      (per_page + 2).times { create(:budget_investment, heading: heading) }

      visit budget_investments_path(budget, heading_id: heading.id)

      within(".submenu .is-active") { expect(page).to have_content "random" }
      order = all(".budget-investment h3").map(&:text)
      expect(order).not_to be_empty

      visit budget_investments_path(budget, heading_id: heading.id)
      new_order = all(".budget-investment h3").map(&:text)

      expect(order).to eq(new_order)
    end

    xscenario "Random order after another order" do
      (per_page + 2).times { create(:budget_investment, heading: heading) }

      visit budget_investments_path(budget, heading_id: heading.id)
      order = all(".budget-investment h3").map(&:text)
      expect(order).not_to be_empty

      click_link "highest rated"

      expect(page).to have_css "h2", exact_text: "highest rated"

      click_link "random"

      expect(page).to have_css "h2", exact_text: "random"

      visit budget_investments_path(budget, heading_id: heading.id)
      new_order = all(".budget-investment h3").map(&:text)

      expect(order).to eq(new_order)
    end

    xscenario "Random order maintained with pagination" do
      (per_page + 2).times { create(:budget_investment, heading: heading) }

      visit budget_investments_path(budget, heading_id: heading.id)

      order = all(".budget-investment h3").map(&:text)
      expect(order).not_to be_empty

      click_link "Next"
      expect(page).to have_css ".pagination .current", text: "2"

      click_link "Previous"
      expect(page).to have_css ".pagination .current", text: "1"

      new_order = all(".budget-investment h3").map(&:text)
      expect(order).to eq(new_order)
    end

    xscenario "Random order maintained when going back from show" do
      per_page.times { create(:budget_investment, heading: heading) }
      first_investment = Budget::Investment.first

      visit budget_investments_path(budget, heading_id: heading.id)

      order = all(".budget-investment h3").map(&:text)
      expect(order).not_to be_empty

      click_link first_investment.title

      expect(page).not_to have_link first_investment.title

      click_link "Go back"

      expect(page).to have_link first_investment.title

      new_order = all(".budget-investment h3").map(&:text)
      expect(order).to eq(new_order)
    end

    xscenario "Investments are not repeated with random order" do
      (per_page + 2).times { create(:budget_investment, heading: heading) }

      visit budget_investments_path(budget, order: "random")

      first_page_investments = investments_order

      click_link "Next"
      expect(page).to have_css ".pagination .current", text: "2"

      second_page_investments = investments_order

      common_values = first_page_investments & second_page_investments

      expect(common_values.length).to eq(0)
    end

    xscenario "Proposals are ordered by confidence_score" do
      best_proposal = create(:budget_investment, heading: heading, title: "Best proposal")
      best_proposal.update_column(:confidence_score, 10)
      worst_proposal = create(:budget_investment, heading: heading, title: "Worst proposal")
      worst_proposal.update_column(:confidence_score, 2)
      medium_proposal = create(:budget_investment, heading: heading, title: "Medium proposal")
      medium_proposal.update_column(:confidence_score, 5)

      visit budget_investments_path(budget, heading_id: heading.id)
      click_link "highest rated"
      expect(page).to have_selector("a.is-active", text: "highest rated")

      within "#budget-investments" do
        expect(best_proposal.title).to appear_before(medium_proposal.title)
        expect(medium_proposal.title).to appear_before(worst_proposal.title)
      end

      expect(page).to have_current_path(/order=confidence_score/)
      expect(page).to have_current_path(/page=1/)
    end

    xscenario "Each user has a different and consistent random budget investment order" do
      (per_page * 1.3).to_i.times { create(:budget_investment, heading: heading) }
      first_user_investments_order = nil
      second_user_investments_order = nil

      in_browser(:one) do
        visit budget_investments_path(budget, heading: heading)
        first_user_investments_order = investments_order
      end

      in_browser(:two) do
        visit budget_investments_path(budget, heading: heading)
        second_user_investments_order = investments_order
      end

      expect(first_user_investments_order).not_to eq(second_user_investments_order)

      in_browser(:one) do
        click_link "Next"
        expect(page).to have_css ".pagination .current", text: "2"

        click_link "Previous"
        expect(page).to have_css ".pagination .current", text: "1"

        expect(investments_order).to eq(first_user_investments_order)
      end

      in_browser(:two) do
        click_link "Next"
        expect(page).to have_css ".pagination .current", text: "2"

        click_link "Previous"
        expect(page).to have_css ".pagination .current", text: "1"

        expect(investments_order).to eq(second_user_investments_order)
      end
    end

    scenario "Each user has a equal and consistent budget investment order when the random_seed is equal" do
      (per_page * 1.3).to_i.times { create(:budget_investment, heading: heading) }

      first_user_investments_order = nil
      second_user_investments_order = nil

      in_browser(:one) do
        visit budget_investments_path(budget, heading: heading, random_seed: "1")
        first_user_investments_order = investments_order
      end

      in_browser(:two) do
        visit budget_investments_path(budget, heading: heading, random_seed: "1")
        second_user_investments_order = investments_order
      end

      expect(first_user_investments_order).to eq(second_user_investments_order)
    end

    scenario "Set votes for investments randomized with a seed" do
      voter = create(:user, :level_two)

      per_page.times { create(:budget_investment, heading: heading) }

      voted_investments = Array.new(per_page) do
        create(:budget_investment, heading: heading, voters: [voter])
      end

      login_as(voter)
      visit budget_investments_path(budget, heading_id: heading.id)

      voted_investments.each do |investment|
        if page.has_link?(investment.title)
          within("#budget_investment_#{investment.id}") do
            expect(page).to have_content "You have already supported this investment"
          end
        end
      end
    end

    xscenario "Order is random if budget is finished" do
      per_page.times { create(:budget_investment, :winner, heading: heading) }

      budget.update!(phase: "finished")

      visit budget_investments_path(budget, heading_id: heading.id)
      order = all(".budget-investment h3").map(&:text)
      expect(order).not_to be_empty

      visit budget_investments_path(budget, heading_id: heading.id)
      new_order = all(".budget-investment h3").map(&:text)

      expect(order).to eq(new_order)
    end

    xscenario "Order always is random for unfeasible and unselected investments" do
      Budget::Phase::kind_or_later("valuating").each do |phase|
        budget.update!(phase: phase)

        visit budget_investments_path(budget, heading_id: heading.id, filter: "unfeasible")

        within(".submenu") do
          expect(page).to have_content "random"
          expect(page).not_to have_content "by price"
          expect(page).not_to have_content "highest rated"
        end
      end

      Budget::Phase.kind_or_later("publishing_prices").each do |phase|
        visit budget_investments_path(budget, heading_id: heading.id, filter: "unselected")

        within(".submenu") do
          expect(page).to have_content "random"
          expect(page).not_to have_content "price"
          expect(page).not_to have_content "highest rated"
        end
      end
    end

    def investments_order
      all(".budget-investment h3").map(&:text)
    end
  end

  context "Phase I - Accepting" do
    before { budget.update(phase: "accepting") }

    xscenario "Create with invisible_captcha honeypot field", :no_js do
      login_as(author)
      visit new_budget_investment_path(budget)

      fill_in "Title", with: "I am a bot"
      fill_in "budget_investment_subtitle", with: "This is the honeypot"
      fill_in "Description", with: "This is the description"
      check   "I agree to the Privacy Policy and the Terms and conditions of use"

      click_button "Create Investment"

      expect(page.status_code).to eq(200)
      expect(page.html).to be_empty
      expect(page).to have_current_path(budget_investments_path(budget))
    end

    xscenario "Create budget investment too fast" do
      allow(InvisibleCaptcha).to receive(:timestamp_threshold).and_return(Float::INFINITY)

      login_as(author)
      visit new_budget_investment_path(budget)

      fill_in_new_investment_title with: "I am a bot"
      fill_in_ckeditor "Description", with: "This is the description"
      check "budget_investment_terms_of_service"

      click_button "Create Investment"

      expect(page).to have_content "Sorry, that was too quick! Please resubmit"
      expect(page).to have_current_path(new_budget_investment_path(budget))
    end

    xscenario "Create with single heading" do
      login_as(author)

      visit new_budget_investment_path(budget)

      expect(page).not_to have_field "budget_investment_heading_id"
      expect(page).to have_content("#{heading.name} (#{budget.formatted_heading_price(heading)})")

      fill_in_new_investment_title with: "Build a skyscraper"
      fill_in_ckeditor "Description", with: "I want to live in a high tower over the clouds"
      fill_in "Location additional info", with: "City center"
      fill_in "If you are proposing in the name of a collective/organization, "\
        "or on behalf of more people, write its name", with: "T.I.A."
      fill_in "Tags", with: "Towers"
      check "I agree to the Privacy Policy and the Terms and conditions of use"

      click_button "Create Investment"

      expect(page).to have_content "Investment created successfully"
      expect(page).to have_content "Build a skyscraper"
      expect(page).to have_content "I want to live in a high tower over the clouds"
      expect(page).to have_content "City center"
      expect(page).to have_content "T.I.A."
      expect(page).to have_content "Towers"

      visit user_path(author, filter: :budget_investments)

      expect(page).to have_content "1 Investment"
      expect(page).to have_content "Build a skyscraper"
    end

    xscenario "Create with single heading and hidden money" do
      budget_hide_money = create(:budget, :hide_money)
      group = create(:budget_group, budget: budget_hide_money)
      create(:budget_heading, name: "Heading without money", group: group)

      login_as(author)

      visit new_budget_investment_path(budget_hide_money)

      expect(page).to have_content "Heading without money"
      expect(page).not_to have_content "€"
    end

    xscenario "Create with single group and multiple headings" do
      create(:budget_heading, group: group, name: "Medical supplies")
      create(:budget_heading, group: group, name: "Even more hospitals")

      login_as(author)

      visit new_budget_investment_path(budget)

      expect(page).to have_select "Heading",
        options: ["", "More hospitals", "Medical supplies", "Even more hospitals"]
      expect(page).not_to have_content "Health"
    end

    xscenario "Create with multiple groups" do
      education = create(:budget_group, budget: budget, name: "Education")

      create(:budget_heading, group: group, name: "Medical supplies")
      create(:budget_heading, group: education, name: "Schools")

      login_as(author)

      visit new_budget_investment_path(budget)

      expect(page).not_to have_content("#{heading.name} (#{budget.formatted_heading_price(heading)})")
      expect(page).to have_select "Heading",
        options: ["", "Health: More hospitals", "Health: Medical supplies", "Education: Schools"]

      select "Health: Medical supplies", from: "Heading"

      fill_in_new_investment_title with: "Build a skyscraper"
      fill_in_ckeditor "Description", with: "I want to live in a high tower over the clouds"
      fill_in "Location additional info", with: "City center"
      fill_in "If you are proposing in the name of a collective/organization, "\
        "or on behalf of more people, write its name", with: "T.I.A."
      fill_in "Tags", with: "Towers"
      check "I agree to the Privacy Policy and the Terms and conditions of use"

      click_button "Create Investment"

      expect(page).to have_content "Investment created successfully"
      expect(page).to have_content "Build a skyscraper"
      expect(page).to have_content "I want to live in a high tower over the clouds"
      expect(page).to have_content "City center"
      expect(page).to have_content "T.I.A."
      expect(page).to have_content "Towers"

      visit user_path(author, filter: :budget_investments)

      expect(page).to have_content "1 Investment"
      expect(page).to have_content "Build a skyscraper"
    end

    scenario "Edit" do
      daniel = create(:user, :level_two)

      create(:budget_investment, heading: heading, title: "Get Schwifty", author: daniel, created_at: 1.day.ago)

      login_as(daniel)

      visit user_path(daniel, filter: "budget_investments")

      click_link("Edit", match: :first)
      fill_in "Title", with: "Park improvements"

      click_button "Update Investment"

      expect(page).to have_content "Investment project updated succesfully"
      expect(page).to have_content "Park improvements"
    end

    scenario "Trigger validation errors in edit view" do
      daniel = create(:user, :level_two)
      message_error = "is too short (minimum is 4 characters), can't be blank"
      create(:budget_investment, heading: heading, title: "Get SH", author: daniel, created_at: 1.day.ago)

      login_as(daniel)

      visit user_path(daniel, filter: "budget_investments")
      click_link("Edit", match: :first)
      fill_in "Title", with: ""

      click_button "Update Investment"

      expect(page).to have_content message_error
    end

    scenario "Another User can't edit budget investment", :admin do
      message_error = "You do not have permission to carry out the action 'edit' on Investment"
      daniel = create(:user, :level_two)
      investment = create(:budget_investment, heading: heading, author: daniel)

      visit edit_budget_investment_path(budget, investment)

      expect(page).to have_content message_error
    end

    xscenario "Errors on create" do
      login_as(author)

      visit new_budget_investment_path(budget)
      click_button "Create Investment"
      expect(page).to have_content error_message
    end

    context "Suggest" do
      factory = :budget_investment

      xscenario "Show up to 5 suggestions" do
        %w[first second third fourth fifth sixth].each do |ordinal|
          create(factory, title: "#{ordinal.titleize} #{factory}, has search term", budget: budget)
        end
        create(factory, title: "This is the last #{factory}", budget: budget)

        login_as(author)
        visit new_budget_investment_path(budget)
        fill_in "Title", with: "search"

        within("div.js-suggest") do
          expect(page).to have_content "You are seeing 5 of 6 investments containing the term 'search'"
        end
      end

      xscenario "No found suggestions" do
        %w[first second third fourth fifth sixth].each do |ordinal|
          create(factory, title: "#{ordinal.titleize} #{factory}, has search term", budget: budget)
        end

        login_as(author)
        visit new_budget_investment_path(budget)
        fill_in "Title", with: "item"

        within("div.js-suggest") do
          expect(page).not_to have_content "You are seeing"
        end
      end

      xscenario "Don't show suggestions from a different budget" do
        %w[first second third fourth fifth sixth].each do |ordinal|
          create(factory, title: "#{ordinal.titleize} #{factory}, has search term", budget: budget)
        end

        login_as(author)
        visit new_budget_investment_path(other_budget)
        fill_in "Title", with: "search"

        within("div.js-suggest") do
          expect(page).not_to have_content "You are seeing"
        end
      end

      describe "Don't show suggestions" do
        let(:investment) { create(factory, title: "Title, has search term", budget: budget, author: author) }

        before do
          login_as(author)
          visit edit_budget_investment_path(budget, investment)
        end

        scenario "for edit action" do
          fill_in "Title", with: "search"

          expect(page).not_to have_content "There is an investment with the term 'search'"
        end

        xscenario "for update action" do
          fill_in "Title", with: ""

          click_button "Update Investment"
          fill_in "Title", with: "search"

          expect(page).not_to have_content "There is an investment with the term 'search'"
        end
      end
    end

    xscenario "Ballot is not visible" do
      login_as(author)

      visit budget_investments_path(budget, heading_id: heading.id)

      expect(page).not_to have_link("Submit my ballot")
      expect(page).not_to have_css("#progress_bar")

      within("#sidebar") do
        expect(page).not_to have_content("My ballot")
        expect(page).not_to have_link("Submit my ballot")
      end
    end

    xscenario "Heading options are correctly ordered" do
      city_group = create(:budget_group, name: "Toda la ciudad", budget: budget)
      create(:budget_heading, name: "Toda la ciudad", price: 333333, group: city_group)
      create(:budget_heading, name: "More health professionals", price: 999999, group: group)

      login_as(author)

      visit new_budget_investment_path(budget)

      select_options = find("#budget_investment_heading_id").all("option").map(&:text)
      expect(select_options).to eq ["",
                                    "Toda la ciudad: Toda la ciudad",
                                    "Health: More health professionals",
                                    "Health: More hospitals"]
    end
  end

  xscenario "Show" do
    investment = create(:budget_investment, heading: heading)

    user = create(:user)
    login_as(user)

    visit budget_investment_path(budget, id: investment.id)

    expect(page).to have_content(investment.title)
    expect(page).to have_content(investment.description)
    expect(page).to have_content(investment.author.name)
    expect(page).to have_content(investment.heading.name)
    within("#investment_code") do
      expect(page).to have_content(investment.id)
    end
  end

  context "Show Investment's price & cost explanation" do
    let(:investment) { create(:budget_investment, :selected_with_price, heading: heading) }

    context "When investment with price is selected" do
      xscenario "Price & explanation is shown when Budget is on published prices phase" do
        Budget::Phase::PUBLISHED_PRICES_PHASES.each do |phase|
          budget.update!(phase: phase)

          if budget.finished?
            investment.update!(winner: true)
          end

          visit budget_investment_path(budget, id: investment.id)

          expect(page).to have_content(investment.formatted_price)
          expect(page).to have_content(investment.price_explanation)
          expect(page).to have_link("See price explanation")

          visit budget_investments_path(budget)

          expect(page).to have_content(investment.formatted_price)
        end
      end

      xscenario "Price & explanation isn't shown when Budget is not on published prices phase" do
        (Budget::Phase::PHASE_KINDS - Budget::Phase::PUBLISHED_PRICES_PHASES).each do |phase|
          budget.update!(phase: phase)
          visit budget_investment_path(budget, id: investment.id)

          expect(page).not_to have_content(investment.formatted_price)
          expect(page).not_to have_content(investment.price_explanation)
          expect(page).not_to have_link("See price explanation")

          visit budget_investments_path(budget)

          expect(page).not_to have_content(investment.formatted_price)
        end
      end
    end

    context "When investment with price is unselected" do
      before do
        investment.update(selected: false)
      end

      xscenario "Price & explanation isn't shown for any Budget's phase" do
        Budget::Phase::PHASE_KINDS.each do |phase|
          budget.update!(phase: phase)
          visit budget_investment_path(budget, id: investment.id)

          expect(page).not_to have_content(investment.formatted_price)
          expect(page).not_to have_content(investment.price_explanation)
          expect(page).not_to have_link("See price explanation")

          visit budget_investments_path(budget)

          expect(page).not_to have_content(investment.formatted_price)
        end
      end
    end
  end

  xscenario "Can access the community" do
    Setting["feature.community"] = true

    investment = create(:budget_investment, heading: heading)
    visit budget_investment_path(budget, id: investment.id)
    expect(page).to have_content "Access the community"
  end

  scenario "Can not access the community" do
    Setting["feature.community"] = false

    investment = create(:budget_investment, heading: heading)
    visit budget_investment_path(budget, id: investment.id)
    expect(page).not_to have_content "Access the community"
  end

  scenario "Don't display flaggable buttons" do
    investment = create(:budget_investment, heading: heading)

    visit budget_investment_path(budget, id: investment.id)

    expect(page).not_to have_selector ".js-follow"
  end

  xscenario "Show back link contains heading id" do
    investment = create(:budget_investment, heading: heading)
    visit budget_investment_path(budget, investment)

    expect(page).to have_link "Go back", href: budget_investments_path(budget, heading_id: investment.heading)
  end

  context "Show (feasible budget investment)" do
    let(:investment) do
      create(:budget_investment,
             :feasible,
             :finished,
             budget: budget,
             heading: heading,
             price: 16,
             price_explanation: "Every wheel is 4 euros, so total is 16")
    end

    before do
      user = create(:user)
      login_as(user)
    end

    scenario "Budget in selecting phase" do
      budget.update!(phase: "selecting")
      visit budget_investment_path(budget, id: investment.id)

      expect(page).not_to have_content("Unfeasibility explanation")
      expect(page).not_to have_content("Price explanation")
      expect(page).not_to have_content(investment.price_explanation)
    end
  end

  scenario "Show (unfeasible budget investment) only when valuation finished" do
    investment = create(:budget_investment,
                        :unfeasible,
                        budget: budget,
                        heading: heading,
                        unfeasibility_explanation: "Local government is not competent in this")

    investment_2 = create(:budget_investment,
                        :unfeasible,
                        :finished,
                        budget: budget,
                        heading: heading,
                        unfeasibility_explanation: "The unfeasible explanation")

    user = create(:user)
    login_as(user)

    visit budget_investment_path(budget, id: investment.id)

    expect(page).not_to have_content("Unfeasibility explanation")
    expect(page).not_to have_content("Local government is not competent in this")
    expect(page).not_to have_content("This investment project has been marked as not feasible "\
                                     "and will not go to balloting phase")

    visit budget_investment_path(budget, id: investment_2.id)

    expect(page).to have_content("Unfeasibility explanation")
    expect(page).to have_content("The unfeasible explanation")
    expect(page).to have_content("This investment project has been marked as not feasible "\
                                 "and will not go to balloting phase")
  end

  scenario "Show (selected budget investment)" do
    investment = create(:budget_investment,
                        :feasible,
                        :finished,
                        :selected,
                        budget: budget,
                        heading: heading)

    user = create(:user)
    login_as(user)

    visit budget_investment_path(budget, id: investment.id)

    expect(page).to have_content("This investment project has been selected for balloting phase")
  end

  describe "winner budget investment text" do
    let(:investment) do
      create(:budget_investment, :winner, budget: budget, heading: heading)
    end

    scenario "don't show text if budget is not finished" do
      budget.update!(phase: "balloting")

      visit budget_investment_path(budget, id: investment.id)

      expect(page).not_to have_content("Winning investment project")
    end

    scenario "show text if budget is finished" do
      budget.update!(phase: "finished")

      visit budget_investment_path(budget, id: investment.id)

      expect(page).to have_content("Winning investment project")
    end
  end

  scenario "Show (not selected budget investment)" do
    budget.update!(phase: "balloting")

    investment = create(:budget_investment,
                        :feasible,
                        :finished,
                        budget: budget,
                        heading: heading)

    user = create(:user)
    login_as(user)

    visit budget_investment_path(budget, id: investment.id)

    expect(page).to have_content("This investment project has not been selected for balloting phase")
  end

  xscenario "Show title (no message)" do
    investment = create(:budget_investment,
                        :feasible,
                        :finished,
                        budget: budget,
                        heading: heading)

    user = create(:user)
    login_as(user)

    visit budget_investment_path(budget, id: investment.id)

    within("aside") do
      expect(page).to have_content("INVESTMENT PROJECT")
      expect(page).to have_css(".label-budget-investment")
    end
  end

  scenario "Show (unfeasible budget investment with valuation not finished)" do
    investment = create(:budget_investment,
                        :unfeasible,
                        :open,
                        budget: budget,
                        heading: heading,
                        unfeasibility_explanation: "Local government is not competent in this matter")

    user = create(:user)
    login_as(user)

    visit budget_investment_path(budget, id: investment.id)

    expect(page).not_to have_content("Unfeasibility explanation")
    expect(page).not_to have_content("Local government is not competent in this matter")
  end

  # it_behaves_like "followable", "budget_investment", "budget_investment_path", { budget_id: "budget_id", id: "id" }

  # it_behaves_like "imageable", "budget_investment", "budget_investment_path", { budget_id: "budget_id", id: "id" }

  # it_behaves_like "nested imageable",
  #                 "budget_investment",
  #                 "new_budget_investment_path",
  #                 { budget_id: "budget_id" },
  #                 "imageable_fill_new_valid_budget_investment",
  #                 "Create Investment",
  #                 "Budget Investment created successfully."

  # it_behaves_like "documentable", "budget_investment", "budget_investment_path", { budget_id: "budget_id", id: "id" }

  # it_behaves_like "nested documentable",
  #                 "user",
  #                 "budget_investment",
  #                 "new_budget_investment_path",
  #                 { budget_id: "budget_id" },
  #                 "documentable_fill_new_valid_budget_investment",
  #                 "Create Investment",
  #                 "Budget Investment created successfully."

  # it_behaves_like "mappable",
  #                 "budget_investment",
  #                 "investment",
  #                 "new_budget_investment_path",
  #                 "",
  #                 "budget_investment_path",
  #                 { budget_id: "budget_id" }

  context "Destroy" do
    scenario "Admin cannot destroy budget investments", :admin do
      user = create(:user, :level_two)
      investment = create(:budget_investment, heading: heading, author: user)

      visit user_path(user)

      within("#budget_investment_#{investment.id}") do
        expect(page).not_to have_link "Delete"
      end
    end

    scenario "Author can destroy while on the accepting phase" do
      user = create(:user, :level_two)
      investment1 = create(:budget_investment, heading: heading, price: 10000, author: user)

      login_as(user)
      visit user_path(user, tab: :budget_investments)

      within("#budget_investment_#{investment1.id}") do
        expect(page).to have_content(investment1.title)

        accept_confirm { click_link("Delete") }
      end

      expect(page).to have_content "Investment project deleted succesfully"

      visit user_path(user, tab: :budget_investments)

      expect(page).to have_content "User has no public activity"
      expect(page).not_to have_content investment1.title
    end
  end

  context "Selecting Phase" do
    before do
      budget.update(phase: "selecting")
    end

    context "Popup alert to vote only in one heading per group" do
      xscenario "When supporting in the first heading group" do
        carabanchel = create(:budget_heading, group: group)
        salamanca   = create(:budget_heading, group: group)

        create(:budget_investment, :selected, title: "In Carabanchel", heading: carabanchel)
        create(:budget_investment, :selected, title: "In Salamanca", heading: salamanca)

        login_as(author)
        visit budget_investments_path(budget, heading_id: carabanchel.id)

        within(".budget-investment", text: "In Carabanchel") do
          expect(page).to have_button count: 1
          expect(page).to have_button "Support"
          expect(page).to have_css "[type='submit'][data-confirm]"
        end
      end

      xscenario "When already supported in the group" do
        carabanchel = create(:budget_heading, group: group)
        salamanca   = create(:budget_heading, group: group)

        create(:budget_investment, title: "In Carabanchel", heading: carabanchel, voters: [author])
        create(:budget_investment, title: "Unsupported in Carabanchel", heading: carabanchel)
        create(:budget_investment, title: "In Salamanca", heading: salamanca)

        login_as(author)
        visit budget_investments_path(budget, heading_id: carabanchel.id)

        within(".budget-investment", text: "Unsupported in Carabanchel") do
          expect(page).to have_button "Support"
          expect(page).not_to have_css "[data-confirm]"
        end
      end

      xscenario "When supporting in another group" do
        heading = create(:budget_heading, group: group)

        group2 = create(:budget_group, budget: budget)
        another_heading1 = create(:budget_heading, group: group2)

        create(:budget_heading, group: group2)
        create(:budget_investment, heading: heading, title: "Investment", voters: [author])
        create(:budget_investment, heading: another_heading1, title: "Another investment")

        login_as(author)
        visit budget_investments_path(budget, heading_id: another_heading1.id)

        within(".budget-investment", text: "Another investment") do
          expect(page).to have_button count: 1
          expect(page).to have_button "Support"
          expect(page).to have_css "[type='submit'][data-confirm]"
        end
      end

      xscenario "When supporting in a group with a single heading" do
        all_city_investment = create(:budget_investment, heading: heading)

        login_as(author)
        visit budget_investments_path(budget, heading_id: heading.id)

        within("#budget_investment_#{all_city_investment.id}") do
          expect(page).to have_button "Support"
          expect(page).not_to have_css "[data-confirm]"
        end
      end
    end

    scenario "Sidebar in show should display support text" do
      investment = create(:budget_investment, budget: budget)
      visit budget_investment_path(budget, investment)

      within("aside") do
        expect(page).to have_content "SUPPORTS"
      end
    end

    xscenario "Remove a support from show view" do
      Setting["feature.remove_investments_supports"] = true
      investment = create(:budget_investment, budget: budget)

      login_as(author)
      visit budget_investment_path(budget, investment)

      within("aside") do
        expect(page).to have_content "No supports"

        click_button "Support"

        expect(page).to have_content "1 support"
        expect(page).to have_content "You have already supported this investment project."

        click_button "Remove your support"

        expect(page).to have_content "No supports"
        expect(page).to have_button "Support"
      end
    end

    xscenario "Remove a support from index view" do
      Setting["feature.remove_investments_supports"] = true
      investment = create(:budget_investment, budget: budget)

      login_as(author)
      visit budget_investments_path(budget)

      within("#budget_investment_#{investment.id}") do
        expect(page).to have_content "No supports"

        click_button "Support"

        expect(page).to have_content "1 support"
        expect(page).to have_content "You have already supported this investment project."

        click_button "Remove your support"

        expect(page).to have_content "No supports"
        expect(page).to have_button "Support"
      end
    end
  end

  context "Evaluating Phase" do
    before do
      budget.update(phase: "valuating")
    end

    scenario "Sidebar in show should display support text and count" do
      investment = create(:budget_investment, :selected, budget: budget, voters: [create(:user)])

      visit budget_investment_path(budget, investment)

      within("aside") do
        expect(page).to have_content "SUPPORTS"
        expect(page).to have_content "1 support"
      end
    end

    xscenario "Index should display support count" do
      investment = create(:budget_investment, budget: budget, heading: heading, voters: [create(:user)])

      visit budget_investments_path(budget, heading_id: heading.id)

      within("#budget_investment_#{investment.id}") do
        expect(page).to have_content "1 support"
      end
    end

    scenario "Show should display support text and count" do
      investment = create(:budget_investment, budget: budget, heading: heading, voters: [create(:user)])

      visit budget_investment_path(budget, investment)

      within("#budget_investment_#{investment.id}") do
        expect(page).to have_content "SUPPORTS"
        expect(page).to have_content "1 support"
      end
    end
  end

  context "Publishing prices phase" do
    before do
      budget.update(phase: "publishing_prices")
    end

    xscenario "Heading index - should show only selected investments" do
      investment1 = create(:budget_investment, :selected, heading: heading, price: 10000)
      investment2 = create(:budget_investment, :selected, heading: heading, price: 15000)
      investment3 = create(:budget_investment, heading: heading, price: 30000)

      visit budget_investments_path(budget, heading: heading)

      within("#budget-investments") do
        expect(page).to have_content investment1.title
        expect(page).to have_content investment2.title
        expect(page).not_to have_content investment3.title
      end
    end
  end

  context "Balloting Phase" do
    before do
      budget.update(phase: "balloting")
    end

    xscenario "Index" do
      user = create(:user, :level_two)
      investment1 = create(:budget_investment, :selected, heading: heading, price: 10000)
      investment2 = create(:budget_investment, :selected, heading: heading, price: 20000)

      login_as(user)
      visit root_path

      first(:link, "Participatory budgeting").click

      click_link "See all investments"

      within("#budget_investment_#{investment1.id}") do
        expect(page).to have_content investment1.title
        expect(page).to have_content "€10,000"
      end

      within("#budget_investment_#{investment2.id}") do
        expect(page).to have_content investment2.title
        expect(page).to have_content "€20,000"
      end

      expect(page).to have_link "Submit my ballot"
      expect(page).to have_content "STILL AVAILABLE TO YOU €666,666"
    end

    xscenario "Order by cost (only when balloting)" do
      mid_investment = create(:budget_investment, :selected, heading: heading, title: "Build a nice house", price: 1000)
      mid_investment.update_column(:confidence_score, 10)
      low_investment = create(:budget_investment, :selected, heading: heading, title: "Build an ugly house", price: 1000)
      low_investment.update_column(:confidence_score, 5)
      high_investment = create(:budget_investment, :selected, heading: heading, title: "Build a skyscraper", price: 20000)

      visit budget_investments_path(budget, heading_id: heading.id)

      click_link "by price"
      expect(page).to have_selector("a.is-active", text: "by price")

      within "#budget-investments" do
        expect(high_investment.title).to appear_before(mid_investment.title)
        expect(mid_investment.title).to appear_before(low_investment.title)
      end

      expect(page).to have_current_path(/order=price/)
      expect(page).to have_current_path(/page=1/)
    end

    xscenario "Show" do
      user = create(:user, :level_two)
      investment = create(:budget_investment, :selected, heading: heading, price: 10000)

      login_as(user)
      visit budget_investments_path(budget, heading_id: heading.id)

      click_link investment.title

      expect(page).to have_content "€10,000"
    end

    xscenario "Show message if user already voted in other heading" do
      group = create(:budget_group, budget: budget, name: "Global Group")
      heading = create(:budget_heading, group: group, name: "Heading 1")
      investment = create(:budget_investment, :selected, heading: heading)
      heading2 = create(:budget_heading, group: group, name: "Heading 2")
      investment2 = create(:budget_investment, :selected, heading: heading2)
      user = create(:user, :level_two, ballot_lines: [investment])

      login_as(user)
      visit budget_investment_path(budget, investment2)

      expect(page).to have_selector(".participation-not-allowed",
                                    text: "You have already voted a different heading: Heading 1",
                                    visible: :hidden)
    end

    scenario "Sidebar in show should display vote text" do
      investment = create(:budget_investment, :selected, budget: budget)
      visit budget_investment_path(budget, investment)

      within("aside") do
        expect(page).to have_content "VOTES"
      end
    end

    xscenario "Confirm" do
      budget.update!(phase: "balloting")
      user = create(:user, :level_two)

      global_group   = create(:budget_group, budget: budget, name: "Global Group")
      global_heading = create(:budget_heading, group: global_group, name: "Global Heading",
                              latitude: -43.145412, longitude: 12.009423)

      carabanchel_heading = create(:budget_heading, group: group, name: "Carabanchel")
      new_york_heading    = create(:budget_heading, group: group, name: "New York",
                                   latitude: -43.223412, longitude: 12.009423)

      create(:budget_investment, :selected, price: 1, heading: global_heading, title: "World T-Shirt")
      create(:budget_investment, :selected, price: 10, heading: global_heading, title: "Eco pens")
      create(:budget_investment, :selected, price: 100, heading: global_heading, title: "Free tablet")
      create(:budget_investment, :selected, price: 1000, heading: carabanchel_heading, title: "Fireworks")
      create(:budget_investment, :selected, price: 10000, heading: carabanchel_heading, title: "Bus pass")
      create(:budget_investment, :selected, price: 100000, heading: new_york_heading, title: "NASA base")

      login_as(user)
      visit budget_investments_path(budget, heading: global_heading)

      add_to_ballot("World T-Shirt")
      add_to_ballot("Eco pens")

      visit budget_investments_path(budget, heading: carabanchel_heading)

      add_to_ballot("Fireworks")
      add_to_ballot("Bus pass")

      visit budget_ballot_path(budget)

      expect(page).to have_content "But you can change your vote at any time "\
                                   "until this phase is closed."

      within("#budget_group_#{global_group.id}") do
        expect(page).to have_content "World T-Shirt"
        expect(page).to have_content "€1"

        expect(page).to have_content "Eco pens"
        expect(page).to have_content "€10"

        expect(page).not_to have_content "Free tablet"
        expect(page).not_to have_content "€100"
      end

      within("#budget_group_#{group.id}") do
        expect(page).to have_content "Fireworks"
        expect(page).to have_content "€1,000"

        expect(page).to have_content "Bus pass"
        expect(page).to have_content "€10,000"

        expect(page).not_to have_content "NASA base"
        expect(page).not_to have_content "€100,000"
      end
    end

    xscenario "Highlight voted heading" do
      budget.update!(phase: "balloting")
      user = create(:user, :level_two)

      heading_1 = create(:budget_heading, group: group, name: "Heading 1")
      heading_2 = create(:budget_heading, group: group, name: "Heading 2")

      create(:budget_investment, :selected, heading: heading_1, title: "Zero-emission zone")

      login_as(user)
      visit budget_investments_path(budget, heading_id: heading_1)

      add_to_ballot("Zero-emission zone")

      visit budget_group_path(budget, group)

      expect(page).to have_css("#budget_heading_#{heading_1.id}.is-active")
      expect(page).to have_css("#budget_heading_#{heading_2.id}")
    end

    xscenario "Ballot is visible" do
      login_as(author)

      visit budget_investments_path(budget, heading_id: heading.id)

      expect(page).to have_link("Submit my ballot")
      expect(page).to have_css("#progress_bar")

      within("#sidebar") do
        expect(page).to have_content("MY BALLOT")
        expect(page).to have_link("Submit my ballot")
      end
    end

    xscenario "Show unselected budget investments" do
      investment1 = create(:budget_investment, :unselected, :feasible, :finished, heading: heading)
      investment2 = create(:budget_investment, :selected,   :feasible, :finished, heading: heading)
      investment3 = create(:budget_investment, :selected,   :feasible, :finished, heading: heading)
      investment4 = create(:budget_investment, :selected,   :feasible, :finished, heading: heading)

      visit budget_investments_path(budget, heading_id: heading.id, filter: "unselected")

      within("#budget-investments") do
        expect(page).to have_css(".budget-investment", count: 1)

        expect(page).to have_content(investment1.title)
        expect(page).not_to have_content(investment2.title)
        expect(page).not_to have_content(investment3.title)
        expect(page).not_to have_content(investment4.title)
      end
    end

    xscenario "Do not display vote button for unselected investments in index" do
      investment = create(:budget_investment, :unselected, heading: heading)

      visit budget_investments_path(budget, heading_id: heading.id, filter: "unselected")

      expect(page).to have_content investment.title
      expect(page).not_to have_link("Vote")
    end

    scenario "Do not display vote button for unselected investments in show" do
      investment = create(:budget_investment, :unselected, heading: heading)

      visit budget_investment_path(budget, investment)

      expect(page).to have_content investment.title
      expect(page).not_to have_link("Vote")
    end

    describe "Reclassification" do
      scenario "Due to heading change" do
        investment = create(:budget_investment, :selected, heading: heading)
        user = create(:user, :level_two, ballot_lines: [investment])
        heading2 = create(:budget_heading, group: group)

        investment.update!(heading: heading2)

        login_as(user)
        visit budget_ballot_path(budget)

        expect(page).to have_content("You have voted 0 investment")
      end

      scenario "Due to being unfeasible" do
        investment = create(:budget_investment, :selected, heading: heading)
        user = create(:user, :level_two, ballot_lines: [investment])

        investment.update!(feasibility: "unfeasible", unfeasibility_explanation: "too expensive")

        login_as(user)
        visit budget_ballot_path(budget)

        expect(page).to have_content("You have voted 0 investment")
      end
    end
  end

  context "sidebar map" do
    xscenario "Display 6 investment's markers on sidebar map" do
      investment1 = create(:budget_investment, heading: heading)
      investment2 = create(:budget_investment, heading: heading)
      investment3 = create(:budget_investment, heading: heading)
      investment4 = create(:budget_investment, heading: heading)
      investment5 = create(:budget_investment, heading: heading)
      investment6 = create(:budget_investment, heading: heading)

      create(:map_location, longitude: 40.1231, latitude: -3.636, investment: investment1)
      create(:map_location, longitude: 40.1232, latitude: -3.635, investment: investment2)
      create(:map_location, longitude: 40.1233, latitude: -3.634, investment: investment3)
      create(:map_location, longitude: 40.1234, latitude: -3.633, investment: investment4)
      create(:map_location, longitude: 40.1235, latitude: -3.632, investment: investment5)
      create(:map_location, longitude: 40.1236, latitude: -3.631, investment: investment6)

      visit budget_investments_path(budget, heading_id: heading.id)

      within ".map_location" do
        expect(page).to have_css(".map-icon", count: 6, visible: :all)
      end
    end

    xscenario "Display 2 investment's markers on sidebar map" do
      investment1 = create(:budget_investment, heading: heading)
      investment2 = create(:budget_investment, heading: heading)

      create(:map_location, longitude: 40.1281, latitude: -3.656, investment: investment1)
      create(:map_location, longitude: 40.1292, latitude: -3.665, investment: investment2)

      visit budget_investments_path(budget, heading_id: heading.id)

      within ".map_location" do
        expect(page).to have_css(".map-icon", count: 2, visible: :all)
      end
    end

    xscenario "Display only investment's related to the current heading" do
      heading_2 = create(:budget_heading, name: "Madrid", group: group)

      investment1 = create(:budget_investment, heading: heading)
      investment2 = create(:budget_investment, heading: heading)
      investment3 = create(:budget_investment, heading: heading)
      investment4 = create(:budget_investment, heading: heading)
      investment5 = create(:budget_investment, heading: heading_2)
      investment6 = create(:budget_investment, heading: heading_2)

      create(:map_location, longitude: 40.1231, latitude: -3.636, investment: investment1)
      create(:map_location, longitude: 40.1232, latitude: -3.685, investment: investment2)
      create(:map_location, longitude: 40.1233, latitude: -3.664, investment: investment3)
      create(:map_location, longitude: 40.1234, latitude: -3.673, investment: investment4)
      create(:map_location, longitude: 40.1235, latitude: -3.672, investment: investment5)
      create(:map_location, longitude: 40.1236, latitude: -3.621, investment: investment6)

      visit budget_investments_path(budget, heading_id: heading.id)

      within ".map_location" do
        expect(page).to have_css(".map-icon", count: 4, visible: :all)
      end
    end

    scenario "Do not display investment's, since they're all related to other heading" do
      heading_2 = create(:budget_heading, name: "Madrid", group: group)

      investment1 = create(:budget_investment, heading: heading_2)
      investment2 = create(:budget_investment, heading: heading_2)
      investment3 = create(:budget_investment, heading: heading_2)

      create(:map_location, longitude: 40.1255, latitude: -3.644, investment: investment1)
      create(:map_location, longitude: 40.1258, latitude: -3.637, investment: investment2)
      create(:map_location, longitude: 40.1251, latitude: -3.649, investment: investment3)

      visit budget_investments_path(budget, heading_id: heading.id)

      within ".map_location" do
        expect(page).to have_css(".map-icon", count: 0, visible: :all)
      end
    end

    xscenario "Shows all investments and not only the ones on the current page" do
      stub_const("#{Budgets::InvestmentsController}::PER_PAGE", 2)

      3.times do
        create(:map_location, investment: create(:budget_investment, heading: heading))
      end

      visit budget_investments_path(budget, heading_id: heading.id)

      within("#budget-investments") do
        expect(page).to have_css(".budget-investment", count: 2)
      end

      within(".map_location") do
        expect(page).to have_css(".map-icon", count: 3, visible: :all)
      end
    end

    context "Author actions section" do
      scenario "Is not shown if investment is not editable or does not have an image" do
        budget.update!(phase: "reviewing")
        investment = create(:budget_investment, heading: heading, author: author)

        login_as(author)
        visit budget_investment_path(budget, investment)

        within("aside") do
          expect(page).not_to have_content "Author"
          expect(page).not_to have_link "Edit"
          expect(page).not_to have_link "Remove image"
        end
      end

      scenario "Contains edit button in the accepting phase" do
        investment = create(:budget_investment, heading: heading, author: author)

        login_as(author)
        visit budget_investment_path(budget, investment)

        within("aside") do
          expect(page).to have_content "AUTHOR"
          expect(page).to have_link "Edit"
          expect(page).not_to have_link "Remove image"
        end
      end

      scenario "Contains remove image button in phases different from accepting" do
        budget.update!(phase: "reviewing")
        investment = create(:budget_investment, :with_image, heading: heading, author: author)

        login_as(author)
        visit budget_investment_path(budget, investment)

        within("aside") do
          expect(page).to have_content "AUTHOR"
          expect(page).not_to have_link "Edit"
          expect(page).to have_link "Remove image"
        end
      end
    end
  end

  describe "SDG related list" do
    before do
      Setting["feature.sdg"] = true
      Setting["sdg.process.budgets"] = true
      budget.update!(phase: "accepting")
    end

    xscenario "create budget investment with sdg related list" do
      login_as(author)
      visit new_budget_investment_path(budget)
      fill_in_new_investment_title with: "A title for a budget investment related with SDG related content"
      fill_in_ckeditor "Description", with: "I want to live in a high tower over the clouds"
      click_sdg_goal(1)
      check "budget_investment_terms_of_service"

      click_button "Create Investment"

      within(".sdg-goal-tag-list") { expect(page).to have_link "1. No Poverty" }
    end

    xscenario "edit budget investment with sdg related list" do
      investment = create(:budget_investment, heading: heading, author: author)
      investment.sdg_goals = [SDG::Goal[1], SDG::Goal[2]]
      login_as(author)
      visit edit_budget_investment_path(budget, investment)

      remove_sdg_goal_or_target_tag(1)
      click_button "Update Investment"

      within(".sdg-goal-tag-list") do
        expect(page).not_to have_link "1. No Poverty"
        expect(page).to have_link "2. Zero Hunger"
      end
    end
  end
end
