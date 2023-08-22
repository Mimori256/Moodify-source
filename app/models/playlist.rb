class Playlist < ApplicationRecord
    #ransackはホワイトリストに登録した属性以外の検索は受け付けないらしい(？)
    def self.ransackable_attributes(auth_object = nil)
        ["created_at", "creator", "creatorId", "id", "name", "tag", "updated_at", "url"]
    end
end
