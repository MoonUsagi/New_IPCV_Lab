function [outDir, manifest] = ch13_makeSyntheticSet(bgFiles, srcObj, objMask, numImages, options)
%CH13_MAKESYNTHETICSET 產生帶標註的合成資料集，並回報它的分布特性。
%
%   [OUTDIR, MANIFEST] = CH13_MAKESYNTHETICSET(BGFILES, SRCOBJ, OBJMASK, NUMIMAGES)
%   把 SRCOBJ 的 OBJMASK 區域插入 BGFILES 的背景中，產生 NUMIMAGES 張
%   合成影像與對應標註，寫到 OUTDIR。
%
%   MANIFEST 是一個 table，每列一張影像：檔名、物件數、框、最大 IoU。
%
%   名稱-值引數：
%     OutputDir       輸出資料夾，預設 tempdir 下的暫存資料夾
%     MaxOverlap      物件間的最大重疊，預設 0.3（**不是**函式預設的 1）
%     ObjectsPerImage 每張影像的物件數範圍，預設 [1 4]
%     BlendMethod     混合方式，預設 "guidedfilter"
%     Scale           幾何擴增的縮放範圍，預設 [0.4 0.8]
%     Rotation        幾何擴增的旋轉範圍（度），預設 [-20 20]
%     Label           物件類別名稱，預設 "object"
%
%   為什麼預設 MaxOverlap 是 0.3 而不是 1
%   -------------------------------------
%   `insertObjectInImage` 的預設值 `1` 代表**完全不限制重疊**。
%
%   第 13 章第 10 節實測（畫布 260x320、物件縮放 0.7–0.9）：
%
%     MaxOverlap   插入個數   最大實際 IoU
%       1.0          10        0.7794
%       0.5           2        0.0000
%
%   不限制時十個物件疊在一起，最嚴重的一對重疊 **78%**。
%   那種標註對訓練是**有害的**：兩個框幾乎重合，
%   模型無法學到「一個物件對應一個框」。
%
%   所以本函式刻意把預設值收到 0.3——**寧可少一點資料，不要壞標註。**
%   若你的真實場景本來就有嚴重遮擋，再手動放寬。
%
%   合成資料真正的風險是分布，不是畫質
%   ----------------------------------
%   本函式回報的 MANIFEST 讓你可以**檢查自己造出了什麼分布**：
%     · 每張影像的物件數分布
%     · 物件大小的分布（框面積）
%     · 重疊程度的分布
%
%   這些都是你用參數「決定」的，不是從真實世界觀察到的。
%   如果真實場景平均每張有 8 個物件、而你合成的每張只有 2 個，
%   模型在真實資料上的表現會不如預期——而**畫質再好也救不回來**。
%
%   混合方式的選擇
%   --------------
%   預設 "guidedfilter" 而不是 "poisson"。
%   第 13 章第 7 節實測：Poisson 混合的內部保真只有 19.5 dB，
%   它只保留梯度不保留絕對值，**物件顏色會被背景拉走**。
%   用它產生訓練資料，模型會學到真實場景不存在的相關性。
%
%   範例：
%     bgs = ["bg1.png" "bg2.png" "bg3.png"];
%     [dir0, mf] = ch13_makeSyntheticSet(bgs, srcObj, objMask, 20, ...
%         MaxOverlap=0.2, ObjectsPerImage=[2 5], Label="pepper");
%
%     disp(mf)
%     fprintf("平均每張 %.1f 個物件\n", mean(mf.NumObjects));
%
%   另見 INSERTOBJECTINIMAGE, OBJECTINSERTIONDATASTORE, CH13_FILLSCENE.

arguments
    bgFiles   (1,:) string {mustBeNonempty}
    srcObj    {mustBeNumeric, mustBeNonempty}
    objMask   {mustBeA(objMask, ["logical" "numeric"])}
    numImages (1,1) double {mustBePositive, mustBeInteger}
    options.OutputDir       (1,1) string = ""
    options.MaxOverlap      (1,1) double {mustBeInRange(options.MaxOverlap,0,1)} = 0.3
    options.ObjectsPerImage (1,2) double {mustBePositive, mustBeInteger} = [1 4]
    options.BlendMethod     (1,1) string ...
        {mustBeMember(options.BlendMethod, ["guidedfilter" "poisson" "none"])} = "guidedfilter"
    options.Scale    (1,2) double {mustBePositive} = [0.4 0.8]
    options.Rotation (1,2) double = [-20 20]
    options.Label    (1,1) string = "object"
end

if exist("insertObjectInImage", "file") == 0
    error("ch13_makeSyntheticSet:noAVI", ...
        "找不到 insertObjectInImage。需要 " + ...
        "Automated Visual Inspection Library for Computer Vision Toolbox。");
end

if ~islogical(objMask), objMask = logical(objMask); end

if options.BlendMethod == "poisson"
    warning("ch13_makeSyntheticSet:poissonForTraining", ...
        "BlendMethod=""poisson"" 會改變物件的顏色（實測內部保真只有 19.5 dB）。" + ...
        "Poisson 混合只保留梯度不保留絕對值，物件會被背景染色。" + ...
        "產生**訓練資料**時建議用 ""guidedfilter""，否則模型會學到" + ...
        "真實場景不存在的顏色相關性。");
end

outDir = options.OutputDir;
if strlength(outDir) == 0
    outDir = string(fullfile(tempdir, "ipcv_ch13_synth_" + ...
        string(datetime("now", Format="yyyyMMdd_HHmmss"))));
end
imgDir = fullfile(outDir, "images");
if ~isfolder(imgDir), mkdir(imgDir); end

% --- 產生 -------------------------------------------------------------
fileName  = strings(numImages, 1);
numObj    = zeros(numImages, 1);
boxCell   = cell(numImages, 1);
maxIoUs   = zeros(numImages, 1);
meanArea  = zeros(numImages, 1);
requested = zeros(numImages, 1);

nRange = options.ObjectsPerImage;
sc     = options.Scale;
rot    = options.Rotation;

for i = 1:numImages
    bgPath = bgFiles(mod(i-1, numel(bgFiles)) + 1);
    dest = imread(bgPath);
    if size(dest,3) == 1, dest = repmat(dest, 1, 1, 3); end

    want = randi(nRange);
    requested(i) = want;

    scene = dest;
    stack = [];
    boxes = zeros(0,4);

    for k = 1:want
        args = {scene, srcObj, objMask, ...
            "GeometricAugmentation", ...
                @() randomAffine2d(Scale=sc, Rotation=rot), ...
            "BlendMethod", options.BlendMethod, ...
            "MaxInsertionAttempts", 50};
        % 第一次呼叫不能傳空的 ObjectsInSceneMasks
        if ~isempty(stack)
            args = [args, {"ObjectsInSceneMasks", stack, ...
                           "ObjectsInSceneMaxOverlap", options.MaxOverlap}];
        end

        try
            [scene, bb, nm] = insertObjectInImage(args{:});
        catch
            break                       % 放不下了
        end
        if isempty(bb) || ~any(nm(:))
            break
        end

        if isempty(stack), stack = nm; else, stack = cat(3, stack, nm); end
        boxes = [boxes; bb];
    end

    fname = sprintf("synth_%04d.png", i);
    imwrite(scene, fullfile(imgDir, fname));

    fileName(i) = fname;
    numObj(i)   = size(boxes,1);
    boxCell{i}  = boxes;

    if size(boxes,1) >= 2
        v = [];
        for a = 1:size(boxes,1)
            for b = a+1:size(boxes,1)
                v(end+1) = bboxOverlapRatio(boxes(a,:), boxes(b,:));
            end
        end
        maxIoUs(i) = max(v);
    end
    if ~isempty(boxes)
        meanArea(i) = mean(boxes(:,3) .* boxes(:,4));
    end
end

labels = repmat(categorical(options.Label), numImages, 1);

manifest = table(fileName, requested, numObj, boxCell, maxIoUs, meanArea, labels, ...
    VariableNames=["File" "Requested" "NumObjects" "Boxes" "MaxIoU" "MeanBoxArea" "Label"]);

save(fullfile(outDir, "manifest.mat"), "manifest");

% --- 檢查造出來的分布 -------------------------------------------------
shortfall = requested - numObj;
if any(shortfall > 0)
    warning("ch13_makeSyntheticSet:insertionShortfall", ...
        "%d / %d 張影像放不進要求的物件數（總共少了 %d 個）。" + ...
        "平均要求 %.1f 個、實際 %.1f 個。" + ...
        "這代表 MaxOverlap=%.2f 在這個畫布尺寸下已經飽和——" + ...
        "**你造出來的分布不是你要求的分布**。" + ...
        "要更多物件就得放寬重疊限制、縮小物件或加大背景。", ...
        nnz(shortfall > 0), numImages, sum(shortfall), ...
        mean(requested), mean(numObj), options.MaxOverlap);
end

if any(numObj == 0)
    warning("ch13_makeSyntheticSet:emptyImages", ...
        "有 %d 張影像完全沒有物件（框是空的）。" + ...
        "這些影像仍然是合法的訓練樣本（負樣本），" + ...
        "但如果不是刻意要的，請檢查物件是否比背景還大。", nnz(numObj == 0));
end

fprintf("已產生 %d 張合成影像於：\n  %s\n", numImages, imgDir);
fprintf("物件數：平均 %.2f、範圍 %d–%d\n", ...
    mean(numObj), min(numObj), max(numObj));
fprintf("最大 IoU：平均 %.4f、最大 %.4f（限制 %.2f）\n", ...
    mean(maxIoUs), max(maxIoUs), options.MaxOverlap);
fprintf("框面積：平均 %.0f 像素\n", mean(meanArea(meanArea > 0)));
fprintf("\n**這些分布是你用參數決定的，不是從真實世界觀察到的。**\n");
fprintf("請與真實場景的統計比對，分布不匹配時畫質再好也沒用。\n");
end
