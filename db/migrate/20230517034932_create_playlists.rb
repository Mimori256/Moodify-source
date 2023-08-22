class CreatePlaylists < ActiveRecord::Migration[6.1]
  def change
    create_table :playlists do |t|

      t.string :name
      t.string :creator
      t.string :url

      t.timestamps
    end
  end
end
