desc "Add loan request images"
task :add_loan_request_images => :environment do
  LoanRequest.find_each do |loan_request|
    loan_request.update_attributes(image_url: DefaultImages.random)
    puts "Adding image to loan request number #{loan_request.id}"
  end
end
