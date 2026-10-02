function hits = findLegacyAPI(folder, options)
%FINDLEGACYAPI 掃描資料夾中用到的已移除或過時 MATLAB 影像／視覺函式。
%
%   FINDLEGACYAPI(FOLDER) 遞迴掃描 FOLDER 下的 .m 檔，找出在 R2026a／R2026b 已被
%   移除、即將移除或已有新版取代的函式，並在命令視窗列出結果。
%
%   HITS = FINDLEGACYAPI(___) 回傳結果 table，欄位為
%   File、Line、Legacy、Severity、Replacement、Note。
%
%   名稱-值引數：
%     Recursive  是否遞迴掃描子資料夾，預設 true
%     Verbose    是否列印報告，預設 true
%
%   掃描採用單純的文字比對，會忽略註解行，但無法分辨同名的區域變數，
%   因此結果僅供人工複核參考。
%
%   範例：
%     findLegacyAPI("C:\我的專案")
%     h = findLegacyAPI(pwd, Verbose=false);
%
%   另見 CHECKENVIRONMENT.

arguments
    folder (1,1) string {mustBeFolder}
    options.Recursive (1,1) logical = true
    options.Verbose   (1,1) logical = true
end

rules = legacyRules();

if options.Recursive
    files = dir(fullfile(folder, "**", "*.m"));
else
    files = dir(fullfile(folder, "*.m"));
end

File = strings(0,1); Line = zeros(0,1); Legacy = strings(0,1);
Severity = strings(0,1); Replacement = strings(0,1); Note = strings(0,1);

for f = 1:numel(files)
    fp = string(fullfile(files(f).folder, files(f).name));
    try
        txt = readlines(fp);
    catch
        continue
    end

    for k = 1:numel(txt)
        codePart = stripComment(txt(k));
        if strlength(strtrim(codePart)) == 0
            continue
        end
        for r = 1:height(rules)
            if ~isempty(regexp(codePart, "(?<![\w.])" + rules.Legacy(r) + "(?![\w])", "once"))
                File(end+1,1)        = fp;             %#ok<AGROW>
                Line(end+1,1)        = k;              %#ok<AGROW>
                Legacy(end+1,1)      = rules.Legacy(r);      %#ok<AGROW>
                Severity(end+1,1)    = rules.Severity(r);    %#ok<AGROW>
                Replacement(end+1,1) = rules.Replacement(r); %#ok<AGROW>
                Note(end+1,1)        = rules.Note(r);        %#ok<AGROW>
            end
        end
    end
end

hits = table(File, Line, Legacy, Severity, Replacement, Note);

if ~isempty(hits)
    order = categorical(hits.Severity, ["已移除" "即將移除" "行為變更" "建議更新"], Ordinal=true);
    [~, idx] = sort(order);
    hits = hits(idx, :);
end

if options.Verbose
    printReport(hits, folder, numel(files));
end

if nargout == 0
    clear hits
end
end

% ========================================================================
function printReport(hits, folder, nFiles)
line = string(repmat('-', 1, 72));
fprintf("\n%s\n  過時 API 掃描：%s\n  掃描 %d 個 .m 檔\n%s\n", line, folder, nFiles, line);

if isempty(hits)
    fprintf("  沒有發現已移除或過時的函式。\n%s\n\n", line);
    return
end

sev = unique(hits.Severity, "stable");
for s = 1:numel(sev)
    sub = hits(hits.Severity == sev(s), :);
    fprintf("\n  [%s]  %d 處\n", sev(s), height(sub));
    for k = 1:height(sub)
        [~, name, ext] = fileparts(sub.File(k));
        fprintf("    %s:%d  %s  ->  %s\n", name + ext, sub.Line(k), ...
            sub.Legacy(k), sub.Replacement(k));
        if strlength(sub.Note(k)) > 0
            fprintf("        %s\n", sub.Note(k));
        end
    end
end
fprintf("\n%s\n\n", line);
end

% ------------------------------------------------------------------------
function s = stripComment(lineText)
%STRIPCOMMENT 移除行尾註解，但保留字串中的 % 字元。
s = lineText;
inStr = false; quote = "";
chars = char(s);
for i = 1:numel(chars)
    c = chars(i);
    if inStr
        if c == quote, inStr = false; end
    else
        if c == '"' || c == ''''
            inStr = true; quote = c;
        elseif c == '%'
            s = string(chars(1:i-1));
            return
        end
    end
end
end

% ------------------------------------------------------------------------
function rules = legacyRules()
%LEGACYRULES R2026a／R2026b 的已移除／過時影像與視覺 API 清單。
raw = [
    % 函式,                        嚴重度,      取代方案,                       備註
    "segnetLayers"              , "已移除"  , "unet / deeplabv3plus"        , "R2026a 已移除，呼叫會直接報錯"
    "unetLayers"                , "已移除"  , "unet"                        , "R2026a 已移除，呼叫會直接報錯"
    "unet3dLayers"              , "已移除"  , "unet3d"                      , "R2026a 已移除，呼叫會直接報錯"
    "deeplabv3plusLayers"       , "已移除"  , "deeplabv3plus"               , "R2026a 已移除，呼叫會直接報錯"
    "fcnLayers"                 , "已移除"  , "unet / deeplabv3plus"        , "R2026a 已移除，呼叫會直接報錯"
    "vision.AlphaBlender"       , "已移除"  , "imblend / insertObjectMask"  , "R2026a 警告，R2026b 已移除（vision:obsolete:removeFunctionality）"
    "augmentedImageSource"      , "已移除"  , "augmentedImageDatastore"     , "R2026b 已移除；參數不用改"
    "efficientADAnomalyDetector", "已移除"  , "studentTeacherAnomalyDetector", "R2026b 的 Visual Inspection Toolbox 不提供 EfficientAD"
    "trainEfficientADAnomalyDetector", "已移除", "trainStudentTeacherAnomalyDetector", "R2026b 的 Visual Inspection Toolbox 不提供 EfficientAD"
    "serial"                    , "已移除"  , "serialport"                  , "R2026b 起呼叫就報錯"
    "matlab.wsdl.createWSDLClient", "已移除", "webread / webwrite"          , "R2026b 已移除"
    "vision.loadPatchCoreAnomalyDetector", "即將移除", "coder.loadDeepLearningNetwork", "R2026b 起發出警告"
    "vision.loadFCDDAnomalyDetector", "即將移除", "coder.loadDeepLearningNetwork", "R2026b 起發出警告"
    "vision.loadFastFlowAnomalyDetector", "即將移除", "coder.loadDeepLearningNetwork", "R2026b 起發出警告"
    "groundTruthLidar"          , "即將移除", "groundTruthMultiSensor"      , "R2026b：Lidar Labeler 由 Multi-Sensor Labeler 取代"
    "labelDefinitionCreatorLidar", "即將移除", "labelDefinitionCreatorMultiSensor", "R2026b：Lidar Labeler 由 Multi-Sensor Labeler 取代"
    "lidarLabeler"              , "即將移除", "multiSensorLabeler"          , "R2026b：Lidar Labeler 由 Multi-Sensor Labeler 取代"
    "plotyy"                    , "即將移除", "yyaxis"                      , "R2026b 起列為即將移除"
    "cnncodegen"                , "即將移除", "codegen + coder.DeepLearningConfig(""none"")", "R2026b 起列為即將移除"
    "pcfitplane"                , "行為變更", "pcfitplane"                  , "R2026b 起會用內點做最小平方精修，誤差大幅下降（Ch.26）"
    "measureIlluminant"         , "行為變更", "measureIlluminant"           , "R2026b 起依 InputColorSpace 計算，不再假設線性 RGB（Ch.12）"
    "detectCheckerboardPoints"  , "行為變更", "detectCheckerboardPoints"    , "R2026b 起魚眼影像必須指定 HighDistortion=true"
    "estimateMultiCameraParameters", "行為變更", "estimateMultiCameraParameters", "R2026b 起要先執行 installMultiSensorCalibrationTools"
    "insertText"                , "行為變更", "insertText"                  , "R2026a 預設字型變更，輸出外觀與舊版不同"
    "imsegsam"                  , "行為變更", "imsegsam"                    , "R2026a 預設模型改為 sam2-large，需安裝 SAM 2 支援包"
    "segmentAnythingModel"      , "行為變更", "segmentAnythingModel"        , "R2026a 預設模型改為 sam2-large，需安裝 SAM 2 支援包"
    "estimateGeometricTransform" , "建議更新", "estgeotform2d"              , "舊 API，新版語法與輸出型別不同"
    "estimateGeometricTransform2D", "建議更新", "estgeotform2d"             , "舊 API"
    "estimateGeometricTransform3D", "建議更新", "estgeotform3d"             , "舊 API"
    "estimateWorldCameraPose"   , "建議更新", "estworldpose"                , "舊 API"
    "cameraPoseToExtrinsics"    , "建議更新", "pose2extr"                   , "舊 API"
    "extrinsicsToCameraPose"    , "建議更新", "extr2pose"                   , "舊 API"
    "affine2d"                  , "建議更新", "affinetform2d"               , "舊式轉換物件，矩陣慣例不同（前乘 vs 後乘）"
    "affine3d"                  , "建議更新", "affinetform3d"               , "舊式轉換物件"
    "rigid2d"                   , "建議更新", "rigidtform2d"                , "舊式轉換物件"
    "rigid3d"                   , "建議更新", "rigidtform3d"                , "舊式轉換物件"
    "projective2d"              , "建議更新", "projtform2d"                 , "舊式轉換物件"
    "trainNetwork"              , "建議更新", "trainnet"                    , "新式訓練函式，搭配 dlnetwork"
    "layerGraph"                , "建議更新", "dlnetwork"                   , "新式網路物件"
    "imtool"                    , "建議更新", "imageViewer"                 , "Image Viewer APP 取代舊的 imtool"
    "alexnet"                   , "建議更新", "imagePretrainedNetwork"      , "改用統一的預訓練網路載入介面"
    "googlenet"                 , "建議更新", "imagePretrainedNetwork"      , "改用統一的預訓練網路載入介面"
    "resnet18"                  , "建議更新", "imagePretrainedNetwork"      , "改用統一的預訓練網路載入介面"
    "resnet50"                  , "建議更新", "imagePretrainedNetwork"      , "改用統一的預訓練網路載入介面"
    "vgg16"                     , "建議更新", "imagePretrainedNetwork"      , "改用統一的預訓練網路載入介面"
    ];

rules = table(raw(:,1), raw(:,2), raw(:,3), raw(:,4), ...
    VariableNames=["Legacy" "Severity" "Replacement" "Note"]);
end
