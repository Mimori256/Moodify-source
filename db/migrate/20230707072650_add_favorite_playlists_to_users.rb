class AddFavoritePlaylistsToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :favoritePlaylists, :text
  end
end
