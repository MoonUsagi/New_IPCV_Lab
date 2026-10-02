% 完整流程：設定路徑 -> 驗證所有教材 -> 建置手冊。
% 供 MCP／CI 以檔案方式執行，避免互動式命令逾時。
userDir = pwd;
root = fileparts(fileparts(mfilename("fullpath")));
cd(root);
ipcvSetup(Quiet=true);

fprintf("========== 步驟 1／2：驗證教材 ==========\n");
v = verifyChapters;

if any(v.Status == "失敗")
    fprintf("有教材無法執行，中止建置。\n");
    cd(userDir);
    return
end

fprintf("========== 步驟 2／2：建置手冊 ==========\n");
b = buildHandbook;

fprintf("\n========== 產出清單 ==========\n");
d = dir(fullfile(root,"build","output","*.*"));
d = d(~[d.isdir]);
for k = 1:numel(d)
    fprintf("  %-22s %7.0f KB\n", d(k).name, d(k).bytes/1024);
end

cd(userDir);
