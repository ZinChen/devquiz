class TestMetadatum < ApplicationRecord
  self.table_name = "test_metadata"

  has_many :test_attempts, foreign_key: :test_slug, primary_key: :slug

  validates :slug, :title, presence: true
  validates :slug, uniqueness: true

  def tag_list
    tags.to_s.split(",").map(&:strip)
  end

  def tag_list=(arr)
    self.tags = Array(arr).join(",")
  end
end
