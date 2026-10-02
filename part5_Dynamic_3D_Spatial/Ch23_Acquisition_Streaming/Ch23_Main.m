%[text] # 第 23 章　影像擷取與串流處理
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\]　｜　建議時數：3 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 說出「一張圖」和「一段流」在程式結構上的差別
%[text] 2. **把單張影格的演算法包成函式，再套用到整支影片**——本章的核心
%[text] 3. 用分段計時找出逐幀管線真正的瓶頸，而不是猜
%[text] 4. 說出 GPU 與 `parfor` 在什麼條件下會**變慢**
%[text] 5. 連接相機，並知道**為什麼量到的取像速率和規格上寫的不一樣**
%[text] 6. 用 `VideoWriter` 錄下結果，並在檔案大小與時間之間做選擇
%[text] ## 前置知識
%[text] 第 6 章（形態學）、第 8 章（分割）、第 11 章（區域量測）。
%[text] ## 環境需求
%[text] Image Processing Toolbox、Computer Vision Toolbox。
%[text] 相機的段落需要 **Image Acquisition Toolbox** 與
%[text] **MATLAB Support Package for USB Webcams**。
%[text] > ## **沒有相機也能跑完整章**
%[text] > 第 10–12 節會嘗試連接相機。**連不上時會自動退回影片檔並印出訊息**，
%[text] > 後面的內容照常進行。退回時你看到的數字不是相機量出來的，
%[text] > `ch23_captureFrames` 回傳的 `info.Source` 會誠實說明這件事。
assert(exist("ch23_ballSegmentFrame", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
%%
%[text] # 1. 這一章的位置：從一張圖到一段流
%[text] 前面 22 章處理的都是**一張**影像。這一章開始，輸入是**一連串**影像。
%[text] 聽起來只是多包一層迴圈，但有四件事會跟著改變：
%[text:table]
%[text] | | 單張影像 | **串流** |
%[text] | --- | --- | --- |
%[text] | 資料從哪來 | 檔案，隨時可重讀 | **相機或影片，可能只能讀一次** |
%[text] | 失敗怎麼辦 | 重跑就好 | **不能重跑**，要當場決定跳過還是補值 |
%[text] | 多快才夠 | 不限 | **要跟得上來源的速度**，否則丟幀 |
%[text] | 結果長什麼樣 | 一個答案 | **一條時間序列**，而且會有缺口 |
%[text:table]
%[text] 本章用 `singleball.mp4` 當主線：一顆綠球由左往右滾，**中途會滾到紙箱後面**。
%[text] 那段遮擋不是瑕疵，是這一章（以及第 24 章）真正要處理的問題。
%%
%[text] # 2. 讀影片：兩種讀法，差別不只是寫法
v = VideoReader("singleball.mp4");
fprintf("%dx%d，%.1f fps，%.2f 秒，共 %d 幀，格式 %s\n", ...
    v.Width, v.Height, v.FrameRate, v.Duration, v.NumFrames, v.VideoFormat);
%[text] **讀法一：`hasFrame` + `readFrame`（循序）**
%[text] 這是串流的自然寫法——不需要事先知道有幾幀，讀到沒有為止。
v1 = VideoReader("singleball.mp4");
n1 = 0;
t0 = tic;
while hasFrame(v1)
    frame = readFrame(v1);
    n1 = n1 + 1;
end
tSeq = toc(t0);
fprintf("循序讀取：%d 幀，%.3f 秒，%.2f 毫秒/幀\n", n1, tSeq, tSeq/n1*1000);
%[text] **讀法二：`read(v, k)`（隨機存取）**
%[text] 指定幀號直接取。寫起來方便，但**對壓縮影片可能很貴**：
%[text] 編碼器只在關鍵影格（I-frame）存完整畫面，其餘是差分，
%[text] 跳到任意一幀可能要從前一個關鍵影格重新解碼。
v2 = VideoReader("singleball.mp4");
t0 = tic;
for k = 1:v2.NumFrames
    frame = read(v2, k);
end
tRand = toc(t0);
fprintf("隨機存取：%d 幀，%.3f 秒，%.2f 毫秒/幀\n", ...
    v2.NumFrames, tRand, tRand/v2.NumFrames*1000);
fprintf("隨機存取是循序的 %.2f 倍\n", tRand/tSeq);

% **從頭到尾遞增地跳**幾乎不花額外成本——解碼器本來就順著走。
% 真正貴的是**反向或大跳躍**，每次都可能要回到前一個關鍵影格重解。
v3 = VideoReader("singleball.mp4");
t0 = tic;
for k = v3.NumFrames:-1:1
    frame = read(v3, k);
end
tRev = toc(t0);
fprintf("反向讀取：%.3f 秒，%.2f 毫秒/幀，是循序的 %.2f 倍\n", ...
    tRev, tRev/v3.NumFrames*1000, tRev/tSeq);
%[text] **遞增地跳幾乎不用錢**（實測 1.0–1.1 倍）——解碼器本來就順著走。
%[text] **反向讀取才是真正貴的**：每一幀都可能要回到前一個關鍵影格重新解碼。
%[text] 在這支 45 幀的短片上差距還不明顯（關鍵影格很密），
%[text] 但在幾千幀的長片上，反向或大跳躍可以慢上**幾十倍**。
%[text] > **`NumFrames` 本身也不是免費的。** 對某些容器格式，
%[text] > 查詢總幀數需要掃過整個檔案。串流程式應該用 `hasFrame`，
%[text] > 不要為了寫 `for k = 1:v.NumFrames` 去問總數。
%%
%[text] # 3. 單張影格：先把演算法做對
%[text] **順序很重要：先讓一張影格正確，再考慮整支影片。**
%[text] 在迴圈裡除錯比在單張影格上除錯難太多了。
%[text] 球是綠色的。偵測綠色有兩種寫法，差別很大：
frame = read(VideoReader("singleball.mp4"), 20);
R = double(frame(:,:,1));
G = double(frame(:,:,2));
B = double(frame(:,:,3));

maskAbs  = G > 100;                  % 寫法一：看綠通道的絕對值
maskLead = (G - max(R,B)) > 15;      % 寫法二：看綠通道領先多少

fprintf("絕對值門檻：%d 像素；領先幅度門檻：%d 像素\n", ...
    nnz(maskAbs), nnz(maskLead));

figure;
tiledlayout(1,3, TileSpacing="compact");
nexttile; imshow(frame);    title("原始影格 20")
nexttile; imshow(maskAbs);  title("G > 100（絕對值）")
nexttile; imshow(maskLead); title("G - max(R,B) > 15（領先幅度）")
%[text] **絕對值會被整體亮度牽著走**：畫面一暗，綠球的 G 值跟著掉，門檻就失效。
%[text] **領先幅度看的是「綠得比別的顏色多多少」**，對亮度變化穩健得多。
%[text] 這件事在第 3 章（照明變化）與第 8 章（色彩分割）都出現過。
%[text] 把它包成函式 `ch23_ballSegmentFrame`。**這支函式只做一件事**：
%[text] 拿一張影格，回傳有沒有找到、在哪裡、多大。
%[text] 它不讀檔、不顯示、不寫檔、不累積結果。
r20 = ch23_ballSegmentFrame(read(VideoReader("singleball.mp4"), 20));
r05 = ch23_ballSegmentFrame(read(VideoReader("singleball.mp4"), 5));
fprintf("幀 20：Found=%d，質心=(%.1f, %.1f)，面積=%.0f\n", ...
    r20.Found, r20.Centroid(1), r20.Centroid(2), r20.Area);
fprintf("幀  5：Found=%d，質心=(%.1f, %.1f)\n", ...
    r05.Found, r05.Centroid(1), r05.Centroid(2));
%[text] > **`Found = false` 不是錯誤，是答案。**
%[text] > 第 5 幀球還沒進畫面，函式回報「沒有」是正確行為。
%[text] > 很多人會在這裡讓函式丟例外或回傳 `[0 0]`——
%[text] > 前者讓呼叫者無法繼續，後者讓「沒看到」和「在原點」分不出來。
%%
%[text] # 4. 從一幀到整支影片　**（本章核心）**
%[text] 現在把單幀函式套到整支影片。這一層要負責四件事，
%[text] **每一件都是單幀函式不該碰的**：
%[text:table]
%[text] | | 責任 | 做錯的後果 |
%[text] | --- | --- | --- |
%[text] | ① | 逐幀讀取與迴圈控制 | — |
%[text] | ② | **預先配置**結果容器 | 幀號和列號對不上 |
%[text] | ③ | 把「找不到」記成 `NaN` | 遮擋變成「不存在」 |
%[text] | ④ | 選用的顯示與錄影 | 顯示變成瓶頸（第 7 節） |
%[text:table]
%[text] **第 ③ 點最容易做錯。** 很多人的迴圈長這樣：
%[text] ```matlab
%[text] if r.Found
%[text]     centroids(end+1,:) = r.Centroid;   % ← 只記錄找到的
%[text] end
%[text] ```
%[text] 這樣 `centroids` 只有 23 列，而影片有 45 幀。
%[text] **你永遠算不出球的速度**，因為你不知道相鄰兩列差了幾幀。
[tracks, info] = ch23_ballSegmentVideo("singleball.mp4");
fprintf("處理 %d 幀，找到球 %d 幀，耗時 %.3f 秒（%.1f fps）\n", ...
    info.NumFrames, info.NumFound, info.Seconds, info.FPS);
disp(head(tracks, 5))
%[text] 表格有 **45 列**（每一幀都有），其中 22 列的 `X`／`Y` 是 `NaN`。
%[text] 這才是正確的資料結構：**缺口被保留下來了。**
%%
%[text] # 5. 看結果：那個 7 幀的洞
gaps = find(~tracks.Found)';
fprintf("未偵測到球的幀：%s\n", mat2str(gaps));

visible = find(tracks.Found);
breaks  = find(diff(visible) > 1);
fprintf("可見區段：");
starts = [visible(1); visible(breaks+1)];
stops  = [visible(breaks); visible(end)];
for k = 1:numel(starts)
    fprintf("%d–%d ", starts(k), stops(k));
end
fprintf("\n");

figure;
tiledlayout(2,1, TileSpacing="compact");
nexttile
plot(tracks.Frame, tracks.X, "o-", LineWidth=1.2); hold on
plot(tracks.Frame, tracks.Y, "s-", LineWidth=1.2);
xline(27, "--", "遮擋開始"); xline(33, "--", "遮擋結束");
legend("X", "Y", Location="northwest"); grid on
xlabel("幀"); ylabel("像素"); title("球的軌跡：中間斷了 7 幀")
nexttile
plot(tracks.Frame, tracks.Area, "o-", LineWidth=1.2); grid on
xlabel("幀"); ylabel("面積（像素）"); title("偵測到的面積")
%[text] 三段：**1–12 沒進畫面**、**13–26 可見**、**27–33 被紙箱遮住**、
%[text] **34–42 又可見**、**43–45 出畫面**。
%[text] > **這個洞是第 24 章的起點。**
%[text] > 逐幀偵測到此為止就沒辦法了——它沒有「上一幀球在哪」的概念。
%[text] > 要在遮擋期間繼續估計球的位置，需要**追蹤**：
%[text] > 用運動模型預測，等球再出現時把它接回同一條軌跡。
%[text] 另外注意面積：從第 14 幀的 255 掉到第 42 幀的 70。
%[text] `ch23_ballSegmentFrame` 的 `MinArea` 預設是 40——
%[text] **再嚴一點就會把最後幾幀丟掉**。練習 1 會量這件事。
%%
%[text] # 6. 先量再改：分段計時
%[text] 逐幀管線最常見的錯誤不是寫得慢，而是**優化錯地方**。
%[text] 先把管線拆開，看時間到底花在哪。
if ipcvFast()
    disp("（快速模式：略過分段計時，見下方表格的既有量測值）")
    naiveTotal = struct(MsPerFrame=8.02, FPS=124.7, Bottleneck="形態學（strel 在迴圈內）");
else
    [naiveReport, naiveTotal] = ch23_pipelineProfile("visiontraffic.avi", ...
        NumFrames=150, Repeats=3, HoistObjects=false);
    disp(naiveReport)
end
fprintf("天真版合計 %.2f 毫秒/幀（%.1f fps），瓶頸是「%s」\n", ...
    naiveTotal.MsPerFrame, naiveTotal.FPS, naiveTotal.Bottleneck);
%[text] 兩次執行的結果（絕對值會變，**排序不會**）：
%[text:table]
%[text] | 階段 | 毫秒/幀 | 佔比 |
%[text] | --- | --- | --- |
%[text] | **形態學（`strel` 在迴圈內）** | **3.34 – 3.63** | **45–47%** |
%[text] | 量測 `regionprops` | 2.06 – 2.29 | 29% |
%[text] | 讀檔（解碼） | 0.93 – 1.02 | 13% |
%[text] | 標註 `insertShape` | 0.43 – 0.65 | 6–8% |
%[text] | 二值化 | 0.27 – 0.35 | 4% |
%[text] | 轉灰階 | 0.08 | 1% |
%[text:table]
%[text] > **絕對值每次都不一樣，合計在 7.1–8.0 毫秒之間跳動。**
%[text] > 所以不要從單次執行的小差距下結論——
%[text] > 這和第 18 章 §6.1 量到的 GPU 非決定性是同一類問題。
%[text] > **但排序與佔比很穩定**，而那才是分段計時要回答的問題。
%[text] **讀檔只佔 13%。** 很多人的直覺是「I/O 一定最慢」，
%[text] 所以先去優化讀檔——但就算把讀檔變成零，整體也只快 13%。
%[text] > **這是 Amdahl 定律的日常版本：
%[text] > 你能得到的加速，上限是那一段佔的比例。**
%%
%[text] # 7. 三個加速手段，和它們真正的效益
%[text] ## 7.1 把重複建構的東西提到迴圈外
%[text] 上面那張表最貴的是形態學。但**慢的不是形態學運算本身**，
%[text] 是每一幀都重新建構一次 `strel("disk", 5)`。
if ipcvFast()
    disp("（快速模式：略過，使用既有量測值）")
    hoistTotal = struct(MsPerFrame=5.52, FPS=181.1, Bottleneck="量測 regionprops");
else
    [hoistReport, hoistTotal] = ch23_pipelineProfile("visiontraffic.avi", ...
        NumFrames=150, Repeats=3, HoistObjects=true);
    disp(hoistReport)
end
fprintf("提到迴圈外後：%.2f 毫秒/幀（%.1f fps），瓶頸變成「%s」\n", ...
    hoistTotal.MsPerFrame, hoistTotal.FPS, hoistTotal.Bottleneck);
fprintf("整體加速 %.2f 倍\n", naiveTotal.MsPerFrame / hoistTotal.MsPerFrame);
%[text] 形態學那一段從 **3.3–3.6 掉到 0.84–0.99 毫秒**（約 4 倍），
%[text] 整體從 7.1–8.0 掉到 4.4–5.5 毫秒（**1.45–1.61 倍**）。
%[text] > **而且瓶頸換人了**：現在最貴的是 `regionprops`（43.3%）。
%[text] > 這是分段計時最重要的用途——**每優化一次就要重量一次**，
%[text] > 否則你會繼續優化一個已經不是瓶頸的東西。
%[text] 同樣的道理對**物件**更嚴重，因為物件還有狀態：
detector = vision.ForegroundDetector(NumTrainingFrames=10);
vv = VideoReader("visiontraffic.avi");
frames = cell(1,100);
for k = 1:100, frames{k} = read(vv, k); end

t0 = tic;
for k = 1:100, fg = detector(im2single(frames{k})); end
tReuse = toc(t0);

t0 = tic;
for k = 1:20
    d = vision.ForegroundDetector(NumTrainingFrames=10);
    fg = d(im2single(frames{k}));
end
tRebuild = toc(t0);

fprintf("重用偵測器　　%.1f 毫秒/幀\n", tReuse/100*1000);
fprintf("每幀重建偵測器 %.1f 毫秒/幀（%.1f 倍）\n", ...
    tRebuild/20*1000, (tRebuild/20)/(tReuse/100));
%[text] 實測慢 **10–12 倍**。
%[text] > **而且結果是錯的。** `vision.ForegroundDetector` 靠前幾十幀
%[text] > 學背景模型。每幀重建等於每幀都是「第一幀」——
%[text] > 它**永遠學不到背景**，前景輸出一片空白或一片雜訊。
%[text] > **慢 10 倍還算好消息，真正的問題是答案錯了。**
%[text] ## 7.2 預先配置
%[text] 課本上的第一條效能建議。實測一下它值多少：
t0 = tic;
C1 = [];
for k = 1:100
    s = regionprops(imbinarize(rgb2gray(frames{k})), "Centroid");
    if ~isempty(s), C1(end+1,:) = s(1).Centroid; end %#ok<AGROW>
end
tGrow = toc(t0);

t0 = tic;
C2 = nan(100, 2);
for k = 1:100
    s = regionprops(imbinarize(rgb2gray(frames{k})), "Centroid");
    if ~isempty(s), C2(k,:) = s(1).Centroid; end
end
tPre = toc(t0);

fprintf("動態成長 %.3f 秒｜預先配置 %.3f 秒｜加速 %.2f 倍\n", ...
    tGrow, tPre, tGrow/tPre);
%[text] ## **量到的結果推翻了我的預期**
%[text] 我本來預期預先配置會明顯較快。兩次執行量到的是：
%[text:table]
%[text] | 執行 | 動態成長 | 預先配置 | 加速 |
%[text] | --- | --- | --- | --- |
%[text] | 第一次 | 0.708 s | 0.559 s | 1.27 倍 |
%[text] | 第二次 | 0.261 s | 0.285 s | **0.92 倍（反而慢）** |
%[text:table]
%[text] **一次快、一次慢——效益落在雜訊裡，等於沒有。**
%[text] 原因是這個迴圈的時間幾乎全部花在 `regionprops` 上，
%[text] 陣列成長的成本相對可以忽略；而且 MATLAB 的陣列成長
%[text] 會**以倍數擴張**容量，不是每次複製整個陣列。
%[text] > **「預先配置能加速」在這裡是一個沒有效果的建議。**
%[text] > 它在**迴圈本身很輕、次數很多**（例如幾十萬次的純數值迴圈）
%[text] > 時才顯著；逐幀影像處理正好是相反的情況。
%[text] > **預先配置仍然要做**——但理由是第 4 節講的**正確性**
%[text] >（幀號要對得上），不是效能。
%[text] > 這是本章第二次看到同一件事：
%[text] > **「課本說重要」和「在你的資料上重要」是兩回事，中間隔著一次量測。**
%[text] ## 7.3 關掉不需要的顯示
%[text] 這是三個裡面效益最大的，而且最常被忽略。
if ipcvFast()
    disp("（快速模式：略過顯示計時）")
else
    [dispReport, dispTotal] = ch23_pipelineProfile("visiontraffic.avi", ...
        NumFrames=100, Display=true, Write=true);
    disp(dispReport)
    fprintf("含顯示與寫檔：%.2f 毫秒/幀（%.1f fps），瓶頸是「%s」\n", ...
        dispTotal.MsPerFrame, dispTotal.FPS, dispTotal.Bottleneck);
end
%[text] 三次執行，顯示都排第一：
%[text:table]
%[text] | 階段 | 毫秒/幀 | 佔比 |
%[text] | --- | --- | --- |
%[text] | **顯示 `vision.VideoPlayer`** | **7.96 – 25.9** | **48 – 61%** |
%[text] | 寫檔 MPEG-4 | 2.22 – 3.24 | 13 – 16% |
%[text] | 讀檔 | 2.04 – 4.13 | 10 – 25% |
%[text] | 全部影像處理加起來 | 1.6 – 2.7 | 9 – 14% |
%[text:table]
%[text] **顯示一項就佔掉一半以上**，比所有影像處理加起來還多 3–6 倍。
%[text] 它的變異也最大（7.96 到 25.9 毫秒，差 3 倍），
%[text] 因為它取決於視窗大小、是否被遮住、顯示卡在忙什麼——
%[text] **全都是和你的演算法無關的東西。**
%[text] > **所以 `ch23_ballSegmentVideo` 的 `Display` 預設是 `false`。**
%[text] > 開發時打開看結果，跑批次時關掉。
%[text] > 要即時監看又不想付全額，可以**每 N 幀才顯示一次**——
%[text] > 練習 4 會量這件事。
%%
%[text] # 8. GPU：什麼時候划算
%[text] 「用 GPU 就會快」是這一章最常見的錯誤期待。
gpuOK = false;
try
    gdev = gpuDevice;
    gpuOK = true;
    fprintf("GPU：%s，可用記憶體 %.2f GB\n", gdev.Name, gdev.AvailableMemory/1e9);
catch
    disp("這台機器沒有可用的 GPU，本節只顯示既有量測值。")
end

if gpuOK && ~ipcvFast()
    small = frames{1};                    % 640x360
    big   = imresize(small, 4);           % 2560x1440

    tSmallCPU = timeit(@() imgaussfilt(rgb2gray(small), 4));
    tSmallGPU = timeit(@() gather(imgaussfilt(rgb2gray(gpuArray(small)), 4)));
    tBigCPU   = timeit(@() imgaussfilt(rgb2gray(big), 4));
    tBigGPU   = timeit(@() gather(imgaussfilt(rgb2gray(gpuArray(big)), 4)));

    fprintf("\n%-12s %10s %10s %8s\n", "影像大小", "CPU (ms)", "GPU (ms)", "加速");
    fprintf("%-12s %10.2f %10.2f %8.2f\n", "640x360", ...
        tSmallCPU*1000, tSmallGPU*1000, tSmallCPU/tSmallGPU);
    fprintf("%-12s %10.2f %10.2f %8.2f\n", "2560x1440", ...
        tBigCPU*1000, tBigGPU*1000, tBigCPU/tBigGPU);
end
%[text] 兩次執行（NVIDIA T550）：
%[text:table]
%[text] | 影像大小 | CPU | GPU（含來回搬移） | 加速 |
%[text] | --- | --- | --- | --- |
%[text] | 640×360 | 1.63 – 1.94 ms | 1.95 – 2.58 ms | **0.63 – 1.00 倍** |
%[text] | 2560×1440 | 20.3 – 25.5 ms | 15.4 – 15.5 ms | 1.31 – 1.66 倍 |
%[text:table]
%[text] **小影像上 GPU 一點都不快。** 資料要從主記憶體搬到顯示記憶體、
%[text] 算完再搬回來，這個來回的成本和 640×360 的高斯濾波差不多。
%[text] 把資料留在 GPU 上量（`gputimeit`）甚至是 **0.89 倍**——比 CPU 慢。
%[text] > **GPU 划算的條件有三個，缺一不可：**
%[text] > ① 運算量夠大（影像大、或運算複雜）
%[text] > ② **資料能留在 GPU 上連續做好幾步**，不要每一步都搬回來
%[text] > ③ 這個函式真的有 GPU 實作（否則會安靜地掉回 CPU）
%[text] 深度學習推論（第 18–22 章）是典型划算的情況：
%[text] 運算量極大，而且整個網路都在 GPU 上跑完才取回結果。
%[text] 而**逐幀做一次高斯濾波是典型不划算的情況**。
%%
%[text] # 9. `parfor`：為什麼在這裡沒用
%[text] 影片的每一幀彼此獨立，看起來是平行化的完美對象。實測結果相反。
%[text] 某次執行（4 個 worker）：
%[text:table]
%[text] | 工作 | 序列 | `parfor` | 加速 |
%[text] | --- | --- | --- | --- |
%[text] | 分割 + 量測（150 幀） | 1.30 s | 1.95 s | **0.66 倍（更慢）** |
%[text] | 放大 3 倍 + 高斯濾波（60 幀） | 2.18 s | 2.23 s | **0.98 倍** |
%[text:table]
%[text] 而且**開平行池本身就花了 36.4 秒**。
%[text] 原因有三個：
%[text] 1. **資料要搬過去。** 每一幀 640×360×3 是 690 KB，
%[text]    要序列化送到 worker 行程再把結果送回來。
%[text]    單幀工作只有 8 毫秒，搬運比計算還貴。
%[text] 2. **`VideoReader` 不能切片。** 它有內部狀態，
%[text]    不能直接寫 `parfor k = 1:n, frame = read(v,k)`——
%[text]    要嘛先全部讀進記憶體（然後付搬運成本），
%[text]    要嘛每個 worker 各開一個 reader（然後每個都重新解碼）。
%[text] 3. **MATLAB 的影像函式本身已經是多執行緒的。**
%[text]    `imopen`、`imgaussfilt` 等已經在用你的多個核心，
%[text]    `parfor` 只是把同一批核心切成四份再搶。
%[text] > **什麼時候 `parfor` 才對？**
%[text] > 單位工作要**夠重**（每幀數百毫秒以上，例如深度學習推論
%[text] > 或大影像的多步驟處理），而且**搬運量相對小**。
%[text] > 判準很簡單：**單幀處理時間 ÷ 單幀資料搬運時間，要遠大於 1。**
%[text] > 真正對批次影片有效的做法通常是**多個檔案平行**
%[text] > （每個 worker 處理一整支影片，搬運只發生一次），
%[text] > 而不是同一支影片的多個影格平行。
%%
%[text] # 10. 相機：三個層級的 API
%[text:table]
%[text] | API | 適用 | 需要 |
%[text] | --- | --- | --- |
%[text] | `webcam` | USB 視訊裝置，最簡單 | USB Webcams 支援包 |
%[text] | `ipcam` | 網路攝影機（RTSP／HTTP） | IP Cameras 支援包 |
%[text] | `videoinput` | 工業相機（GigE、Camera Link、機器視覺卡） | Image Acquisition Toolbox + 對應硬體支援包 |
%[text:table]
%[text] `webcam` 最容易上手：
cams = string.empty;
try
    cams = string(webcamlist);
catch ME
    fprintf("webcamlist 失敗：%s\n", ME.message);
end
if isempty(cams)
    disp("這台機器沒有偵測到相機。第 10–12 節會自動退回影片檔。")
else
    fprintf("偵測到 %d 台相機：%s\n", numel(cams), strjoin(cams, "、"));
end
%[text] `videoinput` 和前兩者的差別在於它**分離了「開始擷取」與「取出資料」**：
%[text] ```matlab
%[text] vid = videoinput("gentl", 1, "Mono8");
%[text] vid.FramesPerTrigger = 100;
%[text] start(vid);              % 相機開始往緩衝區丟影格
%[text] data = getdata(vid);     % 從緩衝區取出
%[text] ```
%[text] > **緩衝區是工業相機的關鍵概念。** `webcam` 的 `snapshot`
%[text] > 是「現在給我一張」，處理慢就丟幀；`videoinput` 會把影格
%[text] > 排進緩衝區，處理慢時**緩衝區會漲**，漲滿了才開始丟。
%[text] > 這讓你能承受短暫的處理延遲，代價是**延遲會累積**——
%[text] > 你看到的畫面可能是幾百毫秒前的。
%[text] **APP：Image Acquisition Explorer**（`imaqtool` 的後繼者）
%[text] 可以不寫程式就瀏覽裝置、試格式、預覽、錄製，
%[text] 並把設定**匯出成程式碼**。第一次接一台新相機時從這裡開始最快。
%%
%[text] # 11. 取像速率：量到的和規格上寫的不一樣
%[text] 這一節的結論可能是整章最實用的一個。
[camFrames, camInfo] = ch23_captureFrames(15, Warmup=0);
fprintf("來源：%s（%s），解析度 %s\n", ...
    camInfo.Source, camInfo.Device, camInfo.Resolution);
fprintf("第一張 %.1f 毫秒｜之後中位數 %.1f 毫秒｜比值 %.1f 倍\n", ...
    camInfo.FirstMs, camInfo.MedianMs, camInfo.WarmupRatio);
if camInfo.Source == "webcam"
    fprintf("穩態取像速率約 %.1f fps\n", 1000/camInfo.MedianMs);
end
%[text] ## 兩個可重現的事實
%[text] **① 第一張一定慢得多。**
%[text] 本機跨多次執行量到 **229 – 1015 毫秒**，是穩態的 **7 – 59 倍**。
%[text] 驅動程式要協商格式、配置緩衝區，相機要完成自動曝光與白平衡。
%[text] **改解析度之後也要重新熱身。**
%[text] > 所以任何計時都要先丟掉幾張。`ch23_captureFrames` 的
%[text] > `Warmup` 引數就是做這件事。
%[text] **② 穩態速率不是一個固定的數字。**
%[text] 同一台相機、同一段程式、同一台機器，跨六次執行量到：
%[text:table]
%[text] | 解析度 | 量到的範圍 |
%[text] | --- | --- |
%[text] | 320×240 | 99.9 ms（10.0 fps） |
%[text] | 640×480 | **32.1 – 96.4 ms（10.4 – 31.2 fps）** |
%[text] | 1280×720 | 97.5 ms（10.3 fps） |
%[text] | 1920×1080 | **17.3 – 97.1 ms（10.3 – 57.8 fps）** |
%[text:table]
%[text] **同一個解析度可以差 5.6 倍**，而且**解析度本身預測不了速率**——
%[text] 最快的一次（57.8 fps）發生在**最高**解析度上。
%[text] 影響因素至少有：自動曝光（畫面越暗，曝光時間越長，幀率越低）、
%[text] USB 頻寬共享、驅動程式的格式協商（MJPEG vs YUY2）、
%[text] 以及相機本身的溫控降頻。
%[text] > ## **這一節真正的教訓**
%[text] > **「這台相機是 30 fps」不是一個你可以拿來設計系統的事實。**
%[text] > 規格上的幀率是在特定曝光、特定格式、特定頻寬下的最大值。
%[text] > **你必須在你的實際環境、實際照明、實際負載下量**，
%[text] > 而且要量夠久（幾百張，不是十張）。
%[text] > 產線的驗收規格應該寫**量到的最差值**，不是規格書上的數字。
%[text] 練習 5 會帶你做一次完整的量測。
%%
%[text] # 12. 即時預算：跟不上會怎樣
%[text] 「即時」的定義很簡單：**每幀處理時間 < 每幀到達間隔**。
frameInterval = 1000 / 30;                      % 30 fps -> 33.3 毫秒

% 每一項都是本章前面量到的數字。
stageName = ["取像（相機）" "解碼與前處理" "分割" "量測" "標註"];
stageMs   = [32.1            1.3            1.3   2.4    0.5];
cumMs     = cumsum(stageMs);

fprintf("\n每幀預算 %.1f 毫秒（30 fps）\n\n", frameInterval);
fprintf("%-16s %10s %10s\n", "階段", "毫秒", "累計");
for k = 1:numel(stageName)
    fprintf("%-16s %10.1f %10.1f\n", stageName(k), stageMs(k), cumMs(k));
end
fprintf("%-16s %10.1f\n", "合計", cumMs(end));

remaining = frameInterval - cumMs(end);
if remaining >= 0
    fprintf("\n剩餘預算 %.1f 毫秒 —— 跟得上\n", remaining);
else
    fprintf("\n剩餘預算 %.1f 毫秒 —— **跟不上**\n", remaining);
end
%[text] 取像那一項用的是量到的**較差值**（32.1 毫秒）。
%[text] 這是刻意的：**預算要用最差值算，不是用最好值。**
%[text] 還剩 **-4.3 毫秒**——**已經超支了**，而且這裡還沒有顯示、
%[text] 沒有錄影、沒有任何深度學習。
%[text] 加上第 7 節量到的顯示成本（12.4 毫秒）就會嚴重落後。
%[text] **跟不上時有四種選擇，各有代價：**
%[text:table]
%[text] | 做法 | 代價 |
%[text] | --- | --- |
%[text] | **丟幀**（處理不完就跳過） | 時間解析度變差；快速移動的物體可能整個漏掉 |
%[text] | **降解析度** | 小物體會消失（第 19、20 章量過） |
%[text] | **降處理頻率**（每 N 幀處理一次） | 同丟幀，但至少是規律的，好分析 |
%[text] | **加緩衝區** | 延遲累積；即時控制場景不能用 |
%[text:table]
%[text] > **最糟的是沒有明確選擇。** `snapshot` 在你處理的期間
%[text] > 並不會排隊——它給你的是**當下**那一張，中間的影格靜靜消失。
%[text] > 程式跑得好好的，資料卻有洞，而且**沒有任何訊息**。
%[text] > **要自己記錄時間戳並檢查間隔**，才知道丟了多少。
%[text] 加分題會比較「丟幀」與「降解析度」哪一個代價小。
%%
%[text] # 13. 錄影輸出：時間與空間的取捨
%[text] 某次執行，同樣 60 幀 640×360：
%[text:table]
%[text] | 編碼 | 毫秒/幀 | 檔案大小 |
%[text] | --- | --- | --- |
%[text] | Uncompressed AVI | **1.5** | **41.5 MB** |
%[text] | Motion JPEG AVI | 2.4 | 1.8 MB |
%[text] | MPEG-4 | 3.4 | **0.6 MB** |
%[text:table]
%[text] **最快的大 69 倍，最小的慢 2.3 倍。** 選哪個看你的瓶頸在哪：
%[text] 硬碟夠快就選 Uncompressed（省 CPU），
%[text] 要長時間錄或要傳出去就選 MPEG-4。
outFile = fullfile(tempdir, "ch23_ball_annotated.mp4");
[~, wInfo] = ch23_ballSegmentVideo("singleball.mp4", WriteTo=outFile);
d = dir(outFile);
fprintf("輸出 %s（%.1f KB，%.3f 秒）\n", "ch23_ball_annotated.mp4", ...
    d.bytes/1024, wInfo.Seconds);
%[text] > **`VideoWriter` 一定要 `close`。** 沒關就是一個壞檔——
%[text] > 索引寫在檔尾，程式中途出錯而沒關檔，前面寫的全部作廢。
%[text] > `ch23_ballSegmentVideo` 用 `onCleanup` 保證這件事，
%[text] > 不管是正常結束還是丟例外。
%[text] > **`FrameRate` 要自己設。** 預設是 30；
%[text] > 來源是 15 fps 的話，不設就會得到一支快轉兩倍的影片。
%%
%[text] # 14. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 處理 |
%[text] | --- | --- | --- |
%[text] | **`insertText` 畫中文** | 每幀一個警告，字畫不出來 | 影像標註用英數；要中文得指定 `Font=`（會綁死機器） |
%[text] | 只記錄有偵測到的幀 | 算不出速度，時間軸錯位 | 每一幀都留一列，找不到記 `NaN` |
%[text] | 迴圈內建構 `strel`／偵測器 | 慢 4–12 倍，**而且有狀態的物件結果是錯的** | 提到迴圈外 |
%[text] | 忘記 `close(writer)` | 影片檔打不開 | `onCleanup` |
%[text] | 沒設 `writer.FrameRate` | 播放速度不對 | 從來源的 `FrameRate` 帶過來 |
%[text] | 用第一張影格計時 | 數字大 7–14 倍 | 先熱身再量 |
%[text] | 假設相機是規格上的 fps | 產線驗收時跟不上 | 在實際環境量最差值 |
%[text] | `parfor` 每一幀 | 比序列還慢 | 改成多檔案平行，或不要平行 |
%[text] | 開發時開著顯示跑批次 | 慢 3 倍以上 | `Display=false` |
%[text:table]
%%
%[text] # 15. 練習
%[text] 練習在 `exercise/Ch23_Exercise.m`。
%%
%[text] # 16. 延伸閱讀
%[text] - `doc VideoReader` / `doc VideoWriter`
%[text] - `doc webcam` / `doc ipcam` / `doc videoinput`
%[text] - **Image Acquisition Explorer**（APP 頁籤）
%[text] - `doc vision.VideoPlayer` / `doc vision.DeployableVideoPlayer`
%[text] - `doc profile` — MATLAB 內建的逐行剖析器
%[text] - `doc gpuArray` / `doc gputimeit`
%[text] - 第 24 章：用追蹤補上本章第 5 節那個 7 幀的洞

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
