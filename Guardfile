guard :rspec, cmd: "bundle exec rspec" do
  watch(%r{^spec/.+\.rb$}) { |_m| "spec/historiographer_spec.rb" }
  watch(%r{^lib/(.+)\.rb$}) { |_m| "spec/historiographer_spec.rb" }
end
