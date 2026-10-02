function info = ch26_nerfSketch(options)
%CH26_NERFSKETCH NeRF（`nerfacto`）的程式碼骨架。**預設不執行訓練。**
%
%   ⚠ **本函式的訓練路徑從未在開發機器上執行過**
%   （NVIDIA T550，4.29 GB 顯示記憶體），而且**沒有適合的多視角資料集**。
%   API 形狀對照過 R2026a 文件，但**收斂行為與數字未經驗證**。
%   見 `docs/PENDING_VERIFICATION.md` 的第 26 章清單。
%
%   INFO = CH26_NERFSKETCH() 印出完整的程式碼並回傳 struct，
%   含 Available（函式在不在）與 Trained（永遠是 false，除非 DoTrain）。
%
%   ## NeRF 的輸入需求常被低估
%   它需要**每一張影像的精確相機姿態**。那通常來自 SfM
%   （`imageviewset` + `bundleAdjustment`）或 COLMAP。
%   **NeRF 不是取代 SfM，是接在 SfM 後面**——
%   姿態不準，輻射場就糊掉，而且**你無法從 NeRF 的輸出看出是姿態的錯**。
%
%   ## 和點雲重建的差別
%   | | 點雲（§2–§6） | NeRF |
%   |---|---|---|
%   | 表示 | 離散的點 | **連續的函數** |
%   | 空洞 | 有（本章量到 49% 沒有深度） | **沒有** |
%   | 新視角 | 只能看已有的點 | **可以合成** |
%   | 取得 | 幾秒 | **數十分鐘到數小時的訓練** |
%   | 幾何是否可直接量測 | **是**（點就是座標） | **否**（要先抽出等值面） |
%
%   > **最後一列常被忽略。** 要做尺寸量測時，NeRF 得先用
%   > marching cubes 之類的方法抽出表面，那一步會引入它自己的誤差。
%   > **如果你的目的是量測而不是視覺化，點雲通常更直接。**
%
%   名稱-值引數：
%     DoTrain  是否真的訓練，預設 false
%     Quiet    是否隱藏程式碼輸出，預設 false
%
%   另見 NERFACTO, TRAINNERFACTO, BUNDLEADJUSTMENT, IMAGEVIEWSET.

arguments
    options.DoTrain (1,1) logical = false
    options.Quiet   (1,1) logical = false
end

available = exist("nerfacto") ~= 0 && exist("trainNerfacto") ~= 0; %#ok<EXIST>

if ~options.Quiet
    % **用字串陣列 + newline，不要把多行程式碼塞進含轉義序列的格式字串。**
    % 第 24 章的 ch24_reidSketch 在這裡踩過兩個疊在一起的坑。
    codeLines = [
        "% ---- NeRF 重建（本機未執行）--------------------------------"
        "% 步驟 0：取得每張影像的相機姿態。這一步通常才是難的。"
        "%   vSet = imageviewset;  ... 加入影像與對應點 ..."
        "%   [~, camPoses] = bundleAdjustment(xyzPoints, pointTracks, ..."
        "%       camPoses, intrinsics);"
        ""
        "% 步驟 1：建立 nerfacto 模型"
        "%   nerfacto 需要場景的包圍盒（AABB）與相機內參。"
        "net = nerfacto(sceneAABB, intrinsics, camPoses);"
        ""
        "% 步驟 2：訓練"
        "opts = trainingOptions(""adam"", ..."
        "    MaxEpochs        = <EPOCHS>, ..."
        "    MiniBatchSize    = <BATCH>, ..."
        "    InitialLearnRate = <LR>, ..."
        "    Plots            = ""training-progress"");"
        "net = trainNerfacto(images, camPoses, net, opts);"
        ""
        "% 步驟 3：合成一個沒拍過的視角"
        "newPose = rigidtform3d(R, t);"
        "I = render(net, newPose, intrinsics);"
        "% ------------------------------------------------------------"
        ];
    codeLines = replace(codeLines, "<EPOCHS>", "30");
    codeLines = replace(codeLines, "<BATCH>",  "4096");
    codeLines = replace(codeLines, "<LR>",     "1e-2");
    fprintf("%s" + newline, codeLines);

    fprintf("\n⚠ DoTrain=false（預設）。上面是程式碼，沒有執行。\n");
    fprintf("  nerfacto 可用：%s\n", string(available));
    fprintf("  **缺的不是函式，是資料**：需要數十張同一場景的影像，\n");
    fprintf("  加上每一張的精確相機姿態。沒有姿態就沒有 NeRF。\n");
end

info = struct( ...
    Available = available, ...
    Trained   = false, ...
    Reason    = "DoTrain=false；本機無 GPU 記憶體與多視角資料集");

if options.DoTrain
    error("ipcv:ch26:notImplemented", ...
        ["NeRF 訓練需要多視角影像與相機姿態，本函式不提供資料。" newline ...
         "請依上面的程式碼，用你自己的資料與 SfM 結果執行。"]);
end

if nargout == 0
    clear info
end
end
