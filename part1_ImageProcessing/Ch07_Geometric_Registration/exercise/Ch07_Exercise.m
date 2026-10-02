%[text] # 第 07 章　練習
%[text] 幾何轉換與影像配準　｜　建議時間：45 分鐘
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
I = im2double(imread("cameraman.tif"));
Rin = imref2d(size(I));
%%
%[text] # 練習 1：選對轉換模型
%[text] 下面產生三組「參考 / 待配準」影像對，各自套用了不同類型的轉換。
%[text] **判斷每一組需要哪種模型**，然後用 `imregcorr` 或 `fitgeotform2d` 配準。
%[text] **要求**：
%[text] - 說明你的判斷依據（提示：平行線還平行嗎？角度變了嗎？）
%[text] - 對每一組，比較用「正確模型」與用「投影模型」的結果
%[text] - **投影模型的自由度最高，為什麼不乾脆每次都用它？** \
%[text] **提示**：比較 PSNR，也比較回復出來的轉換參數合不合理。
pairs = { ...
    "A", imwarp(I, transltform2d(20, -15), OutputView=Rin); ...
    "B", imwarp(I, simtform2d(0.8, 18, [10 10]), OutputView=Rin); ...
    "C", imwarp(I, projtform2d([1 0.08 0; 0.04 1 0; 0.0006 0.0004 1]), OutputView=Rin)};

figure
montage([{I}; pairs(:,2)]', Size=[2 2])
title("參考 ｜ A ｜ B ｜ C")

% TODO


%%
%[text] # 練習 2：初始猜測有多重要
%[text] 主教材示範了 `imregtform` 單獨使用時會失敗。
%[text] **找出它的失敗邊界**：旋轉角度多大時它就跟不上了？
%[text] **要求**：
%[text] 1. 旋轉角度從 0 到 40 度，每 2 度測一次
%[text] 2. 對每個角度，分別測「單獨 imregtform」與「imregcorr 當初始值」
%[text] 3. 畫出角度誤差對真實旋轉角的曲線
%[text] 4. 找出單獨使用時的失效門檻 \
%[text] **提示**：用 `rad2deg(atan2(tf.A(2,1), tf.A(1,1)))` 從矩陣取出角度。

% TODO


%%
%[text] # 練習 3：寫一支穩健的配準函式
%[text] 寫一支 `ch07_registerImages(moving, fixed, options)` 函式。
%[text] **要求**：
%[text] - 自動採用「先 `imregcorr` 再 `imregtform` 精修」的策略
%[text] - 參數：`TransformType`、`Modality`（monomodal／multimodal）、
%[text]   `RadiusScale`（用來調小 InitialRadius）
%[text] - **自動驗證結果**：若配準後的相似度反而比配準前差，
%[text]   就回傳 `imregcorr` 的結果並發出警告
%[text] - 回傳配準後影像、轉換物件、以及診斷 struct
%[text] - 用 `arguments` 驗證，寫完整 help
%[text] - 放到本章的 `code/` 資料夾 \
%[text] 第 4 點是重點：**配準會安靜地失敗**，函式應該自己察覺。

% TODO


%%
%[text] # 練習 4：控制點該給幾個
%[text] 主教材說「至少 4 點」。**驗證這個建議**。
%[text] **要求**：
%[text] 1. 產生 20 個正確的對應點，並在其中加入**小量隨機誤差**（模擬人工標註）
%[text] 2. 分別用 2、3、4、6、10、20 個點做 `fitgeotform2d`
%[text] 3. 對每種點數，比較回復出來的轉換與真值的誤差
%[text] 4. 也記錄每種點數的**殘差**——2 點時殘差是多少？為什麼？ \
%[text] **重點問題**：殘差為零代表配準很準嗎？

% TODO


%%
%[text] # 練習 5：非剛性配準的危險
%[text] 主教材提醒非剛性配準「幾乎總能把來源扭成參考的樣子」。
%[text] **證明這件事**。
%[text] **要求**：
%[text] 1. 拿**兩張完全不相關**的影像（例如 `cameraman.tif` 與 `rice.png`）
%[text] 2. 用 `imregdemons` 配準它們
%[text] 3. 看 PSNR——它會「進步」多少？
%[text] 4. 看位移場——它合理嗎？
%[text] 5. 調整 `AccumulatedFieldSmoothing`，觀察它如何限制這種過度扭曲 \
%[text] **這題的目的**：讓你對「配準成功」的指標保持懷疑。

% TODO


%%
%[text] # 加分題：影像拼接的前半段
%[text] 把兩張有重疊的影像拼接成一張全景圖。
%[text] **要求**：
%[text] 1. 從一張大影像切出兩塊**有重疊**的區域，其中一塊加上旋轉
%[text] 2. 用配準求出兩者的轉換關係
%[text] 3. 用 `imref2d` 計算能裝下兩張影像的**共同座標系**
%[text] 4. 把兩張影像都 warp 到這個座標系並融合 \
%[text] **提示**：融合時重疊區要處理，最簡單的做法是取平均，
%[text] 更好的做法是第 03 章的 `imblend`。
%[text] 第 14 章會用特徵比對做完整的全景拼接，這題是它的前置。

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
