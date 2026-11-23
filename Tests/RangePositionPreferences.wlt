(* Tests of Kernel/RangePositionPreferences.wl: the positions of the Open and the Close in the range, the selection, the histogram, the spikes, the random-walk reference and the picture.
   Run: TestReport["<project>/Tests/RangePositionPreferences.wlt"]. The file loads the study itself. These tests use made-up candlesticks, so they need no data. *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$TestFileName]], "Kernel", "RangePositionPreferences.wl"}]];

(* five candlesticks: two good ones, a flat one (High = Low), one with the Open outside the range, one without a Close *)
rows = {
  <|"Date" -> DateObject[{2000, 12, 29}], "Open" -> 10, "High" -> 20, "Low" -> 0, "Close" -> 5|>,    (* open 0.5, close 0.25; range 20 on a mid price of 10: relative range 2 *)
  <|"Date" -> DateObject[{2001, 1, 5}], "Open" -> 8, "High" -> 8, "Low" -> 8, "Close" -> 8|>,       (* flat *)
  <|"Date" -> DateObject[{2001, 1, 12}], "Open" -> 25, "High" -> 20, "Low" -> 0, "Close" -> 5|>,    (* the Open is above the High: invalid *)
  <|"Date" -> DateObject[{2001, 1, 19}], "Open" -> 5, "High" -> 20, "Low" -> 0|>,                    (* no Close: invalid *)
  <|"Date" -> DateObject[{2001, 1, 26}], "Open" -> 0, "High" -> 20, "Low" -> 0, "Close" -> 20|>};   (* open 0, close 1 *)

kept = StockAnalyzer`Studies`RangePositionPreferences`Private`positionsOfRows[rows];

VerificationTest[
  {kept["Rows"], kept["Flat"], kept["Invalid"], kept["Kept"]}, {5, 1, 2, 2}, TestID -> "rows, flat, invalid and kept candlesticks"]

VerificationTest[
  {kept["Open"], kept["Close"]}, {{0.5, 0.}, {0.25, 1.}}, TestID -> "positions of the Open and of the Close"]

VerificationTest[
  {kept["Year"], kept["RelRange"]}, {{2000, 2001}, {2., 2.}}, TestID -> "the year and the relative range of the kept candlesticks"]

VerificationTest[
  StockAnalyzer`Studies`RangePositionPreferences`collectRangePositions["hourly"], $Failed, {StockAnalyzer`Studies`RangePositionPreferences`collectRangePositions::period}, TestID -> "a bad period"]

VerificationTest[
  StockAnalyzer`Studies`RangePositionPreferences`collectRangePositions["weekly", "Tickers" -> {"NOSUCHTICKERXYZ"}, "Loader" -> Function[{t, p}, {}]], $Failed, {StockAnalyzer`Studies`RangePositionPreferences`collectRangePositions::none}, TestID -> "no data for the tickers"]

(* a hand-made collection: Open 0.1 (2000), 0.3 and 0.3 (2001), 0.6 and 1.0 (2002) *)
collected = <|"Period" -> "weekly", "Open" -> {0.1, 0.3, 0.3, 0.6, 1.}, "Close" -> {0., 0.5, 0.5, 0.5, 0.9}, "RelRange" -> {0.01, 0.02, 0.05, 0.05, 0.05},
  "Year" -> {2000, 2001, 2001, 2002, 2002}, "TickerIndex" -> {1, 1, 2, 2, 2}|>;

small = StockAnalyzer`Studies`RangePositionPreferences`rangePositionPreferences[collected, "Bins" -> 4, "FromYear" -> 2001, "ToYear" -> Automatic, "MinRelativeRange" -> 0, "SpikeThreshold" -> 5, "Null" -> False];

VerificationTest[
  small["Candlesticks"], 4, TestID -> "FromYear 2001 keeps the 4 candlesticks of 2001 and later"]

VerificationTest[
  {small["Open"]["Counts"], small["Open"]["AtLow"], small["Open"]["AtHigh"]}, {{0, 2, 1, 1}, 0., 0.25}, TestID -> "counts of the Open in 4 bins, and the share at exactly 1 (it is in the last bin)"]

VerificationTest[
  small["Open"]["Density"], {0., 2., 1., 1.}, TestID -> "density: 1 means as many as a flat histogram"]

VerificationTest[
  small["Tickers"], 2, TestID -> "the number of tickers of the selected candlesticks"]

VerificationTest[
  StockAnalyzer`Studies`RangePositionPreferences`rangePositionPreferences[collected, "Bins" -> 4, "FromYear" -> 2001, "ToYear" -> 2001, "Null" -> False]["Candlesticks"], 2, TestID -> "ToYear 2001 keeps the 2 candlesticks of 2001"]

VerificationTest[
  StockAnalyzer`Studies`RangePositionPreferences`rangePositionPreferences[collected, "Bins" -> 4, "FromYear" -> 1990, "MinRelativeRange" -> 0.04, "Null" -> False]["Candlesticks"], 3, TestID -> "MinRelativeRange 0.04 keeps the 3 candlesticks with a wide range"]

VerificationTest[
  Head[small["Null"]], Missing, TestID -> "Null -> False gives no random walk"]

VerificationTest[
  StockAnalyzer`Studies`RangePositionPreferences`rangePositionPreferences[collected, "Bins" -> 4, "FromYear" -> 2030], $Failed, {StockAnalyzer`Studies`RangePositionPreferences`rangePositionPreferences::empty}, TestID -> "no candlestick left"]

VerificationTest[
  StockAnalyzer`Studies`RangePositionPreferences`rangePositionPreferences[collected, "Bins" -> 1], $Failed, {StockAnalyzer`Studies`RangePositionPreferences`rangePositionPreferences::option}, TestID -> "a bad number of bins"]

(* a flat histogram (500 positions in each of 100 bins) with 400 more in the bin from 50 % to 51 % (where the position 1/2 is) *)
flat = Flatten[Table[(i - 0.5)/100., {i, 100}, {500}]];
spiked = Join[flat, ConstantArray[0.505, 400]];
(* the Close is as long as the Open: the flat histogram and 400 positions picked at random from it (about 4 more in each bin, no spike) *)
closes = Join[flat, BlockRandom[SeedRandom[1]; RandomSample[flat, 400]]];
spikeCollected = <|"Period" -> "daily", "Open" -> spiked, "Close" -> closes, "RelRange" -> ConstantArray[0.05, Length[spiked]], "Year" -> ConstantArray[2010, Length[spiked]], "TickerIndex" -> ConstantArray[1, Length[spiked]]|>;
spikeResult = StockAnalyzer`Studies`RangePositionPreferences`rangePositionPreferences[spikeCollected, "Bins" -> 100, "FromYear" -> 2001, "SpikeThreshold" -> 5, "Null" -> False];

VerificationTest[
  Normal[spikeResult["Spikes"]][[All, {"Series", "From%", "To%", "Fraction"}]], {<|"Series" -> "Open", "From%" -> 50., "To%" -> 51., "Fraction" -> "1/2"|>}, TestID -> "the spike at 1/2 is found in the Open and only there"]

VerificationTest[
  StockAnalyzer`Studies`RangePositionPreferences`Private`simpleFraction[33/100, 34/100], "1/3", TestID -> "the simple fraction in a bin"]

VerificationTest[
  StockAnalyzer`Studies`RangePositionPreferences`Private`simpleFraction[42/100, 43/100], "", TestID -> "no simple fraction in the bin 42 % to 43 %"]

(* the random walk: the mean position is 1/2 without drift, a histogram adds up to the number of bins *)
walk = StockAnalyzer`Studies`RangePositionPreferences`rangePositionPreferences[collected, "Bins" -> 10, "FromYear" -> 1990, "Null" -> True, "NullSteps" -> 50, "NullPaths" -> 4000, "NullDrift" -> 0, "Seed" -> 1];

VerificationTest[
  {Round[Total[walk["Null"]["Open"]["Density"]], 10^-9], Round[Total[walk["Null"]["Close"]["Density"]], 10^-9]}, {10, 10}, TestID -> "the density of the random walk adds up to the number of bins"]

VerificationTest[
  0.45 < walk["Null"]["Open"]["Mean"] < 0.55 && 0.45 < walk["Null"]["Close"]["Mean"] < 0.55, True, TestID -> "the mean position of a driftless walk is about 1/2"]

VerificationTest[
  walk["Null"]["Open"]["Density"][[1]] > walk["Null"]["Open"]["Density"][[5]], True, TestID -> "a random walk has its Open near the Low more often than in the middle (the U shape)"]

VerificationTest[
  walk["Null"]["Open"]["Counts"] == StockAnalyzer`Studies`RangePositionPreferences`rangePositionPreferences[collected, "Bins" -> 10, "FromYear" -> 1990, "Null" -> True, "NullSteps" -> 50, "NullPaths" -> 4000, "NullDrift" -> 0, "Seed" -> 1]["Null"]["Open"]["Counts"], True, TestID -> "the same seed gives the same walk"]

(* the picture *)
VerificationTest[
  Head[StockAnalyzer`Studies`RangePositionPreferences`showRangePositionPreferences[walk, "Which" -> "Both", "ImageSize" -> 300, "Theme" -> "Light", "ShowNull" -> True, "MarkSpikes" -> True, "YMax" -> Automatic]], Row, TestID -> "the picture is a Row of two pictures"]

VerificationTest[
  Count[StockAnalyzer`Studies`RangePositionPreferences`showRangePositionPreferences[walk, "Which" -> "Open"], _Rectangle, Infinity], 10, TestID -> "one bar for each bin"]

VerificationTest[
  Count[StockAnalyzer`Studies`RangePositionPreferences`showRangePositionPreferences[spikeResult, "Which" -> "Open", "MarkSpikes" -> True], RGBColor[0.85, 0.15, 0.15], Infinity], 1, TestID -> "the spike is drawn in red"]

VerificationTest[
  Count[StockAnalyzer`Studies`RangePositionPreferences`showRangePositionPreferences[spikeResult, "Which" -> "Open", "MarkSpikes" -> False], RGBColor[0.85, 0.15, 0.15], Infinity], 0, TestID -> "MarkSpikes -> False draws no red bar"]

(* the hover: one tooltip for every bin *)
VerificationTest[
  Count[StockAnalyzer`Studies`RangePositionPreferences`showRangePositionPreferences[walk, "Which" -> "Open"], _Tooltip, Infinity], 10, TestID -> "one tooltip for every bin"]

VerificationTest[
  With[{labels = Cases[StockAnalyzer`Studies`RangePositionPreferences`showRangePositionPreferences[walk, "Which" -> "Open", "ShowNull" -> True], Tooltip[_, l_] :> l, Infinity]},
    {StringContainsQ[ToString[labels[[1]], InputForm], "exactly at the Low"], StringContainsQ[ToString[labels[[10]], InputForm], "exactly at the High"], StringContainsQ[ToString[labels[[5]], InputForm], "random walk"], StringContainsQ[ToString[labels[[5]], InputForm], "exactly at"]}],
  {True, True, True, False}, TestID -> "the tooltip of the end bins gives the share at the Low or the High, a middle bin does not; the random walk is in all of them"]

VerificationTest[
  StringContainsQ[ToString[Cases[StockAnalyzer`Studies`RangePositionPreferences`showRangePositionPreferences[spikeResult, "Which" -> "Open"], Tooltip[_, l_] :> l, Infinity][[51]], InputForm], "stands out from its neighbours"], True, TestID -> "the tooltip of a spike says so"]

VerificationTest[
  StringContainsQ[ToString[Cases[StockAnalyzer`Studies`RangePositionPreferences`showRangePositionPreferences[spikeResult, "Which" -> "Open"], Tooltip[_, l_] :> l, Infinity][[51]], InputForm], "position 50% to 51%"], True, TestID -> "the tooltip names the bin"]

(* rounding, the saved form, the loader and the merging of daily candlesticks *)
VerificationTest[
  StockAnalyzer`Studies`RangePositionPreferences`Private`roundSix[{1/3., 0.49999999999999994, 1., 0.}], {0.333333, 0.5, 1., 0.}, TestID -> "positions are rounded to 6 decimals (a half stays exactly 0.5)"]

packedInput = <|"Period" -> "weekly", "Tickers" -> {"A"}, "Open" -> {0.333333, 0.5, 1., 0.}, "Close" -> {0., 0.25, 0.75, 1.}, "RelRange" -> {0.01, 0.5, 1.25, 0.000001}, "Year" -> {2001, 2002, 2003, 2004}, "TickerIndex" -> {1, 1, 1, 1}|>;

VerificationTest[
  StockAnalyzer`Studies`RangePositionPreferences`Private`unpackResult[StockAnalyzer`Studies`RangePositionPreferences`Private`packResult[packedInput]]["Open"], packedInput["Open"], TestID -> "the saved form gives back the same positions"]

VerificationTest[
  Head[StockAnalyzer`Studies`RangePositionPreferences`Private`packResult[packedInput]["Open"]], NumericArray, TestID -> "the saved positions are a NumericArray of integers"]

VerificationTest[
  Module[{file = FileNameJoin[{$TemporaryDirectory, "rangePositionsTest.wxf"}], back},
    Export[file, StockAnalyzer`Studies`RangePositionPreferences`Private`packResult[packedInput], "WXF", PerformanceGoal -> "Size"];
    back = StockAnalyzer`Studies`RangePositionPreferences`collectRangePositions["weekly", "CacheFile" -> file];
    DeleteFile[file];
    {back["Open"], back["Year"], Developer`PackedArrayQ[back["Open"]], Developer`PackedArrayQ[back["Year"]]}],
  {packedInput["Open"], packedInput["Year"], True, True}, TestID -> "collectRangePositions reads the saved file (the period is checked first)"]

(* a loader: a function of a ticker and a period that gives candlesticks *)
loaderRows[ticker_, period_] := rows;

VerificationTest[
  With[{r = StockAnalyzer`Studies`RangePositionPreferences`collectRangePositions["weekly", "Tickers" -> {"AAA", "BBB"}, "Loader" -> loaderRows]}, {r["Tickers"], r["Kept"], r["Rows"], r["TickerIndex"], r["Open"]}],
  {{"AAA", "BBB"}, 4, 10, {1, 1, 2, 2}, {0.5, 0., 0.5, 0.}}, TestID -> "a Loader gives the candlesticks of each ticker"]

VerificationTest[
  StockAnalyzer`Studies`RangePositionPreferences`collectRangePositions["weekly", "Tickers" -> {"AAA"}, "Loader" -> "x"], $Failed, {StockAnalyzer`Studies`RangePositionPreferences`collectRangePositions::loader}, TestID -> "a bad Loader"]

(* two weeks and two months of made-up daily candlesticks *)
dailyRows = {
  <|"Date" -> DateObject[{2024, 1, 29}], "Open" -> 10, "High" -> 12, "Low" -> 9, "Close" -> 11|>,    (* Monday of week 1 *)
  <|"Date" -> DateObject[{2024, 1, 31}], "Open" -> 11, "High" -> 15, "Low" -> 10, "Close" -> 14|>,
  <|"Date" -> DateObject[{2024, 2, 2}], "Open" -> 14, "High" -> 14, "Low" -> 8, "Close" -> 9|>,
  <|"Date" -> DateObject[{2024, 2, 5}], "Open" -> 9, "High" -> 13, "Low" -> 9, "Close" -> 12|>};      (* Monday of week 2 *)

VerificationTest[
  StockAnalyzer`Studies`RangePositionPreferences`Private`resampleRows[dailyRows, "weekly"][[All, {"Open", "High", "Low", "Close"}]],
  {<|"Open" -> 10, "High" -> 15, "Low" -> 8, "Close" -> 9|>, <|"Open" -> 9, "High" -> 13, "Low" -> 9, "Close" -> 12|>}, TestID -> "daily candlesticks merged into weeks that start on Monday"]

VerificationTest[
  StockAnalyzer`Studies`RangePositionPreferences`Private`resampleRows[dailyRows, "monthly"][[All, {"Open", "High", "Low", "Close"}]],
  {<|"Open" -> 10, "High" -> 15, "Low" -> 9, "Close" -> 14|>, <|"Open" -> 14, "High" -> 14, "Low" -> 8, "Close" -> 12|>}, TestID -> "daily candlesticks merged into months"]

(* buildRangePositionData: the download from FinancialData is replaced by made-up daily candlesticks (dailyRows, above) so that the test needs no internet *)
fakeDaily = Function[ticker, If[ticker === "ZZZ", {}, dailyRows]];
buildFolder = FileNameJoin[{$TemporaryDirectory, "rangePositionsBuildTest"}];
If[DirectoryQ[buildFolder], DeleteDirectory[buildFolder, DeleteContents -> True]];

built = Block[{StockAnalyzer`Studies`RangePositionPreferences`Private`financialDailyRows = fakeDaily},
  StockAnalyzer`Studies`RangePositionPreferences`buildRangePositionData[buildFolder, "Tickers" -> {"AAA", "ZZZ", "BBB"}, "Periods" -> {"weekly", "monthly"}, "Retries" -> 0, "Overwrite" -> False]];

VerificationTest[
  {built["Failed"], Keys[built["Periods"]], built["Periods"]["weekly"]["Tickers"], built["Periods"]["weekly"]["Kept"], built["Periods"]["monthly"]["Kept"]}, {{"ZZZ"}, {"weekly", "monthly"}, 2, 4, 4}, TestID -> "the build saves each period; a ticker that gives nothing is reported"]

VerificationTest[
  FileExistsQ[FileNameJoin[{buildFolder, "RangePositions_weekly.wxf"}]] && FileExistsQ[FileNameJoin[{buildFolder, "RangePositions_monthly.wxf"}]] && ! FileExistsQ[FileNameJoin[{buildFolder, "RangePositions_daily.wxf"}]], True, TestID -> "only the files of the periods asked for are written"]

VerificationTest[
  With[{r = StockAnalyzer`Studies`RangePositionPreferences`collectRangePositions["weekly", "CacheFile" -> FileNameJoin[{buildFolder, "RangePositions_weekly.wxf"}]]},
    {r["Tickers"], r["Open"], r["Close"], r["Year"]}],
  {{"AAA", "BBB"}, {0.285714, 0., 0.285714, 0.}, {0.142857, 0.75, 0.142857, 0.75}, {2024, 2024, 2024, 2024}}, TestID -> "the saved file read back gives the positions of the weekly candlesticks"]

VerificationTest[
  Block[{StockAnalyzer`Studies`RangePositionPreferences`Private`financialDailyRows = fakeDaily},
    StockAnalyzer`Studies`RangePositionPreferences`buildRangePositionData[buildFolder, "Tickers" -> {"AAA"}, "Periods" -> {"weekly"}]],
  $Failed, {StockAnalyzer`Studies`RangePositionPreferences`buildRangePositionData::exists}, TestID -> "an existing file is not overwritten by default"]

VerificationTest[
  Block[{StockAnalyzer`Studies`RangePositionPreferences`Private`financialDailyRows = fakeDaily},
    StockAnalyzer`Studies`RangePositionPreferences`buildRangePositionData[buildFolder, "Tickers" -> {"AAA"}, "Periods" -> {"weekly"}, "Overwrite" -> True]["Periods"]["weekly"]["Tickers"]],
  1, TestID -> "Overwrite -> True replaces the file"]

VerificationTest[
  StockAnalyzer`Studies`RangePositionPreferences`buildRangePositionData[buildFolder, "Periods" -> {"hourly"}], $Failed, {StockAnalyzer`Studies`RangePositionPreferences`buildRangePositionData::periods}, TestID -> "a bad period"]

VerificationTest[
  StockAnalyzer`Studies`RangePositionPreferences`buildRangePositionData[buildFolder, "Tickers" -> {}], $Failed, {StockAnalyzer`Studies`RangePositionPreferences`buildRangePositionData::tickers}, TestID -> "no tickers"]

DeleteDirectory[buildFolder, DeleteContents -> True];
