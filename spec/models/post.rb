class Post < ActiveRecord::Base
  include Historiographer
  acts_as_paranoid
  has_many :comments

  validates :type, inclusion: { in: ['Post', 'PrivatePost', nil] }
  before_validation :set_defaults
  after_find :set_comment_count

  attr_reader :comment_count

  def set_defaults
    @type ||= "Post"
  end

  def summary
    "This is a summary of the post."
  end

  def formatted_title
    "Title: #{title}"
  end

  def locked_value
    "My Great Post v1"
  end

  def complex_lookup
    %Q(
      Here is a complicated value, it
      is: #{locked_value}
      And another: #{formatted_title}
    ).strip.gsub(/\n{2}/, " ").split(" ").join(" ")
  end

  def set_comment_count
    comment_count
  end

  def comment_count
    @comment_count ||= comments.count
  end
end
