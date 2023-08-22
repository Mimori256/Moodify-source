class AddDetailsToPlaylist < ActiveRecord::Migration[6.1]
  def change
    add_column :playlists, :tag, :text
  end
end
