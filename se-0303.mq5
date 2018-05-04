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
#define DEF_WAIT_OPEN_DEAL_TIME    3 // время в секундах, которое ожидаем открытие позиции

/**/#define DEF_SHOW_EXPERT_STATUS
#define DEF_SHOW_DEBUG_STATUS/**/

/* #define DEF_DEBUG_FIXED_TP */         // эта отладка для открытия позиций с одинаковыми TP 10.0

//+------------------------------------------------------------------+
//| Trend parameters
//+------------------------------------------------------------------+
input int    trend_hours_ago     = 34;     // [24-48] продолжительность времени в часах начиная с текущего часа, которая анализируется для вычисления тренда
input double trend_min_dimension = 0.0085; // минимальный размер тренда
input double trend_max_dimension = 0.0160; // максимальный размер тренда

//+------------------------------------------------------------------+
//| Alligator parameters
//+------------------------------------------------------------------+
input double k_alligator_open_mouth = 0.15; // [10%-20%] аллигатор с раскрытой пастью, т.е. между зубами, губами и челюстью не менее 10% от тренда

//+------------------------------------------------------------------+
//| Rebound parameters
//+------------------------------------------------------------------+
input double k_rebound = 0.50; // [43%-72%] минимальный ожидаемый отскок цены относительно тренда

//+------------------------------------------------------------------+
//| TP parameters
//+------------------------------------------------------------------+
input double tp_min = 0.0027; // [0.0027-0.0037] минимальный TP

//+------------------------------------------------------------------+
//| Lossing parameters, это параметр показывает через сколько часов после
//|   закрытия ордера в убыток(поражения) можно открывать следующий,
//|   задается уравнением прямой kx + b = y, где x - порядковый номер поражения
//+------------------------------------------------------------------+
input int   loss_skip_hours_k   = 3; // коэф. k - уравнения прямой
input int   loss_skip_hours_b   = 4; // коэф. b - уравнения прямой

input int   loss_consecutive    = 5; // максимальное кол-во последовательных поражений

//+------------------------------------------------------------------+
//| Safing SL parameters
//+------------------------------------------------------------------+
input double k_safing_sl = 0.50; // защитный SL, который устанавливается если позиция перешла в профит

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Enums
//+------------------------------------------------------------------+
enum ExpertStatusEnum
{
  ES_Scan,
  ES_WaitOpenDeal
};

enum OrderDirectionEnum
{
  OD_Unknown,
  OD_Buy,
  OD_Sell
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

double trend_dimension, trend_high, trend_low; // размер, а также максимальное и минимальное значение цены за время тренда

double risk_money = 0.0;
uint cnt_last_loss = 0;
ulong order_ticket = 0;

OrderDirectionEnum hour_od = OD_Unknown; // часовое направление для открытия ордера

ExpertStatusEnum expert_status = ES_Scan; // статус эксперта

int handle_alligator = 0; // дескриптор для индикатора Alligator
double price_lips = 0.0; // цена губы Аллигатора
datetime saved_time; // время текущего часа

bool safing_sl_check = true; // флаг необходимости проверки установки защитного SL

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
    TimeToString(saved_time, TIME_MINUTES) + "/" +
    IntegerToString(cnt_last_loss) + " / " +
    moneyToStr(risk_money) + "]: " +
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
    case ES_WaitOpenDeal:        text = "Wait open deal"; break;
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
  showExpertStatus(expert_status, text);
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
//| Преобразовывает деньги в строку
//+-----------------------------------------------------------------+
string moneyToStr(double money)
{
  return DoubleToString(money, 2);
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

//+-----------------------------------------------------------------+
//| Возвращает кол-во последовательных сделок, которые завершились поражением
//+-----------------------------------------------------------------+
uint getCountConsecutiveLossDeal(datetime &time_last_loss, double &resote_money)
{
  bool res;
  ulong ticket;
  uint i, total, cnt = 0;
  double profit;
  datetime cur_datetime = TimeCurrent();

  res = HistorySelect(cur_datetime - 30*24*60*60, cur_datetime); // TODO: перенести в другое место
  total = HistoryDealsTotal();

  if (res && total)
  {
    for (i = total; i > 0;)
    {
      if ((ticket = HistoryDealGetTicket(--i) ) > 0)
      {
        if (HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT && /* выход из рынка */
            HistoryDealGetString(ticket, DEAL_SYMBOL) == DEF_SYMBOL &&
            HistoryDealGetInteger(ticket, DEAL_MAGIC) == DEF_EXPERT_MAGIC)
        {
          if ((profit = HistoryDealGetDouble(ticket, DEAL_PROFIT)) < 0.0)
          {
            if (0 == cnt) // запоминаем время последней убыточной сделки
            {
              resote_money = - 2 * profit;
              time_last_loss =(datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
            }
            else
              resote_money -= profit; // запоминаем весь убыток

            cnt++; // увеличиваем кол-во убыточных сделок
          }
          else
            break; // закончились убыточные сделки
        }
      }
    }
  }

  return cnt;
}

//+------------------------------------------------------------------+
//| Открывает ордер
//+------------------------------------------------------------------+
bool openOrder(ENUM_ORDER_TYPE order_type,
  double volume, double price, double tp, double sl)
{
   //--- declare and initialize the trade request and result of trade request
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
   request.type_filling = ORDER_FILLING_FOK;

#ifdef DEF_DEBUG_FIXED_TP
   double profit = 100.0;
   if (order_type == ORDER_TYPE_BUY)
     request.volume    = moneyToLots(profit / (tp - price));
   else
     request.volume    = moneyToLots(profit / (price - tp));
#else
   request.volume    = volume;            // volume of N lot
#endif

  //--- send the request
  if (OrderSend(request, result))
  {
    if (result.retcode == TRADE_RETCODE_DONE ||
        result.retcode == TRADE_RETCODE_PLACED)
    {
      if (result.order > 0)
      {
        order_ticket = result.order;
        Print(__FUNCTION__," Order sent in sync mode");
        return (true);
      }
    }
  }

  order_ticket = 0;

#ifdef DEF_SHOW_DEBUG_STATUS
  //--- information about the operation
  PrintFormat("Error %d openOrder: retcode=%u  deal=%I64u  order=%I64u", GetLastError(), result.retcode, result.deal, result.order);
#endif

   return TRADE_RETCODE_DONE == result.retcode; // request completed
}

//+------------------------------------------------------------------+
//| Сдвигает SL и/или TP у откытой позиции
//+------------------------------------------------------------------+
bool movePositionSLTP(ulong position_ticket, double tp, double sl)
{
   MqlTradeRequest request;
   MqlTradeResult  result;
   
   //--- установка параметров операции
   request.action   = TRADE_ACTION_SLTP; // тип торговой операции
   request.position = position_ticket;   // тикет позиции
   request.symbol   = DEF_SYMBOL;        // символ 
   request.sl       = sl;                // Stop Loss позиции
   request.tp       = tp;                // Take Profit позиции
   request.magic    = DEF_EXPERT_MAGIC;  // MagicNumber позиции
   
   //--- отправка запроса
   if (!OrderSend(request, result))
   {
     PrintFormat("OrderSend error %d",GetLastError());  // если отправить запрос не удалось, вывести код ошибки
     return false;
   }
   
   //--- информация об операции   
   PrintFormat("retcode=%u  deal=%I64u  order=%I64u", result.retcode, result.deal, result.order);
   
   return TRADE_RETCODE_DONE == result.retcode;
}

//+------------------------------------------------------------------+
//| Проверяет возможность установки защитного SL
//+------------------------------------------------------------------+
bool checkAndSetSafingSL(double ask, double bid)
{
   ulong  position_ticket; // тикет позиции
   double sl, tp, op, dimension;
   int i, total = PositionsTotal(); // количество открытых позиций
   
   //--- перебор всех открытых позиций
   for (i = 0; i < total; i++)
   {      
      position_ticket = PositionGetTicket(i);// тикет позиции
      
      sl = PositionGetDouble(POSITION_SL);  // Stop Loss позиции
      tp = PositionGetDouble(POSITION_TP);  // Take Profit позиции
      op = PositionGetDouble(POSITION_PRICE_OPEN);
      
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);  // тип позиции
      
      /*string position_symbol=PositionGetString(POSITION_SYMBOL); // символ 
      int    digits=(int)SymbolInfoInteger(position_symbol,SYMBOL_DIGITS); // количество знаков после запятой
      ulong  magic=PositionGetInteger(POSITION_MAGIC); // MagicNumber позиции
      double volume=PositionGetDouble(POSITION_VOLUME);    // объем позиции*/
      
      //--- вывод информации о позиции
      PrintFormat("#%I64u %s  open: %s  sl: %s  tp: %s",
                  position_ticket,                  
                  EnumToString(type),
                  priceToStr(op),
                  priceToStr(sl),
                  priceToStr(tp));

      if (type == POSITION_TYPE_BUY)
      {        
        dimension = (tp - op) * k_safing_sl;
        
        if (bid >= op + dimension) // если цена близка к TP
        {          
          if (sl < op + DEF_OPEN_DJITTER) // если защитный SL еще не установлен
          {
            // Вычисляем новый SL
            sl = op + DEF_OPEN_DJITTER;
            
            // Сдвигаем защитный SL
            movePositionSLTP(position_ticket, tp, sl);
          }
          
          safing_sl_check = false; // TODO: неверная обработка при кол-ве позиций более одной
        }
        
      } else { /* POSITION_TYPE_SELL */

        dimension = (op - tp) * k_safing_sl;
        
        if (ask <= op - dimension) // если цена близка к TP
        {          
          if (sl > op - DEF_OPEN_DJITTER) // если защитный SL еще не установлен
          {
            // Вычисляем новый SL
            sl = op - DEF_OPEN_DJITTER;
            
            // Сдвигаем защитный SL
            movePositionSLTP(position_ticket, tp, sl);
          }
          
          safing_sl_check = false;  // TODO: неверная обработка при кол-ве позиций более одной
        }
      }
   }
   
   return true; // TODO: неверная обработка при кол-ве позиций более одной
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
//| Вычисляем сумму депозита которым можно рискнуть в первом ордере
//+------------------------------------------------------------------+
double calcFirstDepositRisk()
{
  return AccountInfoDouble(ACCOUNT_BALANCE) / MathPow(2, loss_consecutive);
}

//+------------------------------------------------------------------+
//| Проверяет размер тренда на нахождение в разрешенном диапазоне
//+------------------------------------------------------------------+
bool checkValidTrendDimension()
{
  return trend_dimension >= trend_min_dimension &&
         trend_dimension <= trend_max_dimension;
}

//+-----------------------------------------------------------------+
//| Проверяет что Аллигатор с открытым ртом
//+-----------------------------------------------------------------+
OrderDirectionEnum checkAlligatorOpenMouth(double &lips)
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

  /* Подготавливаем текущие значения цен */
  for (i = 0; i < DEF_ALLIGATOR_BUFFERS; i++)
  {
    if (CopyBuffer(handle_alligator, i, 0, DEF_ALLIGATOR_TICK, arr) == DEF_ALLIGATOR_TICK)
    {
      alligator[i] = arr[0];
    } else {
      PRINT_LOG(LOG_Error, "can not copy iAlligator(" +
        IntegerToString(handle_alligator) + ") data to the array " + IntegerToString(i));
      return OD_Unknown;
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

        return OD_Sell;
  } else {
    if (alligator[DEF_JAW] - dimension > alligator[DEF_TEETH] &&
        alligator[DEF_TEETH] - dimension > alligator[DEF_LIPS])

        return OD_Buy;
  }

  SET_DEBUG_STATUS("D: " + priceToStr(dimension) +
    " J: " + priceToStr(alligator[DEF_JAW]) +
    " T: " + priceToStr(alligator[DEF_TEETH]) +
    " L: " + priceToStr(alligator[DEF_LIPS]));

  return OD_Unknown;
}

//+-----------------------------------------------------------------+
//| Проверяет что текущая цена возле губы Аллигатора
//+-----------------------------------------------------------------+
OrderDirectionEnum checkAlligatorLips(OrderDirectionEnum od, double ask, double bid, double lips)
{
  if (OD_Buy == od)
  {
    if (ask > lips && ask < lips + DEF_OPEN_DJITTER)
      return OD_Buy;
  } else if (OD_Sell == od) {
    if (bid < lips && bid > lips - DEF_OPEN_DJITTER)
      return OD_Sell;
  }

  return OD_Unknown;
}

//+------------------------------------------------------------------+
//| Проверяет что отскок еще не завершен и можно установить TP                                   |
//+------------------------------------------------------------------+
OrderDirectionEnum checkRebound(OrderDirectionEnum od,
  double ask, double bid, double &tp, double &sl)
{
  double tp_dimension = 0.0;
  double rebound_dimension = 0.0;

  tp = sl = 0.0;

  // Вычисляем размер отскока
  rebound_dimension = k_rebound * trend_dimension;

  if (OD_Buy == od)
  {
    tp_dimension = rebound_dimension - (ask - trend_low);
    if (tp_dimension >= tp_min)
    {
      tp = ask + tp_dimension;
      sl = ask - tp_dimension;

      return OD_Buy;
    }
  } else if (OD_Sell == od) {

    tp_dimension = rebound_dimension - (trend_high - bid);
    if (tp_dimension >= tp_min)
    {
      tp = bid - tp_dimension;
      sl = bid + tp_dimension;

      return OD_Sell;
    }
  }

  SET_DEBUG_STATUS("D: " + priceToStr(rebound_dimension) +
    " TP: " + priceToStr(tp_dimension) +
    " SL: " + priceToStr(tp_dimension));

  return OD_Unknown;
}

//+------------------------------------------------------------------+
//| Вычисляет время в часах, которое необходимо подождать до следующего
//|   выхода на рынок после поражения
//+------------------------------------------------------------------+
int calcLossSkipHours(int cnt_loss)
{
  return loss_skip_hours_k * cnt_loss + loss_skip_hours_b;
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
  datetime cur_time;

  // 0. Выходим если состояние проверки установки позиции
  if (expert_status >= ES_WaitOpenDeal)
    return;

  // 1. Если есть установленная позиция, то проверяем необходимость установки защитного SL
  if (PositionSelect(DEF_SYMBOL))
  {
    if (safing_sl_check)
    {
      double ask, bid;

      // Получаем текущую цену
      getCurrentPrice(ask, bid);
      
      checkAndSetSafingSL(ask, bid);
    }
    
    return;
  }

  // 2. Проверяем новый час или начало торговли
  if (getCurrentHour(cur_time) && cur_time != saved_time) // если новый час
  {
    datetime time_last_loss;
    int loss_skip_hours; // кол-во часов которое нужно подождать до следующего выхода на рынок после поражения

    hour_od = OD_Unknown; // сбрасываем часовое направление ордера
    saved_time = cur_time; // запоминаем время нового бара

    // 3. Проверяем что уже можно выходить на рынок если прошлый раз было поражения
    cnt_last_loss = getCountConsecutiveLossDeal(time_last_loss, risk_money);
    if (cnt_last_loss)
    {
      loss_skip_hours = calcLossSkipHours(cnt_last_loss);

      if (cur_time < time_last_loss + loss_skip_hours * 60 *60)
      {
#ifdef DEF_SHOW_EXPERT_STATUS
        setLabelText(DEF_CHART_ID, label_trend, "Wait " +
          TimeToString(time_last_loss, TIME_DATE) +
          " after " +
          IntegerToString(cnt_last_loss) + " LOSS [" +
          IntegerToString(loss_skip_hours) + "]");
#endif
        return;
      }
    } else {
      risk_money = calcFirstDepositRisk();
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
    if (checkValidTrendDimension())
    {
      // 6. Проверяем что Аллигатор с открытым ртом
      hour_od = checkAlligatorOpenMouth(price_lips);
    }
  }

  // 7. Если часовые параметры в норме
  if (OD_Unknown != hour_od)
  {
    OrderDirectionEnum cur_od = hour_od;
    double ask, bid, tp, sl, dimension;

   // 8. Получаем текущую цену
   getCurrentPrice(ask, bid);

   // 9. Проверяем что текущая цена возле губы Аллигатора
   cur_od = checkAlligatorLips(cur_od, ask, bid, price_lips);

    if (OD_Unknown != cur_od)
    {
      // 10. Проверяем что отскок еще не завершен
      cur_od = checkRebound(cur_od, ask, bid, tp, sl);

      // 11. Если можно открывать ордер
      if (OD_Unknown != cur_od)
      {
        dimension = OD_Buy == cur_od ? tp - ask : bid - tp;

        // 12. Отправляем ордер
        openOrder(OD_Buy == cur_od ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
            moneyToLots(risk_money / dimension), OD_Buy == cur_od ? ask : bid, tp, sl);

        // 13. Ожидаем открытия позиции
        setExpertStatus(ES_WaitOpenDeal); // ожидаем появления позиции
        EventSetTimer(DEF_WAIT_OPEN_DEAL_TIME); // запускаем таймер, на случай если сервер не открыл позицию
      }
    }
  }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
  if (expert_status == ES_WaitOpenDeal)
  {
    // По какой-то причине сервер не открыл позицию, повторяем попытку открытия ордера
    PRINT_LOG(LOG_Error, "Can not open DEAL, timer expired");

    saved_time = 0; // сбрасываем сохраненное время
    setExpertStatus(ES_Scan); // начинаем сканирование цен

    EventKillTimer(); // останавливаем таймер
  }
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
  switch(trans.type)
  {
    case TRADE_TRANSACTION_HISTORY_ADD:
    {
      if (order_ticket > 0 && trans.order == order_ticket && expert_status == ES_WaitOpenDeal)
      {
        // Вот здесь и смотрим что произошло

        SET_DEBUG_STATUS("Order open successfull");

        order_ticket = 0;
        setExpertStatus(ES_Scan);
        
        if (k_safing_sl > 0.0) // проверяем что нужно ставить защитный SL
          safing_sl_check = true; // разрешаем проверку и установку защитного SL

        EventKillTimer(); // останавливаем таймер проверки открытия позиции
      }
    } break;
    default: {}
  }
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

/*
//+------------------------------------------------------------------+
ORDER_POSITION_ID
Идентификатор позиции, который ставится на ордере при его исполнении. Каждый исполненный ордер порождает сделку, которая открывает новую или изменяет уже существующую позицию. Идентификатор этой позиции и устанавливается исполненному ордеру в этот момент.
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
*/
