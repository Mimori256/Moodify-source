class SessionsController < ApplicationController

  # Spotifyでログインすると、これが呼び出される。ログインして、sessionに、プレイリスト作成に必要なuser_infoを格納
  def create
    user = RSpotify::User.new(request.env["omniauth.auth"])
    session[:user_info] = request.env["omniauth.auth"]

    # ユーザーのID (識別に使用)
    user_id = session[:user_info]["uid"]
    # ユーザーの表示名
    user_name = session[:user_info]["info"]["display_name"]

    # データベース上に登録されているユーザーのID一覧を取得
    user_id_list = User.all.map(&:uid)

    # ユーザーがデータベースに登録されていない場合テーブルに登録する
    if !user_id_list.include?(user_id)
      User.create({ uid: user_id, name: user_name })
    end

    # トップページに戻る
    redirect_to root_path
  end

  def destroy
    session[:user_info] = nil
    # トップページに戻る
    redirect_to root_path
  end
end
