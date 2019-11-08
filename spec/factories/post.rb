FactoryBot.define do
  factory :post do
    sequence(:title) { |n| "Post #{n}"}
    body { "The body of the post" }
    author_id { 1 }
  end
end