function [detector, info] = ch22_trainAnomaly(data, method, options)
%CH22_TRAINANOMALY 訓練異常偵測器。四種方法的 API 差很多，這裡統一介面。
%
%   [DETECTOR, INFO] = CH22_TRAINANOMALY(DATA, METHOD) 用 DATA.GoodTrain
%   訓練一個異常偵測器。METHOD 可以是：
%
%     "patchcore"   - **預設，唯一在本機驗證過的**
%     "fastflow"    - 需要 trainingOptions（第三個位置引數）
%     "fcdd"        - R2026b 起可以只給良品；R2026a 以前需要瑕疵樣本
%     "efficientad" - **R2026b 已移除**，會丟出錯誤並指向替代方案
%
%   名稱-值引數：
%     Backbone      - PatchCore 的骨幹（預設 "resnet18"）
%     DoTrain       - 預設 true（PatchCore 很快）；設 false 只組設定
%     MaxEpochs     - 需要梯度訓練的方法用（預設 5）
%     MiniBatchSize - 預設 4
%
%   ============================================================
%   **四種方法的 API 完全不一致，這是本章最實際的一個坑。**
%
%   | 方法 | 建構 | 訓練 |
%   |---|---|---|
%   | PatchCore | `patchCoreAnomalyDetector(Backbone=...)` | `train...(normalData, detector)` |
%   | FastFlow | `fastFlowAnomalyDetector(Name=Value)` | `train...(normalData, detector, **options**)` |
%   | FCDD | `fcddAnomalyDetector(**network**)` | `train...(normalData, **anomalyData**, detector, options)` |
%
%   三個要注意的地方：
%
%   **① `Backbone` 是名稱-值引數，不是位置引數。**
%   寫 `patchCoreAnomalyDetector("resnet18")` 會報
%   「Invalid argument at position 1」——**那個訊息看起來像缺套件，
%   其實是引數形式錯**。
%
%   **② `fastFlowAnomalyDetector` 的 `Backbone` 要 `dlnetwork`，
%   不吃字串名稱。**
%
%   **③ FCDD 在 R2026a 需要瑕疵樣本**（`trainFCDDAnomalyDetector(normalData,
%   anomalyData, detector, options)`），那時**它不是單類別方法**。
%   **R2026b 起 anomalyData 可以省略**，這裡就走只給良品的路線。
%   實測（R2026b、預設 5 epoch、T550 GPU）：25.5 秒，良品 0.004 ± 0.001、瑕疵 0.881 ± 0.153。
%   ============================================================
%
%   **PatchCore 為什麼適合當起點**
%
%   - **不需要梯度訓練**：它只是把良品的特徵存成一個 coreset，
%     所以沒有學習率、不會發散（和第 18 章的策略一同一個道理）
%   - 24 張 64×64 的合成良品訓練約 **6 秒**
%   - 在本章的合成資料上，良品分數 **1.17 ± 0.03**、
%     瑕疵 **22.93 ± 0.96**——**完全分開**（間隔 609 個良品標準差）
%
%   > **但那個分離度是合成資料給的，不是 PatchCore 的實力證明。**
%   > 真實瑕疵（刮痕、色差、缺件）難得多。
%   > 換上你自己的資料之後，第一件事就是重看這兩個分布有沒有重疊。
%
%   另見 CH22_LOADDATASET, CH22_THRESHOLDANALYSIS.

arguments
    data struct
    method (1,1) string {mustBeMember(method, ...
        ["patchcore" "fastflow" "fcdd" "efficientad"])} = "patchcore"
    options.Backbone      (1,1) string = "resnet18"
    options.DoTrain       (1,1) logical = true
    options.MaxEpochs     (1,1) double {mustBePositive, mustBeInteger} = 5
    options.MiniBatchSize (1,1) double {mustBePositive, mustBeInteger} = 4
end

if size(data.GoodTrain, 4) == 0
    error("ch22_trainAnomaly:noTrainingData", ...
        "GoodTrain 是空的。異常偵測需要良品樣本才能學「正常」。");
end

dsGood = arrayDatastore(data.GoodTrain, IterationDimension=4, OutputType="cell");

info = struct("Method", method, "Trained", false, "SecTrain", NaN, ...
    "NumGoodTrain", size(data.GoodTrain,4), "Note", "");

switch method
    case "patchcore"
        % **Backbone 是名稱-值引數**
        detector = patchCoreAnomalyDetector(Backbone=options.Backbone);
        if ~options.DoTrain
            info.Note = "未訓練（DoTrain=false）";
            return
        end
        t = tic;
        detector = trainPatchCoreAnomalyDetector(dsGood, detector);
        info.SecTrain = toc(t);
        info.Trained = true;

    case "fastflow"
        % FastFlow 要梯度訓練，而且 trainingOptions 是**第三個位置引數**
        detector = fastFlowAnomalyDetector();
        opts = trainingOptions("adam", ...
            MaxEpochs=options.MaxEpochs, ...
            MiniBatchSize=options.MiniBatchSize, ...
            Verbose=false, Plots="none");
        info.TrainingOptions = opts;
        if ~options.DoTrain
            info.Note = "未訓練（FastFlow 需要梯度訓練，本機記憶體有限）";
            return
        end
        t = tic;
        detector = trainFastFlowAnomalyDetector(dsGood, detector, opts);
        info.SecTrain = toc(t);
        info.Trained = true;

    case "fcdd"
        % R2026a 以前：trainFCDDAnomalyDetector 一定要給瑕疵樣本，不是單類別方法。
        % R2026b 起：anomalyData 可以省略，只給良品就能訓練。
        if isMATLABReleaseOlderThan("R2026b")
            error("ch22_trainAnomaly:fcddNeedsAnomalies", ...
                "R2026a 以前的 FCDD 需要瑕疵樣本（trainFCDDAnomalyDetector 的第二個引數），" + ...
                "**它不是單類別方法**，和本章「只有良品」的前提不同。R2026b 起可以只給良品。");
        end
        % FCDD 的建構要一個 dlnetwork 骨幹，不吃字串名稱
        detector = fcddAnomalyDetector(pretrainedEncoderNetwork(options.Backbone, 3));
        opts = trainingOptions("adam", ...
            MaxEpochs=options.MaxEpochs, ...
            MiniBatchSize=options.MiniBatchSize, ...
            Verbose=false, Plots="none");
        info.TrainingOptions = opts;
        if ~options.DoTrain
            info.Note = "未訓練（DoTrain=false）";
            return
        end
        t = tic;
        detector = trainFCDDAnomalyDetector(dsGood, detector, opts);   % 不給瑕疵樣本
        info.SecTrain = toc(t);
        info.Trained = true;

    case "efficientad"
        if isMATLABReleaseOlderThan("R2026b")
            error("ch22_trainAnomaly:notVerified", ...
                "EfficientAD 在本機尚未驗證。" + ...
                "**請見 README 的待驗證清單。**");
        end
        error("ch22_trainAnomaly:removed", ...
            "R2026b 已移除 efficientADAnomalyDetector。官方建議改用 " + ...
            "studentTeacherAnomalyDetector（需要 Visual Inspection Toolbox Model for " + ...
            "Student-Teacher Anomaly Detection 支援包）。");
end

if info.Trained
    fprintf("%s 訓練完成：%d 張良品、%.1f 秒\n", ...
        method, info.NumGoodTrain, info.SecTrain);
end
end
