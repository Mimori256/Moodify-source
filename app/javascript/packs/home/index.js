// ホーム画面(緯度経度やURLを入れるところ) で読み込まれるJavaScriptファイル

//document.addEventListener("turbolinks:load", () => {
// フォームが全て埋めてあるか調べる関数。埋まっていない場合はalertを出す
// フォームが全て埋まっている場合、ローディング画面を表示
// 位置情報取得周り
const fetchLatitudeLongtitude = (position) => {
  const latitude = position.coords.latitude;
  const longitude = position.coords.longitude;
  document.getElementById("latitude").value = latitude;
  document.getElementById("longitude").value = longitude;
  document.getElementById("location-exists").innerHTML = "取得完了◯";
};

const getLocation = () => {
  navigator.geolocation.getCurrentPosition(fetchLatitudeLongtitude);
};

// URLフォーム追加・削除周り
let urlCount = 2;

// URLの入力フォームを新しく追加
const addURL = () => {
  if (urlCount >= 5) {
    alert("6個以上URLを追加することはできません");
  } else {
    urlCount += 1;
    let p = document.createElement("p");
    p.setAttribute("id", `url${urlCount}`);
    let newForm = `<label> URL${urlCount} <input type="text" class="playlist_url" name="url${urlCount}" placeholder="https://open.spotify.com/playlist/..."> </label>`;
    p.innerHTML = newForm;

    let playlistUrl = document.getElementById("playlistURL");
    playlistUrl.appendChild(p);
  }
};

// URLの入力フォームを削除
const removeURL = () => {
  if (urlCount <= 2) {
    alert("最低でもプレイリストは2個以上必要です");
  } else {
    let removeElement = document.getElementById(`url${urlCount}`);
    removeElement.remove();
    urlCount -= 1;
  }
};

let locationButton = document.getElementById("locationButton");
locationButton.addEventListener("click", getLocation);

let addUrlButton = document.getElementById("addURL");
addUrlButton.addEventListener("click", addURL);

let removeUrlButton = document.getElementById("removeURL");
removeUrlButton.addEventListener("click", removeURL);

const rangeElement = document.getElementById("limit");
rangeElement.addEventListener("input", function () {
  document.getElementById("song-limit").innerHTML =
    rangeElement.value + "曲のプレイリストを作成";
});

document.getElementById("song-limit").innerHTML =
  rangeElement.value + "曲のプレイリストを作成";
//});
