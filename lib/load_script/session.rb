require "logger"
require "pry"
require "capybara"
require 'capybara/poltergeist'
require "faker"
require "active_support"
require "active_support/core_ext"

module LoadScript
  class Session
    include Capybara::DSL
    attr_reader :host
    def initialize(host = nil)
      Capybara.default_driver = :poltergeist
      @host = host || "http://localhost:3000"
    end

    def logger
      @logger ||= Logger.new("./log/requests.log")
    end

    def session
      @session ||= Capybara::Session.new(:poltergeist)
    end

    def run
      while true
        run_action(actions.sample)
      end
    end

    def run_action(name)
      benchmarked(name) do
        send(name)
      end
    rescue Capybara::Poltergeist::TimeoutError
      logger.error("Timed out executing Action: #{name}. Will continue.")
    end

    def benchmarked(name)
      logger.info "Running action #{name}"
      puts "Running action #{name}"
      start = Time.now
      val = yield
      logger.info "Completed #{name} in #{Time.now - start} seconds"
      puts "Completed #{name} in #{Time.now - start} seconds"
      val
    end

    def actions
      [:browse_loan_requests,
       :sign_up_as_lender,
       :sign_up_as_borrower,
       :new_borrower_creates_loan_request,
       :lender_makes_loan,
       :browses_categories]
    end

    def log_in(email="demo+horace@jumpstartlab.com", pw="password")
      log_out
      session.visit host
      session.click_link("Login")
      session.fill_in("session_email", with: email)
      session.fill_in("session_password", with: pw)
      session.click_link_or_button("Log In")
    end

    def browse_loan_requests
      session.visit "#{host}/browse"
      session.all(".lr-about").sample.click
    end

    def log_out
      session.visit host
      if session.has_content?("Log out")
        session.find("#logout").click
      end
    end

    def new_user_name
      "#{Faker::Name.name} #{Time.now.to_i}"
    end

    def new_user_email(name)
      "TuringPivotBots+#{name.split.join}@gmail.com"
    end

    def sign_up_as_lender(name = new_user_name)
      log_out
      session.find("#sign-up-dropdown").click
      session.find("#sign-up-as-lender").click
      session.within("#lenderSignUpModal") do
        session.fill_in("user_name", with: name)
        session.fill_in("user_email", with: new_user_email(name))
        session.fill_in("user_password", with: "password")
        session.fill_in("user_password_confirmation", with: "password")
        session.click_link_or_button "Create Account"
      end
    end

    def sign_up_as_borrower(name = new_user_name)
      log_out
      session.find("#sign-up-dropdown").click
      session.find("#sign-up-as-borrower").click
      session.within("#borrowerSignUpModal") do
        session.fill_in("user_name", with: name)
        session.fill_in("user_email", with: new_user_email(name))
        session.fill_in("user_password", with: "password")
        session.fill_in("user_password_confirmation", with: "password")
        session.click_link_or_button "Create Account"
      end
    end

    def new_borrower_creates_loan_request
      sign_up_as_borrower
      session.click_link_or_button "Create Loan Request"
      session.within("#loanRequestModal") do
        session.fill_in("loan_request_title",
                        with: new_loan_request_name)
        session.fill_in("loan_request_description",
                        with: new_loan_request_description)
        session.fill_in("loan_request_image_url",
                        with: "fakeimageurl")
        session.fill_in("loan_request_requested_by_date",
                        with: Time.now.strftime("%m/%d/%Y"))
        session.fill_in("loan_request_repayment_begin_date",
                        with: 10.days.from_now.strftime("%m/%d/%Y"))
        session.select(categories.sample, from: "loan_request_category")
        session.fill_in("loan_request_amount", with: rand(10_000))
        session.click_link_or_button "Submit"
      end
    end

    def new_loan_request_name
      "#{Faker::Commerce.product_name} #{Time.now.to_i}"
    end

    def new_loan_request_description
      "#{Faker::Lorem.sentence}"
    end

    def categories
      ["Agriculture", "Education", "Community"]
    end

    def browses_categories
      session.visit "#{host}/categories"
      session.all(".category").sample.click
    end

    def lender_makes_loan
      begin
        sign_up_as_lender
        session.visit "#{host}/browse"
        session.all(".lr-about").sample.click
        session.find(".btn-contribute").click
        session.visit "#{host}/cart"     
        session.find(".cart-button").click
      rescue
        retry while true
      end
    end
  end
end
