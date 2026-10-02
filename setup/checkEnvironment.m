function report = checkEnvironment(options)
%CHECKENVIRONMENT 檢查本機環境是否符合 IPCV_Lab 課程需求。
%
%   CHECKENVIRONMENT() 檢查全部 31 章所需的工具箱與支援包，並在命令視窗
%   列出報告。
%
%   CHECKENVIRONMENT(Chapters=["17" "19" "21"]) 只檢查指定章節，適合單一
%   路徑開課前確認。
%
%   REPORT = CHECKENVIRONMENT(___) 另外回傳檢查結果 table，欄位為
%   Kind、Name、Level、Installed、Chapters。
%
%   名稱-值引數：
%     Chapters   要檢查的章號字串陣列，預設 "all"
%     MinRelease 最低 MATLAB 版本，預設 "R2026b"
%     ReportFile 若指定路徑，另存一份 HTML 報告
%     Verbose    是否列印報告，預設 true
%
%   範例：
%     checkEnvironment
%     checkEnvironment(Chapters=["00" "02" "09" "17" "18" "19" "20" "21" "22"])
%     r = checkEnvironment(ReportFile="env_report.html");
%
%   另見 COURSEREQUIREMENTS, DOWNLOADCOURSEDATA.

arguments
    options.Chapters   (1,:) string  = "all"
    options.MinRelease (1,1) string  = "R2026b"
    options.ReportFile (1,1) string  = ""
    options.Verbose    (1,1) logical = true
end

%% 1. MATLAB 版本
mr        = matlabRelease;
thisRel   = string(mr.Release);
relOK     = compareRelease(thisRel, options.MinRelease) >= 0;

%% 2. 比對需求與已安裝項目
req       = courseRequirements(options.Chapters);
installed = matlab.addons.installedAddons;
haveNames = string(installed.Name);

[names, ~, g] = unique(req.Name, "stable");
report = table(Size=[numel(names) 5], ...
    VariableTypes=["string" "string" "string" "logical" "string"], ...
    VariableNames=["Kind" "Name" "Level" "Installed" "Chapters"]);

for k = 1:numel(names)
    rows              = req(g == k, :);
    report.Name(k)    = names(k);
    report.Kind(k)    = rows.Kind(1);
    % 只要有任一章列為 required，整體即視為 required
    report.Level(k)   = ternary(any(rows.Level == "required"), "required", "optional");
    report.Installed(k) = any(haveNames == names(k));
    chs               = unique(rows.Chapter, "stable");
    chs               = chs(chs ~= "*");
    report.Chapters(k) = ternary(isempty(chs), "全課程", strjoin(chs, ", "));
end

report = sortrows(report, ["Installed" "Level" "Kind" "Name"], ...
    {'ascend' 'ascend' 'ascend' 'ascend'});

%% 3. GPU
gpuInfo = probeGPU();

%% 4. 列印報告
missingReq = report(~report.Installed & report.Level == "required", :);
missingOpt = report(~report.Installed & report.Level == "optional", :);

if options.Verbose
    line = string(repmat('=', 1, 72));
    fprintf("\n%s\n  IPCV_Lab 課程環境檢查\n%s\n", line, line);

    fprintf("  MATLAB 版本    : %s  %s\n", thisRel, ...
        ternary(relOK, "[OK]", sprintf("[不符] 課程需要 %s 以上", options.MinRelease)));
    fprintf("  檢查範圍       : %s\n", ...
        ternary(isscalar(options.Chapters) && options.Chapters == "all", ...
                "全部 31 章", "第 " + strjoin(options.Chapters, ", ") + " 章"));
    fprintf("  GPU            : %s\n", gpuInfo);
    fprintf("  需求項目       : %d 項（已安裝 %d，缺少 %d）\n", ...
        height(report), sum(report.Installed), sum(~report.Installed));

    if isempty(missingReq) && isempty(missingOpt)
        fprintf("\n  結果：全部需求皆已滿足，可以開始上課。\n");
    end

    if ~isempty(missingReq)
        fprintf("\n%s\n  缺少的必要項目（相關章節無法進行）\n%s\n", line, line);
        printList(missingReq);
    end

    if ~isempty(missingOpt)
        fprintf("\n%s\n  缺少的選用項目（僅影響部分單元）\n%s\n", line, line);
        printList(missingOpt);
    end

    if ~isempty(missingReq) || ~isempty(missingOpt)
        fprintf("\n  安裝方式：MATLAB 首頁 > 附加功能 > 取得附加功能，搜尋上列名稱。\n");
    end
    fprintf("%s\n\n", line);
end

%% 5. 選擇性輸出 HTML 報告
if strlength(options.ReportFile) > 0
    writeHtmlReport(options.ReportFile, thisRel, relOK, gpuInfo, report);
    fprintf("  報告已寫入：%s\n", options.ReportFile);
end
end

% ========================================================================
function printList(t)
for k = 1:height(t)
    fprintf("  [缺少] %-8s %s\n", "(" + t.Kind(k) + ")", t.Name(k));
    fprintf("         用於第 %s 章\n", t.Chapters(k));
end
end

% ------------------------------------------------------------------------
function s = probeGPU()
if exist("canUseGPU", "file") ~= 2
    s = "未安裝 Parallel Computing Toolbox，深度學習章節將以 CPU 執行（較慢）";
    return
end
try
    if canUseGPU
        d = gpuDevice;
        s = sprintf("%s，%.1f GB 可用", d.Name, d.AvailableMemory/1e9);
    else
        s = "偵測不到可用的 GPU，深度學習章節將以 CPU 執行（較慢）";
    end
catch
    s = "GPU 偵測失敗，深度學習章節將以 CPU 執行（較慢）";
end
end

% ------------------------------------------------------------------------
function c = compareRelease(a, b)
%COMPARERELEASE 比較兩個版本字串（如 "R2026a"）。a>b 回傳 1，相等 0，a<b 回傳 -1。
pa = parseRelease(a);
pb = parseRelease(b);
if     isequal(pa, pb), c =  0;
elseif pa(1) > pb(1) || (pa(1) == pb(1) && pa(2) > pb(2)), c = 1;
else,  c = -1;
end
end

function p = parseRelease(r)
tok = regexp(r, "R(\d{4})([ab])", "tokens", "once");
if isempty(tok)
    p = [0 0];
else
    p = [str2double(tok(1)), double(char(tok(2))) - double('a')];
end
end

% ------------------------------------------------------------------------
function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end

% ------------------------------------------------------------------------
function writeHtmlReport(file, rel, relOK, gpuInfo, report)
css = "body{font-family:-apple-system,'Segoe UI',sans-serif;margin:32px;color:#16202b}" + ...
      "h1{font-size:22px}table{border-collapse:collapse;width:100%;font-size:14px;margin-top:16px}" + ...
      "th,td{border-bottom:1px solid #dde3ea;padding:7px 10px;text-align:left}" + ...
      "th{background:#eef2f7;font-size:12px;text-transform:uppercase;letter-spacing:.04em}" + ...
      ".ok{color:#1b7f3b;font-weight:600}.no{color:#b3261e;font-weight:600}" + ...
      ".meta{color:#5b6673;font-size:13px}";

h = "<!doctype html><meta charset='utf-8'><title>IPCV_Lab 環境檢查報告</title>" + ...
    "<style>" + css + "</style><h1>IPCV_Lab 課程環境檢查報告</h1>" + ...
    "<p class='meta'>產生時間：" + string(datetime("now","Format","yyyy-MM-dd HH:mm")) + "<br>" + ...
    "MATLAB 版本：" + rel + ternary(relOK, "（符合）", "（不符）") + "<br>" + ...
    "GPU：" + gpuInfo + "</p>" + ...
    "<table><tr><th>狀態</th><th>種類</th><th>名稱</th><th>層級</th><th>相關章節</th></tr>";

for k = 1:height(report)
    if report.Installed(k)
        cell0 = "<td class='ok'>已安裝</td>";
    else
        cell0 = "<td class='no'>缺少</td>";
    end
    h = h + "<tr>" + cell0 + ...
        "<td>" + report.Kind(k)  + "</td>" + ...
        "<td>" + report.Name(k)  + "</td>" + ...
        "<td>" + report.Level(k) + "</td>" + ...
        "<td>" + report.Chapters(k) + "</td></tr>";
end
h = h + "</table>";

writelines(h, file);
end
