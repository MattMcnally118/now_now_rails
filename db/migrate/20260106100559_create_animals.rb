class CreateAnimals < ActiveRecord::Migration[7.1]
  def change
    create_table :animals do |t|
      t.string :name
      t.string :slug
      t.integer :label

      t.timestamps
    end
    add_index :animals, :slug, unique: true
    add_index :animals, :label, unique: true
  end
end
