% 供 MCP／CI 以檔案方式執行的驗證入口。
% 結果同時寫到 build/last_verify.txt，即使呼叫端逾時也能事後查看。
userDir = pwd;
root = fileparts(fileparts(mfilename("fullpath")));
cd(root);
ipcvSetup(Quiet=true);

r = verifyChapters;

logFile = fullfile(root, "build", "last_verify.txt");
fid = fopen(logFile, "w", "n", "UTF-8");
fprintf(fid, "驗證時間：%s\n", string(datetime("now", Format="yyyy-MM-dd HH:mm:ss")));
fprintf(fid, "%-8s %-10s %-6s %8s\n", "章節", "類型", "狀態", "秒數");
for k = 1:height(r)
    fprintf(fid, "%-8s %-10s %-6s %8.1f\n", r.Chapter(k), r.Kind(k), r.Status(k), r.Seconds(k));
end
failed = r(r.Status == "失敗", :);
fprintf(fid, "\n結果：%d 成功、%d 失敗，總耗時 %.0f 秒\n", ...
    nnz(r.Status == "成功"), height(failed), sum(r.Seconds));
for k = 1:height(failed)
    fprintf(fid, "\n第 %s 章 %s：\n  %s\n", failed.Chapter(k), failed.Kind(k), failed.Message(k));
end
fclose(fid);

fprintf("\n結果已寫入：%s\n", logFile);
cd(userDir);
