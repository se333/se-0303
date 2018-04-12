//+------------------------------------------------------------------+
//|                                                      se-0303.mq5 |
//|                                                    Sergey Bodnya |
//|                                                    se333@ukr.net |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Defines
//+------------------------------------------------------------------+
#define DEF_CHART_ID               0 // default chart identifier(0 - main chart window)
#define DEF_SYMBOL                 "EURUSD"
#define DEF_TIMEFRAME              PERIOD_H1
#define DEF_TREND_MAX_HOURS_AGO    48
#define DEF_OPEN_DJITTER           0.0003
#define DEF_EXPERT_MAGIC           0303 // MagicNumber of the expert

/**/#define DEF_SHOW_EXPERT_STATUS
#define DEF_SHOW_DEBUG_STATUS/**/

#define DEF_DEBUG_FIXED_TP          // эта отладка для открытия позиций с одинаковыми TP 10.0

//+------------------------------------------------------------------+
//| Trend parameters
//+------------------------------------------------------------------+
input int    trend_hours_ago     = 33;     // [24-48] продолжительность времени в часах начиная с текущего часа, которая анализируется для вычисления тренда
input double trend_min_dimension = 0.0085; // минимальный размер тренда
input double trend_max_dimension = 0.0180; // максимальный размер тренда

double trend_dimension, trend_high, trend_low; // размер, а также максимальное и минимальное значение цены за время тренда

//+------------------------------------------------------------------+
//| Alligator parameters
//+------------------------------------------------------------------+
input double k_alligator_open_mouth = 0.16; // [10%-20%] аллигатор с раскрытой пастью, т.е. между зубами, губами и челюстью не менее 10% от тренда

//+------------------------------------------------------------------+
//| Rebound parameters
//+------------------------------------------------------------------+
input double k_rebound = 0.60; // [43%-72%] минимальный ожидаемый отскок цены относительно тренда

//+------------------------------------------------------------------+
//| TP parameters
//+------------------------------------------------------------------+
input double tp_min = 0.0030; // [0.0027-0.0037] минимальный TP

//+------------------------------------------------------------------+
//| Lossing parameters, это параметр показывает через сколько часов после 
//|   закрытия ордера в убыток(поражения) можно открывать следующий, 
//|   задается уравнением прямой kx + b = y, где x - порядковый номер поражения
//+------------------------------------------------------------------+
input int   loss_skip_hours_k   = 4; // коэф. k - уравнения прямой
input int   loss_skip_hours_b   = 8; // коэф. b - уравнения прямой

int loss_skip_hours = 0; // кол-во часов которое нужно подождать до следующего выхода на рынок после поражения

//+------------------------------------------------------------------+
//| Enums
//+------------------------------------------------------------------+
enum ExpertStatusEnum
{
  ES_Scan,
  ES_Error,
  ES_Trend_Min,
  ES_Trend_Max,
  ES_Trend_Ok,
  ES_AlligatorMouth_Buy,
  ES_AlligatorMouth_Sell,
  ES_AlligatorLips_Buy,
  ES_AlligatorLips_Sell,
  ES_OpenOrder_Buy,
  ES_OpenOrder_Sell
};

enum LogLevelEnum
{
  LOG_Error,
  LOG_Warning,
  LOG_Info
};

const string log_level_names[] = {"ERROR", "WARNING", "INFO"};

void showExpertStatus(ExpertStatusEnum status, string text);
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
ExpertStatusEnum expert_status = ES_Error; // статус эксперта
int handle_alligator = 0; // дескриптор для индикатора Alligator
double price_lips = 0.0; // цена губы Аллигатора
datetime saved_time; // время текущего часа

#ifdef DEF_SHOW_DEBUG_STATUS
string text_debug_status;
#endif

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

#ifdef DEF_SHOW_EXPERT_STATUS
//+-----------------------------------------------------------------+
//| Показывает статус советника
//+-----------------------------------------------------------------+
void showExpertStatus(ExpertStatusEnum status, string text)
{
  setLabelText(DEF_CHART_ID, label_status, "STATUS[" +
    TimeToString(saved_time, TIME_MINUTES) + "]: " +
    IntegerToString(status, 2, '0') + " " + text);
}
#endif

//+-----------------------------------------------------------------+
//| Устанавливает статус советника
//+-----------------------------------------------------------------+
void setExpertStatus(ExpertStatusEnum status)
{
  // Сохраняем состояние советника
  expert_status = status;

#ifdef DEF_SHOW_EXPERT_STATUS

  string text;

#ifdef DEF_SHOW_DEBUG_STATUS
  text = text_debug_status;
#else
  switch (expert_status) {
    case ES_Scan:                text = "Scan price"; break;
    case ES_Error:               text = "ERROR"; break;
    case ES_Trend_Min:           text = "Trend is smaller than min value"; break;
    case ES_Trend_Max:           text = "Trend is bigger than max value"; break;
    case ES_Trend_Ok:            text = "Trend is Ok"; break;
    case ES_AlligatorMouth_Buy:  text = "Mouth opened for BUY"; break;
    case ES_AlligatorMouth_Sell: text = "Mouth opened for SELL"; break;
    case ES_AlligatorLips_Buy:   text = "Price is near lips BUY"; break;
    case ES_AlligatorLips_Sell:  text = "Price is near lips SELL"; break;
    case ES_OpenOrder_Buy:       text = "Open order BUY"; break;
    case ES_OpenOrder_Sell:      text = "Open order SELL"; break;
    default:                     text = "Status undefined";
  }
#endif

  showExpertStatus(expert_status, text);
#endif
}

//+-----------------------------------------------------------------+
//| Выводит выводит отладку состояния советника
//+-----------------------------------------------------------------+
#ifdef DEF_SHOW_DEBUG_STATUS

void setDebugStatus(string text)
{
  text_debug_status = text;
}

#define SET_DEBUG_STATUS(text) setDebugStatus(text)

#else
#define SET_DEBUG_STATUS(text)
#endif

//+-----------------------------------------------------------------+
//| Выводит сообщение в журнал и в статус советника
//+-----------------------------------------------------------------+
void printLog(LogLevelEnum level_log, string text)
{
  PrintFormat("%s: %s:%d %s", log_level_names[level_log], __FUNCTION__, __LINE__, text);

#ifdef DEF_SHOW_EXPERT_STATUS
  showExpertStatus(ES_Error, text);
#endif
}

//+-----------------------------------------------------------------+
//| Преобразовывает цену в строку
//+-----------------------------------------------------------------+
string priceToStr(double value)
{
  return DoubleToString(value, _Digits - 1);
}

//+-----------------------------------------------------------------+
//| Преобразовывает деньги в лоты
//+-----------------------------------------------------------------+
double moneyToLots(double money)
{
  return NormalizeDouble(money / 100000.0, 2);
}

//+-----------------------------------------------------------------+
//| Преобразовывает лоты в деньги
//+-----------------------------------------------------------------+
double lotsToMoney(double lots)
{
  return NormalizeDouble(lots * 100000.0, 2);
}

//+-----------------------------------------------------------------+
//| Преобразовывает тип ордера в строку
//+-----------------------------------------------------------------+
string orderTypeToStr(ENUM_ORDER_TYPE order_type)
{
  string str;

  switch (order_type)
  {
    case ORDER_TYPE_BUY:             { str = "BUY"; } break;
    case ORDER_TYPE_SELL:            { str = "SELL"; } break;
    case ORDER_TYPE_BUY_LIMIT:       { str = "BUY_LIMIT"; } break;
    case ORDER_TYPE_SELL_LIMIT:      { str = "SELL_LIMIT"; } break;
    case ORDER_TYPE_BUY_STOP:        { str = "BUY_STOP"; } break;
    case ORDER_TYPE_SELL_STOP:       { str = "SELL_STOP"; } break;
    case ORDER_TYPE_BUY_STOP_LIMIT:  { str = "BUY_STOP_LIMIT"; } break;
    case ORDER_TYPE_SELL_STOP_LIMIT: { str = "SELL_STOP_LIMIT"; } break;
    case ORDER_TYPE_CLOSE_BY:        { str = "CLOSE_BY"; } break;
    default:                         { str = "INVALID ORDER TYPE"; }
  }
  return str;
}

//+------------------------------------------------------------------+
//| Возвращает текущий час
//+------------------------------------------------------------------+
bool getCurrentHour(datetime &dt)
{
  datetime time_array[1];

  if (1 != CopyTime(DEF_SYMBOL, DEF_TIMEFRAME, 0, 1, time_array))
  {
    PRINT_LOG(LOG_Error, "can not get currunt hour array " + TimeToString(time_array[0]) + " Err:" +
      IntegerToString(GetLastError()));
     return false;
  }

  dt = time_array[0];
  return true;
}

//+-----------------------------------------------------------------+
//| Возвращает текущую цену
//+-----------------------------------------------------------------+
void getCurrentPrice(double &ask, double &bid)
{
   MqlTick last_tick = {0};
   SymbolInfoTick(DEF_SYMBOL, last_tick);

   ask = last_tick.ask;
   bid = last_tick.bid;
}

//+------------------------------------------------------------------+
//| Открывает ордер
//+------------------------------------------------------------------+
bool orderSend(ENUM_ORDER_TYPE order_type,
  double volume, double price, double tp, double sl)
{
   //--- declare and initialize the trade request and result of trade request
   bool ret;
   MqlTradeRequest request={0};
   MqlTradeResult  result={0};

   //--- parameters of request
   request.action    = TRADE_ACTION_DEAL; // type of trade operation
   request.symbol    = DEF_SYMBOL;        // symbol   
   request.type      = order_type;        // order type
   request.price     = price;             // price for opening
   request.tp        = tp;
   request.sl        = sl;
   request.deviation = 5;                 // allowed deviation from the price
   request.magic     = DEF_EXPERT_MAGIC;  // MagicNumber of the order

#ifdef DEF_DEBUG_FIXED_TP
   double profit = 100.0;
   if (order_type == ORDER_TYPE_BUY)
     request.volume    = moneyToLots(profit / (tp - price));
   else
     request.volume    = moneyToLots(profit / (price - tp));
#else
   request.volume    = volume;            // volume of 0.1 lot
#endif
   
  //--- send the request
  if(!(ret = OrderSend(request, result)))
      PrintFormat("OrderSend error %d", GetLastError());     // if unable to send the request, output the error code
      
#ifdef DEF_SHOW_DEBUG_STATUS
   //--- information about the operation
   PrintFormat("OrderSend: retcode=%u  deal=%I64u  order=%I64u", result.retcode, result.deal, result.order);
#endif

   return ret && TRADE_RETCODE_DONE == result.retcode; // request completed
}

//+------------------------------------------------------------------+
//| Рассчитыват размер тренда
//+------------------------------------------------------------------+
bool calcTrendDimension(double &td, double &th, double &tl)
{
  int hour;
  double high_array[DEF_TREND_MAX_HOURS_AGO];
  double low_array[DEF_TREND_MAX_HOURS_AGO];

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

  } else {
    td = th = tl = 0;
    PRINT_LOG(LOG_Error, "can not recieve Low and High array");
  }

  return false;
}

//+------------------------------------------------------------------+
//| Проверяет размер тренда на нахождение в разрешенном диапазоне
//+------------------------------------------------------------------+
ExpertStatusEnum checkValidTrendDimension()
{
  if (trend_dimension < trend_min_dimension)
    return ES_Trend_Min;
  else if (trend_dimension > trend_max_dimension)
    return ES_Trend_Max;

  return ES_Trend_Ok;
}

//+-----------------------------------------------------------------+
//| Проверяет что Аллигатор с открытым ртом
//+-----------------------------------------------------------------+
ExpertStatusEnum checkAlligatorOpenMouth(double &lips)
{
  int i;

#define DEF_ALLIGATOR_TICK      1

#define DEF_JAW                 0
#define DEF_TEETH               1
#define DEF_LIPS                2
#define DEF_ALLIGATOR_BUFFERS   3

  double dimension;
  double arr[DEF_ALLIGATOR_TICK];
  double alligator[DEF_ALLIGATOR_BUFFERS] = { 0 };
  ExpertStatusEnum status = ES_Trend_Ok;

  /* Подготавливаем текущие значения цен */
  for (i = 0; i < DEF_ALLIGATOR_BUFFERS; i++)
  {
    if (CopyBuffer(handle_alligator, i, 0, DEF_ALLIGATOR_TICK, arr) == DEF_ALLIGATOR_TICK)
    {
      alligator[i] = arr[0];
    } else {
      PRINT_LOG(LOG_Error, "can not copy iAlligator(" +
        IntegerToString(handle_alligator) + ") data to the array " + IntegerToString(i));
      return ES_Error;
    }
  }

  /* Вычисляем размер минимально необходимого расстояния между челюстью, зубами и губами аллигатора */
  dimension = trend_dimension * k_alligator_open_mouth;
  lips = alligator[DEF_LIPS];

  /* Проверяем что расстояние между челюстью, зубами и губами аллигатора достаточное - пасть открыта */
  if (alligator[DEF_JAW] < alligator[DEF_LIPS])
  {
    if (alligator[DEF_JAW] + dimension < alligator[DEF_TEETH] &&
        alligator[DEF_TEETH] + dimension < alligator[DEF_LIPS])

          status = ES_AlligatorMouth_Sell;
  } else {
    if (alligator[DEF_JAW] - dimension > alligator[DEF_TEETH] &&
        alligator[DEF_TEETH] - dimension > alligator[DEF_LIPS])

        status = ES_AlligatorMouth_Buy;
  }

  SET_DEBUG_STATUS("D: " + priceToStr(dimension) +
    " J: " + priceToStr(alligator[DEF_JAW]) +
    " T: " + priceToStr(alligator[DEF_TEETH]) +
    " L: " + priceToStr(alligator[DEF_LIPS]));

  return status;
}

//+-----------------------------------------------------------------+
//| Проверяет что текущая цена возле губы Аллигатора
//+-----------------------------------------------------------------+
ExpertStatusEnum checkAlligatorLips(ExpertStatusEnum status, double ask, double bid, double lips)
{
  if (ES_AlligatorMouth_Buy == status ||
      ES_AlligatorLips_Buy == status)
  {
    if (ask > lips && ask < lips + DEF_OPEN_DJITTER)
      status = ES_AlligatorLips_Buy;
    else
      status = ES_AlligatorMouth_Buy;
  } else if (ES_AlligatorMouth_Sell == status ||
             ES_AlligatorLips_Sell == status) {
    if (bid < lips && bid > lips - DEF_OPEN_DJITTER)
      status = ES_AlligatorLips_Sell;
    else
      status = ES_AlligatorMouth_Sell;
  }

  return status;
}

//+------------------------------------------------------------------+
//| Проверяет что отскок еще не завершен и можно установить TP                                   |
//+------------------------------------------------------------------+
ExpertStatusEnum checkRebound(ExpertStatusEnum status,
  double ask, double bid, double &tp, double &sl)
{
  double tp_dimension = 0.0;
  double rebound_dimension = 0.0;

  tp = sl = 0.0;

  // Вычисляем размер отскока
  rebound_dimension = k_rebound * trend_dimension;

  if (ES_AlligatorLips_Buy == status)
  {
    tp_dimension = rebound_dimension - (ask - trend_low);
    if (tp_dimension >= tp_min)
    {
      tp = ask + tp_dimension;
      sl = ask - tp_dimension;

      status = ES_OpenOrder_Buy;
    }
  } else if (ES_AlligatorLips_Sell == status) {

    tp_dimension = rebound_dimension - (trend_high - bid);
    if (tp_dimension >= tp_min)
    {
      tp = bid - tp_dimension;
      sl = bid + tp_dimension;

      status = ES_OpenOrder_Sell;
    }
  }

  SET_DEBUG_STATUS("D: " + priceToStr(rebound_dimension) +
    " TP: " + priceToStr(tp_dimension) +
    " SL: " + priceToStr(tp_dimension));

  return status;
}

//+------------------------------------------------------------------+
//| Вычисляет время в часах, которое необходимо подождать до следующего
//|   выхода на рынок после поражения
//+------------------------------------------------------------------+
int calcLossSkipHours(int loss_number_x)
{
  return loss_skip_hours_k * loss_number_x + loss_skip_hours_b;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{

#ifdef DEF_SHOW_DEBUG_STATUS
  CreateLabel(DEF_CHART_ID, label_status, "STATUS:", 0, 5, 20, clrYellow);
  CreateLabel(DEF_CHART_ID, label_trend, "TREND:", 0, 5, 40, clrYellow);
#endif

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
//--- destroy timer
   EventKillTimer();

  }


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  double ask, bid, tp = 0.0, sl = 0.0;
  datetime cur_time;
  
#ifdef DEF_SHOW_DEBUG_STATUS
  PrintFormat("%s:%d", __FUNCTION__, __LINE__);
#endif
  
  // 1. Проверяем наличие позиции
  if (PositionSelect(DEF_SYMBOL))
    return;
  
  // 2. Проверяем новый час или начало торговли
  if (getCurrentHour(cur_time) && cur_time != saved_time) // если новый час
  {
    expert_status = ES_Scan; // сбрасываем состояние эксперта
    saved_time = cur_time; // запоминаем время нового бара


    // 3. Проверяем что уже можно выходить на рынок после поражения
    if (loss_skip_hours)
    {
      loss_skip_hours--; // уменьшаем время ожидания

#ifdef DEF_SHOW_EXPERT_STATUS
      setLabelText(DEF_CHART_ID, label_trend, "SKIP HOURS [" +
        IntegerToString(loss_skip_hours) + "]");
#endif
      return;
    }

    // 4. Вычисляем новый размер тренда
    calcTrendDimension(trend_dimension, trend_high, trend_low);

#ifdef DEF_SHOW_EXPERT_STATUS
    setLabelText(DEF_CHART_ID, label_trend, "TREND[" +
      IntegerToString(trend_hours_ago) + "]: " +
      priceToStr(trend_min_dimension) + "/" +
      priceToStr(trend_max_dimension) + " - " +
      priceToStr(trend_dimension));
#endif

    // 5. Проверяем что размер тренда в установленном диапазоне
    setExpertStatus(checkValidTrendDimension());

    // 6. Проверяем что Аллигатор с открытым ртом
    if (ES_Trend_Ok == expert_status)
      setExpertStatus(checkAlligatorOpenMouth(price_lips));
  }

  // 7. Получаем текущую цену
  getCurrentPrice(ask, bid);

  // 8. Проверяем что текущая цена возле губы Аллигатора
  if (ES_AlligatorMouth_Buy == expert_status ||
      ES_AlligatorMouth_Sell == expert_status ||
      ES_AlligatorLips_Buy == expert_status ||
      ES_AlligatorLips_Sell == expert_status)

      setExpertStatus(checkAlligatorLips(expert_status, ask, bid, price_lips));

  // 9. Проверяем что отскок еще не завершен и можно установить TP
  if (ES_AlligatorLips_Buy == expert_status ||
      ES_AlligatorLips_Sell == expert_status)
  {
    setExpertStatus(checkRebound(expert_status, ask, bid, tp, sl));
  }

  // 10. Открываем ордер
  if (ES_OpenOrder_Buy == expert_status ||
      ES_OpenOrder_Sell == expert_status)
  {
    if (orderSend(ES_OpenOrder_Buy == expert_status ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
      0.1, ES_OpenOrder_Buy == expert_status ? ask : bid, tp, sl))

      expert_status = ES_Scan; // сбрасываем состояние эксперта
  }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
}

//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
{
}

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
}

//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
{
  double ret=0.0;
  return(ret);
}

//+------------------------------------------------------------------+
//| TesterInit function                                              |
//+------------------------------------------------------------------+
void OnTesterInit()
{
}

//+------------------------------------------------------------------+
//| TesterPass function                                              |
//+------------------------------------------------------------------+
void OnTesterPass()
{
}

//+------------------------------------------------------------------+
//| TesterDeinit function                                            |
//+------------------------------------------------------------------+
void OnTesterDeinit()
{
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
}
//+------------------------------------------------------------------+
