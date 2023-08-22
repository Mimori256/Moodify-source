const btn = document.querySelector('button');
const form = document.getElementById('form-block');
const closeIcons = document.querySelectorAll('.close-icon');
const items = document.querySelectorAll('.item');

// URLフォーム追加・削除周り
let urlCount = document.getElementsByClassName("tagForm").length;


// 新しいフォームを作成し、作成したフォームを返す関数
function createNewForm() {
  urlCount += 1;
  const newDiv = document.createElement('div');
  newDiv.classList.add('item');

  const newLabel = document.createElement('label');
  newLabel.textContent = '' //+ urlCount + " : ";

  newLabel.insertAdjacentHTML(
      'beforeend',
      '<input type="text" name = "new_tag_list[]" class = "tagForm textbox-001" maxlength = "20" placeholder="新しいタグ">'
  );


  const newSpan = document.createElement('span');
  newSpan.classList.add('close-icon');
  newSpan.textContent = ' ✖';
  
  newDiv.appendChild(newLabel);
  newDiv.appendChild(newSpan);

  // 「✖」をクリックしたときの処理を追加
  //新しいタグが消されたとき
  newSpan.addEventListener('click', () => {
    urlCount -= 1;
    newDiv.remove();
  });

  return newDiv;
}

// 「✖」をクリックしたときの処理
//既存のタグが消されたとき
for (let j = 0; j < closeIcons.length; j++) {
  closeIcons[j].addEventListener('click', () => {
    urlCount -= 1;
    items[j].remove();
  });
}

// ボタンをクリックしたときの処理
btn.addEventListener('click', () => {
  if (urlCount >= 5) {
    alert("6個以上タグを追加することはできません");
  } else {
    form.appendChild(createNewForm());
  }
});
