function results = verifyChapters(options)
%VERIFYCHAPTERS 在乾淨環境下執行所有教材與解答，確認全部可跑。
%
%   VERIFYCHAPTERS() 依序執行每一章的 ChNN_Main.m 與 exercise 資料夾下的
%   ChNN_Solution.m，回報成功或失敗。這是教材的品質閘門：教材最大的信任
%   殺手不是內容不夠深，而是「照著做卻跑不出來」。
%
%   VERIFYCHAPTERS(Chapters=["00" "01"]) 只驗證指定章節。
%
%   VERIFYCHAPTERS(Include="main") 只跑主教材，不跑解答。
%   可選 "all"（預設）、"main"、"solution"。
%
%   RESULTS = VERIFYCHAPTERS(___) 回傳結果 table，欄位為
%   Chapter、Kind、File、Status、Seconds、Message。
%
%   名稱-值引數：
%     Chapters  章號字串陣列，預設 "all"
%     Include   "all"（預設）／"main"／"solution"
%     Quiet       是否隱藏圖形視窗，預設 true
%     Fast        是否跳過純計時展示的段落，預設 true
%     CaptureDir  若指定，把每個檔案的命令視窗輸出存成
%                 CaptureDir/ChNN_main.txt 等，用來比對不同 MATLAB 版本的數字
%
%   建議在每次提交教材前執行一次，或接進 CI。
%
%   範例：
%     verifyChapters
%     verifyChapters(Chapters="01", Include="solution")
%     r = verifyChapters; failed = r(r.Status == "失敗", :);
%
%   另見 BUILDHANDBOOK, IPCVSETUP.

arguments
    options.Chapters (1,:) string = "all"
    options.Include  (1,1) string {mustBeMember(options.Include,["all" "main" "solution"])} = "all"
    options.Quiet    (1,1) logical = true
    options.Fast     (1,1) logical = true
    options.CaptureDir (1,1) string = ""
end

root    = ipcvRoot();
userDir = pwd;

% 快速模式：教材中純計時展示的段落會自行跳過（見 ipcvFast）。
% 驗證的目的是確認程式碼能跑，不是重新量測效能。
oldFast = getenv("IPCV_FAST");
if options.Fast
    setenv("IPCV_FAST", "1");
else
    setenv("IPCV_FAST", "");
end

targets = table(Size=[0 3], VariableTypes=["string" "string" "string"], ...
    VariableNames=["Chapter" "Kind" "File"]);

if options.Include ~= "solution"
    targets = [targets; collect(root, "Ch*_Main.m", "main", "")];
end
if options.Include ~= "main"
    targets = [targets; collect(root, "Ch*_Solution.m", "solution", "exercise")];
end

if ~(isscalar(options.Chapters) && options.Chapters == "all")
    targets = targets(ismember(targets.Chapter, options.Chapters), :);
end

if isempty(targets)
    error("ipcv:nothingToVerify", "找不到符合條件的檔案。");
end

targets = sortrows(targets, ["Chapter" "Kind"]);

oldVis = get(groot, "defaultFigureVisible");
if options.Quiet
    set(groot, "defaultFigureVisible", "off");
end

Chapter = strings(0,1); Kind = strings(0,1); File = strings(0,1);
Status  = strings(0,1); Seconds = zeros(0,1); Message = strings(0,1);

fprintf("\n驗證教材：%d 個檔案\n\n", height(targets));

for k = 1:height(targets)
    f          = targets.File(k);
    [fdir, fn] = fileparts(f);

    fprintf("  第 %s 章 %-9s %-22s ", targets.Chapter(k), ...
        "(" + targets.Kind(k) + ")", fn);

    t0  = tic;
    st  = "成功";
    msg = "";
    try
        cd(fdir);
        out = runIsolated(fn);   % 必須隔離：腳本會在呼叫端的工作區建立變數，
                           % 直接 run 會覆蓋本函式的迴圈計數器與累積變數
    catch ME
        st  = "失敗";
        msg = string(ME.identifier) + " | " + string(ME.message);
        if ~isempty(ME.stack)
            msg = msg + sprintf(" (第 %d 行 of %s)", ME.stack(1).line, ME.stack(1).name);
        end
    end
    el = toc(t0);
    close all force

    if strlength(options.CaptureDir) > 0
        if ~isfolder(options.CaptureDir), mkdir(options.CaptureDir); end
        if st ~= "成功", out = msg; end
        writelines(string(out), fullfile(options.CaptureDir, ...
            "Ch" + targets.Chapter(k) + "_" + targets.Kind(k) + ".txt"), Encoding="UTF-8");
    end

    if st == "成功"
        fprintf("OK   %5.1f 秒\n", el);
    else
        fprintf("失敗\n      %s\n", msg);
    end

    Chapter(end+1,1) = targets.Chapter(k); %#ok<AGROW>
    Kind(end+1,1)    = targets.Kind(k);    %#ok<AGROW>
    File(end+1,1)    = f;                  %#ok<AGROW>
    Status(end+1,1)  = st;                 %#ok<AGROW>
    Seconds(end+1,1) = el;                 %#ok<AGROW>
    Message(end+1,1) = msg;                %#ok<AGROW>
end

set(groot, "defaultFigureVisible", oldVis);
setenv("IPCV_FAST", oldFast);
cd(userDir);

results = table(Chapter, Kind, File, Status, Seconds, Message);

nOK = nnz(results.Status == "成功");
fprintf("\n結果：%d 成功、%d 失敗，總耗時 %.0f 秒\n\n", ...
    nOK, height(results) - nOK, sum(results.Seconds));

if nargout == 0
    clear results
end
end

% ========================================================================
function out = runIsolated(scriptName)
%RUNISOLATED 在獨立的函式工作區執行腳本，避免變數汙染呼叫端。
%   腳本在 MATLAB 中沒有自己的工作區——它會在呼叫者的工作區建立變數。
%   把 run 包在這支只有一個輸入變數的小函式裡，腳本的變數就只會影響這裡。
out = evalc(sprintf("run('%s')", scriptName));
end

% ------------------------------------------------------------------------
function t = collect(root, pattern, kind, subfolder)
if strlength(subfolder) > 0
    d = dir(fullfile(root, "part*", "Ch*", subfolder, pattern));
else
    d = dir(fullfile(root, "part*", "Ch*", pattern));
end

Chapter = strings(numel(d),1);
Kind    = repmat(kind, numel(d), 1);
File    = strings(numel(d),1);

for k = 1:numel(d)
    tok = regexp(d(k).name, "Ch(\d{2})_", "tokens", "once");
    Chapter(k) = ternaryStr(isempty(tok), "??", string(tok));
    File(k)    = string(fullfile(d(k).folder, d(k).name));
end

t = table(Chapter, Kind, File);
end

% ------------------------------------------------------------------------
function s = ternaryStr(cond, a, b)
if cond, s = a; else, s = b; end
end
