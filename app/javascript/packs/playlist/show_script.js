document.addEventListener("DOMContentLoaded", () => {
  const getTextContents = (elements) => {
    let res = [];
    for (let i = 0; i < elements.length; i++) {
      res.push(elements[i].innerHTML.toLowerCase());
    }
    return res;
  };

  const getMatchedNames = (names, input) => {
    let matchedNames = [];
    for (let i = 0; i < names.length; i++) {
      if (names[i].indexOf(input) === 0) {
        matchedNames.push(names[i]);
      }
    }
    return matchedNames;
  };

  const updateTables = (matchedNames) => {
    let trList = document.querySelectorAll("tr.playlist");
    let tr;
    let creatorName;
    let playlistName;
    for (let i = 0; i < trList.length; i++) {
      tr = trList[i];
      creatorName = tr
        .querySelector("td .button2_creator_name")
        .innerHTML.toLowerCase();
      playlistName = tr
        .querySelector("td.created-playlist-name")
        .innerHTML.toLowerCase();
      if (
        !matchedNames.includes(creatorName) &&
        !matchedNames.includes(playlistName)
      ) {
        tr.setAttribute("hidden", "");
      } else {
        tr.removeAttribute("hidden");
      }
    }
  };

  const replaceTagName = (target, tagName) => {
    if (!target.parentNode) {
      return target;
    }

    const replacement = document.createElement(tagName);
    Array.from(target.attributes).forEach((attribute) => {
      const { nodeName, nodeValue } = attribute;
      if (nodeValue) {
        replacement.setAttribute(nodeName, nodeValue);
      }
    });
    Array.from(target.childNodes).forEach((node) => {
      replacement.appendChild(node);
    });
    target.parentNode.replaceChild(replacement, target);
    return replacement;
  };

  /*
  // 入力フォームに変更があったら実行される
  // プレイリスト名とプレイリストの作成者が入力に部分一致したプレイリストを表示
  const userSearchForm = document.getElementById("user-search-form");
  userSearchForm.oninput = () => {
    const input = document
      .getElementById("user-search-form")
      .value.toLowerCase();
    const creatorNameTags = document.getElementsByClassName(
      "button2_creator_name"
    );
    const playlistNameElements = document.getElementsByClassName(
      "created-playlist-name"
    );
    const creatorNames = getTextContents(creatorNameTags);
    const playlistNames = getTextContents(playlistNameElements);
    const matchedNames = getMatchedNames(
      creatorNames.concat(playlistNames),
      input
    );
    updateTables(matchedNames);
  };
  */

  //タグの複数検索に関する関数
  const getAvailableGenres = () => {
    const genreTags = document.getElementsByClassName("button2_tag");
    let genreNameList = [];
    for (let i = 0; i < genreTags.length; i++) {
      genreNameList.push(genreTags[i].innerHTML);
    }

    // 重複を削除して返す
    const tmpSet = new Set(genreNameList);
    return [...tmpSet];
  };

  // ダイアログの中身のチェックボックスを生成
  const createDialogContent = (genreList) => {
    genreList = genreList.sort();
    let dialogElement;
    let output = [];
    let genre;
    for (let i = 0; i < genreList.length; i++) {
      genre = genreList[i];
      dialogElement = `<label class="genreCheckbox"><input type="checkbox" value="${genre}" checked>${genre}</label>`;
      output.push(dialogElement);
    }
    return output.join("\n");
  };

  const updateFilter = (checkboxes) => {
    let shownGenres = [];
    for (let i = 0; i < checkboxes.length; i++) {
      if (checkboxes[i].checked) {
        shownGenres.push(checkboxes[i].value);
      }
    }
    let trList = document.querySelectorAll("tr.playlist");
    let playlistGenres = [];
    let tr;
    let isShown = false;
    for (let i = 0; i < trList.length; i++) {
      isShown = false;
      tr = trList[i];
      playlistGenres = Array.from(tr.getElementsByClassName("button2_tag")).map(
        (a) => a.innerHTML
      );
      playlistGenres.forEach((genre) => {
        if (shownGenres.includes(genre)) {
          isShown = true;
        }
      });

      if (!isShown) {
        tr.setAttribute("hidden", "");
      }

      if (isShown && tr.hasAttribute("hidden")) {
        tr.removeAttribute("hidden");
      }
    }
  };

  const availableGenres = getAvailableGenres();
  const checkboxContent = createDialogContent(availableGenres);
  const removeCheck = document.getElementById("removeCheck");
  const closeButton = document.getElementById("closeButton");
  document.getElementById("genreCheckboxes").innerHTML = checkboxContent;

  const openDialog = document.getElementById("openDialog");
  const filterDialog = document.getElementById("filterDialog");

  openDialog.addEventListener("click", () => {
    if (filterDialog.open) {
      filterDialog.close();
    }
    filterDialog.show();
  });

  removeCheck.addEventListener("click", () => {
    const checkboxes = document.querySelectorAll('input[type="checkbox"]');
    let checkbox;
    for (let i = 0; i < checkboxes.length; i++) {
      checkbox = checkboxes[i];
      checkbox.checked = false;
    }
    updateFilter(checkboxes);
  });

  closeButton.addEventListener("click", () => {
    filterDialog.close();
  });

  filterDialog.addEventListener("click", (event) => {
    if (event.target.closest("#dialogContent") === null) {
      filterDialog.close();
    }
  });

  const checkboxes = document.querySelectorAll('input[type="checkbox"]');
  let checkbox;
  for (let i = 0; i < checkboxes.length; i++) {
    checkbox = checkboxes[i];
    checkbox.addEventListener("change", () => {
      updateFilter(checkboxes);
    });
  }

  // 並び順を指定するセレクトボックス
  const sortSelect = document.getElementById("sortMethod");

  // セレクトボックスに変更があったとき実行
  sortSelect.addEventListener("change", () => {
    // indexが0の場合: 作成日順に表示
    // indexが1の場合: お気に入り数順に表示
    const index = sortSelect.selectedIndex;
    console.log(index);

    if (index === 1) {
      location.href = "/playlist/show?sort=favorite";
    } else {
      location.href = "/playlist/show?sort=date";
    }
  });

  // ウィンドウサイズに変更があったときに実行される関数
  // 横幅が800px以下なら、タグを変更して画面表示に対応させる
  const checkSmallWindowView = () => {
    // レスポンシブデザインに対応するための処理
    const clientWidth = document.documentElement.clientWidth;
    // 小さい画面用の表示にしなければいけない場合
    const playlistTagsElements =
      document.getElementsByClassName("playlist-tag");
    if (clientWidth <= 800) {
      for (let i = 0; i < playlistTagsElements.length; i++) {
        replaceTagName(playlistTagsElements[i], "div");
      }
    } else {
      for (let i = 0; i < playlistTagsElements.length; i++) {
        replaceTagName(playlistTagsElements[i], "span");
      }
    }
  };

  checkSmallWindowView();
  // ウィンドウサイズが変更されるたびに、この関数が実行される
  window.onresize = checkSmallWindowView;
});
