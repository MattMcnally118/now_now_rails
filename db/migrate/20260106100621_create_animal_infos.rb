class CreateAnimalInfos < ActiveRecord::Migration[7.1]
  def change
    create_table :animal_infos do |t|
      t.references :animal, null: false, foreign_key: true
      t.text :habitat
      t.text :diet
      t.text :behavior_notes
      t.string :image_path
      t.string :icon_path

      t.timestamps
    end
  end
end
