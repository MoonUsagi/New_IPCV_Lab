%[text] # 第 09 章　練習解答
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
hasSAM = exist("imsegsam","file") == 2;
if ~hasSAM
    disp("未安裝 SAM 2 支援包。以下顯示實測結果，程式碼不執行。")
end
I = imresize(imread("coloredChips.png"), 0.5);
%%
%[text] # 解答 1：SAM 會把「一個物件」定義成什麼
if hasSAM
    model = segmentAnythingModel("sam2-tiny");
    emb = extractEmbeddings(model, I);

    chipPoint = [148 88];            % 一個圓片的中心
    chipBox   = [130 70 40 40];      % 同一個圓片的外框

    [maskPoint, scorePoint] = segmentObjectsFromEmbeddings(model, emb, size(I), ...
        ForegroundPoints=chipPoint);
    [maskBox, scoreBox] = segmentObjectsFromEmbeddings(model, emb, size(I), ...
        BoundingBox=chipBox);

    fprintf("%-10s %10s %10s\n", "提示方式", "遮罩像素", "信心");
    fprintf("%-10s %10d %10.4f\n", "點", nnz(maskPoint), scorePoint);
    fprintf("%-10s %10d %10.4f\n", "框", nnz(maskBox), scoreBox);

    figure
    montage({labeloverlay(I, maskPoint), labeloverlay(I, maskBox)})
    title("點提示 ｜ 框提示")
end
%%
%[text] ## 多重遮罩的三個層級
if hasSAM
    [multi, multiScores] = segmentObjectsFromEmbeddings(model, emb, size(I), ...
        ForegroundPoints=chipPoint, ReturnMultiMask=true);

    fprintf("\n%-8s %10s %10s %12s\n", "遮罩", "像素", "信心", "佔全圖%");
    for k = 1:size(multi,3)
        fprintf("%-8d %10d %10.4f %11.1f%%" + "\n", k, nnz(multi(:,:,k)), multiScores(k), ...
            100*nnz(multi(:,:,k))/numel(multi(:,:,1)));
    end

    figure
    montage({multi(:,:,1), multi(:,:,2), multi(:,:,3)}, Size=[1 3])
    title("候選 1（物件）｜ 候選 2（局部）｜ 候選 3（整片背景）")
end
%[text] 三個候選代表三種**層級的解讀**：
%[text] 「這個圓片」、「圓片的一部分」、「圓片所在的整片區域」。
%[text] **注意順序不是依分數排列的**——上面的輸出裡，分數最高的是第 2 個。
%[text] 換一個提示點，順序又會不一樣。
%[text] **千萬不要寫 `multi(:,:,1)` 就當成最佳結果**，要用分數挑：
if hasSAM
    [~, best] = max(multiScores);
    fprintf("分數最高的是第 %d 個候選（%.4f）\n", best, multiScores(best));
end
%%
%[text] ## 點在邊緣 vs 點在中心
if hasSAM
    positions = [148  88;      % 圓片中心
                 160  75;      % 靠近邊緣
                 170  70];     % 兩個圓片之間
    edgeMasks = cell(3,1);

    fprintf("\n%-14s %10s %10s\n", "點位置", "遮罩像素", "信心");
    for k = 1:3
        [edgeMasks{k}, sc] = segmentObjectsFromEmbeddings(model, emb, size(I), ...
            ForegroundPoints=positions(k,:));
        fprintf("%-14s %10d %10.4f\n", mat2str(positions(k,:)), nnz(edgeMasks{k}), sc);
    end

    figure
    tiledlayout(1,4)
    nexttile
    imshow(I); hold on
    plot(positions(:,1), positions(:,2), "r*", MarkerSize=12, LineWidth=2); hold off
    title("三個點的位置")
    for k = 1:3
        nexttile; imshow(edgeMasks{k}); title("點 " + k)
    end
end
%[text] ## 什麼時候框提示比點提示可靠
%[text:table]
%[text] | 情境 | 建議 | 理由 |
%[text] | --- | --- | --- |
%[text] | 物件小、周圍乾淨 | 點提示 | 快、簡單，歧義少 |
%[text] | **物件與鄰居相連或重疊** | **框提示** | 框同時給了位置**與範圍**，能排除鄰居 |
%[text] | 物件內部有多層結構（車／車輪） | 框提示或多重遮罩 | 點提示的歧義最大 |
%[text] | 要批次自動處理 | 框提示 | 可由偵測器產生，不需人工點擊（見 Ch.21 Grounded SAM） |
%[text:table]
%[text] **框提示的本質是多給了一個約束**。點提示只說「這裡」，
%[text] 框提示說「這裡，而且大概這麼大」——歧義自然變少。
%%
%[text] # 解答 2：模型變體的取捨曲線
%[text] 這題會跑很久。預設不執行，把 `runVariantSweep` 改成 `true` 再跑。
runVariantSweep = false;

if hasSAM && runVariantSweep
    hard = imresize(imread("kobi.png"), 0.25);
    fprintf("困難影像尺寸 %s\n\n", mat2str(size(hard)));

    fprintf("%-16s %10s %10s\n", "變體", "秒數", "區域數");
    for m = ["sam2-tiny" "sam2-small" "sam2-large"]
        t0 = tic;
        masks = imsegsam(hard, ModelName=m, Verbose=false);
        fprintf("%-16s %10.1f %10d\n", m, toc(t0), masks.NumObjects);
    end
else
    disp("（略過模型變體掃描，耗時數分鐘）")
    disp("主教材對 coloredChips 的實測（權重已快取）：")
    disp("  sam2-tiny      30.0 秒   28 個區域")
    disp("  sam2-small     34.6 秒   28 個區域")
    disp("  sam2-baseplus  59.6 秒   28 個區域")
    disp("  sam2-large    110.8 秒   31 個區域")
    disp("  sam-base       59.8 秒   36 個區域（切得更碎，不是更好）")
end
%[text] ## 大模型的優勢什麼時候才明顯
%[text] 在簡單影像上（顏色分明、物件邊界清楚），tiny 與 large 的結果幾乎相同。
%[text] 大模型的優勢要在以下情況才看得出來：
%[text] - **低對比**的邊界（醫療影像、夜間影像）
%[text] - **物件重疊**或部分遮擋
%[text] - **細長或不規則**的形狀
%[text] - **紋理複雜**的背景 \
%[text] **實務策略**：用 tiny 開發流程，用 large 跑正式結果。
%[text] 兩者的介面完全相同，換模型只要改一個字串。
%%
%[text] # 解答 3：SAM 輔助標註函式
%[text] 完整實作在 `code/ch09_samAnnotate.m`。
%[text] 用第 02 章的 `ch02_findChips` 找出真實的圓片中心當作「使用者點擊」，
%[text] 再故意加一個點在背景上：
if hasSAM
    chips = ch02_findChips(I, MinArea=100, MinCircularity=0.8);
    clicks = round(chips.Centroid);
    clicks(end+1,:) = [230 100];       % 故意點歪，落在背景

    fprintf("模擬 %d 次點擊（其中最後一個落在背景）\n\n", size(clicks,1));

    [labels, report] = ch09_samAnnotate(I, clicks, ModelName="sam2-tiny");

    figure
    montage({I, labeloverlay(I, labels)})
    title(sprintf("原圖 ｜ 標註結果（%d 個物件）", max(labels(:))))
end
%[text] ## 為什麼一定要用面積規則
%[text] 看那張報告表的最後一列：落在背景的那個點，
%[text] **信心分數 0.966 是全場最高的**，遮罩卻佔了全圖 75%。
%[text:table]
%[text] | 點 | 遮罩像素 | 佔全圖 | 信心分數 |
%[text] | --- | --- | --- | --- |
%[text] | 圓片（7 個） | 264–444 | < 1% | 0.946–0.963 |
%[text] | **背景（誤點）** | **38234** | **75.3%** | **0.966 ← 最高** |
%[text:table]
%[text] **信心分數擋不住這個錯誤**，因為 SAM 並沒有做錯——
%[text] 它非常有信心地告訴你「你指的那片背景，是一個完整連貫的區域」。
%[text] 這個判斷完全正確，只是不是你要的。
%[text] **模型的信心是對「它回答的問題」的信心，不是對「你的意圖」的信心。**
%[text] 這個區別在所有深度學習應用上都成立，後面幾章會反覆遇到。
%%
%[text] # 解答 4：SAM 的失敗模式
%[text] 這題同樣耗時，預設不執行。把 `runFailureTests` 改成 `true` 再跑。
runFailureTests = false;

failureCases = { ...
    "AT3_1m4_01.tif", "低對比、邊界模糊的細胞", "先 top-hat 校正照明再用傳統分割（Ch.06/08）"; ...
    "rice.png",       "大量重複的小物件",       "傳統方法快得多且更穩定（Ch.08）"; ...
    "tissue.png",     "紋理區域，無明確物件邊界", "紋理特徵 + 門檻（Ch.08 第 9 節）"};

if hasSAM && runFailureTests
    fprintf("%-18s %10s %12s\n", "影像", "SAM 區域數", "耗時");
    for k = 1:size(failureCases,1)
        X = imresize(im2gray(imread(failureCases{k,1})), 0.4);
        if size(X,3) == 1, X = repmat(X, 1, 1, 3); end
        t0 = tic;
        masks = imsegsam(X, ModelName="sam2-tiny", Verbose=false);
        fprintf("%-18s %10d %11.1fs\n", failureCases{k,1}, masks.NumObjects, toc(t0));
    end
else
    disp("（略過失敗模式測試）")
end

fprintf("\n%-18s %-26s %s\n", "影像", "SAM 的困難", "建議改用");
for k = 1:size(failureCases,1)
    fprintf("%-18s %-26s %s\n", failureCases{k,:});
end
%[text] ## 三種典型的失敗模式
%[text] **1. 低對比、邊界模糊**（細胞、醫療影像）
%[text] SAM 的「物件性」依賴清楚的邊界。邊界模糊時它會過度合併或漏掉物件。
%[text] 這類影像通常先做照明校正與對比增強，傳統方法反而更可靠。
%[text] **2. 大量重複的小物件**（米粒、顆粒、粉末）
%[text] SAM 的全自動模式會為每個物件跑一次解碼器——上百個物件就很慢。
%[text] 而且這類影像通常對比好、形狀單純，**Otsu 加形態學就能在毫秒內解決**。
%[text] 用 SAM 是殺雞用牛刀。
%[text] **3. 紋理區域**（布料、組織、地表）
%[text] 這裡沒有「物件」可言，只有「材質區域」。
%[text] SAM 會試著把紋理的局部結構切成物件，得到一堆沒有語意的碎片。
%[text] 紋理分割要用紋理特徵（`entropyfilt` 等）。
%[text] ## 一句話的判準
%[text] **SAM 擅長的是「有明確邊界的離散物件」。**
%[text] 影像裡如果不存在這種東西（紋理、漸層、連續場），
%[text] 或者物件多到成百上千，SAM 就不是對的工具。
%%
%[text] # 加分題：混合流程
%[text] 這題把 SAM 當「老師」，教出一組傳統參數，再用傳統方法上線。
if hasSAM
    fullChips = imread("coloredChips.png");
    small = imresize(fullChips, 0.5);

    % 步驟 1：用 SAM 標註少量影像，取得高品質遮罩
    chipStats = ch02_findChips(small, MinArea=100, MinCircularity=0.8);
    teachClicks = round(chipStats.Centroid);

    [samLabels, ~] = ch09_samAnnotate(small, teachClicks, ...
        ModelName="sam2-tiny", Verbose=false);
    samMask = samLabels > 0;

    fprintf("SAM 標註出 %d 個物件，共 %d 像素\n", max(samLabels(:)), nnz(samMask));

    % 步驟 2：從 SAM 遮罩反推 HSV 門檻
    hsvSmall = rgb2hsv(small);
    H = hsvSmall(:,:,1); S = hsvSmall(:,:,2); V = hsvSmall(:,:,3);

    hueInside = H(samMask);
    % 色相是環狀的，紅色跨越 0/1。先把接近 1 的值平移到負數再統計
    hueInside(hueInside > 0.5) = hueInside(hueInside > 0.5) - 1;

    derived = struct( ...
        "HueLo",  prctile(hueInside, 5), ...
        "HueHi",  prctile(hueInside, 95), ...
        "SatLo",  prctile(S(samMask), 5), ...
        "ValLo",  prctile(V(samMask), 5));

    fprintf("\n從 SAM 遮罩推導出的門檻：\n");
    fprintf("  色相 %.3f – %.3f（負值代表繞過 0）\n", derived.HueLo, derived.HueHi);
    fprintf("  飽和度 ≥ %.3f\n", derived.SatLo);
    fprintf("  明度   ≥ %.3f\n", derived.ValLo);

    % 步驟 3：用推導出的門檻做傳統分割
    Hwrapped = H;
    Hwrapped(Hwrapped > 0.5) = Hwrapped(Hwrapped > 0.5) - 1;
    classicalMask = Hwrapped >= derived.HueLo & Hwrapped <= derived.HueHi & ...
                    S >= derived.SatLo & V >= derived.ValLo;
    classicalMask = bwareaopen(imopen(classicalMask, strel("disk",2)), 100);

    fprintf("\n傳統方法結果：%d 個物件\n", max(bwlabel(classicalMask),[],"all"));
    fprintf("與 SAM 遮罩的 Dice：%.4f\n", dice(classicalMask, samMask));

    figure
    montage({small, labeloverlay(small, samMask), labeloverlay(small, classicalMask)}, Size=[1 3])
    title("原圖 ｜ SAM 標註（老師）｜ 推導出的傳統方法（學生）")

    % 步驟 4：估計處理 10000 張的總時間
    tSAM = timeitSam(small);
    tClassical = timeit(@() bwareaopen(imopen( ...
        Hwrapped >= derived.HueLo & Hwrapped <= derived.HueHi & ...
        S >= derived.SatLo & V >= derived.ValLo, strel("disk",2)), 100));

    fprintf("\n處理 10000 張的估計總時間：\n");
    fprintf("  全部用 SAM      %.0f 秒（%.1f 小時）\n", 10000*tSAM, 10000*tSAM/3600);
    fprintf("  推導出的傳統法  %.0f 秒（%.1f 分鐘）\n", 10000*tClassical, 10000*tClassical/60);
    fprintf("  加速比          %.0f 倍\n", tSAM/tClassical);
end
%[text] ## 這個流程的價值——以及它的代價
%[text] 加速比接近 **800 倍**（4.7 小時 → 21 秒）。但**品質是有損失的**：
%[text] 推導出的傳統方法與 SAM 遮罩的 Dice 只有約 **0.70**，
%[text] 而且物件數也對不上（傳統法 10 個 vs SAM 7 個）。
%[text] **為什麼差這麼多**：這裡的「推導」很粗糙——
%[text] 直接取 SAM 遮罩內像素的 5%–95% 百分位當門檻。這個做法有兩個問題：
%[text] 1. 百分位取得太緊（飽和度下限 0.63、明度下限 0.81），
%[text] 邊緣像素被排除，遮罩會比 SAM 的小一圈
%[text] 2. **只用了 7 個物件的統計**，樣本太少 \
%[text] 改善的方向：放寬百分位（例如 1%–99%）、用更多張影像推導、
%[text] 或改推導 Lab 空間的範圍而非 HSV。
%[text] **但更重要的是認清這個取捨的本質**：
%[text] 你用 30% 的品質損失，換到 800 倍的速度。
%[text] 划不划算**完全取決於下游任務**——計數可能夠用，精密量測就不行。
%[text] **SAM 付出的是一次性的標註成本，傳統方法付出的是每張影像的執行成本。**
%[text] **這正是第 17 到 22 章的主線**：
%[text] 用 SAM／VLM 產生標註 → 訓練或推導一個快的模型 → 那個模型上線。
%[text] 差別只在於這裡「推導」的是幾個門檻值，而後面幾章訓練的是神經網路。
%[text] **注意這個流程的前提**：影像的變異要夠小（同一條產線、固定照明）。
%[text] 若照明會變，推導出的門檻就會失效——那正是第 02 章的教訓。

function t = timeitSam(I)
%TIMEITSAM 估計 SAM 處理一張影像的時間（embeddings + 一次提示）。
model = segmentAnythingModel("sam2-tiny");
t0 = tic;
emb = extractEmbeddings(model, I);
segmentObjectsFromEmbeddings(model, emb, size(I), ForegroundPoints=round(size(I,[2 1])/2));
t = toc(t0);
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
