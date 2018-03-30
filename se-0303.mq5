//+------------------------------------------------------------------+
//|                                                      se-0303.mq5 |
//|                                                    Sergey Bodnya |
//|                                                    se333@ukr.net |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Defines
//+------------------------------------------------------------------+
#define DEF_CHART_ID              0 // default chart identifier(0 - main chart window)
#define DEF_SYMBOL                "EURUSD"
#define DEF_TIMEFRAME             PERIOD_H1
#define DEF_TREND_MAX_HOURS_AGO   48

//+------------------------------------------------------------------+
//| Trend parameters
//+------------------------------------------------------------------+
input int    trend_hours_ago     = 24;     // [24_48:2] продолжительность времени в часах начиная с текущего часа, которая анализируется для вычисления тренда
input double trend_min_dimension = 0.0070; // минимальный размер тренда
input double trend_max_dimension = 0.0280; // максимальный размер тренда

double trend_dimension, trend_high, trend_low; // размер, а также максимальное и минимальное значение цены за время тренда

//+------------------------------------------------------------------+
//| Alligator parameters
//+------------------------------------------------------------------+
input double k_alligator_open_mouth = 0.10; // [10%_20%:2] аллигатор с раскрытой пастью, т.е. между зубами, губами и челюстью не менее 10% от тренда

//+------------------------------------------------------------------+
//| Enums
//+------------------------------------------------------------------+
enum StatusLevelEnum
{
  ST_Error,
  ST_WaitTrend,
  ST_WaitAlligator,
  ST_OpenOrder
};

enum LogLevelEnum
{
  LOG_Error,
  LOG_Warning,
  LOG_Info
};

const string log_level_names[] = {"ERROR", "WARNING", "INFO"};

void showStatus(StatusLevelEnum level, string text);
void printLog(LogLevelEnum level_log, string text);

#define PRINT_LOG(log_level, str) printLog(log_level, str)

//+------------------------------------------------------------------+
//| Constant parameters
//+------------------------------------------------------------------+
const string label_status = "labelStatus";
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
//| Показывает статус советника
//+-----------------------------------------------------------------+
void showStatus(StatusLevelEnum level_status, string text)
{
  setLabelText(DEF_CHART_ID, label_status, "STATUS[" +
    TimeToString(saved_time, TIME_MINUTES) + "]: " +
    IntegerToString(level_status, 2, '0') + " " + text);
}

//+-----------------------------------------------------------------+
//| Выводит сообщение в журнал и в статус советника
//+-----------------------------------------------------------------+
void printLog(LogLevelEnum level_log, string text)
{
  PrintFormat("%s: %s:%d %s", log_level_names[level_log], __FUNCTION__, __LINE__, text);
  showStatus(ST_Error, text);
}

//+-----------------------------------------------------------------+
//| Преобразовывает цену в строку
//+-----------------------------------------------------------------+
string priceToStr(double value)
{
  return DoubleToString(value, _Digits - 1);
}

//+------------------------------------------------------------------+
//| Возвращает текущий час
//+------------------------------------------------------------------+
bool getCurrentHour(datetime &dt)
{
  datetime time_array[1];

  PrintFormat("%s:%d", __FUNCTION__, __LINE__);
    
  if (1 != CopyTime(DEF_SYMBOL, DEF_TIMEFRAME, 0, 1, time_array))
  {
    PRINT_LOG(LOG_Error, "can not get currunt hour array " + TimeToString(time_array[0]) + " Err:" +
      IntegerToString(GetLastError()));
     return false;
  }

  dt = time_array[0]; 
  return true;
}

//+------------------------------------------------------------------+
//| Рассчитыват размер тренда
//+------------------------------------------------------------------+
bool calcTrendDimension(double &td, double &th, double &tl)
{
  int hour;
  double high_array[DEF_TREND_MAX_HOURS_AGO];
  double low_array[DEF_TREND_MAX_HOURS_AGO];

  PrintFormat("%s:%d", __FUNCTION__, __LINE__);

  if (trend_hours_ago <= DEF_TREND_MAX_HOURS_AGO &&
      trend_hours_ago == CopyHigh(DEF_SYMBOL, DEF_TIMEFRAME, 0, trend_hours_ago, high_array) &&
      trend_hours_ago == CopyLow(DEF_SYMBOL, DEF_TIMEFRAME, 0, trend_hours_ago, low_array))
  {
    th = 0;
    tl = low_array[0];

    /* 1. Вычисляем максимальную и минимальную цену за указанный период времени */
    for (hour = 0; hour < trend_hours_ago; hour++)
    {
      if (high_array[hour] > th)
        th = high_array[hour];
      if (low_array[hour] < tl)
        tl = low_array[hour];
    }

    /* 2. Определяем расстояние между максимальным и минимальным значениями */
    td = th - tl;

    return true;

  } else
    PRINT_LOG(LOG_Error, "can not recieve Low and High array");

  return false;
}

//+------------------------------------------------------------------+
//| Проверяет размер тренда на нахождение в разрешенном диапазоне
//+------------------------------------------------------------------+
bool isValidTrendDimension()
{
  if (trend_dimension < trend_min_dimension)
  {
    showStatus(ST_WaitTrend, "Trend is less than min value");
    return false;
  }

  if (trend_dimension > trend_max_dimension)
  {
    showStatus(ST_WaitTrend, "Trend is more than max value");
    return false;
  }

  return true;
}

//+-----------------------------------------------------------------+
//| Проверяет что Alligator готов для открытия ордера
//+-----------------------------------------------------------------+
bool isAlligatorPreparedForOpenOrder()
{
  int i;

#define DEF_ALLIGATOR_TICK      1

#define DEF_JAW                 0
#define DEF_TEETH               1
#define DEF_LIPS                2
#define DEF_ALLIGATOR_BUFFERS   3
  bool   allow_open_order = true;
  double dimension;
  string str_order_type;
  double arr[DEF_ALLIGATOR_TICK];
  double alligator[DEF_ALLIGATOR_BUFFERS] = { 0 };

  /* Подготавливаем текущие значения цен */
  for (i = 0; i < DEF_ALLIGATOR_BUFFERS; i++)
  {
    if (CopyBuffer(handle_alligator, i, 0, DEF_ALLIGATOR_TICK, arr) == DEF_ALLIGATOR_TICK)
    {
      alligator[i] = arr[0];
    } else {
      PRINT_LOG(LOG_Error, "can not copy iAlligator(" +
        IntegerToString(handle_alligator) + ") data to the array " + IntegerToString(i));
      return false;
    }
  }

  /* Вычисляем размер минимально необходимого расстояния между челюстью, зубами и губами аллигатора */
  dimension = trend_dimension * k_alligator_open_mouth;

  /* Проверяем что расстояние между челюстью, зубами и губами аллигатора достаточное - пасть открыта */
  if (alligator[DEF_JAW] < alligator[DEF_LIPS])
  {
    if (alligator[DEF_JAW] + dimension > alligator[DEF_TEETH] ||
        alligator[DEF_TEETH] + dimension > alligator[DEF_LIPS])

        allow_open_order = false;

    str_order_type = "SELL";
  } else {
    if (alligator[DEF_JAW] - dimension < alligator[DEF_TEETH] ||
        alligator[DEF_TEETH] - dimension < alligator[DEF_LIPS])

        allow_open_order = false;

    str_order_type = "BUY";
  }

  showStatus(ST_WaitAlligator, "D: " + priceToStr(dimension) +
      " J: " + priceToStr(alligator[DEF_JAW]) +
      " T: " + priceToStr(alligator[DEF_TEETH]) +
      " L: " + priceToStr(alligator[DEF_LIPS]) +
      str_order_type + " " + IntegerToString(allow_open_order));

    /*showStatus(ST_WaitAlligator, "wait for Alligator will open mouth for " + order_type);*/

  return true;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  PrintFormat("%s:%d", __FUNCTION__, __LINE__);

  CreateLabel(DEF_CHART_ID, label_status, "STATUS:", 0, 5, 20, clrYellow);
  CreateLabel(DEF_CHART_ID, label_trend, "TREND:", 0, 5, 40, clrYellow);

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

  // 1. Проверяем новый час или начало торговли
  if (getCurrentHour(cur_time) && cur_time != saved_time) // если новый час
  {
    saved_time = cur_time; // запоминаем время нового бара

    calcTrendDimension(trend_dimension, trend_high, trend_low);

    setLabelText(DEF_CHART_ID, label_trend, "TREND[" +
      IntegerToString(trend_hours_ago) + "]: " +
      priceToStr(trend_min_dimension) + "/" +
      priceToStr(trend_max_dimension) + "  " +
      priceToStr(trend_dimension));

      if (isValidTrendDimension() &&
          isAlligatorPreparedForOpenOrder()) {}

        /* showStatus(ST_OpenOrder, "Open order"); */
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

