%[text] # 第 06 章　練習
%[text] 形態學影像處理　｜　建議時間：45 分鐘
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
%%
%[text] # 練習 1：用形態學移除掃描線
%[text] 下面產生一張有水平掃描線干擾的二值影像。
%[text] **用形態學**把掃描線移除，同時保留圓形物件。
%[text] **要求**：
%[text] - 不使用頻域方法（第 05 章已經示範過了）
%[text] - 想想哪一種結構元素**只對特定方向**有反應
%[text] - 量化結果：移除後還剩幾條線？物件損失多少面積？ \
%[text] **提示**：`strel("line", 長度, 角度)`。
%[text] 線的長度要**夠長**——掃描線橫貫整張影像（329 像素寬），
%[text] 而物件本身也可能有一段是水平的。長度取得太短，物件內部的水平段
%[text] 也會被當成「線」留下來。先想清楚該取多長，再動手。
BW = imread("blobs.png");           % 注意：這張圖本來就是白色物件，不需 imcomplement
withLines = BW;
withLines(20:30:end, :) = true;      % 每 30 列畫一條貫穿全寬的水平線

figure
imshow(withLines); title("有掃描線干擾")

% TODO


%%
%[text] # 練習 2：分開黏在一起的物件
%[text] 下面產生兩個重疊的圓。用形態學把它們分開並正確計數。
%[text] **要求**：
%[text] - 用**距離轉換**（`bwdist`）找出每個圓的中心區域
%[text] - 用侵蝕或門檻取得標記
%[text] - 用 `imreconstruct` 或 `watershed` 還原成完整的兩個圓
%[text] - 驗證結果確實是 2 個，且形狀接近原本的圓 \
%[text] **這是第 08 章分水嶺分割的前置練習。**
[xx, yy] = meshgrid(1:200, 1:200);
twoCircles = ((xx-80).^2 + (yy-100).^2 < 45^2) | ((xx-125).^2 + (yy-100).^2 < 45^2);

figure
imshow(twoCircles); title("兩個重疊的圓（看起來像一個物件）")
fprintf("直接計數：%d 個\n", max(bwlabel(twoCircles), [], "all"));

% TODO


%%
%[text] # 練習 3：寫一支形態學清理函式
%[text] 寫一支 `ch06_cleanMask(BW, options)` 函式，把常見的清理步驟包起來。
%[text] **要求**：
%[text] - 參數：`OpenRadius`、`CloseRadius`、`MinArea`、`MaxArea`、
%[text]   `FillHoles`、`ClearBorder`
%[text] - 每個步驟都可以單獨關閉（半徑設 0 即跳過）
%[text] - 回傳清理後的遮罩，以及一個記錄「每個步驟後還剩幾個物件」的 table
%[text] - 用 `arguments` 驗證，寫完整 help，說明**為什麼預設是先開後閉**
%[text] - 放到本章的 `code/` 資料夾 \
%[text] 這支函式在第 08 章與第 11 章都會用到。

% TODO


%%
%[text] # 練習 4：粒徑分析認出兩種尺寸
%[text] 主教材的粒徑分析只有一個峰值（米粒尺寸單一）。
%[text] 這題產生一張**同時有大小兩種圓**的影像，用粒徑分析把兩個尺寸都找出來。
%[text] **要求**：
%[text] - 畫出粒徑分布圖，應該看到**兩個峰值**
%[text] - 從峰值位置推算兩種圓的半徑，與實際值比較
%[text] - 說明為什麼這個方法不需要先把物件分割開 \
%[text] **提示**：用 `findpeaks` 自動找峰值。
rng(0);
[gx, gy] = meshgrid(1:400, 1:400);
canvas = false(400, 400);

for k = 1:12       % 小圓，半徑 8
    cx = randi([20 380]);  cy = randi([20 380]);
    canvas = canvas | ((gx - cx).^2 + (gy - cy).^2 < 8^2);
end
for k = 1:6        % 大圓，半徑 20
    cx = randi([30 370]);  cy = randi([30 370]);
    canvas = canvas | ((gx - cx).^2 + (gy - cy).^2 < 20^2);
end

figure
imshow(canvas); title("大小兩種圓（半徑 8 與 20）")

% TODO


%%
%[text] # 練習 5：形態學梯度 vs 傳統邊緣偵測
%[text] 主教材提到形態學梯度（膨脹 − 侵蝕）也是一種邊緣偵測。
%[text] **比較它與 `edge(I,"Canny")` 在有雜訊時的表現。**
%[text] **要求**：
%[text] 1. 對乾淨影像與加了高斯雜訊的影像，各做兩種邊緣偵測
%[text] 2. 用一個量化指標比較（提示：以乾淨影像的 Canny 結果當「正解」，
%[text]    算 Dice 係數或 IoU）
%[text] 3. 哪一種對雜訊比較穩健？為什麼？ \
%[text] **思考**：形態學梯度用的是鄰域的**極值**，Canny 用的是**微分**。
%[text] 哪一種對單一異常像素比較敏感？

% TODO


%%
%[text] # 加分題：用形態學做車牌字元切割
%[text] `printedtext.png` 是一張印刷文字影像。
%[text] 用形態學把**個別字元**切出來。
%[text] **要求**：
%[text] - 二值化後用形態學清理
%[text] - 用**水平方向的 SE** 把同一行的字連成一整行（找出文字行）
%[text] - 再回到原始遮罩，在每一行內切出個別字元
%[text] - 回報偵測到幾行、每行幾個字元 \
%[text] **提示**：`strel("line", L, 0)` 的閉運算會把水平方向靠近的東西連起來。
%[text] 這是 OCR 前處理的經典做法，第 15 章會再用到。

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
