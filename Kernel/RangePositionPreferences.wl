(* ::Package:: *)

(* ====================================================================== *)
(* RangePositionPreferences.wl                                             *)
(* ====================================================================== *)
(*
  ARE THERE PREFERRED PLACES FOR THE OPEN AND THE CLOSE IN THE RANGE OF A CANDLESTICK?

  For every single candlestick of every ticker we have, the position of the Open (and of the Close) in the range: (Open - Low)/(High - Low), from 0 (at the Low) to 1 (at the High).
  RangePositions.wl does this for one ticker at every merging level; this file does it for ALL the tickers at ONE scale (the original candlesticks of a period: daily, weekly, ...)
  and asks whether some positions are preferred.

    Get["<project>\\Studies\\RangePositionPreferences.wl"];
    collected = collectRangePositions["weekly"];                        (* reads every ticker; a few minutes for daily, so use "CacheFile" *)
    result = rangePositionPreferences[collected];
    showRangePositionPreferences[result]

  Three things the study has to get right, found on the real data:

  1. The histogram of a pure random walk is NOT flat. The Open and the Close of a driftless walk sit near the Low and near the High more often than in the middle (a U shape), because the
     Low and the High are by definition places the walk has been. So a flat histogram is the wrong "nothing special" reference. The reference here is a simulated random walk ("Null").
  2. The prices of the US stocks were quoted in fractions (1/8, 1/16, ...) until 2001. A candlestick whose range is 2, 3 or 4 ticks wide can only have positions 0, 1/2, 1 or 0, 1/3, 2/3, 1
     or 0, 1/4, 1/2, 3/4, 1, so the histogram of the data before 2001 has sharp spikes at 25 %, 33 %, 50 %, 67 % and 75 %. That is the price grid, not a preference of the market. So the
     default is "FromYear" -> 2001. (A position does not change when prices are adjusted for splits and dividends, so the old grid is still in the adjusted data.)
  3. A position of exactly 0 or exactly 1 (the Open at the Low, the Close at the High, ...) is a point mass, not part of the smooth histogram. It is reported on its own ("AtLow", "AtHigh").
*)

Scan[Function[name, If[Names["Global`" <> name] =!= {}, ClearAll[Evaluate["Global`" <> name]]]],
  {"collectRangePositions", "buildRangePositionData", "rangePositionPreferences", "showRangePositionPreferences"}];

(* Inside the StockAnalyzer2 project (this file is in Studies/) the data layer is loaded if it is not yet. A copy of this file in another folder (for example Kernel/ of the stand-alone
   package RangePositionPreferences) finds no Kernel/init.m next to it and needs nothing: it works on the saved data, or on tickers read with FinancialData. *)
With[{init = FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "Kernel", "init.m"}]},
  If[Names["StockAnalyzer`StockDataManager`loadTickerData"] === {} && FileExistsQ[init], Get[init]]];

BeginPackage["StockAnalyzer`Studies`RangePositionPreferences`"];

collectRangePositions::usage =
  "collectRangePositions[period] reads the candlesticks of every ticker that has local data for the period (\"daily\", \"weekly\", \"monthly\" or \"yearly\") and keeps, for every candlestick that has a range " <>
  "(High > Low, and the Open and the Close between the Low and the High), the position of the Open and of the Close in the range, the relative range (High - Low)/((High + Low)/2) and the year. " <>
  "The positions and the relative range are rounded to 6 decimals. The positions are packed lists, one value for each candlestick of all the tickers together.\n" <>
  "Options: \"Tickers\" -> Automatic (all the tickers of the local data layer of the StockAnalyzer2 project; or a list of names, for example {\"AAPL\", \"MSFT\"}), " <>
  "\"Loader\" -> Automatic (a function loader[ticker, period] that gives the candlesticks, a list of associations with Date, Open, High, Low and Close; Automatic: the data layer of the StockAnalyzer2 project if it is loaded, " <>
  "otherwise FinancialData: daily prices merged into weekly, monthly or yearly candlesticks, which needs an internet connection), " <>
  "\"CacheFile\" -> None (a path ending in .wxf: if the file exists the result is read from it, otherwise the result is computed and written to it in a compact form; the saved data contain no prices, only positions, relative ranges and years).\n" <>
  "The result is an association: \"Period\", \"Tickers\", \"TickerSummary\" (a Dataset with the Rows, Kept, Flat and Invalid candlesticks of each ticker), \"Rows\", \"Kept\", \"Flat\" (High = Low), " <>
  "\"Invalid\" (missing prices, or an Open or Close outside the range), \"Open\", \"Close\", \"RelRange\", \"Year\" and \"TickerIndex\" (the lists of the kept candlesticks).";

buildRangePositionData::usage =
  "buildRangePositionData[folder] reads the daily prices of the stocks with FinancialData (an internet connection is needed), makes the daily, weekly and monthly candlesticks of each one, and saves, in the folder, " <>
  "the files RangePositions_daily.wxf, RangePositions_weekly.wxf and RangePositions_monthly.wxf that collectRangePositions reads with its \"CacheFile\" option (the positions of the Open and of the Close in the range of every candlestick, " <>
  "the relative range and the year: no prices are saved). Every ticker is downloaded once, which takes about 20 seconds (the first call is slower: FinancialData prepares its indices); for the 500 stocks of the S&P 500 it takes about 3 hours, so try a few tickers first.\n" <>
  "Options: \"Tickers\" -> Automatic (the current members of the S&P 500, from FinancialData; or a list of names), \"Periods\" -> {\"daily\", \"weekly\", \"monthly\"} (\"yearly\" is also possible), " <>
  "\"Retries\" -> 2 (more tries for a ticker that gives nothing), \"Overwrite\" -> False (False: stop if a file exists already).\n" <>
  "The result is an association: \"Folder\", \"Periods\" (for each period: the file, the number of tickers, of candlesticks read and of candlesticks kept) and \"Failed\" (the tickers that gave nothing).";

rangePositionPreferences::usage =
  "rangePositionPreferences[collected] makes the histogram of the position of the Open and of the Close in the range, for the candlesticks of collectRangePositions that pass the selection, " <>
  "compares it with the histogram of a simulated random walk and finds the bins that stand out from their neighbours.\n" <>
  "Options: \"Bins\" -> 100 (equal bins of the range 0 % to 100 %), \"FromYear\" -> 2001 and \"ToYear\" -> Automatic (the years kept; before 2001 the prices were in fractions, which makes spikes at 1/2, 1/3, 1/4, ...), " <>
  "\"MinRelativeRange\" -> 0 (keep only candlesticks whose (High - Low)/((High + Low)/2) is at least this: 0.02 means 2 %; a wide range has more ticks, so a finer grid), " <>
  "\"SpikeThreshold\" -> 5 (a bin is a spike when its count differs from the median of its 4 nearest neighbours by more than this many standard deviations of a count), " <>
  "\"Null\" -> True (simulate the random walk), \"NullSteps\" -> 200 (steps of a walk, the Open is the first point and the Close the last), \"NullPaths\" -> 100000, " <>
  "\"NullDrift\" -> 0 (drift of a step, in standard deviations of a step), \"Seed\" -> 1.\n" <>
  "The result is an association: \"Period\", \"Selection\", \"Candlesticks\", \"BinEdges\" (in %), \"Open\" and \"Close\" (each an association with \"Counts\", \"Density\" (1 = what a flat histogram would give), " <>
  "\"AtLow\" and \"AtHigh\" (the fractions of the candlesticks at exactly 0 and exactly 1), \"Mean\"), \"Null\" (the same for the simulated walk), \"Spikes\" (a Dataset: the series, the bin, " <>
  "its density, the density expected from its neighbours, z, and the simple fraction in the bin) and \"Summary\" (a Dataset).";

showRangePositionPreferences::usage =
  "showRangePositionPreferences[result] draws the histogram of the position of the Open and of the Close in the range (the result of rangePositionPreferences): bars of the density " <>
  "(1 = a flat histogram), a line for the simulated random walk, the spikes in red. The two bins at the ends hold the point masses at the Low and at the High and are clipped, with their value written on them. " <>
  "Hover: the mouse over a bin (anywhere in its column) shows its range of positions, its density, its count and share, the density of the random walk, the share exactly at the Low or the High (end bins) and, for a spike, its z.\n" <>
  "Options: \"Which\" -> \"Both\" (\"Open\", \"Close\" or \"Both\"), \"ImageSize\" -> 520 (of each picture), \"Theme\" -> \"Light\" (or \"Dark\"), \"ShowNull\" -> True (the random-walk line), " <>
  "\"MarkSpikes\" -> True (the spikes in red), \"YMax\" -> Automatic (the top of the picture).";

Begin["`Private`"];

collectRangePositions::period = "The period \"`1`\" must be \"daily\", \"weekly\", \"monthly\" or \"yearly\".";
collectRangePositions::none = "No candlesticks could be read for the period \"`1`\".";
collectRangePositions::tickers = "There is no local data layer to list the tickers from: give the tickers, for example \"Tickers\" -> {\"AAPL\", \"MSFT\"}, or read the saved data with \"CacheFile\".";
collectRangePositions::loader = "The option \"Loader\" must be Automatic or a function of a ticker and a period.";
buildRangePositionData::periods = "The option \"Periods\" must be a list of \"daily\", \"weekly\", \"monthly\" or \"yearly\", not `1`.";
buildRangePositionData::exists = "These files exist already: `1`. Use another folder or \"Overwrite\" -> True.";
buildRangePositionData::members = "FinancialData did not give the members of the S&P 500 (an internet connection is needed). Give the tickers with \"Tickers\" -> {\"AAPL\", \"MSFT\"}.";
buildRangePositionData::tickers = "The option \"Tickers\" must be Automatic or a non-empty list of strings, not `1`.";
buildRangePositionData::none = "No candlesticks could be read for any ticker.";
rangePositionPreferences::input = "The first argument must be the result of collectRangePositions.";
rangePositionPreferences::option = "The option \"`1`\" must be `2`, not `3`.";
rangePositionPreferences::empty = "No candlestick is left after the selection (years `1` to `2`, relative range at least `3`).";

(* ---------------------------------------------------------------------------------------------------- one ticker: positions of a list of candlesticks *)

yearOf[d_DateObject] := With[{l = d[[1]]}, If[MatchQ[l, {_Integer, ___}], l[[1]], DateValue[d, "Year"]]];
yearOf[_] := 0;

(* rows: a list of associations (or of lists of rules) with Open, High, Low, Close and Date. Only the candlesticks with a range and with the Open and the Close inside it are kept. *)
positionsOfRows[rows_List] :=
  Module[{assoc = Association /@ rows, o, h, l, c, dates, numeric, kept, flat, nonFlat, inside, valid},
    {o, h, l, c} = Lookup[assoc, #, Missing[]] & /@ {"Open", "High", "Low", "Close"};
    dates = Lookup[assoc, "Date", Missing[]];
    numeric = Flatten[Position[MapThread[And[NumberQ[#1], NumberQ[#2], NumberQ[#3], NumberQ[#4]] &, {o, h, l, c}], True]];
    {o, h, l, c, dates} = #[[numeric]] & /@ {N[o], N[h], N[l], N[c], dates};
    flat = Flatten[Position[MapThread[#1 <= #2 &, {h, l}], True]];
    nonFlat = Complement[Range[Length[numeric]], flat];
    inside = Select[nonFlat, With[{i = #}, o[[i]] >= l[[i]] && o[[i]] <= h[[i]] && c[[i]] >= l[[i]] && c[[i]] <= h[[i]]] &];
    {o, h, l, c, dates} = #[[inside]] & /@ {o, h, l, c, dates};
    <|"Rows" -> Length[rows], "Flat" -> Length[flat], "Invalid" -> Length[rows] - Length[numeric] + (Length[nonFlat] - Length[inside]), "Kept" -> Length[inside],
      "Open" -> roundSix[(o - l)/(h - l)],
      "Close" -> roundSix[(c - l)/(h - l)],
      "RelRange" -> roundSix[(h - l)/((h + l)/2)],
      "Year" -> Developer`ToPackedArray[yearOf /@ dates]|>];

(* rounded to 6 decimals: k/10^6 for the nearest integer k. A position that should be exactly 1/2 (a range of 2 ticks) is then exactly 0.5, not 0.49999999999999994, so that it always falls in the same bin;
   and the saved data are the integers k, so that the result is the same whether it is computed or read from the saved file *)
roundSix[x_List] := Developer`ToPackedArray[N[Round[10^6 x]/10.^6]];

(* ---------------------------------------------------------------------------------------------------- all the tickers of a period *)

(* ---- the saved form: the positions as integers (millionths), small integer types, compressed (the daily data of 519 tickers: 112 MB as plain numbers, about 30 MB this way) *)
packResult[r_Association] :=
  Join[r, <|"Open" -> NumericArray[Round[10^6 r["Open"]], "Integer32"], "Close" -> NumericArray[Round[10^6 r["Close"]], "Integer32"],
    "RelRange" -> NumericArray[Round[10^6 r["RelRange"]], "Integer32"], "Year" -> NumericArray[r["Year"], "Integer16"],
    "TickerIndex" -> NumericArray[r["TickerIndex"], "Integer16"], "Format" -> "RangePositions-v2"|>];

unpackResult[r_Association] :=
  If[r["Format"] =!= "RangePositions-v2", r,
    Join[KeyDrop[r, "Format"],
      <|"Open" -> roundSix[Normal[r["Open"]]/10.^6], "Close" -> roundSix[Normal[r["Close"]]/10.^6], "RelRange" -> roundSix[Normal[r["RelRange"]]/10.^6],
        "Year" -> Developer`ToPackedArray[Normal[r["Year"]]], "TickerIndex" -> Developer`ToPackedArray[Normal[r["TickerIndex"]]]|>]];

(* ---- candlesticks from FinancialData: daily prices, merged into weeks (from Monday), months or years; used when there is no local data layer and no Loader *)
financialDataRows[ticker_String, period_String] := resampleRows[financialDailyRows[ticker], period];

(* the daily candlesticks of a ticker from FinancialData as a list of associations with Date, Open, High, Low, Close (prices as numbers), or {} when nothing could be read *)
financialDailyRows[ticker_String] :=
  Module[{series, pairs, magnitude},
    series = Quiet[FinancialData[ticker, "OHLCV", {{1970, 1, 1}, Take[DateList[], 3]}]];
    If[! MatchQ[series, _TimeSeries], Return[{}]];
    pairs = Normal[series];
    magnitude[x_Quantity] := QuantityMagnitude[x];
    magnitude[x_] := x;
    Select[
      Map[With[{v = Association[Normal[#[[2]]]]}, <|"Date" -> #[[1]], "Open" -> magnitude[v["Open"]], "High" -> magnitude[v["High"]], "Low" -> magnitude[v["Low"]], "Close" -> magnitude[v["Close"]]|>] &, pairs],
      AllTrue[{#["Open"], #["High"], #["Low"], #["Close"]}, NumberQ] &]];

(* daily candlesticks (a list of associations with Date, Open, High, Low, Close, in date order) merged into weeks (from Monday), months or years: Open of the first, highest High, lowest Low, Close of the last *)
resampleRows[daily_List, period_String] :=
  Module[{key, groups},
    key = Switch[period,
      "weekly", Function[d, Floor[Floor[AbsoluteTime[d]/86400]/7]],    (* 1900-01-01 was a Monday *)
      "monthly", Function[d, DateValue[d, {"Year", "Month"}]],
      "yearly", Function[d, DateValue[d, "Year"]],
      _, None];
    If[key === None, Return[daily]];
    groups = GatherBy[daily, key[#["Date"]] &];
    Map[<|"Date" -> First[#]["Date"], "Open" -> First[#]["Open"], "High" -> Max[#["High"] & /@ #], "Low" -> Min[#["Low"] & /@ #], "Close" -> Last[#]["Close"]|> &, groups]];

Options[collectRangePositions] = {"Tickers" -> Automatic, "Loader" -> Automatic, "CacheFile" -> None};

collectRangePositions[period_String, OptionsPattern[]] :=
  Module[{cache = OptionValue["CacheFile"], per = ToLowerCase[period], loader = OptionValue["Loader"], localLayer, tickers, parts, names, summary, join, kept},
    If[! MemberQ[{"daily", "weekly", "monthly", "yearly"}, per], Message[collectRangePositions::period, period]; Return[$Failed]];
    If[StringQ[cache] && FileExistsQ[cache], Return[unpackResult[Import[cache, "WXF"]]]];
    localLayer = Names["StockAnalyzer`StockDataManager`loadTickerData"] =!= {};
    If[loader === Automatic,
      loader = If[localLayer, Symbol["StockAnalyzer`StockDataManager`loadTickerData"], financialDataRows],
      If[Head[loader] === String || loader === None, Message[collectRangePositions::loader]; Return[$Failed]]];
    tickers = Which[
      ListQ[OptionValue["Tickers"]], OptionValue["Tickers"],
      localLayer, Symbol["StockAnalyzer`StockDataManager`listAvailableTickers"][],
      True, Message[collectRangePositions::tickers]; Return[$Failed]];
    parts = Table[
      With[{rows = Normal[loader[t, per]]},
        If[! ListQ[rows] || rows === {}, Nothing, <|"Ticker" -> t, "Positions" -> positionsOfRows[rows]|>]],
      {t, tickers}];
    If[parts === {}, Message[collectRangePositions::none, period]; Return[$Failed]];
    With[{result = assembleCollected[per, parts]},
      If[StringQ[cache], saveResult[cache, result]];
      result]];

(* the result of collectRangePositions from the positions of the tickers: parts = a list of <|"Ticker" -> name, "Positions" -> positionsOfRows[...]|> *)
assembleCollected[per_String, parts_List] :=
  Module[{join, kept = #["Positions"]["Kept"] & /@ parts},
    join[key_] := Join @@ (#["Positions"][key] & /@ parts);
    <|"Period" -> per, "Tickers" -> (#["Ticker"] & /@ parts),
      "TickerSummary" -> Dataset[<|"Ticker" -> #["Ticker"], "Rows" -> #["Positions"]["Rows"], "Kept" -> #["Positions"]["Kept"], "Flat" -> #["Positions"]["Flat"], "Invalid" -> #["Positions"]["Invalid"]|> & /@ parts],
      "Rows" -> Total[#["Positions"]["Rows"] & /@ parts], "Kept" -> Total[kept], "Flat" -> Total[#["Positions"]["Flat"] & /@ parts], "Invalid" -> Total[#["Positions"]["Invalid"] & /@ parts],
      "Open" -> join["Open"], "Close" -> join["Close"], "RelRange" -> join["RelRange"], "Year" -> join["Year"],
      "TickerIndex" -> Developer`ToPackedArray[Join @@ MapIndexed[ConstantArray[First[#2], #1] &, kept]]|>];

saveResult[file_String, result_Association] := (
  Quiet[CreateDirectory[DirectoryName[file], CreateIntermediateDirectories -> True]];
  Export[file, packResult[result], "WXF", PerformanceGoal -> "Size"]);

(* ---------------------------------------------------------------------------------------------------- building the saved data from FinancialData *)

(* Monitor in a notebook; in a kernel without a front end Monitor gives a message, so there the work is simply done *)
SetAttributes[withProgress, HoldAll];
withProgress[work_, display_] := If[TrueQ[$Notebooks], Monitor[work, display], work];

Options[buildRangePositionData] = {"Tickers" -> Automatic, "Periods" -> {"daily", "weekly", "monthly"}, "Retries" -> 2, "Overwrite" -> False};

buildRangePositionData[folder_String, OptionsPattern[]] :=
  Module[{periods = ToLowerCase /@ Flatten[{OptionValue["Periods"]}], retries = OptionValue["Retries"], tickers = OptionValue["Tickers"], files, members, total, partsOf, failed = {}, daily, t, results},
    If[! (periods =!= {} && SubsetQ[{"daily", "weekly", "monthly", "yearly"}, periods]), Message[buildRangePositionData::periods, OptionValue["Periods"]]; Return[$Failed]];
    If[tickers =!= Automatic && ! (ListQ[tickers] && tickers =!= {} && AllTrue[tickers, StringQ]), Message[buildRangePositionData::tickers, tickers]; Return[$Failed]];
    files = AssociationMap[FileNameJoin[{folder, "RangePositions_" <> # <> ".wxf"}] &, periods];
    If[! TrueQ[OptionValue["Overwrite"]] && AnyTrue[Values[files], FileExistsQ],
      Message[buildRangePositionData::exists, Select[Values[files], FileExistsQ]]; Return[$Failed]];
    If[tickers === Automatic,
      members = Quiet[FinancialData["^GSPC", "Members"]];
      If[! ListQ[members] || members === {}, Message[buildRangePositionData::members]; Return[$Failed]];
      tickers = Union[StringReplace[StringReplace[ToString[#], Whitespace -> ""], __ ~~ ":" -> ""] & /@ members]];
    total = Length[tickers];
    partsOf = AssociationThread[periods -> ConstantArray[{}, Length[periods]]];
    (* every ticker is downloaded once (the daily prices); the periods are made from them. In a notebook a progress bar is shown. *)
    withProgress[
      Do[
        t = tickers[[i]];
        daily = {};
        Do[daily = financialDailyRows[t]; If[daily =!= {}, Break[]], {retries + 1}];
        If[daily === {},
          AppendTo[failed, t],
          Scan[Function[p, partsOf[p] = Append[partsOf[p], <|"Ticker" -> t, "Positions" -> positionsOfRows[resampleRows[daily, p]]|>]], periods]],
        {i, total}],
      Row[{ProgressIndicator[i, {0, total}], "  ", i, " of ", total, ": ", t}]];
    results = Association @ Table[
      If[partsOf[p] === {}, Nothing,
        With[{r = assembleCollected[p, partsOf[p]]},
          saveResult[files[p], r];
          p -> <|"File" -> files[p], "Tickers" -> Length[r["Tickers"]], "Rows" -> r["Rows"], "Kept" -> r["Kept"]|>]],
      {p, periods}];
    If[results === <||>, Message[buildRangePositionData::none]; Return[$Failed]];
    <|"Folder" -> folder, "Periods" -> results, "Failed" -> failed|>];

(* ---------------------------------------------------------------------------------------------------- histograms *)

(* the counts in bins equal bins of [0, 1]; a position of exactly 1 is in the last bin *)
binCounts[x_List, bins_Integer] := BinCounts[Clip[Floor[bins x] + 1, {1, bins}], {1, bins + 1, 1}];

(* the fractions of positions that are exactly 0 and exactly 1 *)
atLow[x_List] := If[x === {}, 0., N[(Length[x] - Total[Unitize[x]])/Length[x]]];
atHigh[x_List] := If[x === {}, 0., N[(Length[x] - Total[Unitize[x - 1.]])/Length[x]]];

seriesOf[x_List, bins_Integer] :=
  Module[{counts = binCounts[x, bins]},
    <|"Counts" -> counts, "Density" -> N[counts bins/Max[1, Length[x]]], "AtLow" -> atLow[x], "AtHigh" -> atHigh[x], "Mean" -> If[x === {}, 0., Mean[x]]|>];

(* ---------------------------------------------------------------------------------------------------- the random walk that serves as the reference *)

(* paths walks of steps steps (a step is normal, with the mean drift and sd 1); the Open is the first point and the Close the last; chunks keep the memory small *)
nullSeries[steps_Integer, paths_Integer, drift_, bins_Integer, seed_] :=
  BlockRandom[
    SeedRandom[seed];
    Module[{chunk = 5000, done = 0, acc = {ConstantArray[0, bins], ConstantArray[0, bins]}, low = {0, 0}, high = {0, 0}, sum = {0., 0.}, w, mn, mx, po, pc, m},
      While[done < paths,
        m = Min[chunk, paths - done];
        w = Accumulate[RandomVariate[NormalDistribution[drift, 1.], {steps, m}]];
        w = Join[{ConstantArray[0., m]}, w];
        mn = Min /@ Transpose[w]; mx = Max /@ Transpose[w];
        po = (0. - mn)/(mx - mn); pc = (Last[w] - mn)/(mx - mn);
        acc += {binCounts[po, bins], binCounts[pc, bins]};
        low += {m - Total[Unitize[po]], m - Total[Unitize[pc]]};
        high += {m - Total[Unitize[po - 1.]], m - Total[Unitize[pc - 1.]]};
        sum += {Total[po], Total[pc]};
        done += m];
      Association @ MapThread[
        #1 -> <|"Counts" -> #2, "Density" -> N[#2 bins/paths], "AtLow" -> N[#3/paths], "AtHigh" -> N[#4/paths], "Mean" -> N[#5/paths]|> &,
        {{"Open", "Close"}, acc, low, high, sum}]]];

(* ---------------------------------------------------------------------------------------------------- the spikes: bins that stand out from their neighbours *)

simpleFraction[lo_, hi_] :=
  With[{eps = 10^-6},
    Module[{found = Select[Union[Flatten[Table[k/m, {m, 2, 6}, {k, 1, m - 1}]]], lo - eps <= # < hi + eps &]},
      If[found === {}, "", With[{f = First[SortBy[found, Denominator]]}, ToString[Numerator[f]] <> "/" <> ToString[Denominator[f]]]]]];

spikesOf[name_String, counts_List, threshold_, bins_Integer] :=
  Module[{n = Total[counts], rows = {}, expected, z},
    If[bins < 20 || n == 0, Return[{}]];
    Do[
      expected = Median[{counts[[i - 2]], counts[[i - 1]], counts[[i + 1]], counts[[i + 2]]}];
      If[expected > 0,
        z = (counts[[i]] - expected)/Sqrt[expected];
        If[Abs[z] > threshold,
          AppendTo[rows, <|"Series" -> name, "From%" -> 100. (i - 1)/bins, "To%" -> 100. i/bins, "Density" -> N[counts[[i]] bins/n], "Expected" -> N[expected bins/n], "z" -> Round[z, 0.1],
            "Fraction" -> simpleFraction[(i - 1)/bins, i/bins]|>]]],
      {i, 3, bins - 2}];
    rows];

(* ---------------------------------------------------------------------------------------------------- rangePositionPreferences *)

Options[rangePositionPreferences] = {"Bins" -> 100, "FromYear" -> 2001, "ToYear" -> Automatic, "MinRelativeRange" -> 0, "SpikeThreshold" -> 5,
  "Null" -> True, "NullSteps" -> 200, "NullPaths" -> 100000, "NullDrift" -> 0, "Seed" -> 1};

rangePositionPreferences[collected_Association, OptionsPattern[]] :=
  Module[{bins = OptionValue["Bins"], from = OptionValue["FromYear"], to = OptionValue["ToYear"], minRange = OptionValue["MinRelativeRange"], threshold = OptionValue["SpikeThreshold"],
      mask, open, close, years, openSeries, closeSeries, null = Missing["NotComputed"], spikes, summaryRows},
    If[! (KeyExistsQ[collected, "Open"] && KeyExistsQ[collected, "Year"] && KeyExistsQ[collected, "RelRange"]), Message[rangePositionPreferences::input]; Return[$Failed]];
    If[! IntegerQ[bins] || bins < 2, Message[rangePositionPreferences::option, "Bins", "an integer of at least 2", bins]; Return[$Failed]];
    If[! IntegerQ[from], Message[rangePositionPreferences::option, "FromYear", "an integer", from]; Return[$Failed]];
    If[! (to === Automatic || IntegerQ[to]), Message[rangePositionPreferences::option, "ToYear", "an integer or Automatic", to]; Return[$Failed]];
    If[! (NumberQ[minRange] && minRange >= 0), Message[rangePositionPreferences::option, "MinRelativeRange", "a number of at least 0", minRange]; Return[$Failed]];
    years = collected["Year"];
    (* the candlesticks with from <= Year <= to and RelRange >= minRange (UnitStep[x] is 1 for x >= 0 and 0 otherwise) *)
    mask = Flatten[Position[UnitStep[years - from] UnitStep[If[to === Automatic, 10^6, to] - years] UnitStep[collected["RelRange"] - minRange], 1]];
    If[mask === {}, Message[rangePositionPreferences::empty, from, to, minRange]; Return[$Failed]];
    open = collected["Open"][[mask]]; close = collected["Close"][[mask]];
    openSeries = seriesOf[open, bins]; closeSeries = seriesOf[close, bins];
    If[TrueQ[OptionValue["Null"]],
      null = nullSeries[OptionValue["NullSteps"], OptionValue["NullPaths"], OptionValue["NullDrift"], bins, OptionValue["Seed"]]];
    spikes = Join[spikesOf["Open", openSeries["Counts"], threshold, bins], spikesOf["Close", closeSeries["Counts"], threshold, bins]];
    summaryRows = Table[
      With[{s = If[name === "Open", openSeries, closeSeries]},
        <|"Series" -> name, "MeanPosition" -> s["Mean"], "AtLow%" -> 100 s["AtLow"], "AtHigh%" -> 100 s["AtHigh"],
          "NullMean" -> If[AssociationQ[null], null[name]["Mean"], Missing[]],
          "NullAtLow%" -> If[AssociationQ[null], 100 null[name]["AtLow"], Missing[]],
          "NullAtHigh%" -> If[AssociationQ[null], 100 null[name]["AtHigh"], Missing[]],
          "Spikes" -> Count[spikes, _?(#["Series"] === name &)]|>],
      {name, {"Open", "Close"}}];
    <|"Period" -> collected["Period"],
      "Selection" -> <|"FromYear" -> from, "ToYear" -> to, "FirstYear" -> Min[years[[mask]]], "LastYear" -> Max[years[[mask]]], "MinRelativeRange" -> minRange|>,
      "Candlesticks" -> Length[mask], "Tickers" -> Length[Union[collected["TickerIndex"][[mask]]]],
      "BinEdges" -> N[100 Range[0, bins]/bins], "Open" -> openSeries, "Close" -> closeSeries, "Null" -> null,
      "Spikes" -> Dataset[spikes], "Summary" -> Dataset[summaryRows]|>];

(* ---------------------------------------------------------------------------------------------------- the picture *)

Options[showRangePositionPreferences] = {"Which" -> "Both", "ImageSize" -> 520, "Theme" -> "Light", "ShowNull" -> True, "MarkSpikes" -> True, "YMax" -> Automatic};

(* a number with at most 2 decimals and no trailing "." *)
shortNumber[x_] := With[{r = Round[N[x], 0.01]}, If[r == Round[r], ToString[Round[r]], ToString[r]]];

(* the text shown when the mouse is over the bin i of the series which: the bin, the density, the count and its share, the random walk, the point mass at the ends, the spike *)
hoverLabel[which_String, i_Integer, bins_Integer, result_Association, hasNull_, spikeRow_] :=
  Module[{counts = result[which]["Counts"], total, lines},
    total = Max[1, Total[counts]];
    lines = {
      Style[which <> ": position " <> shortNumber[100 (i - 1)/bins] <> "% to " <> shortNumber[100 i/bins] <> "%", Bold],
      "density " <> shortNumber[result[which]["Density"][[i]]] <> " (1 = flat)",
      ToString[NumberForm[counts[[i]], DigitBlock -> 3, NumberSeparator -> ","]] <> " candlesticks, " <> shortNumber[100. counts[[i]]/total] <> "% of them"};
    If[hasNull, AppendTo[lines, "random walk: density " <> shortNumber[result["Null"][which]["Density"][[i]]]]];
    If[i == 1, AppendTo[lines, "exactly at the Low: " <> shortNumber[100 result[which]["AtLow"]] <> "% of them"]];
    If[i == bins, AppendTo[lines, "exactly at the High: " <> shortNumber[100 result[which]["AtHigh"]] <> "% of them"]];
    If[AssociationQ[spikeRow],
      AppendTo[lines, Style["stands out from its neighbours: z = " <> shortNumber[spikeRow["z"]] <> If[spikeRow["Fraction"] =!= "", ", the fraction " <> spikeRow["Fraction"], ""], Italic]]];
    Column[lines]];

preferencePicture[result_Association, which_String, size_, theme_String, showNull_, markSpikes_, yMaxOption_] :=
  Module[{dens = result[which]["Density"], bins = Length[result[which]["Density"]], null = result["Null"], hasNull, nullDens, spikeBins, spikeInfo, hovers, fg, bg, bar, spike, nullColor, yMax, w, bars, line, clipped, ticks, title, gap = 0.12},
    {fg, bg} = If[theme === "Dark", {GrayLevel[0.92], GrayLevel[0.12]}, {GrayLevel[0], GrayLevel[1]}];
    bar = If[theme === "Dark", RGBColor[0.45, 0.65, 0.95], RGBColor[0.2, 0.4, 0.75]];
    spike = RGBColor[0.85, 0.15, 0.15];
    nullColor = If[theme === "Dark", RGBColor[1, 0.75, 0.3], RGBColor[0.9, 0.5, 0.05]];
    hasNull = TrueQ[showNull] && AssociationQ[null];
    nullDens = If[hasNull, null[which]["Density"], {}];
    (* the spikes of this series by bin number (they are listed in the tooltip even when MarkSpikes is False; only the red colour depends on it) *)
    spikeInfo = Association[(Round[#["From%"] bins/100] + 1 -> #) & /@ Select[Normal[result["Spikes"]], #["Series"] === which &]];
    spikeBins = If[TrueQ[markSpikes], Keys[spikeInfo], {}];
    yMax = If[NumberQ[yMaxOption], yMaxOption, 1.2 Max[1, Max[dens[[2 ;; bins - 1]]], If[hasNull, Max[nullDens[[2 ;; bins - 1]]], 0]]];
    w = 100./bins;
    bars = Table[
      {If[MemberQ[spikeBins, i], spike, bar], Rectangle[{(i - 1) w + gap w, 0}, {i w - gap w, Min[dens[[i]], yMax]}]},
      {i, bins}];
    clipped = Table[
      If[dens[[i]] > yMax, Text[Style[ToString[NumberForm[dens[[i]], {3, 1}]], FontColor -> fg, FontSize -> 10], {(i - 0.5) w, yMax}, {If[i < bins/2, -1.1, 1.1], 1}], Nothing],
      {i, bins}];
    line = If[hasNull, {nullColor, AbsoluteThickness[1.6], Line[Table[{(i - 0.5) w, Min[nullDens[[i]], yMax]}, {i, bins}]]}, {}];
    ticks = Table[{x, ToString[x] <> "%"}, {x, 0, 100, 20}];
    title = StringJoin[which, ": ", result["Period"], ", ", ToString[result["Selection"]["FirstYear"]], "-", ToString[result["Selection"]["LastYear"]], ", ",
      ToString[NumberForm[result["Candlesticks"], DigitBlock -> 3, NumberSeparator -> ","]], " candlesticks, ", ToString[result["Tickers"]], " tickers"];
    (* an almost invisible column over every bin, from the bottom to the top of the picture: the mouse shows the tooltip anywhere in the column, also over a short or empty bar; it is drawn last, so it is on top *)
    hovers = Table[
      {bg, Opacity[0.003], Tooltip[Polygon[{{(i - 1) w, 0}, {i w, 0}, {i w, yMax}, {(i - 1) w, yMax}}], hoverLabel[which, i, bins, result, hasNull, Lookup[spikeInfo, i, None]]]},
      {i, bins}];
    Graphics[{bars, {Dashing[{0.01, 0.01}], GrayLevel[0.55], Line[{{0, 1}, {100, 1}}]}, line, clipped, hovers},
      Frame -> True, FrameLabel -> {Style["position in the range (0% = Low, 100% = High)", FontColor -> fg], Style["density (1 = flat)", FontColor -> fg]},
      FrameTicks -> {{Automatic, None}, {ticks, None}}, PlotRange -> {{0, 100}, {0, yMax}}, PlotRangePadding -> {0, Scaled[0.02]},
      PlotLabel -> Style[title, FontColor -> fg, FontSize -> 11, Bold], Background -> bg, FrameStyle -> fg, BaseStyle -> {FontColor -> fg, FontSize -> 11},
      ImageSize -> size, AspectRatio -> 0.65, ImagePadding -> {{50, 10}, {40, 28}}]];

showRangePositionPreferences[result_Association, OptionsPattern[]] :=
  Module[{which = OptionValue["Which"], size = OptionValue["ImageSize"], theme = OptionValue["Theme"], names},
    names = Switch[which, "Open", {"Open"}, "Close", {"Close"}, _, {"Open", "Close"}];
    Row[preferencePicture[result, #, size, theme, OptionValue["ShowNull"], OptionValue["MarkSpikes"], OptionValue["YMax"]] & /@ names, Spacer[10]]];

End[];

EndPackage[];
