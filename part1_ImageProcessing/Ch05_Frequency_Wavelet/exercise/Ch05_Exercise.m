%[text] # 第 05 章　練習
%[text] 頻域處理與小波分析　｜　建議時間：50 分鐘
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
I = im2double(imread("cameraman.tif"));
%%
%[text] # 練習 1：從頻譜反推影像內容
%[text] 下面產生三張人造影像。**先只看頻譜**，寫下你對每張影像內容的推測，
%[text] 再顯示影像驗證。
%[text] **要求**：說明你從頻譜的哪個特徵做出推測的。
[rows, cols] = size(I);
[xx, yy] = meshgrid(1:cols, 1:rows);

puzzle = cell(1,3);
puzzle{1} = 0.5 + 0.3*sin(2*pi*yy/8);
puzzle{2} = 0.5 + 0.3*sin(2*pi*xx/8) + 0.2*sin(2*pi*yy/32);
puzzle{3} = im2double(checkerboard(32, 4, 4) > 0.5);
puzzle{3} = imresize(puzzle{3}, [rows cols]);

figure
tiledlayout(1,3)
for k = 1:3
    nexttile
    imshow(log(1 + abs(fftshift(fft2(puzzle{k})))), [])
    title("頻譜 " + k)
end

% TODO 寫下推測，再顯示 puzzle{k} 驗證


%%
%[text] # 練習 2：振鈴假影有多嚴重
%[text] 量化理想低通濾波器造成的振鈴。
%[text] **要求**：
%[text] 1. 用理想、巴特沃斯（n=2）、高斯三種低通濾波器處理 `cameraman.tif`
%[text] 2. 在一條穿過強邊緣的水平線上取剖面（用 `improfile` 或直接索引）
%[text] 3. 畫出三條剖面曲線，指出哪一條有振盪
%[text] 4. 用一個數字量化振鈴強度（提示：可以看剖面的二階差分） \
%[text] **提示**：攝影機外套與天空的交界是很強的邊緣。

% TODO


%%
%[text] # 練習 3：自己寫一支 notch 濾波函式
%[text] 寫一支 `ch05_notchFilter(I, options)` 函式，**自動**偵測並移除週期性干擾。
%[text] **要求**：
%[text] - 自動找出頻譜中的干擾峰值（排除中心低頻）
%[text] - 峰值必須**成對**處理（頻譜共軛對稱）
%[text] - 可調參數：要移除幾對峰值、notch 半徑、中心排除半徑
%[text] - 回傳處理後影像與一個診斷 struct（找到的峰值位置與強度）
%[text] - 用 `arguments` 驗證，寫完整 help
%[text] - 放到本章的 `code/` 資料夾 \
%[text] **驗證**：對主教材的條紋影像測試，PSNR 應該接近 26 dB。
%[text] 再用**不同頻率與方向**的條紋測試一次，確認它不是只對某一組參數有效。

% TODO


%%
%[text] # 練習 4：小波階數怎麼選
%[text] 對加了高斯雜訊的影像，用 `wdenoise2` 掃描分解階數 1 到 6。
%[text] **要求**：
%[text] 1. 畫出階數對 PSNR 與 SSIM 的曲線
%[text] 2. 找出最佳階數
%[text] 3. 解釋為什麼階數再往上加沒有幫助 \
%[text] **注意語法**：階數是**位置引數**，寫成 `wdenoise2(J, n)`，
%[text] 不是 `wdenoise2(J, Level=n)`——後者會報錯。
%[text] **提示**：主教材印過 3 階分解的尺寸表。看看第 3 階的近似係數剩多大，
%[text] 再想 6 階會剩下什麼。
noisy = imnoise(I, "gaussian", 0, 0.01);

% TODO


%%
%[text] # 練習 5：哪個視角最適合？
%[text] 下面四個情境，各該用空間域、頻域，還是小波？寫下理由。
%[text] 1. 產線相機拍到的影像有固定的水平掃描線干擾
%[text] 2. 低光源拍攝的影像有明顯顆粒感
%[text] 3. 要找出影像中「哪一個區域的紋理特別粗糙」
%[text] 4. 要對 5000×5000 的影像做 101×101 的高斯模糊 \
%[text] **提示**：第 4 題想想卷積定理，以及運算量如何隨核大小成長。

% TODO 寫下答案（註解即可）


%%
%[text] # 加分題：混合域去雜訊
%[text] 主教材的條紋影像**同時**有週期性條紋與隨機雜訊時該怎麼辦？
%[text] **要求**：
%[text] 1. 產生一張同時有條紋與高斯雜訊的影像
%[text] 2. 設計一個兩階段流程處理它
%[text] 3. 測試**順序**的影響：先 notch 再去雜訊 vs 先去雜訊再 notch
%[text] 4. 哪個順序比較好？為什麼？ \
%[text] **提示**：想想去雜訊濾波器會不會影響頻譜中的干擾峰值。

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
