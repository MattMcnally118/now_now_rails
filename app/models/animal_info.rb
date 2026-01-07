class AnimalInfo < ApplicationRecord
  belongs_to :animal

  validates :habitat, presence: true
  validates :diet, presence: true
  validates :behavior_notes, presence: true
  validates :animal_id, uniqueness: true
end
