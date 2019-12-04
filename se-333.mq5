//+------------------------------------------------------------------+
//|                                                      se-333.mq5 |
//|                                                    Sergey Bodnya |
//|                                                    se333@ukr.net |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Defines
//+------------------------------------------------------------------+
#define DEF_CHART_ID               0 // default chart identifier(0 - main chart window)
#define DEF_SYMBOL                 Symbol()

#define DEF_EXPERT_MAGIC           333 // MagicNumber of the expert
#define DEF_WAIT_OPEN_DEAL_TIME    3 // время в секундах, которое ожидаем открытие позиции

/**/#define DEF_SHOW_EXPERT_STATUS
#define DEF_SHOW_DEBUG_STATUS/**/

#define DEF_DEBUG_FORCE_OPEN_DEAL // эта отладка для принудительного открытия позиций

#ifdef DEF_DEBUG_FORCE_OPEN_DEAL
static bool need_open_deal = true;
#endif

//+------------------------------------------------------------------+
//| Входные параметры
//+------------------------------------------------------------------+
input double input_real_balance = 133.0; // баланс
input int input_cur_attemp      = 1;     // номер текущей попытки выиграть (5..1)

//+------------------------------------------------------------------+
//| Коэффициенты 
//+------------------------------------------------------------------+
input double input_k_protected_sl = 0.70; // коэф. защитного SL, который устанавливается если сделка перешла в профит

//+------------------------------------------------------------------+
//| Константы
//+------------------------------------------------------------------+
const double param_real_dist_stop  = 0.0030; // расстояние от установленного TP до реальных стопов(SL/TP)
const double param_djitter         = 0.0003; // джитер при котором не изменяются SL/TP

//+------------------------------------------------------------------+
//| Enums
//+------------------------------------------------------------------+
enum ExpertStatusEnum
{
  ESE_DealGuard, // сделка открыта и советник в режиме охраны
  ESE_WaitOpenDeal // ожидает открытия сделки
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

ulong order_ticket = 0;

ExpertStatusEnum expert_status = ESE_WaitOpenDeal; // статус эксперта

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
  setLabelText(DEF_CHART_ID, label_status, "Balance: " +
    moneyToStr(input_real_balance) + " [" +    
    IntegerToString(input_cur_attemp) + " / " + 
    moneyToStr(calcFirstDepositRisk()) + "] " +
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
    case ESE_DealGuard:          text = "Deal guard"; break;
    case ESE_WaitOpenDeal:       text = "Wait open deal"; break;
    default:                     text = "Status undefined";
  }
#endif

  showExpertStatus(expert_status, text);
#endif
}

//+-----------------------------------------------------------------+
//| Выводит отладку состояния советника
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
  return "$" + DoubleToString(money, 2);
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

  if (1 != CopyTime(DEF_SYMBOL, PERIOD_H1, 0, 1, time_array))
  {
    PRINT_LOG(LOG_Error, "can`t get currunt hour array " + TimeToString(time_array[0]) +
      " Err:" + IntegerToString(GetLastError()));
     return false;
  }

  dt = time_array[0];
  return true;
}

//+-----------------------------------------------------------------+
//| Возвращает текущую цену
//+-----------------------------------------------------------------+
bool getCurrentPrice(double &ask, double &bid)
{
  MqlTick last_tick = {0};
   
  if (SymbolInfoTick(DEF_SYMBOL, last_tick))
  {
    ask = last_tick.ask;
    bid = last_tick.bid;
      
    return true;
  } else
    ask = bid = 0.0;
    
    PRINT_LOG(LOG_Error, "can`t get currunt price." +
      " Err:" + IntegerToString(GetLastError()));
   
  return false;
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
   MqlTradeCheckResult resultCheck={0};
   
   //--- parameters of request
   request.action    = TRADE_ACTION_DEAL; // type of trade operation
   request.symbol    = DEF_SYMBOL;        // symbol
   request.type      = order_type;        // order type
   request.volume    = volume;            // volume
   request.price     = price;             // price for opening
   request.tp        = tp;
   request.sl        = sl;
   request.deviation = 5;                 // allowed deviation from the price
   request.magic     = DEF_EXPERT_MAGIC;  // MagicNumber of the order
   request.type_filling = ORDER_FILLING_FOK;

  //--- send the request
  if (OrderCheck(request, resultCheck))
  {
    if (OrderSend(request, result)) {
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
//| Проверяет текущую цену как реальный TP, SL, protected SL
//+------------------------------------------------------------------+
bool checkCurrentPrice(double ask, double bid)
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
        dimension = (tp - op) * input_k_protected_sl;
        
        if (bid >= op + dimension) // если цена близка к TP
        {          
          if (sl < op + param_djitter) // если защитный SL еще не установлен
          {
            // Вычисляем новый SL
            sl = op + param_djitter;
            
            // Сдвигаем защитный SL
            movePositionSLTP(position_ticket, tp, sl);
          }
        }
        
      } else { /* POSITION_TYPE_SELL */

        dimension = (op - tp) * input_k_protected_sl;
        
        if (ask <= op - dimension) // если цена близка к TP
        {          
          if (sl > op - param_djitter) // если защитный SL еще не установлен
          {
            // Вычисляем новый SL
            sl = op - param_djitter;
            
            // Сдвигаем защитный SL
            movePositionSLTP(position_ticket, tp, sl);
          }
        }
      }
   }

   return true; // TODO: неверная обработка при кол-ве позиций более одной
}


//+------------------------------------------------------------------+
//| Вычисляем сумму депозита которым можно рискнуть в первом ордере
//+------------------------------------------------------------------+
double calcFirstDepositRisk()
{
  /*return AccountInfoDouble(ACCOUNT_BALANCE) / MathPow(2, loss_consecutive);*/
  return input_real_balance / MathPow(2, input_cur_attemp);
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
#ifdef DEF_SHOW_DEBUG_STATUS
  CreateLabel(DEF_CHART_ID, label_status, "Balance: ", 0, 5, 20, clrYellow);
  CreateLabel(DEF_CHART_ID, label_trend, "INFO:", 0, 5, 40, clrYellow);
#endif

  setExpertStatus(ESE_WaitOpenDeal); // ожидаем появления позиции
  
  /* handle_alligator = iAlligator(DEF_SYMBOL, DEF_TIMEFRAME, 13, 8, 8, 5, 5, 2, MODE_SMA, PRICE_MEDIAN); */

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
  // Если есть установленная позиция
  if (PositionSelect(DEF_SYMBOL))
  {
    double ask, bid;
        
    getCurrentPrice(ask, bid);    
    checkCurrentPrice(ask, bid);
        
    return;
  }
  
#ifdef DEF_DEBUG_FORCE_OPEN_DEAL
  if (need_open_deal)
  {

    OrderDirectionEnum cur_od;
    double ask, bid, tp, sl;
  
    tp = 0.0;
    sl = 0.0;
    
    // Получаем текущую цену
    getCurrentPrice(ask, bid);
    cur_od = OD_Buy; tp = 1.1498; sl = 0.0;
    /* cur_od = OD_Sell; tp = 1.1420; sl = 0.0; */
    /* dimension = OD_Buy == cur_od ? tp - ask : bid - tp; */

    // Отправляем ордер
    openOrder(OD_Buy == cur_od ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
        0.1, OD_Buy == cur_od ? ask : bid, tp, sl);

    // 13. Ожидаем открытия позиции
    setExpertStatus(ESE_WaitOpenDeal); // ожидаем появления позиции
    EventSetTimer(DEF_WAIT_OPEN_DEAL_TIME); // запускаем таймер, на случай если сервер не открыл позицию
    need_open_deal = false;
  }
#endif

}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
#ifdef DEF_DEBUG_FORCE_OPEN_DEAL
  if (expert_status == ESE_WaitOpenDeal)
  {
    // По какой-то причине сервер не открыл позицию, повторяем попытку открытия сделки
    PRINT_LOG(LOG_Error, "Can`t open DEAL, timer expired");
    need_open_deal = true;
    
    EventKillTimer(); // останавливаем таймер
  }
#endif
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
#ifdef DEF_DEBUG_FORCE_OPEN_DEAL
  switch(trans.type)
  {
    case TRADE_TRANSACTION_HISTORY_ADD:
    {
      if (order_ticket > 0 && trans.order == order_ticket && expert_status == ESE_WaitOpenDeal)
      {
        // Вот здесь и смотрим что произошло

        SET_DEBUG_STATUS("Order open successfull");

        order_ticket = 0;
        setExpertStatus(ESE_DealGuard);
        
        EventKillTimer(); // останавливаем таймер проверки открытия позиции
      }
    } break;
    default: {}
  }
#endif
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
