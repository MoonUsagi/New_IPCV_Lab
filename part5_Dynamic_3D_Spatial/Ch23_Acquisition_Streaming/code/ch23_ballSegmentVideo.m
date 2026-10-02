function [tracks, info] = ch23_ballSegmentVideo(source, options)
%CH23_BALLSEGMENTVIDEO 把單幀演算法套用到整支影片。
%
%   TRACKS = CH23_BALLSEGMENTVIDEO(SOURCE) 逐幀執行
%   CH23_BALLSEGMENTFRAME，回傳一個 table，每一列是一幀：
%     Frame     幀號
%     Time      時間（秒）
%     Found     這一幀是否找到球
%     X, Y      質心座標（找不到時為 NaN）
%     Area      面積（找不到時為 NaN）
%
%   [TRACKS, INFO] = ... 另外回傳 struct，含 NumFrames、NumFound、
%   Seconds、FPS、FrameRate、Size。
%
%   SOURCE 可以是檔名字串，或已建立好的 VideoReader 物件。
%
%   **這支函式就是「把一幀變成一支影片」的那一層。**
%   它負責四件單幀函式不該管的事：
%     ① 逐幀讀取與迴圈控制
%     ② **預先配置**結果容器
%     ③ 把「找不到」記成 NaN 而不是跳過（否則幀號會對不上）
%     ④ 選用的顯示與錄影
%
%   名稱-值引數：
%     Threshold   傳給 ch23_ballSegmentFrame，預設 15
%     MinArea     傳給 ch23_ballSegmentFrame，預設 40
%     MaxFrames   最多處理幾幀，預設 Inf
%     Display     是否即時顯示，預設 false
%     WriteTo     輸出影片檔名；空字串表示不錄影，預設 ""
%     Annotate    是否在輸出影格上標註，預設 true
%
%   **為什麼預設不顯示？** 第 7 節量到 vision.VideoPlayer 要
%   25.9 毫秒／幀，比整個分割管線（15.3 毫秒）還貴——
%   **顯示會變成瓶頸本身**。預設關掉，需要時才打開。
%
%   範例：
%     tracks = ch23_ballSegmentVideo("singleball.mp4");
%     fprintf("%d / %d 幀找到球\n", nnz(tracks.Found), height(tracks));
%
%   另見 CH23_BALLSEGMENTFRAME, CH23_PIPELINEPROFILE, VIDEOWRITER.

arguments
    source
    options.Threshold (1,1) double {mustBePositive} = 15
    options.MinArea   (1,1) double {mustBePositive} = 40
    options.MaxFrames (1,1) double {mustBePositive} = Inf
    options.Display   (1,1) logical = false
    options.WriteTo   (1,1) string  = ""
    options.Annotate  (1,1) logical = true
end

if isa(source, "VideoReader")
    v = source;
else
    v = VideoReader(source);
end

n = min(v.NumFrames, options.MaxFrames);

% ---- ② 預先配置。動態成長在這裡不是效能問題就好，而是**正確性**問題：
%         幀號必須和列號對得上，才能畫出時間軸。
Frame = (1:n)';
Time  = (Frame - 1) / v.FrameRate;
Found = false(n,1);
X     = nan(n,1);
Y     = nan(n,1);
Area  = nan(n,1);

% ---- 把所有會重複建構的東西提到迴圈外（第 7 節量到這件事值 4.86 倍）
player = [];
if options.Display
    player = vision.VideoPlayer(Name="ch23 ball");
end
writer = [];
if strlength(options.WriteTo) > 0
    writer = VideoWriter(options.WriteTo, "MPEG-4");
    writer.FrameRate = v.FrameRate;
    open(writer);
end
cleanupObj = onCleanup(@() localCleanup(player, writer));

t0 = tic;
for k = 1:n
    frame = read(v, k);

    r = ch23_ballSegmentFrame(frame, ...
        Threshold = options.Threshold, ...
        MinArea   = options.MinArea);

    % ---- ③ 找不到就留 NaN。**不要 continue 掉、也不要從表裡刪除**，
    %         否則第 27–33 幀的遮擋在資料上會變成「不存在」而不是「沒看到」。
    Found(k) = r.Found;
    if r.Found
        X(k)    = r.Centroid(1);
        Y(k)    = r.Centroid(2);
        Area(k) = r.Area;
    end

    if options.Display || ~isempty(writer)
        out = frame;
        if options.Annotate
            out = localAnnotate(out, r, k, n);
        end
        if options.Display, player(out); end
        if ~isempty(writer), writeVideo(writer, out); end
    end
end
seconds = toc(t0);

tracks = table(Frame, Time, Found, X, Y, Area);

info = struct( ...
    NumFrames = n, ...
    NumFound  = nnz(Found), ...
    Seconds   = seconds, ...
    FPS       = n / seconds, ...
    FrameRate = v.FrameRate, ...
    Size      = [v.Height v.Width]);
end

% ========================================================================
function out = localAnnotate(frame, r, k, n)
%LOCALANNOTATE 在影格上畫出偵測結果。
% **影像上的標註一律用英數字。** insertText 的預設字型 Roboto-Regular
% 不含中文，傳中文進去每一幀都會發警告，而且字會畫不出來。
% 要中文就得指定字型檔（Font="Microsoft JhengHei"），但那會綁死機器。
label = sprintf("%d/%d", k, n);
if r.Found
    out = insertShape(frame, "filled-circle", ...
        [r.Centroid 8], Color="yellow", Opacity=0.7);
    out = insertShape(out, "rectangle", r.BBox, Color="green", LineWidth=2);
    label = label + sprintf("  A=%.0f", r.Area);
else
    out = insertText(frame, [10 40], "OCCLUDED", ...
        BoxColor="red", TextColor="white", FontSize=14);
end
out = insertText(out, [10 10], label, BoxColor="black", ...
    TextColor="white", FontSize=14);
end

% ------------------------------------------------------------------------
function localCleanup(player, writer)
%LOCALCLEANUP 不管是正常結束還是中途出錯，都要把資源放掉。
%   影片檔沒有 close 就是一個壞檔；播放器沒有 release 會佔住視窗。
if ~isempty(player), release(player); end
if ~isempty(writer) && isvalid(writer)
    try
        close(writer);
    catch
    end
end
end
