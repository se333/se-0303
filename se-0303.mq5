//+------------------------------------------------------------------+
//|                                                      se-0303.mq5 |
//|                                                    Sergey Bodnya |
//|                                                    se333@ukr.net |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Trend parameters
//+------------------------------------------------------------------+
input int    trend_hours_ago     = 24;     // [24_48:2] продолжительность времени в часах начиная с текущего часа, которая анализируется для вычисления тренда
input double trend_min_dimension = 0.0070; // минимальный размер тренда
input double trend_max_dimension = 0.0280; // максимальный размер тренда

//+------------------------------------------------------------------+
//| Defines
//+------------------------------------------------------------------+
#define DEF_CHART_ID              0 // default chart identifier(0 - main chart window)
#define DEF_SYMBOL                "EURUSD"
#define DEF_TIMEFRAME             PERIOD_H1
#define DEF_TREND_MAX_HOURS_AGO   48

//+------------------------------------------------------------------+
//| Enums
//+------------------------------------------------------------------+
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
//| Constant parameters
//+------------------------------------------------------------------+
const string label_trend = "labelTrend";

//+------------------------------------------------------------------+
//| Static parameters
//+------------------------------------------------------------------+

datetime saved_time; // время текущего часа

int handle_alligator; // дескриптор для индикатора Alligator

//+------------------------------------------------------------------+
//| Создает метку на экране
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

//+-----------------------------------------------------------------+
//| Устанавливает текст в метке
//+-----------------------------------------------------------------+
void setLabelText(long chart_id, string name, string text)
{
  ObjectSetString(chart_id, name, OBJPROP_TEXT, text);
}

//+-----------------------------------------------------------------+
//| Преобразовывает цену в строку
//+-----------------------------------------------------------------+
string priceToStr(double value)
{
  return DoubleToString(value, _Digits - 1);
}

//+------------------------------------------------------------------+
//| Рассчитыват размер тренда
//+------------------------------------------------------------------+
bool calcTrendDimension(double &td)
{
  int hour;
  double high, low;
  double high_array[DEF_TREND_MAX_HOURS_AGO];
  double low_array[DEF_TREND_MAX_HOURS_AGO];

  PrintFormat("%s:%d", __FUNCTION__, __LINE__);

  if (trend_hours_ago <= DEF_TREND_MAX_HOURS_AGO &&
      trend_hours_ago == CopyHigh(DEF_SYMBOL, DEF_TIMEFRAME, 0, trend_hours_ago, high_array) &&
      trend_hours_ago == CopyLow(DEF_SYMBOL, DEF_TIMEFRAME, 0, trend_hours_ago, low_array))
  {
    high = 0;
    low = low_array[0];

    /* 1. Вычисляем максимальную и минимальную цену за указанный период времени */
    for (hour = 0; hour < trend_hours_ago; hour++)
    {
      if (high_array[hour] > high)
        high = high_array[hour];
      if (low_array[hour] < low)
        low = low_array[hour];
    }

    /* 2. Определяем расстояние между максимальным и минимальным значениями */
    td = high - low;

    return true;

  } else
    PRINT_LOG(LOG_Error, "can not recieve Low and High array");

  return false;
}

//+------------------------------------------------------------------+
//| Проверяет размер тренда на нахождение в разрешенном диапазоне
//+------------------------------------------------------------------+
bool isValidTrendDimension(double td)
{
  return td >= trend_min_dimension &&
         td <= trend_max_dimension;
}

//+------------------------------------------------------------------+
//| Возвращает текущий час
//+------------------------------------------------------------------+
datetime getCurrentHour()
{
  datetime time_array[1];

  PrintFormat("%s:%d", __FUNCTION__, __LINE__);

  if (1 != CopyTime(DEF_SYMBOL, DEF_TIMEFRAME, 0, 1, time_array))
    PRINT_LOG(LOG_Error, "can not get currunt hour array");

  return time_array[0];
}

//+-----------------------------------------------------------------+
//| Проверяет что Alligator готов для открытия ордера
//+-----------------------------------------------------------------+
bool isAlligatorPreparedForOpenOrder()
{
  int i, cnt = 0;

#define DEF_ALLIGATOR_TICK    1
#define DEF_ALLIGATOR_BUFFERS 3

  double jaw_array[DEF_ALLIGATOR_TICK], teeth_array[DEF_ALLIGATOR_TICK], lips_array[DEF_ALLIGATOR_TICK];

  for (i = 0; i < DEF_ALLIGATOR_BUFFERS; i++)
  {
    if (i == 0)
      cnt = CopyBuffer(handle_alligator, i, 0, 1, jaw_array);
    else if (i == 1)
      cnt = CopyBuffer(handle_alligator, i, 0, 1, teeth_array);
    else if (i == 2)
      cnt = CopyBuffer(handle_alligator, i, 0, 1, lips_array);

    if (cnt < 0)
    {
      PRINT_LOG(LOG_Error, "can not copy iAlligator(" + IntegerToString(handle_alligator) +
        ") data to the array " + IntegerToString(i));
      return false;
    }
  }

  return true;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  PrintFormat("%s:%d", __FUNCTION__, __LINE__);
  CreateLabel(DEF_CHART_ID, label_trend, "TREND:", 0, 5, 20, clrYellow);

  handle_alligator = iAlligator(DEF_SYMBOL, DEF_TIMEFRAME, 13, 8, 8, 5, 5, 2, MODE_SMA, PRICE_MEDIAN);

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
  datetime cur_time;

  PrintFormat("%s:%d", __FUNCTION__, __LINE__);

  cur_time = getCurrentHour();

  // 1. Проверяем новый час или начало торговли
  if (cur_time != saved_time) // если новый час
  {
    double td;

    saved_time = cur_time; // запоминаем время нового бара

    calcTrendDimension(td);

    setLabelText(DEF_CHART_ID, label_trend, "TREND[" +
      IntegerToString(trend_hours_ago) + "]: " +
      priceToStr(trend_min_dimension) + "/" +
      priceToStr(trend_max_dimension) + "  " +
      priceToStr(td));
  }


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

