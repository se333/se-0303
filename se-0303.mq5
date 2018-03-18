//+------------------------------------------------------------------+
//|                                                      se-0303.mq5 |
//|                                                    Sergey Bodnya |
//|                                                    se333@ukr.net |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Defines
//+------------------------------------------------------------------+
#define DEF_CHART_ID    0 // default chart identifier(0 - main chart window)

enum LogLevelEnum
{
  LOG_Error,
  LOG_Warning,
  LOG_Info
};

const string log_level_names[] = {"ERROR", "WARNING", "INFO"};

#define PRINT_LOG(log_level, str) \
  PrintFormat("%s: %s:%d %s", log_level_names[log_level], __FUNCTION__, __LINE__, str);

//+------------------------------------------------------------------+
//| Input parameters
//+------------------------------------------------------------------+
input int      Input1 = 3;


//+------------------------------------------------------------------+
//| CreateLabel - создает метку на экране
//+------------------------------------------------------------------+
void CreateLabel(long chart_id, string name, string text, int corner, int x, int y,
                 color tc = CLR_NONE, int fs = 9, string fn = "Arial")
{
  if (-1 == ObjectFind(chart_id, name))
  {
    if (ObjectCreate(chart_id, name, OBJ_LABEL, 0, 0, 0 ))
    {
      ObjectSetString(chart_id, name, OBJPROP_TEXT, text);
      ObjectSetString(chart_id, name, OBJPROP_FONT, fn);
      ObjectSetInteger(chart_id, name, OBJPROP_FONTSIZE, fs);
      ObjectSetInteger(chart_id, name, OBJPROP_COLOR, tc);
      ObjectSetInteger(chart_id, name, OBJPROP_CORNER, corner);
      ObjectSetInteger(chart_id, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(chart_id, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(chart_id, name, OBJPROP_SELECTABLE, false);
      ChartRedraw(chart_id);
    }
    else
      PRINT_LOG(LOG_Error, "can not create new object");
  } else
    PRINT_LOG(LOG_Error, "object '" + name + "' was found");
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  PrintFormat("%s:%d", __FUNCTION__, __LINE__);
  CreateLabel(DEF_CHART_ID, "runLabel", "Run: 12.4567", 0, 5, 20, clrYellow);
//--- create timer
/*   EventSetTimer(60);*/

//---
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  PrintFormat("%s:%d", __FUNCTION__, __LINE__);
//--- destroy timer
   EventKillTimer();

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
  PrintFormat("%s:%d", __FUNCTION__, __LINE__);
//---

  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
  PrintFormat("%s:%d", __FUNCTION__, __LINE__);
//---

  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
  PrintFormat("%s:%d", __FUNCTION__, __LINE__);
//---

  }
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
  PrintFormat("%s:%d", __FUNCTION__, __LINE__);
//---

  }
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
  PrintFormat("%s:%d", __FUNCTION__, __LINE__);
//---
   double ret=0.0;
//---

//---
   return(ret);
  }
//+------------------------------------------------------------------+
//| TesterInit function                                              |
//+------------------------------------------------------------------+
void OnTesterInit()
  {
  PrintFormat("%s:%d", __FUNCTION__, __LINE__);
//---

  }
//+------------------------------------------------------------------+
//| TesterPass function                                              |
//+------------------------------------------------------------------+
void OnTesterPass()
  {
  PrintFormat("%s:%d", __FUNCTION__, __LINE__);
//---

  }
//+------------------------------------------------------------------+
//| TesterDeinit function                                            |
//+------------------------------------------------------------------+
void OnTesterDeinit()
  {
  PrintFormat("%s:%d", __FUNCTION__, __LINE__);
//---

  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
  PrintFormat("%s:%d", __FUNCTION__, __LINE__);
//---

  }
//+------------------------------------------------------------------+
