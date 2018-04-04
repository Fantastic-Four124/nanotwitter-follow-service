class CreateFollow < ActiveRecord::Migration[5.1]
  def change
    create_table :follows do |t|
      t.integer :user_id
      t.integer :leader_id
      t.datetime   :follow_date
      t.timestamps

      t.index(:leader_id)

    end
  end
end
