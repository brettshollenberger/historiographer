class PrivatePost < Post
  self.table_name = "posts"
  include Historiographer

  def title
    "Private — You cannot see!"
  end

  def formatted_title
    "Private — You cannot see!"
  end
end
