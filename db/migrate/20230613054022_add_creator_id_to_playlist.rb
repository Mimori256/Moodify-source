class AddCreatorIdToPlaylist < ActiveRecord::Migration[6.1]
  def change
    add_column :playlists, :creatorId, :string
  end
end
