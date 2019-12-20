//+------------------------------------------------------------------+
//|                                                      se-333.mq5  |
//|                                                    Sergey Bodnya |
//|                                                    se333@ukr.net |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Defines
//+------------------------------------------------------------------+
#define DEF_CHART_ID               0 // default chart identifier(0 - main chart window)
#define DEF_SYMBOL                 Symbol()

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
//| Enums
//+------------------------------------------------------------------+
enum ExpertStatusEnum
{
  ESE_DealGuard, // сделка открыта и советник в режиме охраны
  ESE_WaitOpenDeal // ожидает открытия сделки
};

enum LogLevelEnum
{
  LOG_Error,
  LOG_Warning,
  LOG_Info
};

//+------------------------------------------------------------------+
//| Constant parameters
//+------------------------------------------------------------------+
const double param_real_dist_stop  = 0.0010; // расстояние от установленного TP до реальных стопов(SL/TP)
const double param_djitter         = 0.0003; // джитер при котором не изменяются SL/TP

const string label_status = "labelStatus";
const string label_trend = "labelTrend";

const string log_level_names[] = {"ERROR", "WARNING", "INFO"};

const string trend_name_template = "TREND";

//+------------------------------------------------------------------+
//| Static parameters
//+------------------------------------------------------------------+
ulong order_ticket = 0;
ExpertStatusEnum expert_status = ESE_WaitOpenDeal; // статус эксперта

#ifdef DEF_SHOW_DEBUG_STATUS
string text_debug_status;
#endif

//+-----------------------------------------------------------------+
//| Проверяет что цена не установлена
//+-----------------------------------------------------------------+
bool isZeroPrice(double price)
{
  return price < 0.0001;
}

//+-----------------------------------------------------------------+
//| Преобразовывает цену в строку
//+-----------------------------------------------------------------+
string priceToStr(double price)
{
  return DoubleToString(price, _Digits - 1);
}

//+-----------------------------------------------------------------+
//| Преобразовывает деньги в строку
//+-----------------------------------------------------------------+
string moneyToStr(double money)
{
  return "$" + DoubleToString(money, 2);
}

//+-----------------------------------------------------------------+
//| Преобразовывает обьем в строку
//+-----------------------------------------------------------------+
string volumeToStr(double volume)
{
  return "v" + DoubleToString(volume, 2);
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
//| Преобразовывает номер тикета в строку
//+-----------------------------------------------------------------+
string ticketToStr(ulong ticket)
{
  return "#" + IntegerToString(ticket);
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

//+-----------------------------------------------------------------+
//| Преобразовывает тип позиции в строку
//+-----------------------------------------------------------------+
string positionTypeToStr(ENUM_POSITION_TYPE position_type)
{
  string str;

  switch (position_type)
  {
    case POSITION_TYPE_BUY:          { str = "BUY"; } break;
    case POSITION_TYPE_SELL:         { str = "SELL"; } break;
    default:                         { str = "INVALID POSITION TYPE"; }
  }
  return str;
}

//+-----------------------------------------------------------------+
//| Отправляет письмо
//+-----------------------------------------------------------------+
bool SendActionMail(string subject, string some_text)
{
  return SendMail(subject, some_text);
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
    moneyToStr(calcDepositRisk()) + "] " +
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
void printLog(LogLevelEnum level_log, string fn_name, int fn_line, string text)
{
  PrintFormat("%s: %s():%d>> %s", log_level_names[level_log], fn_name, fn_line, text);

#ifdef DEF_SHOW_EXPERT_STATUS
  showExpertStatus(expert_status, text);
#endif
}

//+-----------------------------------------------------------------+
//| Выводит результат работы
//+-----------------------------------------------------------------+
#define PRINT_LOG(log_level, str) printLog(log_level, __FUNCTION__, __LINE__, str);
#define PRINT_DEBUG(log_level, str) printLog(log_level, __FUNCTION__, __LINE__, str);
#define PRINT_RESULT(result) printLog(LOG_Info, __FUNCTION__, __LINE__, StringFormat("retcode=%u; deal=%I64u; order=%I64u", result.retcode, result.deal, result.order));

//+------------------------------------------------------------------+
//| Создает метку на экране
//+------------------------------------------------------------------+
void CreateLabel(long chart_id, string name, string text, int corner, int x, int y,
                 color tc = CLR_NONE, int fs = 9, string fn = "Arial")
{
  if (ObjectFind(chart_id, name)<0)
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
      PRINT_LOG(LOG_Error, "can not create new object" + "");
  }
}

//+-----------------------------------------------------------------+
//| Устанавливает текст в метке
//+-----------------------------------------------------------------+
void setLabelText(long chart_id, string name, string text)
{
  ObjectSetString(chart_id, name, OBJPROP_TEXT, text);
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

//+------------------------------------------------------------------+
//| Возвращает текущий минуту
//+------------------------------------------------------------------+
bool getCurrentMinute(datetime &dt)
{
  datetime time_array[1];

  if (1 != CopyTime(DEF_SYMBOL, PERIOD_M1, 0, 1, time_array))
  {
    PRINT_LOG(LOG_Error, "can`t get currunt minute array " + TimeToString(time_array[0]) +
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
            HistoryDealGetString(ticket, DEAL_SYMBOL) == DEF_SYMBOL)
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
bool openPosition(ENUM_POSITION_TYPE type, double volume, double ask, double bid, double tp, double sl)
{
  MqlTradeResult  result = {0};
  MqlTradeRequest request = {0};
  MqlTradeCheckResult resultCheck = {0};

  // Parameters of request
  request.action    = TRADE_ACTION_DEAL; // type of trade operation
  request.symbol    = DEF_SYMBOL;        // symbol
  request.type      = type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL; // order type
  request.volume    = volume;            // volume
  request.price     = type == POSITION_TYPE_BUY ? ask : bid; // price for opening
  request.tp        = tp;
  request.sl        = sl;
  request.deviation = 5;                 // allowed deviation from the price
  request.type_filling = ORDER_FILLING_FOK;

  order_ticket = 0; // сбрасываем номер ордера

  PRINT_LOG(LOG_Info, positionTypeToStr(type) + " " + volumeToStr(volume) + " " + priceToStr(ask) + "/" + priceToStr(bid) + " tp=" + priceToStr(tp) + " sl=" + priceToStr(sl));

  // Send the request
  if (OrderCheck(request, resultCheck))
  {
    if (OrderSend(request, result)) {
      if (result.retcode == TRADE_RETCODE_DONE ||
          result.retcode == TRADE_RETCODE_PLACED)
      {
        if (result.order > 0)
        {
          order_ticket = result.order;
          PRINT_LOG(LOG_Info, ticketToStr(order_ticket) + " sent in sync mode, successful");

          return true;
        }
      }
    } else
      PRINT_LOG(LOG_Error, ticketToStr(order_ticket) + " error: " + IntegerToString(GetLastError()));
  } else
    PRINT_LOG(LOG_Error, ticketToStr(order_ticket) + " error: " + IntegerToString(GetLastError()));

  return false;
}

//+------------------------------------------------------------------+
//| Сдвигает SL и/или TP у откытой позиции
//+------------------------------------------------------------------+
bool movePositionSLTP(ulong ticket, double tp, double sl)
{
  MqlTradeResult result = {0};
  MqlTradeRequest request = {0};
  MqlTradeCheckResult resultCheck = {0};

  // Установка параметров операции
  request.action   = TRADE_ACTION_SLTP; // тип торговой операции
  request.position = ticket;            // тикет позиции
  request.symbol   = DEF_SYMBOL;        // символ
  request.sl       = sl;                // Stop Loss позиции
  request.tp       = tp;                // Take Profit позиции

  PRINT_LOG(LOG_Info, ticketToStr(ticket) + " tp=" + priceToStr(tp) + " sl=" + priceToStr(sl));

  // Send the request
  if (OrderCheck(request, resultCheck))
  {
    if (OrderSend(request, result)) {
      if (TRADE_RETCODE_DONE == result.retcode ||
          TRADE_RETCODE_PLACED == result.retcode)
      {
        PRINT_LOG(LOG_Info, ticketToStr(ticket) + " successful");
        return true;
      }
    } else
      PRINT_LOG(LOG_Error, ticketToStr(ticket) + " error: " + IntegerToString(GetLastError()));
  } else
    PRINT_LOG(LOG_Error, ticketToStr(ticket) + " error: " + IntegerToString(GetLastError()));

  return false;
}

//+------------------------------------------------------------------+
//| закрывает позицию указанного обьема
//+------------------------------------------------------------------+
bool closePosition(ENUM_POSITION_TYPE type, ulong ticket, double volume, double ask, double bid)
{
  MqlTradeResult result = {0};
  MqlTradeRequest request = {0};
  MqlTradeCheckResult resultCheck = {0};

  request.action = TRADE_ACTION_DEAL;
  request.position = ticket;
  request.symbol = DEF_SYMBOL;
  request.volume = volume;
  request.deviation = 5; // допустимое отклонение от цены
  /* request.magic =EXPERT_MAGIC; */

  PRINT_LOG(LOG_Info, positionTypeToStr(type) + " " + ticketToStr(ticket) + " " + volumeToStr(volume) + " " + priceToStr(ask) + "/" + priceToStr(bid));

  if(POSITION_TYPE_BUY == type)
  {
    request.price = bid;
    request.type = ORDER_TYPE_SELL;
  } else {
    request.price = ask;
    request.type = ORDER_TYPE_BUY;
  }

  // Send the request
  if (OrderCheck(request, resultCheck))
  {
    if (OrderSend(request, result)) {
      if (TRADE_RETCODE_DONE == result.retcode ||
          TRADE_RETCODE_PLACED == result.retcode)
      {
        if (result.order > 0)
        {
          PRINT_LOG(LOG_Info, ticketToStr(ticket) + " successful");
          return true;
        }
      }
    } else
      PRINT_LOG(LOG_Error, ticketToStr(ticket) + " error: " + IntegerToString(GetLastError()));
  } else
    PRINT_LOG(LOG_Error, ticketToStr(ticket) + " error: " + IntegerToString(GetLastError()));

  return false;
}

//+------------------------------------------------------------------+
//| Проверяет текущую цену для реальный TP, SL, protected SL
//+------------------------------------------------------------------+
void checkCurrentPrice(double ask, double bid)
{
   ulong  ticket; // тикет позиции
   double sl, tp, po, volume;
   ENUM_POSITION_TYPE type;
   int i, total = PositionsTotal(); // количество открытых позиций

   // Перебор всех открытых позиций
   for (i = 0; i < total; i++)
   {
      ticket = PositionGetTicket(i);// тикет позиции

      sl = PositionGetDouble(POSITION_SL);  // Stop Loss позиции
      tp = PositionGetDouble(POSITION_TP);  // Take Profit позиции
      po = PositionGetDouble(POSITION_PRICE_OPEN);
      type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);  // тип позиции
      volume = PositionGetDouble(POSITION_VOLUME); // объем позиции
      /*string position_symbol=PositionGetString(POSITION_SYMBOL); // символ
      int    digits=(int)SymbolInfoInteger(position_symbol,SYMBOL_DIGITS); // количество знаков после запятой
      ulong  magic=PositionGetInteger(POSITION_MAGIC); // MagicNumber позиции */

      //--- вывод информации о позиции
      /* PrintFormat("#%I64u %s  open: %s  sl: %s  tp: %s",
                  ticket, EnumToString(type), priceToStr(po), priceToStr(sl), priceToStr(tp)); */

      // 1. Обрабатывем позицию если установлен TP
      if (isZeroPrice(tp))
        continue;

      // 2. Проверяем что цена в зоне реального TP/SL и закрывем всю позицию принудительно
      if ((POSITION_TYPE_BUY == type && (bid > (tp - param_real_dist_stop) || (bid < po - (tp - po) - param_real_dist_stop))) ||
          (POSITION_TYPE_SELL == type && (ask < (tp + param_real_dist_stop) || (ask > po + (po - tp) - param_real_dist_stop))))
      {
        closePosition(type, ticket, volume, ask, bid);
        continue;
      }

      // 3. Убираем пинг-SL, если пинг-SL установлен за дистанцией большей чем TP
      if (!isZeroPrice(sl))
      {
        if ((POSITION_TYPE_BUY == type && (sl < (po - (tp - po)))) ||
            (POSITION_TYPE_SELL == type && (sl > (po + (po - tp)))))
        {
          // Убираем пинг-SL
          PRINT_LOG(LOG_Info, "Delete the ping-SL for " + ticketToStr(ticket));
          movePositionSLTP(ticket, tp, 0.0);
          continue;
        }
      } else { // 4. Проверяем наличие защитного SL, если защитный SL уже установлен, то его никогда не убираем

        if ((POSITION_TYPE_BUY == type && bid >= (po + ((tp - po) * input_k_protected_sl))) ||
            (POSITION_TYPE_SELL == type && ask <= (po - ((po - tp) * input_k_protected_sl))))
        {
          // Вычисляем новый SL
          sl = POSITION_TYPE_BUY == type ? (po + param_djitter) : (po - param_djitter);

          // Устанавливаем защитный SL
          PRINT_LOG(LOG_Info, "Set the protected SL for " + ticketToStr(ticket));
          movePositionSLTP(ticket, tp, sl);
          continue;
        }
      }
   }
}

//+------------------------------------------------------------------+
//| Вычисляем сумму депозита, которым можно рискнуть
//+------------------------------------------------------------------+
double calcDepositRisk()
{
  /* return AccountInfoDouble(ACCOUNT_BALANCE) / MathPow(2, loss_consecutive); */
  return input_real_balance / MathPow(2, input_cur_attemp);
}

//+------------------------------------------------------------------+
//| Проверяет значения точек привязки линии тренда и для пустых |
//| значений устанавливает значения по умолчанию |
//+------------------------------------------------------------------+
void getTrendEmptyPoints(datetime &time1,double &price1,
 datetime &time2,double &price2)
 {
//--- если время первой точки не задано, то она будет на текущем баре
 if(!time1)
 time1=TimeCurrent();
//--- если цена первой точки не задана, то она будет иметь значение Bid
 if(!price1)
 price1=SymbolInfoDouble(Symbol(),SYMBOL_BID);
//--- если время второй точки не задано, то она лежит на 9 баров левее второй
 if(!time2)
 {
 //--- массив для приема времени открытия 10 последних баров
 datetime temp[10];
 CopyTime(Symbol(),Period(),time1,10,temp);
 //--- установим вторую точку на 9 баров левее первой
 time2=temp[0];
 }
//--- если цена второй точки не задана, то она совпадает с ценой первой точки
 if(!price2)
 price2=price1;
 }
 
//+------------------------------------------------------------------+
//| Создает линию тренда по заданным координатам
//+------------------------------------------------------------------+
bool TrendCreate(const long chart_ID=0, // ID графика
    const string name="TrendLine", // имя линии
    const int sub_window=0, // номер подокна
    datetime time1=0, // время первой точки
    double price1=0, // цена первой точки
    datetime time2=0, // время второй точки
    double price2=0, // цена второй точки
    const color clr=clrRed, // цвет линии
    const ENUM_LINE_STYLE style=STYLE_SOLID, // стиль линии
    const int width=1, // толщина линии
    const bool back=false, // на заднем плане
    const bool selection=true, // выделить для перемещений
    const bool ray_left=false, // продолжение линии влево
    const bool ray_right=false, // продолжение линии вправо
    const bool hidden=true, // скрыт в списке объектов
    const long z_order=0) // приоритет на нажатие мышью
{
  
  //--- создадим трендовую линию по заданным координатам
  if(!ObjectCreate(chart_ID,name,OBJ_TREND,sub_window,time1,price1,time2,price2))
  {
    Print(__FUNCTION__, ": не удалось создать линию тренда! Код ошибки = ",GetLastError());
    return(false);
  }
  
  //--- установим цвет линии
  ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
  //--- установим стиль отображения линии
  ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);
  //--- установим толщину линии
  ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width);
  //--- отобразим на переднем (false) или заднем (true) плане
  ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
  //--- включим (true) или отключим (false) режим перемещения линии мышью
  //--- при создании графического объекта функцией ObjectCreate, по умолчанию объект
  //--- нельзя выделить и перемещать. Внутри же этого метода параметр selection
  
  //--- по умолчанию равен true, что позволяет выделять и перемещать этот объект
  ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
  ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
  //--- включим (true) или отключим (false) режим продолжения отображения линии влево
  ObjectSetInteger(chart_ID,name,OBJPROP_RAY_LEFT,ray_left);
  //--- включим (true) или отключим (false) режим продолжения отображения линии вправо
  ObjectSetInteger(chart_ID,name,OBJPROP_RAY_RIGHT,ray_right);
  //--- скроем (true) или отобразим (false) имя графического объекта в списке объектов
  ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
  //--- установим приоритет на получение события нажатия мыши на графике
  ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
  //--- успешное выполнение
  
  return(true);
}
//+------------------------------------------------------------------+

#define TREND_POINTS_CNT 2

class Trend {
  public:
    Trend(datetime dt0, double price0,datetime dt1, double price1);
    
    void setPoint(int index, datetime dt, double price);
    void getPoint(int index, datetime &dt, double &price);
    
    double getTrendPriceByDatetime(datetime dt);
    
    int getTrendPoints() { return TREND_POINTS_CNT; }
    
  private:  
    struct TrendPoint {
      datetime dt;
      double price;
    };

    TrendPoint points[TREND_POINTS_CNT];
};
//+------------------------------------------------------------------+

Trend::Trend(datetime dt0, double price0,datetime dt1, double price1)
{  
  setPoint(0, dt0, price0);
  setPoint(1, dt1, price1);
}
//+------------------------------------------------------------------+

void Trend::setPoint(int index, datetime dt, double price)
{
  if (index < TREND_POINTS_CNT)
  {
    points[index].dt = dt;
    points[index].price = price;
    
    PRINT_DEBUG(LOG_Info, "Trend::setPoint[" + IntegerToString(index) + "] dt=" + IntegerToString(dt)+ " " + TimeToString(dt) + " price=" + DoubleToString(price));
    
  } else
    PRINT_LOG(LOG_Error, "invalid index");
}
//+------------------------------------------------------------------+

void Trend::getPoint(int index, datetime &dt, double &price)
{
  if (index < TREND_POINTS_CNT)
  {
    dt = points[index].dt;
    price = points[index].price;
  } else
    PRINT_LOG(LOG_Error, "invalid index");
}
//+------------------------------------------------------------------+

double Trend::getTrendPriceByDatetime(datetime dt)
{
  // double getLineX(double x1, double y1, double x2, double y2, double y)
  //   return (y-y1)/(y2-y1)*(x2-x1)+x1;
  
  // Проверка: должен быть 2.0 при правильной работе функции getTrendPriceByDatetime(3)
  // Trend trend_debug(1, 1.0, 5, 3.0);
  // PRINT_LOG(LOG_Info, "OnChartEvent: dt_curr_debug:" + " price=" + priceToStr(trend_debug.getTrendPriceByDatetime(3)));
      
  // return ((double)(dt-points[0].dt))/(((double)(points[1].dt-points[0].dt))*(points[1].price-points[0].price)+points[0].price);
  return ((double)(dt-points[0].dt))/((double)(points[1].dt-points[0].dt))*(points[1].price-points[0].price)+points[0].price;
}
//+------------------------------------------------------------------+

// #include <Generic\ArrayList.mqh>

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  // CArrayList<int> arrayList = new CArrayList<int>();
  
 //SendNotification("TEST-111"); 
 // double x = getLineX(1.0, 1.0, 5.0, 3.0,   2.0); x - должен быть 3.0 при правильной работе функции
 // Трендовая линия OBJ_TREND ObjectGetTimeByValue

  /*datetime time1; double price1; datetime time2; double price2;  
  getTrendEmptyPoints(time1, price1, time2, price2);
  TrendCreate(DEF_CHART_ID, trend_line_name_up, 0, time1, price1, time2, price2);*/
 


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

    ENUM_POSITION_TYPE type;
    double ask, bid, tp, sl;

    tp = 0.0;
    sl = 0.0;

    // Получаем текущую цену
    getCurrentPrice(ask, bid);    
    if (bid < 1.1490)
      return;
      
    /* type = POSITION_TYPE_BUY; tp = 1.1490; sl = 1.1412; */
    type = POSITION_TYPE_SELL; tp = 1.1450; sl = 1.1543;

    // Открываем позицию
    openPosition(type, 0.1, ask, bid, tp, sl);

    // Ожидаем открытия позиции
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
  if (id == CHARTEVENT_OBJECT_DRAG)
  {
    if (StringFind(sparam, trend_name_template) >= 0 && ObjectFind(DEF_CHART_ID, sparam) >= 0)
    {
      datetime dt[TREND_POINTS_CNT], dt_curr;
      double price[TREND_POINTS_CNT];
      string trend_name = sparam;
      
      dt[0] = (datetime)ObjectGetInteger(DEF_CHART_ID, trend_name, OBJPROP_TIME, 0);
      dt[1] = (datetime)ObjectGetInteger(DEF_CHART_ID, trend_name, OBJPROP_TIME, 1);

      price[0] = ObjectGetDouble(DEF_CHART_ID, trend_name, OBJPROP_PRICE, 0);
      price[1] = ObjectGetDouble(DEF_CHART_ID, trend_name, OBJPROP_PRICE, 1);

      PRINT_LOG(LOG_Info, "OnChartEvent:" + IntegerToString(id) + " Found trend:" + sparam);
      
      Trend trend(dt[0], price[0], dt[1], price[1]);
      
      dt_curr = TimeCurrent();      
      
      PRINT_LOG(LOG_Info, "OnChartEvent: dt_curr:" + TimeToString(dt_curr) + " price=" + priceToStr(trend.getTrendPriceByDatetime(dt_curr)));


    }
  }
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
