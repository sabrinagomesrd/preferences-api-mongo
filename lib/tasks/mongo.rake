# frozen_string_literal: true

namespace :db do
  desc "Create Mongoid indexes declared on Preference"
  task create_indexes: :environment do
    Preference.create_indexes
    puts "Preference indexes created"
  end
end
