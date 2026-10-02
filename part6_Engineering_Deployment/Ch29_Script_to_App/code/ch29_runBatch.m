function [results, failures] = ch29_runBatch(files, config, options)
%CH29_RUNBATCH 對一批檔案執行 ch29_countGrains，**一個壞檔不會停掉整批**。
%
%   [RESULTS, FAILURES] = CH29_RUNBATCH(FILES, CONFIG) 對 FILES（string 陣列）
%   逐一讀檔並計數，回傳：
%     RESULTS   table：File、Count、MeanArea、Threshold、Seconds
%     FAILURES  table：File、Identifier、Message
%
%   ## 批次處理的三條原則
%   **① 一個檔失敗，不能讓其他檔跟著失敗。**
%   腳本的寫法是一個 `for` 迴圈；第 37 個檔是壞的，前 36 個的結果
%   **全部丟失**（還在迴圈的區域變數裡），後面的也沒跑。
%
%   **② 失敗要被記錄，不能被吞掉。** `try ... catch, end`（空的 catch）
%   比沒有 try 更糟——**整批「成功」跑完，但有幾個檔根本沒處理**，
%   而你不會知道。這裡把每一個失敗的識別碼與訊息收進 FAILURES。
%
%   **③ 要有紀錄檔。** 使用者關掉視窗之後，唯一留下來的就是 log。
%
%   名稱-值引數：
%     LogFile     紀錄檔路徑；空字串表示不寫，預設 ""
%     StopOnError 遇到錯誤就停（除錯用），預設 false
%     Quiet       不在命令視窗印進度，預設 false
%
%   另見 CH29_COUNTGRAINS, CH29_LOADCONFIG.

arguments
    files  (1,:) string
    config (1,1) struct
    options.LogFile     (1,1) string  = ""
    options.StopOnError (1,1) logical = false
    options.Quiet       (1,1) logical = false
end

logger = localLogger(options.LogFile);
logger("開始批次：%d 個檔案", numel(files));
logger("參數：BackgroundRadius=%g, MinArea=%g, Threshold=%g", ...
    config.BackgroundRadius, config.MinArea, config.Threshold);

n = numel(files);
File      = strings(0,1);
Count     = zeros(0,1);
MeanArea  = zeros(0,1);
Threshold = zeros(0,1);
Seconds   = zeros(0,1);
FailFile  = strings(0,1);
FailId    = strings(0,1);
FailMsg   = strings(0,1);

for k = 1:n
    f = files(k);
    t0 = tic;
    try
        img = imread(f);
        r = ch29_countGrains(img, ...
            BackgroundRadius = config.BackgroundRadius, ...
            MinArea          = config.MinArea, ...
            Threshold        = config.Threshold);
        File(end+1,1)      = f;                        %#ok<AGROW>
        Count(end+1,1)     = r.Count;                  %#ok<AGROW>
        MeanArea(end+1,1)  = mean(r.Areas, "omitnan"); %#ok<AGROW>
        Threshold(end+1,1) = r.Threshold;              %#ok<AGROW>
        Seconds(end+1,1)   = toc(t0);                  %#ok<AGROW>
        logger("[%d/%d] OK   %s：%d 顆", k, n, localShort(f), r.Count);
    catch ME
        FailFile(end+1,1) = f;                         %#ok<AGROW>
        FailId(end+1,1)   = string(ME.identifier);     %#ok<AGROW>
        FailMsg(end+1,1)  = string(ME.message);        %#ok<AGROW>
        logger("[%d/%d] FAIL %s：%s", k, n, localShort(f), ME.message);
        if options.StopOnError
            rethrow(ME);
        end
    end
    if ~options.Quiet
        fprintf("  [%d/%d] %s\n", k, n, localShort(f));
    end
end

results  = table(File, Count, MeanArea, Threshold, Seconds);
failures = table(FailFile, FailId, FailMsg, ...
    VariableNames=["File" "Identifier" "Message"]);
logger("結束：%d 成功、%d 失敗", height(results), height(failures));
end

% ========================================================================
function logger = localLogger(logFile)
%LOCALLOGGER 回傳一個寫 log 的函式。每一行都有時間戳。
%   **每次都開檔、寫一行、關檔**——慢一點，但程式中途當掉時
%   已經寫進去的紀錄不會遺失（第 23 章 VideoWriter 沒關檔就壞檔是同一件事）。
if strlength(logFile) == 0
    logger = @(varargin) [];
    return
end
logger = @(fmt, varargin) localWrite(logFile, fmt, varargin{:});
end

function localWrite(logFile, fmt, varargin)
fid = fopen(logFile, "a", "n", "UTF-8");
if fid < 0, return; end
stamp = string(datetime("now", Format="yyyy-MM-dd HH:mm:ss.SSS"));
fprintf(fid, "%s  %s" + newline, stamp, sprintf(fmt, varargin{:}));
fclose(fid);
end

function s = localShort(f)
[~, name, ext] = fileparts(f);
s = name + ext;
end
