function results = buildHandbook(options)
%BUILDHANDBOOK 由各章主教材產生手冊（PDF／HTML）。
%
%   BUILDHANDBOOK() 把每一章的 ChNN_Main.m 匯出成 HTML，放到 build/output。
%   匯出時預設會**重新執行**教材，確保手冊裡的每一張圖與每一段輸出，
%   都是當前版本真正跑出來的結果——這是防止教材腐化最有效的機制。
%
%   BUILDHANDBOOK(Chapters=["00" "01"]) 只建置指定章節。
%
%   BUILDHANDBOOK(Format="pdf") 產生 PDF。可選 "html"（預設）、"pdf"、"docx"。
%
%   BUILDHANDBOOK(Run=false) 不重新執行，只轉檔（快很多，但圖會是上次存檔的）。
%
%   RESULTS = BUILDHANDBOOK(___) 回傳結果 table，欄位為
%   Chapter、Source、Output、Status、Seconds。
%
%   名稱-值引數：
%     Chapters   章號字串陣列，預設 "all"
%     Format     "html"（預設）／"pdf"／"docx"
%     Run        匯出前是否重新執行教材，預設 true
%     OutputDir  輸出資料夾，預設 build/output
%     Quiet      是否隱藏圖形視窗，預設 true
%
%   注意：Run=true 時每章需數十秒到數分鐘。建議先以單章測試再全部建置。
%
%   範例：
%     buildHandbook(Chapters="01")
%     buildHandbook(Format="pdf")
%     r = buildHandbook(Run=false);
%
%   另見 EXPORT, IPCVSETUP.

arguments
    options.Chapters  (1,:) string  = "all"
    options.Format    (1,1) string {mustBeMember(options.Format,["html" "pdf" "docx"])} = "html"
    options.Run       (1,1) logical = true
    options.OutputDir (1,1) string  = ""
    options.Quiet     (1,1) logical = true
end

root = ipcvRoot();
if strlength(options.OutputDir) == 0
    options.OutputDir = fullfile(root, "build", "output");
end
if ~isfolder(options.OutputDir)
    mkdir(options.OutputDir);
end

mains = dir(fullfile(root, "part*", "Ch*", "Ch*_Main.m"));
if isempty(mains)
    error("ipcv:noChapters", "在 %s 底下找不到任何 Ch*_Main.m。", root);
end

% 依章號排序
chNums = arrayfun(@(f) extractChapterNumber(f.name), mains);
[chNums, order] = sort(chNums);
mains = mains(order);

if ~(isscalar(options.Chapters) && options.Chapters == "all")
    keep   = ismember(chNums, options.Chapters);
    mains  = mains(keep);
    chNums = chNums(keep);
    if isempty(mains)
        error("ipcv:noMatch", "指定的章節沒有對應的主教材檔。");
    end
end

% 隱藏圖形視窗，避免建置過程大量彈窗。
% 這裡刻意不用 onCleanup：export 會序列化工作區，遇到 onCleanup 物件會發出警告。
oldVis = get(groot, "defaultFigureVisible");
if options.Quiet
    set(groot, "defaultFigureVisible", "off");
end

Chapter = strings(0,1); Source = strings(0,1); Output = strings(0,1);
Status  = strings(0,1); Seconds = zeros(0,1);

fprintf("\n建置手冊：%d 章，格式 %s，%s\n", numel(mains), options.Format, ...
    ternaryStr(options.Run, "重新執行教材", "不重新執行"));
fprintf("輸出位置：%s\n\n", options.OutputDir);

for k = 1:numel(mains)
    src     = string(fullfile(mains(k).folder, mains(k).name));
    [~, nm] = fileparts(mains(k).name);
    dst     = fullfile(options.OutputDir, nm + "." + options.Format);

    fprintf("  [%2d/%2d] 第 %s 章 ... ", k, numel(mains), chNums(k));
    t0 = tic;
    try
        export(src, dst, Run=options.Run);
        st = "成功";
        fprintf("成功 (%.0f 秒)\n", toc(t0));
    catch ME
        st = "失敗：" + string(ME.message);
        fprintf("失敗\n          %s\n", ME.message);
    end
    close all force

    Chapter(end+1,1) = chNums(k);  %#ok<AGROW>
    Source(end+1,1)  = src;        %#ok<AGROW>
    Output(end+1,1)  = dst;        %#ok<AGROW>
    Status(end+1,1)  = st;         %#ok<AGROW>
    Seconds(end+1,1) = toc(t0);    %#ok<AGROW>
end

set(groot, "defaultFigureVisible", oldVis);

results = table(Chapter, Source, Output, Status, Seconds);

nOK = nnz(results.Status == "成功");
fprintf("\n完成：%d 成功、%d 失敗，總耗時 %.0f 秒\n", ...
    nOK, height(results) - nOK, sum(results.Seconds));

failed = results(results.Status ~= "成功", :);
if ~isempty(failed)
    fprintf("\n失敗的章節：\n");
    for k = 1:height(failed)
        fprintf("  第 %s 章 — %s\n", failed.Chapter(k), failed.Status(k));
    end
    fprintf("\n提示：先用 run 直接執行該章的 ChNN_Main.m 找出錯誤所在。\n");
end
fprintf("\n");

if nargout == 0
    clear results
end
end

% ========================================================================
function n = extractChapterNumber(filename)
tok = regexp(filename, "Ch(\d{2})_Main", "tokens", "once");
if isempty(tok)
    n = "??";
else
    n = string(tok{1});
end
end

% ------------------------------------------------------------------------
function s = ternaryStr(cond, a, b)
if cond, s = a; else, s = b; end
end
