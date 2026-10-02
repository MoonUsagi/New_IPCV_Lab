%[text] # 第 00 章　練習解答
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
%%
%[text] # 解答 1：查詢單一章節的需求
req22 = courseRequirements("22");

fprintf("第 22 章需求，共 %d 項\n\n", height(req22));

required = req22(req22.Level == "required", :);
optional = req22(req22.Level == "optional", :);

fprintf("必要（%d 項）：\n", height(required));
fprintf("  [%s] %s\n", [required.Kind, required.Name]');

fprintf("\n選用（%d 項）：\n", height(optional));
if isempty(optional)
    fprintf("  無\n");
else
    fprintf("  [%s] %s\n", [optional.Kind, optional.Name]');
end
%[text] **注意**：回傳結果會包含章號為 `"*"` 的全課程共同需求
%[text] （Image Processing Toolbox 與 Computer Vision Toolbox）。
%[text] 這是刻意的設計——任何一章都需要這兩個工具箱，與其在 80 幾列裡重複，
%[text] 不如用 `"*"` 標記一次。
disp(req22)
%%
%[text] # 解答 2：判斷某條路徑是否可行
pathB  = ["00" "02" "09" "17" "18" "19" "20" "21" "22"];
report = checkEnvironment(Chapters=pathB, Verbose=false);

missingRequired = report(~report.Installed & report.Level == "required", :);
canRun = isempty(missingRequired);

if canRun
    fprintf("可以完整上完路徑 B。\n");
else
    fprintf("目前無法完整上完路徑 B，缺少 %d 項必要項目：\n\n", height(missingRequired));
    for k = 1:height(missingRequired)
        fprintf("  %s\n", missingRequired.Name(k));
        fprintf("    影響章節：第 %s 章\n", missingRequired.Chapters(k));
    end

    affected = unique(split(strjoin(missingRequired.Chapters, ", "), ", "));
    fprintf("\n受影響的章節共 %d 章：%s\n", numel(affected), strjoin(sort(affected), ", "));
    fprintf("其餘章節仍可正常進行。\n");
end
%[text] **為什麼要用回傳值而不是看螢幕輸出**：實務上你會想把這段包進開課前的
%[text] 自動檢查流程——例如讓每位學員執行後自動回傳結果，或在 CI 裡驗證
%[text] 教材環境。只有可程式化的回傳值才辦得到。
%[text] 這也是本課程反覆強調的原則：**函式回傳資料，由呼叫端決定怎麼呈現**。
%[text] `ch01_imageSummary` 回傳 table 而不是 `fprintf`，是同一個道理。
%%
%[text] # 解答 3：掃描舊程式碼
testDir = fullfile(tempdir, "ch00_legacy_test");
if ~isfolder(testDir), mkdir(testDir); end

sampleCode = [
    "% 這是一支刻意使用舊 API 的示範腳本"
    "lgraph = unetLayers([256 256 3], 2);              % 已移除"
    "net    = trainNetwork(ds, lgraph, opts);          % 建議更新"
    "tform  = estimateGeometricTransform(p1, p2, ""similarity"");  % 建議更新"
    "blender = vision.AlphaBlender();                  % R2026b 已移除"
    "out    = insertText(I, [10 10], ""label"");       % 行為變更"
    "% 註解裡提到 fcnLayers 不應該被抓到"
    ];
writelines(sampleCode, fullfile(testDir, "old_project.m"));

hits = findLegacyAPI(testDir);
%[text] **怎麼解讀這四種等級**：
%[text:table]
%[text] | 等級 | 意義 | 該怎麼做 |
%[text] | --- | --- | --- |
%[text] | 已移除 | R2026a 呼叫會直接報錯 | **必須改**，否則程式跑不動 |
%[text] | 即將移除 | 目前會發出警告 | 排進計畫改掉，不急於今天 |
%[text] | 行為變更 | 能跑，但結果與舊版不同 | 檢查下游是否受影響；教材要重拍截圖 |
%[text] | 建議更新 | 舊 API 仍可用 | 新寫的程式用新 API，舊的可暫留 |
%[text:table]
%[text] 注意最後一行的 `fcnLayers` 出現在註解裡，**沒有**被列入結果——
%[text] `findLegacyAPI` 會先移除行尾註解再比對。
%[text] 但它仍然只是文字比對，無法分辨同名的區域變數，結果要人工複核。
fprintf("\n共發現 %d 處，其中「已移除」等級 %d 處\n", ...
    height(hits), nnz(hits.Severity == "已移除"));
%%
%[text] # 加分題：擴充相容性規則
%[text] 這題沒有標準答案，但示範一下加規則的做法。
%[text] 打開 `shared/functions/findLegacyAPI.m`，在 `legacyRules` 的 `raw`
%[text] 陣列裡加一列即可，格式是「函式名, 嚴重度, 取代方案, 備註」：
%[text] ```matlabCodeExample
%[text] "bwlabeln"  , "建議更新", "bwconncomp"  , "bwconncomp 記憶體效率較佳"
%[text] ```
%[text] 加完後重新執行練習 3 驗證新規則生效。
%[text] **維護建議**：每次 MATLAB 改版（一年兩次）就回頭看一次 Release Notes
%[text] 的「Functionality being removed or changed」段落，把新項目補進規則表。
%[text] 這件事花不到半小時，卻能讓整套教材不會在改版後悄悄壞掉。

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
