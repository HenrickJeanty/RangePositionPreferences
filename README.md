# RangePositionPreferences

Are there preferred places for the **Open** and the **Close** in the range of a candlestick? A study of every single daily, weekly and monthly candlestick of 519 stocks, in the Wolfram Language.

For a candlestick, the position of the Open in its range is `(Open - Low)/(High - Low)`: 0 when the Open is at the Low, 1 when it is at the High. The same for the Close.

**Discussion:** the study is described, with figures and results, in the Wolfram Community post [Do the Open and the Close of a candlestick prefer certain places in its range? A study of 519 stocks](https://community.wolfram.com/t/do-the-open-and-the-close-of-a-candlestick-prefer-certain-places-in-its-range-a-study-of-519-stocks/28660).

**The price data are not included.** They come from `FinancialData`, whose terms apply, so the package does not redistribute them. Instead it contains `buildRangePositionData`, which downloads the prices through your own access to `FinancialData` and saves only the positions, relative ranges and years (no prices) in `Data/`. `Tickers.txt` lists the 519 tickers of the study.

## Quick start

1. Download or clone this folder and keep the folders together (`Kernel/`, `Data/`, `Notebooks/`).
2. Open `Notebooks/RangePositionPreferences.nb`. Evaluate section 1 (load the code), then section 2 once (build the data: about 20 seconds for each ticker, about 3 hours for all 519; try 10 tickers first). Then evaluate any of sections 3 to 5.

Or from a script or a notebook of your own:

```wolfram
(* Load the code: change the path to the folder you downloaded *)
Get["path/to/RangePositionPreferences/Kernel/RangePositionPreferences.wl"]
```

```wolfram
(* Build the data for 10 tickers (about 4 minutes; needs an internet connection and FinancialData). Remove the Take for all 519. *)
buildRangePositionData[
  "path/to/RangePositionPreferences/Data",
  "Tickers" -> Take[Import["path/to/RangePositionPreferences/Tickers.txt", "List"], 10],
  "Periods" -> {"daily", "weekly", "monthly"},
  "Retries" -> 2,
  "Overwrite" -> False
]
```

```wolfram
(* Read the saved weekly positions, make the histograms (from 2001 on) and draw them *)
weeklyCollected = collectRangePositions[
  "weekly",
  "Tickers" -> Automatic,
  "Loader" -> Automatic,
  "CacheFile" -> "path/to/RangePositionPreferences/Data/RangePositions_weekly.wxf"
];

weeklyResult = rangePositionPreferences[
  weeklyCollected,
  "Bins" -> 100,
  "FromYear" -> 2001,
  "ToYear" -> Automatic,
  "MinRelativeRange" -> 0,
  "SpikeThreshold" -> 5,
  "Null" -> True,
  "NullSteps" -> 200,
  "NullPaths" -> 100000,
  "NullDrift" -> 0,
  "Seed" -> 1
];

showRangePositionPreferences[
  weeklyResult,
  "Which" -> "Both",
  "ImageSize" -> 520,
  "Theme" -> "Light",
  "ShowNull" -> True,
  "MarkSpikes" -> True,
  "YMax" -> Automatic
]
```

Move the mouse over a bin of a picture to see its range, density, count, the random-walk density, the share exactly at the Low or the High (end bins) and, for a red bin, its z.

## What is in the folder

| Path | What |
|---|---|
| `Kernel/RangePositionPreferences.wl` | the code: `buildRangePositionData`, `collectRangePositions`, `rangePositionPreferences`, `showRangePositionPreferences` (each has a usage message) |
| `Notebooks/RangePositionPreferences.nb` | the guide: loads the code, builds the data and runs every analysis, with every option spelled out |
| `Tickers.txt` | the 519 tickers of the study: the constituents of the S&P 500 in November 2026 |
| `Data/` | empty: section 2 of the notebook (or `buildRangePositionData`) writes `RangePositions_{daily,weekly,monthly}.wxf` here (not under git) |
| `Tests/RangePositionPreferences.wlt` | the tests (made-up candlesticks, no data and no internet needed): `TestReport["Tests/RangePositionPreferences.wlt"]` |
| `Documentation/` | the draft of the Wolfram Community post and its figures |

## The data

* **Which stocks:** the 519 tickers in `Tickers.txt`, the constituents of the S&P 500 when I downloaded the prices (November 2026). They are *current* members, so the sample has survivorship bias (stocks that left the index are not in it). `buildRangePositionData` with `"Tickers" -> Automatic` uses the members of the S&P 500 on the day you run it, which will differ a little.
* **What is saved:** for every candlestick that has a range (High > Low, and the Open and the Close between the Low and the High): the position of the Open, the position of the Close, the relative range `(High - Low)/((High + Low)/2)` and the year, as integers in millionths. No prices. The positions do not depend on whether the prices were adjusted for splits and dividends.
* **Same numbers as the post?** The post's numbers come from the 519 tickers and the prices of November 2026. A build on another day gives slightly different numbers, and a build with few tickers is noisier.
* **Your own tickers or source:** `collectRangePositions["weekly", "Tickers" -> {"AAPL", "MSFT"}]` reads tickers directly with `FinancialData` (daily prices merged into weeks that start on Monday, into months or into years). Or give your own `"Loader"`: a function of a ticker and a period that gives a list of associations with the keys `Date`, `Open`, `High`, `Low` and `Close`. Use `"CacheFile" -> "path.wxf"` to save the result.

## Three things the study has to get right

1. **The histogram of a random walk is not flat.** The Open and the Close of a driftless walk sit near the Low and the High more often than in the middle (a U shape), because the Low and the High are places the walk has been. The reference is a simulated random walk.
2. **Before 2001 the prices were in fractions.** A candlestick with a range of 2, 3 or 4 ticks can only have positions 1/2, 1/3, 1/4, ...: sharp spikes that are the price grid, not a preference of the market. The default is `"FromYear" -> 2001`; for daily candlesticks, whose range can be a few cents, `"MinRelativeRange" -> 0.03` keeps only wide ones.
3. **A position of exactly 0 or 1 is a point mass**, reported on its own (`"AtLow"`, `"AtHigh"`), not part of the smooth histogram.

## Requirements

Developed and tested on Wolfram Language 15.0. It uses only standard functions (`Dataset`, `NumericArray`, WXF files), so recent older versions should work too, but I have not tested them. Building the data needs an internet connection and a Wolfram licence with access to `FinancialData`; the analysis itself does not.

## Limits

* The random-walk reference is rough: a fixed number of steps for every candlestick, no volatility clustering. Differences in the broad shape should not be over-read.
* It describes where prices end up inside their range. It is not a trading signal and not investment advice.

## Licence

MIT (see `LICENSE`). The licence covers the code. The prices behind the data are subject to the terms of `FinancialData`.
