classdef tCountGrains < matlab.unittest.TestCase
%TCOUNTGRAINS ch29_countGrains 的單元測試與回歸測試。
%
%   執行：runtests("tests")（在 Ch29_Script_to_App 資料夾下）
%
%   ## 三種測試，各自防什麼
%   | 類型 | 防什麼 | 例子 |
%   |---|---|---|
%   | **回歸測試** | 改了程式，結果悄悄變了 | rice.png 必須數到固定的顆數 |
%   | **介面測試** | 壞的輸入被安靜接受 | 傳 `true` 當參數必須報錯 |
%   | **性質測試** | 結果違反常識 | MinArea 越大，顆數不能變多 |
%
%   ## 回歸測試要比較什麼
%   **不要比較整張遮罩是否逐像素相同。** 主教材 §6 量到：
%   把輸入從 double 改成 single，遮罩就有像素不同，但顆數完全一樣。
%   逐像素比對會讓無害的改動也失敗，久了大家就開始忽略測試失敗——
%   **那比沒有測試更糟**。比較的是你真正在意的量（顆數、平均面積），
%   並且給一個有根據的容許誤差。

    properties (Constant)
        % 這些值是在 R2026a 上**跑出來**的，然後目視檢查過疊圖：
        % 沒有明顯的漏抓，但有 2 個區塊面積超過中位數的 2 倍（很可能是
        % 兩顆黏在一起），而影像上緣幾顆被裁切的米粒沒有被算進去。
        %
        % **所以這是「這個演算法現在的行為」，不是「真實的米粒數」。**
        % 回歸測試保護的是「沒有人不小心改變行為」；
        % 它不保證行為是對的——那是另一種測試（要有標註的真值）。
        %
        % 我第一版在這裡寫了 83 與 201.1，是**還沒跑就先填的數字**，
        % 實際是 93 與 189.2。測試第一次執行就失敗了——這正是它的用途。
        % 改了演算法之後如果這裡要改，commit 訊息必須寫理由。
        RiceCount    = 93
        RiceMeanArea = 189.2151
    end

    methods (Test)
        % ---------------- 回歸測試 ----------------
        function riceCountIsStable(tc)
            r = ch29_countGrains(imread("rice.png"));
            tc.verifyEqual(r.Count, tc.RiceCount, ...
                "rice.png 的顆數改變了——如果是刻意的，請更新基準值並寫明理由。");
        end

        function riceMeanAreaWithinTolerance(tc)
            r = ch29_countGrains(imread("rice.png"));
            % 容許 1%：面積是像素數的平均，演算法的小改動（例如邊界補值）
            % 會讓每顆差一兩個像素，那不是回歸。
            tc.verifyEqual(mean(r.Areas), tc.RiceMeanArea, RelTol=0.01);
        end

        function paramsAreRecorded(tc)
            r = ch29_countGrains(imread("rice.png"), MinArea=80);
            tc.verifyEqual(r.Params.MinArea, 80);
        end

        % ---------------- 介面測試 ----------------
        function logicalParameterIsRejected(tc)
            % (1,1) double 會把 true 安靜地轉成 1——這裡要確定它被擋下來
            tc.verifyError(@() ch29_countGrains(imread("rice.png"), MinArea=true), ...
                ?MException);
        end

        function stringParameterIsRejected(tc)
            tc.verifyError(@() ch29_countGrains(imread("rice.png"), MinArea="50"), ...
                ?MException);
        end

        function thresholdOutOfRange(tc)
            tc.verifyError(@() ch29_countGrains(imread("rice.png"), Threshold=1.5), ...
                "ipcv:ch29:thresholdRange");
        end

        function binaryInputIsRejected(tc)
            tc.verifyError(@() ch29_countGrains(imread("rice.png") > 100), ...
                "ipcv:ch29:alreadyBinary");
        end

        function rgbInputIsAccepted(tc)
            gray = imread("rice.png");
            rgb  = repmat(gray, 1, 1, 3);
            tc.verifyEqual(ch29_countGrains(rgb).Count, ch29_countGrains(gray).Count);
        end

        % ---------------- 性質測試 ----------------
        function largerMinAreaNeverIncreasesCount(tc)
            img = imread("rice.png");
            counts = arrayfun(@(a) ch29_countGrains(img, MinArea=a).Count, [0 50 100 200]);
            tc.verifyTrue(all(diff(counts) <= 0), ...
                "MinArea 變大，顆數卻變多了：" + mat2str(counts));
        end

        function allAreasAboveMinArea(tc)
            r = ch29_countGrains(imread("rice.png"), MinArea=120);
            tc.verifyGreaterThanOrEqual(min(r.Areas), 120);
        end
    end
end
