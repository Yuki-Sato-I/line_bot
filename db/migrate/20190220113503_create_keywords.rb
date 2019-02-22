class CreateKeywords < ActiveRecord::Migration[5.2]
  def change
    create_table :keywords do |t|
      t.integer :user_id
      t.string :key

      t.timestamps
    end
  end
end
