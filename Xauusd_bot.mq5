
//+------------------------------------------------------------------+
//| XAUUSD BOT - Exness MT5                                          |
//| Demo testing version - 0.5% risk                                 |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
CTrade trade;

// SETTINGS
input double RiskPercent = 0.5;
input int FastEMA = 20;
input int SlowEMA = 50;
input int RSIPeriod = 14;
input int ATRPeriod = 14;
input double ATRMultiplier = 2.0;
input double RiskReward = 1.5;
input int MaxSpreadPoints = 1500;
input ulong MagicNumber = 20261125;

int fastHandle, slowHandle, rsiHandle, atrHandle;
datetime lastBar = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);

   fastHandle = iMA(_Symbol, PERIOD_M15, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   slowHandle = iMA(_Symbol, PERIOD_M15, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, PERIOD_M15, RSIPeriod, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, PERIOD_M15, ATRPeriod);

   if(fastHandle == INVALID_HANDLE ||
      slowHandle == INVALID_HANDLE ||
      rsiHandle == INVALID_HANDLE ||
      atrHandle == INVALID_HANDLE)
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(fastHandle);
   IndicatorRelease(slowHandle);
   IndicatorRelease(rsiHandle);
   IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
double CalculateLot(double stopDistance)
{
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE)
                      * RiskPercent / 100.0;

   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(tickSize <= 0 || tickValue <= 0 || step <= 0)
      return 0;

   double lossPerLot = (stopDistance / tickSize) * tickValue;

   if(lossPerLot <= 0)
      return 0;

   double lot = riskMoney / lossPerLot;
   lot = MathFloor(lot / step) * step;

   if(lot < minLot)
      return 0;

   lot = MathMin(lot, maxLot);

   return NormalizeDouble(lot, 8);
}

//+------------------------------------------------------------------+
void OnTick()
{
   datetime currentBar = iTime(_Symbol, PERIOD_M15, 0);

   if(currentBar == 0 || currentBar == lastBar)
      return;

   lastBar = currentBar;

   if(Bars(_Symbol, PERIOD_M15) < 100)
      return;

   if(PositionSelect(_Symbol))
      return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double spread = (ask - bid) / _Point;

   if(spread > MaxSpreadPoints)
      return;

   double fast[], slow[], rsi[], atr[];

   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);

   if(CopyBuffer(fastHandle, 0, 1, 2, fast) != 2) return;
   if(CopyBuffer(slowHandle, 0, 1, 2, slow) != 2) return;
   if(CopyBuffer(rsiHandle, 0, 1, 1, rsi) != 1) return;
   if(CopyBuffer(atrHandle, 0, 1, 1, atr) != 1) return;

   bool buySignal =
      fast[1] > slow[1] &&
      fast[0] <= slow[0] &&
      rsi[0] > 50 && rsi[0] < 70;

   bool sellSignal =
      fast[1] < slow[1] &&
      fast[0] >= slow[0] &&
      rsi[0] < 50 && rsi[0] > 30;

   double stopDistance = atr[0] * ATRMultiplier;

   if(stopDistance <= 0)
      return;

   double lot = CalculateLot(stopDistance);

   if(lot <= 0)
      return;

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(buySignal)
   {
      double sl = NormalizeDouble(ask - stopDistance, digits);
      double tp = NormalizeDouble(ask + stopDistance * RiskReward, digits);

      trade.Buy(lot, _Symbol, 0, sl, tp, "XAUUSD BUY");
   }

   if(sellSignal)
   {
      double sl = NormalizeDouble(bid + stopDistance, digits);
      double tp = NormalizeDouble(bid - stopDistance * RiskReward, digits);

      trade.Sell(lot, _Symbol, 0, sl, tp, "XAUUSD SELL");
   }
}
//+------------------------------------------------------------------+
