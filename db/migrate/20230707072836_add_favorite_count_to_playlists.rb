class AddFavoriteCountToPlaylists < ActiveRecord::Migration[6.1]
  def change
    add_column :playlists, :favoriteCount, :integer
  end
end
