require "uri"
require "net/http"
require "rspotify"
require "date"

class PlaylistController < ApplicationController
  rescue_from RestClient::NotFound, with: :url_error
  rescue_from RestClient::BadRequest, with: :playlist_error

  protect_from_forgery
  # View上でこの関数を呼び出せるようにする
  helper_method :playlist_url_to_image

  def confirm
    RSpotify.authenticate(ENV["SPOTIFY_CLIENT_ID"], ENV["SPOTIFY_CLIENT_SECRET"])
    ENV["ACCEPT_LANGUAGE"] = "ja"

    # 送られている情報: param = {track-ids => 作成画面で作った、プレイリストのトラックをカンマで区切ったもの
    # playlist-name => プレイリストの名前, creator-name => 作成者の名前}

    # パラメータが与えられていないときに処理を止める
    if params["playlist-name"].nil?
      return -1
    end

    # user-infoをもとにユーザーのインスタンスを作成
    @user = RSpotify::User.new($user_info)

    # プレイリストを生成
    @playlist = @user.create_playlist!(params["playlist-name"])
    @track_list = []

    @track_id_list = params["track-ids"].split(",")
    @track_id_list.each do |id|
      @track_list << RSpotify::Track.find(id)
    end

    # プレイリストのジャンルを3つ、カンマ区切りで取得
    @genres = get_genre(@track_list)

    @playlist.add_tracks!(@track_list)
    @id = @playlist.id
    @name = @playlist.name
    @creator = params["creator-name"]
    # ユーザーのIDを取得
    @creator_id = $user_info["uid"]
    @url = "https://open.spotify.com/playlist/#{@id}"

    @twitter_share_link = "http://twitter.com/intent/tweet?text=Moodifyを使ってプレイリスト「#{@name}」を作成しました!!"
    @twitter_share_link += "&url=#{@url}"
    @twitter_share_link += "&hashtags=Moodify"

    # データベースに追加
    Playlist.create({ name: @name, creator: @creator, creatorId: @creator_id, url: @url, tag: @genres, favoriteCount: 0 })
  end

  def create
    RSpotify.authenticate(ENV["SPOTIFY_CLIENT_ID"], ENV["SPOTIFY_CLIENT_SECRET"])
    ENV["ACCEPT_LANGUAGE"] = "ja"

    @parameters = params

    $error_flag = false

    # パラメータが与えられていないときに処理を止める
    return -1 if params["user-info"].nil?

    # プレイリストの作成に必要なユーザー情報がpostされているので、それをグローバル変数として、後で使えるようにしている
    $user_info = eval(params["user-info"])
    @user_name = $user_info["info"]["display_name"]

    # トップページで指定した曲数の受け取り
    limit = params["limit"]

    @url_list = get_url_list(@parameters)
    @id_list = []
    @url_list.each do |url|
      @id_list << url.split("/")[-1]
    end


    # プレイリストに入れる曲として推薦された、トラックのリスト(これを推薦する関数が欲しい)
    @tracks, recommendation_type_hash = get_track_list(@id_list, limit.to_i)
    # 重複したトラックを削除
    @tracks.uniq!(&:id)
    @track_id_list = @tracks.map(&:id)

    @tr_list = []
    @track_id_list.each do |track|
      @tr_list << "<tr class = 'track #{recommendation_type_hash[track]}'>"
    end

    # duration(曲の長さ)は、API上ではミリ秒で渡されるため、それを"分:秒"形式に変換して、リストにしている
    @durations = []
    @tracks.each do |track|
      @durations << parse_duration_ms(track)
    end
  end

  # データベースに保存されているすべてのプレイリスト情報を返す
  def show
    # パラメーターが指定されていない場合、全てのプレイリストを表示

    if not params["query"].nil?
      query = "%#{params["query"]}%"
      @playlists = Playlist.where("creator LIKE ? OR name LIKE ?", query, query)
    elsif params["user"].nil? && params["tag"].nil?
      @playlists = Playlist.all
      @message = "みんなが作成したプレイリスト一覧"
      @message_class = "button2_creator_name"
    elsif not params["user"].nil?
      @user_id = params["user"]
      @playlists = Playlist.where(creatorId: @user_id)
      @user_name = User.find_by(uid: @user_id).name

      # @message = "#{@user_name}が作成したプレイリスト一覧"
      @message = "#{@user_name}"
      @message_class = "button2_creator_name"
    else
      @tag = params["tag"]
      @playlists = Playlist.ransack(tag_cont: @tag).result
      # @message = "#{@tag}のタグを持つプレイリスト一覧"
      @message = "#{@tag}"
      @message_class = "button2_selected_tag"
    end

    # お気に入りに追加されている曲の一覧の配列を取得
    @favorite_playlists = []
    current_user = User.find_by(uid: session[:user_info]["info"]["id"])
    if not current_user.favoritePlaylists.nil?
      @favorite_playlists = current_user.favoritePlaylists.split(",")
    end

    # お気に入り一覧を表示するモードの場合
    @show_favorite = false
    if not params["favorite"].nil? and params["favorite"] == "true"
      @show_favorite = true
      @playlists = []
      @favorite_playlists.each do |url|
        playlist = Playlist.find_by(url: url)
        if not playlist.nil?
          @playlists << playlist
        end
      end
    end

    # ソート方法のチェック
    @sort_by_favorite = false
    if not params["sort"].nil? and params["sort"] == "favorite"
      # お気に入り順に並び替え
      @sort_by_favorite = true
      @playlists = @playlists.sort_by { |v| v.favoriteCount }
      @playlists = @playlists.reverse
    else
      # 通常の日付順の並び替え
      # 新しいプレイリストを先頭に表示するために、逆にする
      @playlists = @playlists.reverse
    end

    # 1ページあたり10件プレイリストを表示する
    @playlists = Kaminari.paginate_array(@playlists).page(params[:page]).per(10)
  end

  # 選択されたプレイリストをデータベースから削除する
  def delete
    if not params["url"].nil?
      @url = params["url"]
      @playlist = Playlist.find_by(url: @url)
      @playlist_name = @playlist.name
      if (session[:user_info]["info"]["id"] == @playlist.creatorId)
        @playlist.destroy
      else
        @message = "自分のプレイリスト以外は削除できません。"
      end
    end
  end

  # 選択されたプレイリスト名、タグを編集する
  def edit_confirm
    if not params["url"].nil?
      @url = params["url"]
      @playlist = Playlist.find_by(url: @url)
      @old_playlist_name = @playlist.name
      @old_tag_list = []
      if not @playlist.tag.nil?
        @tags = @playlist.tag.split(",")
        @tags.each do |tag|
          @old_tag_list << tag
        end
      end
      # Playlist.find_by(url: @url).update(name: @playlist_name)
    end
  end

  def edit_execute
    @url = params["url"]
    @playlist = Playlist.find_by(url: @url)
    if (session[:user_info]["info"]["id"] == @playlist.creatorId)
      if not params["new_playlist_name"].nil?
        @new_playlist_name = params["new_playlist_name"]
        @playlist.update(name: @new_playlist_name)
      end

      if params["new_tag_list"].nil?
        @playlist.update(tag: nil)
      else
        @new_tag_list = params["new_tag_list"]
        @new_tag_list.delete("")  #配列から空欄の要素を取り出す
        @new_tag_list = @new_tag_list.join(",")
        @playlist.update(tag: @new_tag_list)
      end

      @new_playlist = Playlist.find_by(url: @url)
    else
      @message = "自分のプレイリスト以外は編集できません。"
    end
  end

  # 曲のお気に入りの切り替えをするためのアクション
  def like
    url = params["url"]
    favorite_playlists = []
    current_user = User.find_by(uid: session[:user_info]["info"]["id"])

    if not current_user.favoritePlaylists.nil?
      favorite_playlists = current_user.favoritePlaylists.split(",")
    end

    selected_playlist = Playlist.find_by(url: url)
    like_count = selected_playlist.favoriteCount

    #like_countがnilだった場合0にしておく
    if like_count.nil?
      like_count = 0
    end

    # すでに選択した曲がお気に入り登録されている場合
    if favorite_playlists.include?(url)
      favorite_playlists.delete(url)
      like_count -= 1
      # 選択した曲がお気に入り登録されていない場合
    else
      favorite_playlists << url
      like_count += 1
    end

    # レコードの値を更新
    current_user.update(favoritePlaylists: favorite_playlists.join(","))
    selected_playlist.update(favoriteCount: like_count)
    redirect_to "/playlist/show"
  end

  private

  # 送られてきたparamsから、プレイリストのURL一覧を取得する
  def get_url_list(parameters)
    url_count = 1
    url_list = []
    loop do
      url = parameters["url#{url_count}"]
      break if url.nil?

      url_list << url
      url_count += 1
    end

    return url_list
  end

  # 日中か夜か、雨が降っているかを返す
  def get_weather(latitude, longitude)
    accces_url = "https://api.open-meteo.com/v1/forecast?latitude=#{latitude}&longitude=#{longitude}&current_weather=true&timezone=JST"

    if params["manual-parameter"] == "on"
      is_day = 1
      is_raining = 0
      is_day = 0 if params["day"] == "night"
      is_raining = 1 if params["weather"] == "rainy"
      return [is_day, is_raining]
    end

    uri = URI(accces_url)
    res = Net::HTTP.get_response(uri)

    json = eval(res.body)

    weather_code = json[:current_weather][:weathercode]

    # 1: 日中, 0: 夜
    is_day = json[:current_weather][:is_day]
    is_raining = weather_code > 50 ? 1 : 0

    return [is_day, is_raining]
  end

  # 再生時間はミリ秒で渡されるので、それを、 分:秒 形式にする関数
  def parse_duration_ms(track)
    duration_ms = track.duration_ms()
    minute = duration_ms / 60000
    second = (duration_ms % 60000) / 1000

    # 秒が一桁の場合、先頭に0をつける
    second = format("%02d", second)

    return "#{minute}:#{second}"
  end

  # プレイリストのURLから、そのプレイリストの画像のURLを返す関数
  def playlist_url_to_image(url)
    playlist_id = url.split("/")[-1]
    playlist = RSpotify::Playlist.find_by_id(playlist_id)
    return playlist.images[0]["url"]
  end

  #プレイリストのIDのリストから、すべての曲をまとめて1つのリストに入れる。
  def add_track_list(idlist)
    track_list = []
    idlist.each do |id|
      playlist = RSpotify::Playlist.find_by_id(id)
      #プレイリストが空だった場合、エラーページを表示する
      if playlist.tracks.empty? and not $error_flag
        @error_message = "空のプレイリストのURLは入力しないでください！"
        playlist_error
      else
        playlist.tracks.each do |song|
          track_list << song
        end
      end
    end
    return track_list
  end

  #一致数をカウントし、ハッシュの値として入力する
  def match_count(track_list)
    hash = {}
    track_list.each do |track|
      if hash[track.id].nil?
        hash[track.id] = 1
      else
        hash[track.id] += 1
      end
    end

    return hash
  end

  def get_weather_parameters(is_raining, is_day)
    t_danceability = is_raining == 1 ? 0.3 : 0.8
    t_acousticness = is_raining == 1 ? 0.8 : 0.3
    t_tempo = is_raining == 1 ? 80 : 150
    t_valence = is_raining == 1 ? 0.3 : 0.7

    if is_day == 1
      #昼のパラメータ
      t_energy = 0.8
      t_instrumentalness = 0.3
      t_valence += 0.2
    else
      #夜のパラメータ
      t_energy = 0.3
      t_instrumentalness = 0.6
      t_valence -= 0.2
    end
    return t_acousticness, t_danceability, t_energy, t_instrumentalness, t_tempo, t_valence
  end

  #季節によるパラメータ修正
  def season_parameters(t_acousticness, t_danceability, t_energy, t_tempo)
    month = Date.today.mon

    if params["manual-parameter"] == "on"
      month = 12 if params["season"] == "winter"
      month = 8 if params["season"] == "summer"
      month = 4 if params["season"] == "normal" 
    end
    if (1 <= month && month <= 2) || month == 12
      t_energy -= 0.2
      t_danceability -= 0.3
      t_tempo -= 0.1
      t_liveness = 0.1
    elsif (6 <= month && month <= 8)
      t_acousticness -= 0.1
      t_danceability += 0.1
      t_tempo += 0.1
      t_liveness = 0.6
    else
      t_liveness = 0.1
    end

    return t_acousticness, t_danceability, t_tempo, t_energy, t_liveness
  end

  # プレイリストから、アーティストIDの配列を取得
  def get_artist_list(playlist_id)
    res = []
    playlist = RSpotify::Playlist.find_by_id(playlist_id)
    playlist.tracks.each do |track|
      artists = track.artists.map(&:id)
      res.concat(artists)
    end
    return res.uniq
  end

  # playlistからトラックをn個ランダムに選択する
  # 引数: プレイリストのID, 選択する個数 → プレイリストの中のランダムな曲のIDの配列
  def choose_random_track(playlist, n)
    tracks = RSpotify::Playlist.find_by_id(playlist).tracks
    return tracks.sample(n)
  end

  # プレイリストで曲の重複がない場合、シードトラックを作るために、それぞれのプレイリストから曲を選ぶ
  # 引数: プレイリストIDの配列 → シードとなるトラックの配列
  def select_tracks_from_each(playlists)
    seed_tracks = []
    length = playlists.length
    tracks_per_playlist = 5 / length

    playlists.each do |playlist|
      seed_tracks.concat(choose_random_track(playlist, tracks_per_playlist))
    end

    remaining_tracks_count = 5 - seed_tracks.length
    seed_tracks.concat(choose_random_track(playlists[-1], remaining_tracks_count))
    return seed_tracks
  end

  # プレイリストでアーティストの重複がない場合、シードアーティストを作るために、それぞれのプレイリストからアーティストを選ぶ
  # 引数: プレイリストIDの配列 → シードとなるアーティストの配列
  def select_artists_from_each(playlists)
    seed_artists = []
    length = playlists.length
    artists_per_playlist = 5 / length

    playlists.each do |playlist|
      seed_artists.concat(get_artist_list(playlist).sample(artists_per_playlist))
    end

    remaining_artists_count = 5 - seed_artists.length

    seed_artists.concat(get_artist_list(playlists[-1]).sample(remaining_artists_count))
    return seed_artists
  end

  # 特定のアーティストの曲を指定した曲数ランダムで取ってくる関数
  def get_random_songs_from_artist(artist_id_list, n)
    return_list = []
    artists_num = artist_id_list.length
    # 各アーティストから取ってくる数→全体の数と考慮しつつ多めに取る→超えたら消す
    each_n = n / artists_num

    artist_id_list.each do |artist_id|
      # 最後のアーティストは残りの曲数取ってくる
      if artist_id == artist_id_list[-1]
        each_n = n - return_list.length
      end

      count = 0
      artist = RSpotify::Artist.find(artist_id)
      albums = artist.albums(limit: 15, country: "JP").shuffle

      albums.each do |album|
        # 指定曲数見つかるかすべてのアルバムを探したら終わり
        break if count >= each_n

        # アルバムから一曲ランダムで取ってくる
        track = album.tracks.sample
        # そのアーティストの曲ならreturn_listに追加(複数のアーティストで作るアルバムもあるため)
        if track.artists[0].id == artist_id
          return_list << track
        end
        count += 1
      end
    end

    return return_list
  end

  def recommend_by_song(length_limit, seed_tracks, result, check_value, is_day, is_raining)
    # 位置情報によるパラメータを使用するか否かによる推薦の場合分け
    if check_value != "on"
      t_acousticness, t_danceability, t_energy, t_instrumentalness, t_tempo, t_valence = get_weather_parameters(is_raining, is_day)
      t_acousticness, t_danceability, t_tempo, t_liveness = season_parameters(t_acousticness, t_danceability, t_energy, t_tempo)

      return RSpotify::Recommendations.generate(limit: ((length_limit - result.length) / 2).floor, seed_tracks: seed_tracks, target_acousticness: t_acousticness, target_danceability: t_danceability, target_energy: t_energy, target_instrumentalness: t_instrumentalness, target_tempo: t_tempo, target_valence: t_valence, target_liveness: t_liveness).tracks
    else
      return RSpotify::Recommendations.generate(limit: ((length_limit - result.length) / 2).floor, seed_tracks: seed_tracks).tracks
    end
  end

  def recommend_by_artist(artists_limit, seed_artists, result, check_value, is_day, is_raining)
    # 位置情報によるパラメータを使用するか否かによる推薦の場合分け
    if check_value != "on"
      t_acousticness, t_danceability, t_energy, t_instrumentalness, t_tempo, t_valence = get_weather_parameters(is_raining, is_day)
      t_acousticness, t_danceability, t_energy, t_tempo, t_liveness = season_parameters(t_acousticness, t_danceability, t_energy, t_tempo)

      return RSpotify::Recommendations.generate(limit: artists_limit, seed_artists: seed_artists, target_acousticness: t_acousticness, target_danceability: t_danceability, target_energy: t_energy, target_instrumentalness: t_instrumentalness, target_tempo: t_tempo, target_valence: t_valence, target_liveness: t_liveness).tracks
    else
      return RSpotify::Recommendations.generate(limit: artists_limit, seed_artists: seed_artists).tracks
    end
  end

  def get_track_list(playlists, length_limit)
    # 最終的なトラック一覧
    result = []
    seed_tracks = []
    recommendation_type_hash = {}

    # チェックボックスの状態と位置情報の値の取得
    # チェックされているときは"on"が返ってくる
    check_value = params["check_value"]
    latitude = params["latitude"]
    longitude = params["longitude"]

    is_day = 0
    is_raining = 0

    if check_value != "on"
      is_day, is_raining = get_weather(latitude, longitude)
    end

    # 重複したトラックを探す
    track_list = add_track_list(playlists)
    # ここで得られるハッシュは {トラックのID => カウント}
    match_hash = match_count(track_list)
    match_hash.each do |k, v|
      if v > 1
        # IDからトラックを取得する
        result << RSpotify::Track.find(k)
        recommendation_type_hash[k] = "track-red"
      end
    end

    # 重複したトラックを指定したプレイリストの曲数の半分にする
    if result.length > (length_limit / 2)
      result = result.sample(length_limit / 2)
    end

    # 重複したトラックによる推薦
    if result.length > 5
      seed_tracks = result.sample(5)

      # 重複したトラックがない場合
    elsif result.empty?
      seed_tracks = select_tracks_from_each(playlists)
    else
      seed_tracks = result
    end

    # seed_tracksは上の都合上トラックのリストのため、mapを使ってIDのリストにする
    # seed_tracksは、Trackのリストである
    recommendations = recommend_by_song(length_limit, seed_tracks.map(&:id), result, check_value, is_day, is_raining)

    recommendations.each do |track|
      if recommendation_type_hash[track.id].nil?
        recommendation_type_hash[track.id] = "track-green"
      end
    end

    result.concat(recommendations)

    #重複したアーティストによる推薦
    seed_artists = []
    match_artist_hash = {}
    random_artists = []
    # アーティストによる推薦に割り当てられた数
    artists_limit = length_limit - result.length
    playlists.each do |playlist|
      unique_artist_list = get_artist_list(playlist)
      unique_artist_list.each do |artist|
        if match_artist_hash.keys.include?(artist)
          match_artist_hash[artist] += 1
        else
          match_artist_hash[artist] = 1
        end
      end
    end

    match_artist_hash.each_key do |artist|
      if match_artist_hash[artist] > 1
        seed_artists << artist
      end
    end

    # 全員一致したアーティストはget_random_songs_from_artist()を使う。
    perfect_match_artists_list = match_artist_hash.select { |k, v| v == playlists.length }.keys
    if not perfect_match_artists_list.empty?
      #最大25%
      if perfect_match_artists_list.length >= 5
        random_artists = get_random_songs_from_artist(perfect_match_artists_list[0, 5], artists_limit / 2)
      else
        # 5曲以下なら一曲あたり5%の数取ってくる
        random_artists = get_random_songs_from_artist(perfect_match_artists_list, perfect_match_artists_list.length * (artists_limit / 10))
      end
    end
    random_artists.each do |track|
      if recommendation_type_hash[track.id].nil?
        recommendation_type_hash[track.id] = "track-gray"
      end
    end
    result.concat(random_artists)

    artists_limit -= random_artists.length

    if seed_artists.length > 5
      seed_artists = seed_artists.sample(5)
      # 重複したアーティストがいない場合
    elsif seed_artists.empty?
      seed_artists = select_artists_from_each(playlists)
    end

    recommendations = recommend_by_artist(artists_limit, seed_artists, result, check_value, is_day, is_raining)

    recommendations.each do |track|
      if recommendation_type_hash[track.id].nil?
        recommendation_type_hash[track.id] = "track-blue"
      end
    end

    result.concat(recommendations)

    return [result, recommendation_type_hash]
  end

  # トラックリストからジャンルを3つまで調べ→戻り値は文字列("genre1,genre2,genre3")
  def get_genre(tracklist)
    genre_list = []
    genre_hash = Hash.new(0)

    tracklist.each do |track|
      track.artists.each do |artist|
        artist.genres.each do |genre|
          genre_list << genre
        end
      end
    end

    # genre_listのそれぞれのgenreの出現回数カウント
    genre_list.each_with_object(genre_hash) { |genre, counts| counts[genre] += 1 }

    # valueが1以上orリストのサイズの1割以上のジャンルのみ取り出す。
    genre_hash = genre_hash.find_all { |k, v| (v > 1) && (v > tracklist.length * 0.1) }.to_h

    # valueで昇順に並び替え
    genre_hash = genre_hash.sort { |(k1, v1), (k2, v2)| v2 <=> v1 }.to_h

    return genre_hash.keys.first(3).join(",")
  end

  # URLのエラー処理
  def url_error
    if not $error_flag
      $error_flag = true
      @error_message = "SpotifyのプレイリストのURLを入力してください！"
      render "/playlist/error"
    end
  end

  # プレイリストが空だった場合のエラー処理
  def playlist_error
    if not $error_flag
      $error_flag = true
      @error_message = "空のプレイリストのURLは入力しないでください！"
      render "/playlist/error"
    end
  end
end
