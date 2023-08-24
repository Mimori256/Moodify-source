# Moodify-source
情報メディア実験で制作したWebアプリMoodifyのソース公開用のレポジトリです。

## 動かし方
* https://developer.spotify.com/ から新しいアプリを作成
* Client ID と Client Secretを保存
* Redirect URI として、http://localhost:3000/auth/spotify/callback, http://localhost:3000/callback を追加
* レポジトリを clone
* .env を以下の形式で保存

  ```
  SPOTIFY_CLIENT_ID="保存したID"
  SPOTIFY_CLIENT_SECRET="保存したSecret"
  ```

* bundle install を実行
* rails db:migrate を実行
* rails s を実行
