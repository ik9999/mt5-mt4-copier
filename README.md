# MT5-MT4-Copier

Tools for copying orders from Metatrader 5 to Metatrader 4.

Both terminals have to be on a same PC. Orders are stored in csv file that both terminals read simultaneously.

Sub-directory with csv file from one terminal should be sym-linked to another one.

For example, with default input variables (`InpFileName = "positions.csv"`, `InpFilePath = "copier_cache\\"`):

In `Program Files (x86)/RoboForex MT4 Terminal/MQL4/Files`:

```
lrwxrwxrwx  1 eq eq   85 Feb  9 19:16 copier_cache -> 'Program Files/RoboForex - MetaTrader 5/MQL5/Files/copier_cache'
```

In `Program Files/RoboForex - MetaTrader 5/MQL5/Files`:

```
drwxr-xr-x  2 eq eq 4.0K Feb 12 19:45 copier_cache
```

First add Sender EA to MT5 terminal, then Receiver Script to MT4 terminal.

**Whats supported**:

Opening new orders

Closing closed orders

Editing TP/SL

**Whats not supported**:

Partial closing
