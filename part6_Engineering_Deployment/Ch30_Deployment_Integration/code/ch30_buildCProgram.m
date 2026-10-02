function info = ch30_buildCProgram(options)
%CH30_BUILDCPROGRAM 把 C 函式庫打成交付包，在包裡寫一支純 C 主程式並編成 exe。
%
%   INFO = CH30_BUILDCPROGRAM() 需要先執行 ch30_buildMex(Kind="lib")。步驟：
%     1. 用 packNGo 把產生的程式碼與**它依賴的所有檔案**打成 zip（交付包）
%     2. 解壓到一個**新資料夾**——模擬「對方拿到的東西」
%     3. 在那個資料夾裡寫 grain_main.c，只用包裡的檔案編譯
%   回傳 struct：
%     ExeFile / PackFolder / ZipKB
%     NumFiles          交付包的檔案數
%     NumDLL / DLLs     交付包裡的 .dll（產生的程式碼執行時需要）
%     HasTmwtypes       交付包是否包含 tmwtypes.h
%     Success / Cached / Seconds / Message
%
%   產生的程式用法：
%       grain_c.exe 影像.raw [門檻]
%   從檔案讀 **65536 個位元組**（256×256 uint8），呼叫 ch30_countGrainsCG
%  （門檻省略時用 -1，也就是自動門檻），印出
%       bytes_in_file=… count=… threshold=… first_area=…
%
%   ## 為什麼要 packNGo
%   第一版直接在 codegen 的輸出資料夾編譯，失敗在
%   「rtwtypes.h: 'tmwtypes.h': No such file or directory」——
%   **產生的程式碼依賴 MATLAB 安裝目錄裡的標頭檔**。對方的電腦沒有 MATLAB，
%   只看 codegen 的資料夾會漏掉這些檔。packNGo 依建置資訊把它們全部收進來。
%
%   ## 交付包裡有 DLL
%   以「MATLAB 主機」為目標產生程式碼時，`imopen` 等函式會呼叫
%   **MathWorks 預先編譯、針對主機最佳化的共用函式庫**（libmwmorphop_*、IPP、TBB…）。
%   所以這支「不需要 MATLAB 的 C 程式」**仍然需要這些 DLL 放在旁邊**，
%   而且**只能在同一種平台（Windows x64）上執行**。要給 ARM 用，
%   要把硬體目標設成 ARM，才會產生可攜的純 C（見主教材 §4）。
%
%   ## 這支 C 主程式刻意「像一般 C 呼叫端」
%   - 它**不知道**影像要以行為主排列——直接把檔案內容當成 image[65536]
%   - 它**只讀前 65536 個位元組**，檔案比較大也不報錯，只印出檔案大小
%   這兩點是主教材 §4 說的介面契約：**函式本身檢查不了，只有呼叫端能檢查。**
%
%   `first_area` 是「第一個連通區域」的面積。連通區域依記憶體順序編號，
%   所以影像轉置時顆數不變、`first_area` 會變——用來證明函式看到了不同的影像。
%
%   編譯用 codegen 產生的 `setup_msvc.bat`（本機 MSVC 2019），**只適用 Windows + MSVC**。
%
%   名稱-值引數：
%     Force  強制重建，預設 false
%
%   另見 CH30_BUILDMEX, PACKNGO, CODEGEN.

arguments
    options.Force (1,1) logical = false
end

libDir = fullfile(tempdir, "ch30_build", "ch30_lib");
packDir = fullfile(tempdir, "ch30_build", "ch30_pack");
zipFile = fullfile(tempdir, "ch30_build", "ch30_pack.zip");
exeFile = fullfile(packDir, "grain_c.exe");
info = struct(ExeFile=exeFile, PackFolder=packDir, ZipKB=NaN, NumFiles=0, ...
    NumDLL=0, DLLs=strings(0,1), HasTmwtypes=false, ...
    Success=false, Cached=false, Seconds=0, Message="");

buildInfoFile = fullfile(libDir, "buildInfo.mat");
if ~isfile(buildInfoFile) || ~isfile(fullfile(libDir, "setup_msvc.bat"))
    info.Message = "找不到 C 函式庫，請先執行 ch30_buildMex(Kind=""lib"")。";
    return
end

mainFile = fullfile(packDir, "grain_main.c");
sameMain = isfile(mainFile) && isequal(strtrim(erase(string(fileread(mainFile)), char(13))), ...
    strtrim(strjoin(mainSource(), newline)));
if ~options.Force && sameMain && isfile(exeFile) && isfile(zipFile) && ...
        dir(exeFile).datenum >= dir(buildInfoFile).datenum
    info.Cached = true;
else
    t0 = tic;
    b = load(buildInfoFile);
    if isfile(zipFile), delete(zipFile); end
    packNGo(b.buildInfo, fileName=zipFile, packType="flat");
    if isfolder(packDir), rmdir(packDir, "s"); end
    unzip(zipFile, packDir);
    % setup_msvc.bat 是本機編譯器的設定，不屬於交付包；只拿來編譯
    copyfile(fullfile(libDir, "setup_msvc.bat"), packDir);
    writelines(mainSource(), fullfile(packDir, "grain_main.c"));

    % 用 .\ 明確指定當前資料夾：NoDefaultCurrentDirectoryInExePath 設定時，
    % cmd 不會在當前資料夾找 setup_msvc.bat（見 ch30_buildMex）
    cmd = sprintf(['cd /d "%s" && call .\\setup_msvc.bat >nul && ' ...
        'cl /nologo /O2 /utf-8 grain_main.c ch30_countGrainsCG.lib libmw*.lib /Fe:grain_c.exe'], packDir);
    [status, out] = system(cmd);
    info.Seconds = toc(t0);
    if status ~= 0 || ~isfile(exeFile)
        info.Message = string(strtrim(out));
        return
    end
end

files = dir(packDir);
files = files(~[files.isdir]);
names = string({files.name});
info.ZipKB = dir(zipFile).bytes / 1024;
info.NumFiles = numel(names) - 3;          % 扣掉 grain_main.c、setup_msvc.bat、grain_c.exe
info.DLLs = names(endsWith(names, ".dll")).';
info.NumDLL = numel(info.DLLs);
info.HasTmwtypes = any(names == "tmwtypes.h");
info.Success = true;
end

function src = mainSource()
src = [
    "/* grain_main.c：由 ch30_buildCProgram 產生。一個不需要 MATLAB 的 C 呼叫端。 */"
    "#include <stdio.h>"
    "#include <stdlib.h>"
    "#include ""ch30_countGrainsCG.h"""
    "#include ""ch30_countGrainsCG_emxAPI.h"""
    "#include ""ch30_countGrainsCG_initialize.h"""
    "#include ""ch30_countGrainsCG_terminate.h"""
    ""
    "int main(int argc, char **argv)"
    "{"
    "    static unsigned char image[65536];"
    "    double count = 0.0, threshold = 0.0;"
    "    double thresholdIn = -1.0;"
    "    emxArray_real_T *areas;"
    "    long fileBytes;"
    "    size_t n;"
    "    FILE *f;"
    "    if (argc < 2) { fprintf(stderr, ""usage: grain_c raw_file [threshold]\n""); return 2; }"
    "    if (argc >= 3) { thresholdIn = atof(argv[2]); }   /* 不檢查範圍：像一般呼叫端 */"
    "    f = fopen(argv[1], ""rb"");"
    "    if (f == NULL) { fprintf(stderr, ""cannot open %s\n"", argv[1]); return 1; }"
    "    fseek(f, 0, SEEK_END); fileBytes = ftell(f); fseek(f, 0, SEEK_SET);"
    "    n = fread(image, 1, sizeof(image), f);   /* 只讀前 65536 個位元組 */"
    "    fclose(f);"
    "    if (n < sizeof(image)) { fprintf(stderr, ""file too small: %ld bytes\n"", fileBytes); return 1; }"
    "    ch30_countGrainsCG_initialize();"
    "    emxInitArray_real_T(&areas, 2);"
    "    ch30_countGrainsCG(image, 15.0, 50.0, thresholdIn, &count, areas, &threshold);"
    "    printf(""bytes_in_file=%ld count=%.0f threshold=%.6f first_area=%.0f\n"","
    "           fileBytes, count, threshold, areas->size[1] > 0 ? areas->data[0] : -1.0);"
    "    emxDestroyArray_real_T(areas);"
    "    ch30_countGrainsCG_terminate();"
    "    return 0;"
    "}"
    ];
end
