function [report, flows] = ch24_flowCompare(frameA, frameB, options)
%CH24_FLOWCOMPARE 在同一對影格上比較多種光流方法。
%
%   [REPORT, FLOWS] = CH24_FLOWCOMPARE(FRAMEA, FRAMEB) 回傳 REPORT table：
%     Method      方法名稱
%     MaxSpeed    最大速度（像素/幀）
%     P95Speed    95 百分位速度
%     MedianSpeed 中位數速度
%     Seconds     耗時
%     Available   這個方法在本機可用嗎
%
%   FLOWS 是 struct，欄位是方法名稱，值是 opticalFlow 物件（不可用時為空）。
%
%   ## 為什麼要比，而不是挑一個用
%   **四種傳統方法在同一對影格上可以差 75 倍。**
%   Lucas–Kanade 與 Horn–Schunck 都建立在**亮度恆定的線性化**上，
%   那個近似只在**位移小於一個像素**時成立。
%   物體每幀移動 20 像素時，它們會嚴重低估——
%   **而且不會報錯，只會給你一個看起來很合理的小數字。**
%
%   Farnebäck 用影像金字塔（先在縮小的影像上估大位移，再逐層細化），
%   所以能處理大位移。代價是慢 3–5 倍。
%
%   > **光流的輸出沒有單位檢查。** 你拿到的永遠是一張速度場，
%   > 看起來都很像。**要驗證它，必須有一個你已知答案的位移。**
%
%   名稱-值引數：
%     Methods    要比較哪些方法，預設
%                ["opticalFlowLK" "opticalFlowHS" "opticalFlowFarneback" ...
%                 "opticalFlowLKDoG" "opticalFlowRAFT"]
%     Mask       只在這個遮罩內統計（logical）；空的話統計全畫面。
%                **強烈建議給遮罩**：物體只佔畫面一小部分時，
%                中位數與 95 百分位幾乎都是 0，什麼也看不出來。
%     Quiet      是否隱藏「方法不可用」的訊息，預設 false
%
%   **`opticalFlowRAFT` 需要 Computer Vision Toolbox Model for RAFT
%   Optical Flow Estimation 支援包。** 沒安裝時本函式不會失敗，
%   只會把該列的 Available 標成 false 並印一行訊息。
%
%   範例：
%     v = VideoReader("singleball.mp4");
%     r = ch24_flowCompare(read(v,20), read(v,21));
%     disp(r)
%
%   另見 OPTICALFLOWFARNEBACK, OPTICALFLOWLK, OPTICALFLOWHS, OPTICALFLOWRAFT.

arguments
    frameA
    frameB
    options.Methods (1,:) string = ["opticalFlowLK" "opticalFlowHS" ...
        "opticalFlowFarneback" "opticalFlowLKDoG" "opticalFlowRAFT"]
    options.Mask    = []
    options.Quiet   (1,1) logical = false
end

grayA = localGray(frameA);
grayB = localGray(frameB);

nm = numel(options.Methods);
Method      = strings(nm,1);
MaxSpeed    = nan(nm,1);
P95Speed    = nan(nm,1);
MedianSpeed = nan(nm,1);
Seconds     = nan(nm,1);
Available   = false(nm,1);

flows = struct();

for i = 1:nm
    name = options.Methods(i);
    Method(i) = name;
    try
        of = feval(name);

        % RAFT 吃彩色影格對；傳統方法吃灰階並且需要**先餵一張**
        % 建立內部狀態（第一次呼叫的輸出是全零，不能用）。
        if name == "opticalFlowRAFT"
            t0 = tic;
            fl = estimateFlow(of, frameA, frameB);
            Seconds(i) = toc(t0);
        else
            estimateFlow(of, grayA);
            t0 = tic;
            fl = estimateFlow(of, grayB);
            Seconds(i) = toc(t0);
        end

        M = fl.Magnitude;
        if ~isempty(options.Mask)
            M = M(options.Mask);
        end
        MaxSpeed(i)    = max(M(:));
        P95Speed(i)    = prctile(M(:), 95);
        MedianSpeed(i) = median(M(:));
        Available(i)   = true;
        flows.(name)   = fl;

    catch ME
        flows.(name) = [];
        if ~options.Quiet
            if contains(ME.identifier, "supportpackages")
                fprintf("⚠ %s 需要支援包，本機未安裝——跳過。\n", name);
            else
                fprintf("⚠ %s 失敗：%s\n", name, localShortMsg(ME.message));
            end
        end
    end
end

report = table(Method, MaxSpeed, P95Speed, MedianSpeed, Seconds, Available);
end

% ========================================================================
function g = localGray(I)
if size(I,3) == 3
    g = rgb2gray(I);
else
    g = I;
end
end

% ------------------------------------------------------------------------
function s = localShortMsg(msg)
s = string(msg);
s = extractBefore(s + newline, newline);
if strlength(s) > 70
    s = extractBefore(s, 70) + "...";
end
end
