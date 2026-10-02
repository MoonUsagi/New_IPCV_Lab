%[text] # 第 28 章　練習
%[text] {"align":"left"}大型影像與特殊影像模態　｜　MATLAB R2026b
%[text] 解答在 `Ch28_Solution.m`。**建議先自己做完再看。**
%[text] 六題練習 + 一題加分題。每一題都先寫下預期再執行。
assert(exist("ch28_blockedFilter", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
%%
%[text] # 練習 1　`PadMethod` 要對齊誰
%[text] 主教材 §3 量到：高斯濾波在 `BorderSize` = 核半寬時完全精確；
%[text] 開運算卻要加 `PadMethod="symmetric"`。**規則到底是什麼？**
%[text] 1. 對下面三種運算，各掃 `BorderSize` ∈ {0, 半寬, 2×半寬}
%[text]    與 `PadMethod` ∈ {`"replicate"`, `"symmetric"`, 常數 0}，
%[text]    和整張處理的結果比錯誤像素數：
%[text]    - `imfilter(I, fspecial("average", 15))`（**預設邊界**）
%[text]    - `imfilter(I, fspecial("average", 15), "replicate")`
%[text]    - `medfilt2(I, [11 11])`
%[text] 2. 每一種運算，**哪一個 `PadMethod` 完全精確？**
%[text] 3. 去查這三個函式各自預設怎麼處理影像邊緣。
%[text]    **你的答案和第 2 題一致嗎？**
%[text] 4. 用一句話寫出 `PadMethod` 的選擇規則。
%[text] 5. 如果不知道一個函式怎麼處理邊緣，**你要怎麼找出正確的 `PadMethod`**？

% 你的程式碼：

%%
%[text] # 練習 2　不能分塊的演算法
%[text] 主教材 §3 說「全域門檻沒有夠大的 BorderSize」。**量出有多糟。**
%[text] 1. 用 `peppers.png` 放大 2 倍的灰階影像，128×128 分塊。
%[text] 2. 比較 `imbinarize(I)`（整張）和逐塊 `imbinarize(block.Data)`：
%[text]    **有多少比例的像素結果不同？**
%[text] 3. 用 `apply` 算出每一塊自己的 `graythresh`，和全域門檻比。範圍多大？
%[text] 4. 修正方法：**先算全域門檻，再分塊套用**。結果和整張一樣嗎？
%[text] 5. 但對一張放不進記憶體的影像，**你要怎麼算全域門檻？**
%[text]    （提示：Otsu 只需要直方圖，而直方圖可以逐塊累加。）
%[text] 6. 寫一個 `blockedGraythresh(bim)`：逐塊累加直方圖，最後算 Otsu。
%[text]    和 `graythresh(I)` 比，**一樣嗎？**

% 你的程式碼：

%%
%[text] # 練習 3　用錯單位的 HU 門檻
%[text] 1. 讀 `CT-MONO2-16-ankle.dcm`，同時保留儲存值與 HU（用 `ch28_dicomToPhysical`）。
%[text] 2. 骨頭的常用門檻是 **> 300 HU** 與 **> 700 HU**（皮質骨）。
%[text]    **分別用 HU 與儲存值套這兩個門檻**，比較得到的像素數。
%[text] 3. 誤用儲存值會多算幾倍？**為什麼 700 的倍數比 300 大？**
%[text] 4. 空氣是 **< −500 HU**。用儲存值套這個門檻會得到什麼？
%[text] 5. 這兩種錯誤哪一種比較容易被發現？為什麼？
%[text] 6. 寫一個守門函式：**如果影像的最小值大於 −100 卻宣稱是 CT 的 HU，就發警告。**
%[text]    這個檢查的根據是什麼物理事實？

% 你的程式碼：

%%
%[text] # 練習 4　光譜門檻能不能移轉
%[text] 主教材 §7 說「分數尺度差五個數量級，門檻不能跨方法用」。
%[text] **那同一個方法，跨區域可以嗎？**
%[text] 1. 把 Pavia 切成左右兩半。**先檢查兩半各有多少屋頂像素**
%[text]    （切錯位置的話，其中一半可能完全沒有正樣本）。
%[text] 2. 在左半找「召回率 90%」的門檻，套到右半，
%[text]    記錄右半的召回率與精確率。五種方法都做。
%[text] 3. **召回率移轉得過去嗎？精確率呢？**
%[text] 4. 把切點從第 150 欄改到第 170 欄，重做。
%[text]    **同一個門檻，右半的精確率變了多少？為什麼？**
%[text] 5. 把 `sam` 的門檻直接套到 `sid`、`ns3`、`jmsam` 上。會發生什麼事？
%[text] 6. 根據結果，寫出「光譜門檻能移轉到哪裡、不能移轉到哪裡」。

% 你的程式碼：

%%
%[text] # 練習 5　體素間距的合理性檢查
%[text] 主教材 §6 用「一顆頭有多大」檢查出 `[1 1 1]` 是預設值。**把它寫成函式。**
%[text] 1. 寫 `checkVoxelSpacing(sz, spacing, expectedExtentMm)`：
%[text]    - 算出每個方向的物理範圍（體素數 × 間距）
%[text]    - 和預期的物理範圍比，**差超過一個倍數（例如 2 倍）就警告**
%[text] 2. 用 `brain.nii`、`mri.mat`、`knee1.dcm` 測試。
%[text]    各自的「預期物理範圍」要填什麼？**依據是什麼？**
%[text] 3. 如果標頭間距是對的，但你的預期填錯了，會怎樣？
%[text]    **這個檢查能抓到什麼、不能抓到什麼？**
%[text] 4. 把這個函式和第 27 章「標記離相機多遠合不合理」比較。
%[text]    **兩者用的是同一種推理嗎？**

% 你的程式碼：

%%
%[text] # 練習 6　處理你自己的大影像
%[text] 1. 找一張你手上**最大的**影像（病理、衛星、產線全幅掃描都可以）。
%[text]    沒有的話，用 `ch28_makeLargeImage(ImageSize=[20000 20000])`。
%[text] 2. 用 `blockedImage` 開啟，**不要整張讀進記憶體**。
%[text] 3. 建一個多解析度金字塔，用 `bigimageshow` 看。
%[text] 4. 寫一個逐塊的分析（濾波、分割、或偵測），
%[text]    用練習 1 的方法決定 `BorderSize` 與 `PadMethod`。
%[text] 5. **拿一小塊，和整張處理的結果比一次。** 完全一樣嗎？
%[text] 6. 如果是偵測類的分析，用主教材 §5 的方法處理跨界目標，
%[text]    並回報「偵測數 vs 你目視數到的數量」。

% 你的程式碼：

%%
%[text] # 加分題　NDVI 的波段是誰決定的
%[text] `ndvi(hc)` 沒有讓你選波段。**它選了哪兩個？選別的會差多少？**
%[text] 1. 用 $(N - R)/(N + R)$ 自己算 NDVI，試四組波段：
%[text]    紅 670／近紅外 800、650／830、700／760、620／838（取最接近的波段）。
%[text] 2. 每一組算「NDVI > 0.4」的像素比例（當作植被覆蓋率），
%[text]    以及和內建 `ndvi` 的相關係數。
%[text] 3. **內建 `ndvi` 用的是哪一組？** 你怎麼推斷的？
%[text] 4. 植被覆蓋率在四組之間差多少？相關係數卻都很高——
%[text]    **為什麼高相關不代表結論一樣？**
%[text] 5. 換成 EO-1 Hyperion（`EO1H0440342002212110PY_cropped.dat`）重做。
%[text]    它的波段範圍不同，**同樣的「紅／近紅外」要怎麼選？**

% 你的程式碼：

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
