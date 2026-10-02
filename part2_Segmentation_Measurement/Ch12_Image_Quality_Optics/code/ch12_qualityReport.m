function report = ch12_qualityReport(I, options)
%CH12_QUALITYREPORT 產出影像品質報告，並檢查指標是否用在有效區間。
%
%   REPORT = CH12_QUALITYREPORT(I) 對單張影像計算無參考指標，回傳 struct：
%     Scores         各指標分數的 table
%     Reference      有給 Reference 時的全參考指標 table，否則空 table
%     Warnings       偵測到的問題（string 陣列）
%     ModelNote      使用的 NIQE 模型說明
%     Verdict        綜合判定："通過" / "需複驗" / "不合格"
%
%   名稱-值引數：
%     Reference     原圖。給了才會算 psnr/ssim/multissim。預設 []
%     NiqeModel     自訓的 niqeModel。**非自然影像領域強烈建議提供**
%     DomainNote    領域說明，會寫進 ModelNote
%     NiqeThreshold NIQE 的合格門檻，預設 NaN（不判定）
%
%   為什麼這支函式主要在「發警告」
%   ------------------------------
%   第 12 章實測到的三件事讓「直接回報分數」變成一件危險的事：
%
%   **① 無參考指標不是絕對尺度。**
%   乾淨的 text.png NIQE = 39.62，乾淨的 peppers.png = 3.11。
%   分數反映的是「與自然照片統計的距離」，不是品質。
%
%   **② 預設模型在非自然領域會把排序弄反。**
%   合成晶圓紋理上：乾淨 64.68、模糊 sigma=3 只有 12.02。
%   **預設模型認為模糊的那張好 5.4 倍。**
%   拿它當產線門檻會主動挑掉清晰的影像。
%
%   **③ 指標有飽和區與非單調區。**
%   PIQE 在模糊 sigma>=4 一律 100；NIQE 與 BRISQUE 在重度模糊時會「回頭」
%   （NIQE sigma=4 是 6.93，sigma=8 反而降到 6.65）。
%
%   所以本函式會在下列情況出聲：
%     · 沒給 NiqeModel 而影像的統計看起來不像自然照片
%     · PIQE 觸及上限 100（已進入飽和區，失去解析能力）
%     · 三個指標的排序互相矛盾
%     · 只給了 Reference 而只看 PSNR
%
%   為什麼要記 ModelNote
%   --------------------
%   自訓 NIQE 的分數**只有相對意義**。5.22 與 8065.89 不能跨專案比較。
%   與第 11 章的校正係數同一個原則：
%   **任何依賴模型或校正的數字，都要帶著它的來歷一起流動。**
%
%   範例：
%     % 自然照片，沒有原圖
%     r = ch12_qualityReport(imread("peppers.png"));
%     disp(r.Scores); disp(r.Warnings)
%
%     % 工業影像，用自訓模型
%     model = fitniqe(imageDatastore(trainDir));
%     r = ch12_qualityReport(waferImg, NiqeModel=model, ...
%             DomainNote="晶圓紋理，24 張合格品訓練", NiqeThreshold=50);
%     fprintf("%s\n", r.Verdict);
%
%   另見 NIQE, FITNIQE, BRISQUE, PIQE, SSIM, PSNR, CH12_MEASUREMTF.

arguments
    I {mustBeNumeric, mustBeNonempty}
    options.Reference     = []
    options.NiqeModel     = []
    options.DomainNote    (1,1) string = ""
    options.NiqeThreshold (1,1) double = NaN
end

G = im2double(I);
if size(G,3) > 1
    G = im2gray(G);
end

warnings = strings(0);

% --- 無參考指標 ------------------------------------------------------
usingCustom = ~isempty(options.NiqeModel);
if usingCustom
    niqeScore = niqe(G, options.NiqeModel);
else
    niqeScore = niqe(G);
end
brisqueScore = brisque(G);
piqeScore    = piqe(G);

scores = table( ...
    ["NIQE"; "BRISQUE"; "PIQE"], ...
    [niqeScore; brisqueScore; piqeScore], ...
    [usingCustom; false; false], ...
    VariableNames=["Metric" "Score" "CustomModel"]);

% --- 模型來歷 --------------------------------------------------------
if usingCustom
    modelNote = "自訓 niqeModel（BlockSize " + ...
        mat2str(options.NiqeModel.BlockSize) + "）";
    if strlength(options.DomainNote) > 0
        modelNote = modelNote + "，領域：" + options.DomainNote;
    end
    modelNote = modelNote + "。分數**僅在同一模型內可比**，不可跨專案比較。";
else
    modelNote = "預設 NIQE 模型（訓練於自然照片）。" + ...
        "分數反映與自然照片統計的距離，不是絕對品質。";
end

% --- 檢查 1：領域是否像自然照片 --------------------------------------
% 判準：自然照片的梯度分布是重尾的。週期性強、灰階層次少的工業影像
% 會有明顯不同的統計。這裡用一個粗略但有用的指標：
% 相鄰像素差的峰度。自然照片通常遠大於高斯的 3。
d = diff(G(:));
if numel(d) > 100
    kurt = kurtosis(d);
    if ~usingCustom && kurt < 6
        warnings(end+1) = sprintf( ...
            "影像的梯度峰度只有 %.2f（自然照片通常 > 6），" + ...
            "統計特性可能不像自然照片，而你用的是**預設** NIQE 模型。" + ...
            "實測顯示預設模型在非自然領域會把好壞排序弄反" + ...
            "（乾淨 64.68 vs 模糊 12.02）。請用 fitniqe 訓練領域模型。", kurt);
    end
end

% --- 檢查 2：PIQE 飽和 -----------------------------------------------
if piqeScore >= 99.5
    warnings(end+1) = "PIQE = " + sprintf("%.2f", piqeScore) + ...
        " 已觸及上限 100，進入飽和區。" + ...
        "實測模糊 sigma=4 與 sigma=8 的 PIQE 都是 100——" + ...
        "此時 PIQE 無法分辨劣化程度，不要用它做排序。";
end

% --- 檢查 3：指標互相矛盾 --------------------------------------------
% 三個指標各自的量綱不同，無法直接比大小。但可以看它們相對於
% 「自然照片典型值」的位置是否一致。
typicalNiqe = 4; typicalBrisque = 30; typicalPiqe = 30;
flags = [niqeScore > 2*typicalNiqe, ...
         brisqueScore > 1.5*typicalBrisque, ...
         piqeScore > 1.5*typicalPiqe];
if ~usingCustom && any(flags) && ~all(flags)
    names = ["NIQE" "BRISQUE" "PIQE"];
    warnings(end+1) = "指標判斷不一致：" + ...
        join(names(flags), "、") + " 認為品質差，而 " + ...
        join(names(~flags), "、") + " 認為正常。" + ...
        "三個無參考指標訓練的失真類型不同，排序可能相反" + ...
        "（實測同一組影像：NIQE 說雜訊更糟、BRISQUE 與 PIQE 說模糊更糟）。" + ...
        "請選定一個指標並固定使用。";
end

% --- 全參考指標 ------------------------------------------------------
refTable = table();
if ~isempty(options.Reference)
    R = im2double(options.Reference);
    if size(R,3) > 1, R = im2gray(R); end
    if ~isequal(size(R), size(G))
        error("ch12_qualityReport:sizeMismatch", ...
            "Reference 的尺寸 %s 與輸入 %s 不同。", ...
            mat2str(size(R)), mat2str(size(G)));
    end

    refTable = table( ...
        ["MSE"; "PSNR"; "SSIM"; "MultiSSIM"], ...
        [immse(G,R); psnr(G,R); ssim(G,R); multissim(G,R)], ...
        VariableNames=["Metric" "Value"]);

    warnings(end+1) = "提醒：PSNR 只是 MSE 的對數變換，排序完全相同。" + ...
        "實測等 MSE 的雜訊與模糊 PSNR 都是 26.0499，但 SSIM 是 " + ...
        "0.4394 vs 0.8081（差 1.84 倍）。**不要只報 PSNR。**";
end

% --- 判定 ------------------------------------------------------------
if isnan(options.NiqeThreshold)
    verdict = "未判定（未提供 NiqeThreshold）";
elseif niqeScore <= options.NiqeThreshold
    verdict = sprintf("通過（NIQE %.2f <= 門檻 %.2f）", ...
        niqeScore, options.NiqeThreshold);
elseif niqeScore <= 1.5*options.NiqeThreshold
    verdict = sprintf("需複驗（NIQE %.2f，門檻 %.2f）", ...
        niqeScore, options.NiqeThreshold);
else
    verdict = sprintf("不合格（NIQE %.2f >> 門檻 %.2f）", ...
        niqeScore, options.NiqeThreshold);
end

if ~isnan(options.NiqeThreshold) && ~usingCustom
    warnings(end+1) = "用**預設** NIQE 模型搭配固定門檻做判定，風險很高。" + ...
        "門檻是針對特定領域校正出來的，換領域就必須重新校正——" + ...
        "而預設模型在非自然領域的排序本身就可能是錯的。";
end

if isempty(warnings)
    warnings = "無";
end

report = struct( ...
    "Scores",    scores, ...
    "Reference", refTable, ...
    "Warnings",  warnings, ...
    "ModelNote", modelNote, ...
    "Verdict",   string(verdict));
end
