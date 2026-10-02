function ch30_grainCLI(imageFile)
%CH30_GRAINCLI 命令列版的顆粒計數，給 MATLAB Compiler 打包用。
%
%   打包後在命令列執行：ch30_grainCLI.exe rice.png
%   輸出一行「檔名: 顆數」。
%
%   ## 為什麼另外寫一支，不直接打包 ch29_countGrains
%   打包成 exe 之後，**輸入全部是字串**（命令列引數），輸出只有標準輸出與結束碼。
%   第 29 章那種「回傳一個 struct」的介面在這裡沒有意義。
%   這支函式就是 exe 的「介面層」：解析命令列、呼叫演算法、印結果、
%   失敗時用非零結束碼讓呼叫端（排程器、PLC 閘道程式）知道。
%
%   另見 CH30_BUILDSTANDALONE, ISDEPLOYED.

if nargin < 1
    % 不給預設檔名：第一版寫了內建影像的檔名當預設值，打包時相依性分析
    % 把那個字串當成要包進去的檔案，產生「Excluded … Not supported in the
    % MATLAB Runtime environment」的警告
    fprintf(2, "usage: ch30_grainCLI image_file\n");
    if isdeployed, exit(2); else, return; end
end
try
    I = imread(imageFile);
    if size(I,3) == 3
        I = rgb2gray(I);
    end
    [count, ~, ~] = ch30_countGrainsCG(im2uint8(I), 15, 50, -1);
    fprintf("%s: %d\n", imageFile, count);
catch ME
    fprintf(2, "ERROR %s: %s\n", imageFile, ME.message);
    if isdeployed
        exit(1);          % 讓呼叫端從結束碼知道失敗了
    else
        rethrow(ME);
    end
end
end
