// 推薦されたプレイリストを編集する画面で読み込まれるJavaScript
const {
  REGEXP_ABSOLUTE_RESOURCE_PATH,
} = require("webpack/lib/ModuleFilenameHelpers");

document.addEventListener("DOMContentLoaded", () => {
  // 各トラックの長さ(1:23といった形式)のリストから、プレイリスト全体の再生時間を計算する

  const calculateDuration = (durationList) => {
    let totalSecond = 0;

    for (const duration of durationList) {
      const [minute, second] = duration.split(":").map(Number);
      totalSecond += minute * 60 + second;
    }

    const minutes = Math.floor(totalSecond / 60);
    const seconds = totalSecond % 60;

    return `${minutes}分${seconds}秒`;
  };

  // 除外されていないトラックの一覧を取得
  const getUncheckedTracks = () => {
    const playlistTracks = Array.from(
      document.querySelectorAll("tr.track")
    ).filter((tr) => !tr.classList.contains("remove-item"));

    return playlistTracks;
  };

  // 並び替えが行われたときに、それをIDの順番に反映させる
  const updateIdList = () => {
    let trackIdTd = document.querySelectorAll("td.track-id");
    let trackIdList = [];

    trackIdTd.forEach((trackId) => {
      trackIdList.push(trackId.innerHTML.trim());
    });

    document.getElementById("track-id").value = trackIdList.join(",");
  };

  // プレイリストの曲数、再生時間の表示を更新する
  const updateLength = () => {
    let playlistTracks = getUncheckedTracks();
    let durationList = [];
    let output;

    durationList = playlistTracks.map((track) => {
      return track.getElementsByClassName("duration")[0].innerText;
    });

    output = `♪ ${playlistTracks.length}曲, ${calculateDuration(durationList)}`;

    document.getElementById("playlistLength").innerHTML = output;
  };

  let tr = document.querySelectorAll("tr.track");

  // 現在再生しているAudio
  let currentlyPlayingAudio;
  // 現在再生しているpreview要素
  let currentlyPlayingButton;

  // 現在曲を再生しているか
  let isPlayingAudio;
  tr.forEach(function (el) {
    const lastTd = el.querySelector("td:last-child");

    lastTd.addEventListener("click", function (e) {
      e.stopPropagation();
    });

    const playButton = lastTd.querySelector("span");
    const url = playButton.classList[1];
    playButton.addEventListener("click", function (e) {
      if (typeof url === "undefined") {
        alert("この曲は再生できません！");
      } else {
        let preview = new Audio(url);

        if (playButton.classList.contains("playing")) {
          // 現在再生している曲のボタンをクリックした場合、その曲を停止
          currentlyPlayingAudio.pause();
          currentlyPlayingAudio.currentTime = 0;
          playButton.classList.remove("playing");
          playButton.innerHTML = "▶";
          isPlayingAudio = false;
        } else if (!isPlayingAudio) {
          // 何も再生していない状態で、再生ボタンを押した場合
          preview.play();
          currentlyPlayingAudio = preview;
          currentlyPlayingButton = playButton;
          playButton.classList.add("playing");
          playButton.innerHTML = "■";
          isPlayingAudio = true;
        } else {
          // 何か再生していて、別の再生ボタンを押した場合
          // 現在再生している曲を停止
          currentlyPlayingAudio.pause();
          currentlyPlayingAudio.currentTime = 0;
          currentlyPlayingButton.innerHTML = "▶";
          currentlyPlayingButton.classList.remove("playing");

          // クリックされたボタンの曲を再生
          preview.play();
          currentlyPlayingAudio = preview;
          currentlyPlayingButton = playButton;
          playButton.classList.add("playing");
          playButton.innerHTML = "■";
          isPlayingAudio = true;
        }

        // 曲が終わった場合、自動で停止ボタンを再生ボタンに変える
        preview.addEventListener("ended", function () {
          currentlyPlayingAudio.pause();
          currentlyPlayingAudio.currentTime = 0;
          playButton.classList.remove("playing");
          playButton.innerHTML = "▶";
          isPlayingAudio = false;
        });
      }
    });

    // 曲をクリックすると、それを除外するようにする(rowにクラス "remove-item" を追加)
    el.addEventListener("click", function () {
      if (
        getUncheckedTracks().length === 1 &&
        !el.classList.contains("remove-item")
      ) {
        alert("すべての曲を除外することはできません！");
      } else {
        el.classList.toggle("remove-item");
        updateLength();
      }
    });
  });

  //JavaScriptライブラリSoartable.jsを用いて、ドラッグアンドドロップで簡単に並び替えができるようにしている
  let sortElement = document.getElementById("sort-table");
  Sortable.create(sortElement, {
    animation: 150,
    onSort: function () {
      updateIdList();
    },
  });
  updateLength();
  updateIdList();
});
