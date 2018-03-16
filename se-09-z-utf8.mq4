//+------------------------------------------------------------------+
//|                                                      se-09-z.mq4 |
//|                               Copyright 2012-2013, Bodnya Sergey |
//|                                                    se333@ukr.net |
//+------------------------------------------------------------------+

string str_make_expert = "26/11/13 21:31"; // 1. EUR/USD
//string str_make_expert = "04/04/13 11:45"; // 1. Закоментировано удаление ограничиваюего ордера при параметре 0.0
//string str_make_expert = "14/03/13 11:26"; // 1. Сдвинуты ограничивающие ордера на 0.0300, перенесен пинг-ордер на 1,4700
//string str_make_expert = "25/10/12 17:43"; // 1. Затирка стоп-лосс ордеров удалена 2. Изменился механизм установки ограничения на открытия ордеров. 3. Добавлена проверка работы советника(ping). 4. Добавлена проверка правильности баров в истории.
//string str_make_expert = "14/09/12 10:32"; // 1. Немного изменены коэф. 2. Добавлена возможность, менять шрифт меток
//string str_make_expert = "12/09/12 10:46"; // 1. Добавлена возможность, менять положение меток на экране через свойства советника
//string str_make_expert = "10/09/12 14:25"; // 1. Изменены коэф.
//string str_make_expert = "09/09/12 09:17"; // 1. Добавлен параметр зона заморозки для ордеров маленького обьема
//string str_make_expert = "04/09/12 13:47"; // 1. Обрабатывается уровень маржи 60%, при снижении которого начинают принудительно закрывать самые убыточные ордера
//string str_make_expert = "30/08/12 09:53"; // 1. Стало возможным на другом терменале смотреть все переменные которые вычисляет советник, но не вмешиваться в торговлю. Используется переменная user_trade_on_.
//string str_make_expert = "24/08/12 05:05"; // 1. Зона заморозки изменено понятие, теперь для каждой сессии, а не для всего торгового дня. 2. Новый параметр коефю использования баланса
//string str_make_expert = "21/08/12 17:03"; // 1. Исправлена ошибка при установке пользователем расстояние до тейк-профита.
//string str_make_expert = "20/08/12 18:20"; // 1. Разделена переменная multi_lot_dist на две. 2. Заменена проверка цены открытия последнего ордера. 3. Добавлен параметр trande_exist_rebound_max_k, который говорит, если есть тренд и был большой отскок, то ордера против тренда не устанавливать.
//string str_make_expert = "19/08/12 19:01"; // 1. dist_open_second_small_k = 2.7 вместо 2.5; 2. Расставлены пределы изменения коэф. .
//string str_make_expert = "18/08/12 11:32"; // 1. Учитывается спред при определении цены фрактала для BUY; 2. Подобраны новые коэф. 3. Фиксируется пользовательский тейк-профит на все время работы советника
//string str_make_expert = "16/08/12 06:42";

//#property copyright "Copyright 2012, Bodnya Sergey"
//#property link      "se333@ukr.net"

string symbol = "EURUSD";

string label_buy  = "LabelBuy";
string label_sell = "LabelSell";

string label_spread = "LabelSpread";
string label_balance = "LabelBalance";

string label_user_man = "LabelUserMan";
string label_set      = "LabelSet";
string label_set2     = "LabelSet2";
string label_trande   = "LabelTrande";
string label_session  = "LabelSession";

string line_dist_open_buy  = "LineDistOpenBuy";
string line_dist_open_sell = "LineDistOpenSell";

string line_dist_open_limit_buy  = "LineDistOpenLimitBuy";
string line_dist_open_limit_sell = "LineDistOpenLimitSell";

string line_dist_open_limit_sh_buy  = "LineDistOpenLimitShadowBuy"; // для затемнения отложеных ордеров, которые используются для ограничения
string line_dist_open_limit_sh_sell = "LineDistOpenLimitShadowSell";

string line_stop_loss_buy  = "LineStopLossBuy";
string line_stop_loss_sell = "LineStopLossSell";

string info_buy  = "InfoBuy";
string info_sell = "InfoSell";

string arrow_buy  = "ArrowBuy";
string arrow_sell = "ArrowSell";

string label_make_expert = "LabelMakeExpert";

//string label_debug = "LabelDebug";

int line_style_dist_open       = STYLE_DASH;
int line_style_dist_open_limit = STYLE_SOLID;
int line_style_stop_loss       = STYLE_DOT;

string font_name = "Courier New";
//string font_name = "Arial Black";
//string font_name = "Arial Narrow";

color color_label = Aqua; // цвет меток
color color_text  = Gold; // цвет текста
color color_limit = LightSalmon; // цвет линий ограничения открытия ордеров

#define ARROW_TRIANGL_LOW 0 // минимум
#define ARROW_TRIANGL_HIGH 1 // максимум
#define ARROW_TRIANGL_REBD_BEGIN  2 // отскок начало
#define ARROW_TRIANGL_REBD_END    3 // отскок конец

#define USER_ORDER_LIMIT_OFFSET 0.0300 // смещение, для установки граничения для открытия ордеров

#define SESSION_INDEX_INVALID -1 // неправильный индекс сессии

#define PING_ORDER_TYPE OP_SELLSTOP // тип пинг-ордера
#define PING_PRICE      1.2700      // цена, на которой устанавливается пинг-ордер

// 1. Переменные для прогнозирования следующего бара

int bar_cnt_days = 5; // кол-во дней для прогнозирования бара

// 1.1 Переменные для прогнозирования ВЫСОТЫ бара
// (доля текущего, предыдущего и следующего часа за несколько дней, а также доля часа этого дня ранее)

double bar_height_part_cur   = 60.0; // высота бара текущего часа за несколько дней
double bar_height_part_prev  = 10.0; // высота бара предыдущего часа за несколько дней
double bar_height_part_next  = 10.0; // высота бара следующего часа за несколько дней
double bar_height_part_early = 30.0; // высота бара часом ранее

// 1.2 Коэффициенты дистанция открытия ордеров и дистанция тейк-профита

extern double curve_dist_open_k     = 0.33; // (0.33-0.37) коэффициент открытия ордеров относительно прогнозной высоты
extern double curve_dist_tp_k       = 0.5; // (0.8-1.2) коэффициент тейк-профита относительно прогнозной высоты
//extern double curve_dist_redound_k  = 1.20; // коэффициент установки отложеных ордеров относительно прогнозной высоты бара за предыдущие дни

// 1.3 Огранечители ( borders )

extern double multi_lot_min        = 2.0;    // (3.0-5.0) минимальное значения умножения лотов
extern double multi_lot_max        = 3.0;    // (5.0-7.0) максимальное значения умножения лотов
extern double multi_lot_dist_force = 0.0050; // (0.0040-0.0070) расстояние после которого, принудительно(после 0.0050) включается умножение лотов
extern double multi_lot_dist_curve = 0.0180; // (0.0050-0.0100) расстояние которое характеризует наклон прямой умножения, начиная от точки multi_lot_dist_force и в диопазане от multi_lot_min до multi_lot_max.

extern int orders_small_max        = 3; // (4-6) максимальное кол-во ордеров маленького обьема
extern int orders_sessions_big_max = 2; // (2-4) максимальное кол-во открытых ордеров большого обьема в одном торговом дне

extern double dist_open_freez_zone_small_k = 0.14; // (0.0 - 0.2) зона заморозки - процент от дневной высоты бара, который показывает что в этой зоне нельзя выставлять ордера так как близко к точке безубыточности
extern double dist_open_freez_zone_big_k   = 0.70; // (0.0 - 0.2) зона заморозки - процент от дневной высоты бара, который показывает что в этой зоне нельзя выставлять ордера так как близко к точке безубыточности
extern double dist_open_second_small_k     = 1.00; // (1.5-3.0) коэффициент для дистанции открытия второго ордера маленького обьема в сессии
extern double dist_open_second_big_k       = 1.00; // (2.0-3.0) коэффициент для дистанции открытия второго ордера большого обьема в сессии
extern double dist_open_last_small_k       = 1.5;  // (1.1-1.8) коэффициент для дистанции открытия последнего ордера(когда открыто более 50%) маленького обьема в торговом дне
extern double dist_open_last_big_k         = 2.0;  // (3.0-4.5) коэффициент для дистанции открытия последнего ордера большого обьема в торговом дне

extern double session_dist_open_min     = 0.0005; // (0.0003-0.0007) минимальное расстояние от цены для открытия ордеров в сессии
extern double session_dist_open_max     = 0.0015; // (0.0010-0.0016) максимальное расстояние от цены для открытия ордеров в сессии

extern double session_dist_tp_small_min  = 0.0010; // (0.0010-0.0012) минимальное расстояние от точки безубыточности до цены тейк-профита в сессии
extern double session_dist_tp_small_max  = 0.0026; // (0.0022-0.0030) максимальное расстояние от точки безубыточности до цены тейк-профита в сессии
extern double session_dist_tp_big_min    = 0.0012; // (0.0016-0.0022) минимальное расстояние от точки безубыточности до цены тейк-профита в сессии
extern double session_dist_tp_big_max    = 0.0018; // (0.0022-0.0036) максимальное расстояние от точки безубыточности до цены тейк-профита в сессии

extern int fractal_timeframe  = PERIOD_M1; // время для фракталов

/*extern double trande_exist_distance      = 0.0110; // дистанция показывающее, что существует тренд ( разница между максимальной и минимальной ценой за сутки )
extern double trande_exist_cur_k         = 0.82;   // (0-1) коэф. показывающий, что существует тренд ( цена отошла более чем на 83% от дистанции )
extern double trande_exist_rebound_min_k = 0.26;   // (0-1) коэф. показывающий, что на тренде уже начались отскоки более 28% дистанции
extern double trande_exist_rebound_max_k = 0.55;   // (0-1) коэф. показывающий, что на сильном тренде были отскоки более 45% дистанции, ставить ордера опасно
extern double trande_exist_off           = 0.0160; // расстояние показывающее, что существует сильный тренд, не было отскока и нужно отключить запрет высталять ордера
extern double trande_exist_direct_k      = 0.026;  // (0-1) коэф. показывающий, что существует сильный тренд для прямого (по тренду) направления торговли
extern double trande_exist_reverse_k     = 0.06;   // (0-1) коэф. показывающий, что существует сильный тренд для противоположного направления торговли
*/
// 1.4 Временной период когда можно открывать ордера(сессии)

extern int sessions_time_begin  = 22; // 22:00, время начала сессий
extern int sessions_time_end    = 08; // 08:00, время конца сессий

// 1.5. Магические номера

extern int magic_number = 0; // магик номер для ордеров ( 0 - все ордера )

// 2. СТРАТЕГИЯ: ВОЗВРАТ К СРЕДНЕМУ (Limit)

//int allow_fractals       = 1; // (1 - разрешает; 0 - запрещает) использовать фракталы при выходе на рынок
    
// 3. СТРАТЕГИЯ: ПРОБОЙ (Stop)

//double sleep_ac = 0.0; // сон для ускорения цены
//double sleep_ao = 0.0; // сон для движущей силы
//double sleep_al = 0.0; // сон для алигатора

//extern int shifts_stop = 3; // кол-во периодов сна

// 4. Управление балансом

extern double orders_volume_max_k   = 22.0; // (30.0-40.0) максимально разрешенный обьем, во сколько раз можно умножить обьем относительно первого ордера
extern double orders_drawdown_max_k = 0.22; // (0.45-0.60) максимальный процент просадки, тостигнув которой прекращается установка ордеров
extern double balance_first_k       = 0.018; // коэф.(процент) начальной суммы денег для первого ордера от баланса
extern double balance_use_k         = 1.00;  // коэф.(процент) использования баланса

// 5. Для ручного управления

extern string S1 = "--- User manual trade ---";

extern bool user_trade_on_sell     = true; // разрешает торговать ордерами на продажу (для ручного управления)
extern bool user_trade_on_buy      = true; // разрешает торговать ордерами на покупку (для ручного управления)

extern double user_change_tp_sell = 0.0; // изменяет тейк-профит в открытых ордерах на указаное расстояние ( 0.0 - отключен )
extern double user_change_tp_buy  = 0.0; // изменяет тейк-профит в открытых ордерах на указаное расстояние ( 0.0 - отключен )

// Теперь настраивается с помощью отложеных ордеров обьемом 0.01 лот и установленных на расстоянии 100 пунктов.
extern double user_price_open_limit_sell = 0.0; // ограничивает цену открытия ордера ( 0.0 - ограничие отключено )
extern double user_price_open_limit_buy  = 0.0; // ограничивает цену открытия ордера ( 0.0 - ограничие отключено )

//extern double change_sl_buy  = 0.0; // изменяет стоп-лосс в открытых ордерах на указаное расстояние ( 0.0 - удалить )
//extern double change_sl_sell = 0.0; // изменяет стоп_лосс в открытых ордерах на указаное расстояние ( 0.0 - удалить )

// 6. Положение меток на экране

extern string S2 = "--- Labels position ---";

extern int font_size = 8;   // размер шрифта
extern int string_dist = 15; // расстояние между строками меток на экране

extern int position_session_x =  5; 
extern int position_session_y = 20;

extern int position_balance_x =  5; 
extern int position_balance_y = 20;

extern int position_settings_x =  5; 
extern int position_settings_y = 10;


// Глобальные переменные

datetime bar_time_old = 0; // прошлое время бара

bool user_trade_on_old_sell     = true; // прошлое значение параметра; разрешает торговать ордерами на продажу (для ручного управления)
bool user_trade_on_old_buy      = true; // прошлое значение параметра; разрешает торговать ордерами на покупку (для ручного управления)

double user_change_tp_old_sell = 0.0; // изменяет тейк-профит в открытых ордерах на указаное расстояние ( 0.0 - отключен )
double user_change_tp_old_buy  = 0.0; // изменяет тейк-профит в открытых ордерах на указаное расстояние ( 0.0 - отключен )

double user_price_open_limit_old_sell = 0.0; // ограничивает цену открытия ордера ( 0.0 - ограничие отключено )
double user_price_open_limit_old_buy  = 0.0; // ограничивает цену открытия ордера ( 0.0 - ограничие отключено )

                                            // Расчет на основе анализа истории                                   
double session_dist_zone_freez_small = 0.0; // вычисляет зону заморозки
double session_dist_zone_freez_big   = 0.0; // вычисляет зону заморозки
double session_dist_open             = 0.0; // расстояние от цены для открытия ордеров в сессии
double session_dist_tp               = 0.0; // расстояние тейк-профита ордеров для текущей сессии

int trade_disable_buy  = 0; // запрет на установку нового ордера покупки (в часах)
int trade_disable_sell = 0; // запрет на установку нового ордера продажи (в часах)

bool trande_exist_buy  = false; // флаг наличия тренда покупки в торговом дне
bool trande_exist_sell = false; // флаг наличия тренда продажи в торговом дне

double trande_exist_direct_buy  = 0.0; // ограничитель открытия ордера в прямом направлении при наличии тренда
double trande_exist_direct_sell = 0.0; // ограничитель открытия ордера в прямом направлении при наличии тренда

double trande_exist_reverse_buy  = 0.0; // ограничитель открытия ордера в противоположном направлении при наличии тренда
double trande_exist_reverse_sell = 0.0; // ограничитель открытия ордера в противоположном направлении при наличии тренда

double trande_day_buy          = 0.0; // информация о тренде
double trande_day_sell         = 0.0;
double trande_cur_buy          = 0.0;
double trande_cur_sell         = 0.0;
double trande_rebound_max_buy  = 0.0;
double trande_rebound_max_sell = 0.0;

double allow_price_buy  = 0.0; // разрешенная цена покупки следующего ордера
double allow_price_sell = 0.0; // разрешенная цена продажи следующего ордера

double allow_volume_buy  = 0.0; // разрешенный обьем следующего ордера покупки
double allow_volume_sell = 0.0; // разрешенный обьем следующего ордера продажи

double allow_dist_tp_buy  = 0.0; // разрешенное расстояние до тейк-профита для текущей сессии
double allow_dist_tp_sell = 0.0; // разрешенное расстояние до тейк-профита для текущей сессии

double orders_tp_buy      = 0.0; // общая цена тейк-профита для всех открытых ордеров
double orders_tp_sell     = 0.0; // общая цена тейк-профита для всех открытых ордеров

bool orders_open_buy  = true; // есть открытые ордера
bool orders_open_sell = true; // есть открытые ордера

string off_reason_buy;  // причина запрета открывать ордера
string off_reason_sell; // причина запрета открывать ордера

double digits_step = 0.0; // шаг изменения цены

double lot_min = 0.0; // минимальный лот
int lot_precision = 0; // до какого знака округляется обьем
int sessions_cnt = 0; // кол-во непрерывных сессий 

double stop_level = 0.00019; // минимальное расстояние стопов в пунктах от цены

bool bars_history_valid = true; // правильность баров в истории

// Для быстрого тестирования

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+

bool MODE_VISUAL  = true;
   
int init()
{ 
  if ( IsTesting() && ! IsVisualMode() )
    MODE_VISUAL = false;
  
  if ( MODE_VISUAL )
  {    
    string str;
    
    // Левый верхний угол

    CreateLabel( "label_session", "SESSION:", 0, position_session_x,       position_session_y, color_label, font_size, font_name );
    CreateLabel( label_session,        "-",   0, position_session_x + 70,  position_session_y, color_text,  font_size, font_name );
        
    CreateLabel( "label_sell", "SELL:",       0, position_session_x,       position_session_y + string_dist, color_label, font_size, font_name );
    CreateLabel( label_sell, "-",             0, position_session_x + 40,  position_session_y + string_dist,  color_text, font_size, font_name );
    
    CreateLabel( "label_buy",  "BUY: ",       0, position_session_x,       position_session_y + string_dist * 2, color_label, font_size, font_name );    
    CreateLabel( label_buy,  "-",             0, position_session_x + 40,  position_session_y + string_dist * 2,  color_text, font_size, font_name );
    
    // Правый верхний угол
    
    CreateLabel( "label_spread", "LEVERAGE/SPREAD:", 1, position_balance_x + 100, position_balance_y,                   color_label, font_size, font_name );
    CreateLabel( label_spread, "-",                  1, position_balance_x,       position_balance_y,                   color_text,  font_size, font_name );
  
    CreateLabel( "label_balance", "BALANCE:",        1, position_balance_x + 155, position_balance_y + string_dist,     color_label, font_size, font_name );
    CreateLabel( label_balance, "-",                 1, position_balance_x,       position_balance_y + string_dist,     color_text,  font_size, font_name );
        
    CreateLabel( "info_sell", "SELL: ",              1, position_balance_x + 170, position_balance_y + string_dist * 2, color_label, font_size, font_name );
    CreateLabel( info_sell,    "-",                  1, position_balance_x,       position_balance_y + string_dist * 2, color_text,  font_size, font_name );
    
    CreateLabel( "info_buy", "BUY: ",                1, position_balance_x + 176, position_balance_y + string_dist * 3, color_label, font_size, font_name );
    CreateLabel( info_buy,    "-",                   1, position_balance_x,       position_balance_y + string_dist * 3, color_text,  font_size, font_name );
    
    // Левый нижний угол
    
    //CreateLabel( "label_debug", "DEBUG:", 2, 5,  90, color_label, font_size, font_name );
    //CreateLabel( label_debug,    "-",     2, 75,  90,  color_text, font_size, font_name );
    
    str = GetStrUserMan();

    CreateLabel( "label_user_man", "USER:", 2,  position_settings_x,      position_settings_y + string_dist * 3, color_label, font_size, font_name );
    CreateLabel( label_user_man,      str,  2,  position_settings_x + 50, position_settings_y + string_dist * 3, color_text,  font_size, font_name );
  
    str = KToStr( curve_dist_open_k, 3 ) + "/" + KToStr( curve_dist_tp_k, 2 ) +
          "; ORD[" + orders_small_max + "/" + orders_sessions_big_max +
          "]; OPEN:" + PriceToStrAsPips( session_dist_open_min ) + "/" + PriceToStrAsPips( session_dist_open_max ) + 
          ", OPEN2[" + KToStr( dist_open_second_small_k, 2 ) + "/" + KToStr( dist_open_second_big_k, 2 ) + "] LAST[" + KToStr( dist_open_last_small_k ) + "/" + KToStr( dist_open_last_big_k ) + "];";

    CreateLabel( "label_set", "SET:",       2,  position_settings_x,      position_settings_y + string_dist * 2, color_label, font_size, font_name );
    CreateLabel( label_set, str,            2,  position_settings_x + 50, position_settings_y + string_dist * 2, color_text,  font_size, font_name );

    str = "TP:" + PriceToStrAsPips( session_dist_tp_small_min ) + "/" + PriceToStrAsPips( session_dist_tp_small_max ) + ", " + 
                    PriceToStrAsPips( session_dist_tp_big_min )   + "/" + PriceToStrAsPips( session_dist_tp_big_max ) + 
          "; MULT:" + KToStr( multi_lot_min ) + "/" + KToStr( multi_lot_max ) + " " + PriceToStrAsPips( multi_lot_dist_force ) + "/" + PriceToStrAsPips( multi_lot_dist_curve ) +
          "; V:"  + KToStr( orders_volume_max_k, 0 ) + 
          "; DD:" + KToStrPercent( orders_drawdown_max_k ) + 
          "; F:"  + KToStrPercent( balance_first_k, 1 ) + "/" + KToStrPercent( balance_use_k ) + ";";

    //CreateLabel( "label_set2", "SET2:",   2, position_settings_x,      position_settings_y + string_dist, color_label, font_size, font_name );
    CreateLabel( label_set2,       str,     2, position_settings_x + 50, position_settings_y + string_dist, color_text,  font_size, font_name );

    str = "ON:" + //PriceToStrAsPips( trande_exist_distance ) + " " + KToStrPercent( trande_exist_cur_k ) +  " " + KToStrPercent( trande_exist_rebound_min_k ) + "/" + KToStrPercent( trande_exist_rebound_max_k ) +
         ", OFF:" + //PriceToStrAsPips( trande_exist_off ) +          
          "; OFFSET:" + //KToStrPercent( trande_exist_direct_k, 1 ) + "/" + KToStrPercent( trande_exist_reverse_k, 1 ) +
          "; FREEZ:" + KToStrPercent( dist_open_freez_zone_small_k ) + "/" + KToStrPercent( dist_open_freez_zone_big_k ) + ";";
    
    CreateLabel( "label_trande", "TRANDE:", 2, position_settings_x,      position_settings_y, color_label, font_size, font_name );
    CreateLabel( label_trande,    str,      2, position_settings_x + 50, position_settings_y, color_text,  font_size, font_name );
      
    // Правый нижний        

    CreateLabel( "label_make_expert", "MAKE:",           3, 105,  10, color_label, 8, font_name );
    CreateLabel( label_make_expert, str_make_expert,     3,   5,  10, color_text,  8, font_name );
    
    // Проверяем правильность истории
  
    bars_history_valid = isValidBarsHistory();  
  }
    
  // 1. Определяем до какого знака округляется обьем
  
  lot_min = MarketInfo( symbol, MODE_MINLOT );
  if ( lot_min <= 0.01 )
    lot_precision = 2;
  else
    lot_precision = 1;   
  
  // 2. Подсчитываем кол-во сессий
  
  if ( IsNightSessions() ) // если ночная торговля
    sessions_cnt = 24 - sessions_time_begin + sessions_time_end;
  else
    sessions_cnt = sessions_time_end - sessions_time_begin;
  
  // 3. Шаг изменения цены
  
  if ( MarketInfo( symbol, MODE_DIGITS ) == 5 )
    digits_step = 0.00001;
  else
    digits_step = 0.0001;
    
  // 4. Сбрасываем прошлое время
  
  bar_time_old = 0; // прошлое время бара  
  
  return (0);
}

//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+

int deinit()
{
  ObjectDelete( "label_session" );
  ObjectDelete( label_session );
        
  ObjectDelete( "label_sell" );
  ObjectDelete( "label_buy" );
        
  ObjectDelete( label_sell );
  ObjectDelete( label_buy );

  ObjectDelete( "label_user_man" );
  ObjectDelete( label_user_man );
  
  
  ObjectDelete( "label_set" );
  ObjectDelete( label_set );

  ObjectDelete( label_set2 );
    
  ObjectDelete( "label_trande" );
  ObjectDelete( label_trande );
      
  ObjectDelete( "label_spread" );
  ObjectDelete( label_spread );
  
  ObjectDelete( "label_balance" );
  ObjectDelete( label_balance );
        
  ObjectDelete( "info_sell" );
  ObjectDelete( info_sell );
    
  ObjectDelete( "info_buy" );
  ObjectDelete( info_buy );

  ObjectDelete( "label_make_expert" );
  ObjectDelete( label_make_expert );
  
  ObjectDelete( line_dist_open_buy );
  ObjectDelete( line_dist_open_sell );

  ObjectDelete( line_dist_open_limit_buy );
  ObjectDelete( line_dist_open_limit_sell );

  ObjectDelete( line_dist_open_limit_sh_buy );
  ObjectDelete( line_dist_open_limit_sh_sell );

  ObjectDelete( line_stop_loss_buy );
  ObjectDelete( line_stop_loss_sell );

  ObjectDelete( arrow_buy );
  ObjectDelete( arrow_sell );

  return (0);
}
//+------------------------------------------------------------------+

int start()
{ 
  if ( ! bars_history_valid )
  {
    SetText( label_session, "Bars history invalid" );
    
    return ( 0 );
  }
    
  // 1. Проверяем новый час или начало торговли
  
  if ( iTime( symbol, PERIOD_H1, 0 ) != bar_time_old ) // если новый час
  {    
    // 1.1. Рассчитываем параметры для сессий
    
    CalcSessionsParams(); 
    
    bar_time_old = iTime( symbol, PERIOD_H1, 0 ); // запоминаем время нового бара
  }

  // 2. Применяем пользовательские настройки
  
  if ( MODE_VISUAL )
  {    
    // 2.1. Проверяем правильность истории
  
    bars_history_valid = isValidBarsHistory();
  
    // 2.2. Проверяем ограничения открытия ордеров установленные пользователем, которые храняться на сервере ДЦ
    
    user_price_open_limit_buy  = CheckUserPriceOpenLimit( OP_BUYLIMIT,  user_price_open_limit_buy,  user_price_open_limit_old_buy  );
    user_price_open_limit_sell = CheckUserPriceOpenLimit( OP_SELLLIMIT, user_price_open_limit_sell, user_price_open_limit_old_sell );
        
    // 2.3. Проверяем наличие изменений от пользователя
    
    if ( user_trade_on_old_buy  != user_trade_on_buy  || // если изменялось разрешение торговли
         user_trade_on_old_sell != user_trade_on_sell ||
                  
         user_change_tp_old_buy  != user_change_tp_buy  ||
         user_change_tp_old_sell != user_change_tp_sell ||

         user_price_open_limit_old_buy  != user_price_open_limit_buy ||
         user_price_open_limit_old_sell != user_price_open_limit_sell ||
         
         user_price_open_limit_buy  != HLinePrice( line_dist_open_limit_buy ) || // нечаяно сдвинулась линия ограничения открытия ордера
         user_price_open_limit_sell != HLinePrice( line_dist_open_limit_sell ) )
         
    {
      // 2.3.1. Рассчитываем параметры для сессий
      
      CalcSessionsParams();
      
      // 2.3.2. Устанавливаем новый тейк-профит указаный пользователем
      
      UserChangeTP( OP_BUY,  user_change_tp_buy,  user_change_tp_old_buy,  orders_tp_buy  );
      UserChangeTP( OP_SELL, user_change_tp_sell, user_change_tp_old_sell, orders_tp_sell );                  

      // 2.3.3. Выставляем горизонтальные линии ограничения покупки и продажи
          
      HLineSet( line_dist_open_limit_buy,  user_price_open_limit_buy,  color_limit, line_style_dist_open_limit );
      HLineSet( line_dist_open_limit_sell, user_price_open_limit_sell, color_limit, line_style_dist_open_limit );

      HLineSet( line_dist_open_limit_sh_buy,  UserPriceToServ( OP_BUYLIMIT,  user_price_open_limit_buy ),  color_limit, line_style_dist_open_limit );
      HLineSet( line_dist_open_limit_sh_sell, UserPriceToServ( OP_SELLLIMIT, user_price_open_limit_sell ), color_limit, line_style_dist_open_limit );
            
      // 2.3.4. Запоминаем параметры торговли
      
      user_trade_on_old_buy = user_trade_on_buy; 
      user_trade_on_old_sell = user_trade_on_sell;

      user_change_tp_old_buy  = user_change_tp_buy;
      user_change_tp_old_sell = user_change_tp_sell;

      user_price_open_limit_old_buy  = user_price_open_limit_buy;
      user_price_open_limit_old_sell = user_price_open_limit_sell;
      
      // 2.3.5. Показываем новые настройки заданые пользователем
      
      SetText( label_user_man, GetStrUserMan() );
    }
    
    // 2.4. Удаляем пинг-ордер
    
    DeletePingOrder();
    
    // 2.5. Показываем информацию о ордерах и счете

    ShowInfo( symbol );
  }
  
  // 3. СТРАТЕГИЯ: ВОЗВРАТ К СРЕДНЕМУ(Limit)
    
  // 3.1. Пытаемся открыть новые ордера

  SessionTrade( OP_BUY,  user_trade_on_buy,  trade_disable_buy,  Ask, Bid, user_change_tp_buy,  user_price_open_limit_buy,  line_dist_open_buy,  label_buy,  arrow_buy,  Blue, trande_exist_buy,  trande_exist_direct_buy,  trande_exist_reverse_sell, trande_day_buy,  trande_cur_buy,  trande_rebound_max_buy,  allow_volume_buy,  allow_price_buy,  allow_dist_tp_buy,  orders_tp_buy,  orders_open_buy,  off_reason_buy );
  SessionTrade( OP_SELL, user_trade_on_sell, trade_disable_sell, Bid, Ask, user_change_tp_sell, user_price_open_limit_sell, line_dist_open_sell, label_sell, arrow_sell, Red,  trande_exist_sell, trande_exist_direct_sell, trande_exist_reverse_buy,  trande_day_sell, trande_cur_sell, trande_rebound_max_sell, allow_volume_sell, allow_price_sell, allow_dist_tp_sell, orders_tp_sell, orders_open_sell, off_reason_sell );
 
  // 3.2. Смещаем тейк-профиты для открытых ордеров в одну цену
  
  OrdersModifyTP( symbol, OP_BUY,  Bid, orders_tp_buy  );  
  OrdersModifyTP( symbol, OP_SELL, Ask, orders_tp_sell );
     
      
  // 4. СТРАТЕГИЯ: ПРОБОЙ(Stop)
  
  /*str = "";
  if ( ticket_buy == TICKET_NO && ticket_sell == TICKET_NO )
  {
    if ( Ask > price_buy && Bid < price_sell ) // если цена внутри высоты прогнозного бара
    {
      if ( isPriceSleep( symbol, fractal_timeframe, sleep_ac, shifts_stop, 
                                                    sleep_ao, shifts_stop,
                                                    sleep_al, shifts_stop, str ) )
      {
        str = "set orders";
      }
    }
    else
      str = "wait price";
  }
  else
    str = "...";

  SetText( label_stop, "STOP: " + str );
  */      

  //SetText( label_debug, MarketInfo( symbol, MODE_STOPLEVEL ) );  
    
  return ( 0 );
}
//+------------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcSessionsParams - вычисляет парамертры для торгового дня и сессий
//+-----------------------------------------------------------------+

void CalcSessionsParams()
{    
    string str;
    int session_index; // индекс текущей сессии
    int session_hours_begin; // кол-во часов до начала сессий    
    double session_height; // высота в сессии
    double height_days; // средняя суточная высота
    double price_open_session_buy, price_open_session_sell; // цена открытия сессии
    
    // 1. Сбрасываем разрешенный обьем, цену и тейк-профит
    
    allow_price_buy = 0.0; 
    allow_price_sell = 0.0;
    
    allow_volume_buy  = 0.0;
    allow_volume_sell = 0.0;
    
    allow_dist_tp_buy   = 0.0;
    allow_dist_tp_sell  = 0.0;

    // 2. Проверяем временной диапазон нахождения на рынке
        
    session_height = 0.0;

    session_dist_zone_freez_small = 0.0;
    session_dist_zone_freez_big   = 0.0;
    
    session_dist_open = 0.0;
    session_dist_tp   = 0.0;

    session_index = SessionIndexByHour( Hour() ); // получаем индекс сессии относительно времени    
 
    // 3. Вычисляем ВЫСОТУ, СМЕЩЕНИЕ и ТЕЙК-ПРОФИТ для этого часа
       
    if ( SESSION_INDEX_INVALID != session_index ) // если разрешено торговать
    {      
      if ( iBars( symbol, PERIOD_H1 ) > bar_cnt_days * 24 )
      {
        int i;        
        double bar_height_cur, bar_height_prev, bar_height_next, bar_height_early; // средняя высота бара за несколько дней: текущего, предыдущего и следующего часа, а также часом ранее        
        
        // 3.2. Вычисляем расстояние зоны заморозки для сессии
          
        for ( i = 1; i <= bar_cnt_days; i++ ) // по всем дням
          height_days = height_days + BarHeight( symbol, PERIOD_D1, 24 * i ); // накапливаем высоту бара
          
        height_days = height_days / bar_cnt_days; // усредняем
                              
        session_dist_zone_freez_small = ND( height_days * dist_open_freez_zone_small_k, Digits ); // вычисляем расстояние заморозки в пипсах
        session_dist_zone_freez_big   = ND( height_days * dist_open_freez_zone_big_k,   Digits ); // вычисляем расстояние заморозки в пипсах

        // 3.3. Определяем прогнозируемую ВЫСОТУ бара
      
        bar_height_cur  = 0.0; // сбрасываем высоту бара
        bar_height_prev = 0.0;
        bar_height_next = 0.0;
      
        for ( i = 1; i <= bar_cnt_days; i++ ) // по всем дням
        {
          bar_height_cur  = bar_height_cur  + BarHeight( symbol, PERIOD_H1, 24 * i ); // накапливаем высоту бара
          bar_height_prev = bar_height_prev + BarHeight( symbol, PERIOD_H1, 24 * i + 1 );
          bar_height_next = bar_height_next + BarHeight( symbol, PERIOD_H1, 24 * i - 1 );
        }
      
        bar_height_cur  = bar_height_cur  / bar_cnt_days; // усредняем
        bar_height_prev = bar_height_prev / bar_cnt_days;
        bar_height_next = bar_height_next / bar_cnt_days;
      
        bar_height_early = BarHeight( symbol, PERIOD_H1, 1 ); // высота бара часом ранее

        session_height = ( bar_height_cur   * bar_height_part_cur +
                           bar_height_prev  * bar_height_part_prev +
                           bar_height_next  * bar_height_part_next +
                           bar_height_early * bar_height_part_early ) /
                         ( bar_height_part_cur +
                           bar_height_part_prev + 
                           bar_height_part_next +
                           bar_height_part_early ); // вычисляем пропорционально долям        
        
        // 3.4. Вычисляем новую дистанцию открытия ордеров
                
        session_dist_open = ND( session_height * curve_dist_open_k, Digits ); // дистанцию открытия ордеров
        
        // Ограничиваем дистанцию открытия ордеров
        
        if ( session_dist_open < session_dist_open_min ) // минимальная высота для сессии
          session_dist_open = session_dist_open_min;
        else if ( session_dist_open > session_dist_open_max ) // максимальная высота для сессии
          session_dist_open = session_dist_open_max;

        // 3.5. Вычисляем новое расстояние тейк-профита
                
        session_dist_tp = ND( session_height * curve_dist_tp_k, Digits ); // расстояние до тейк-профита
                        
        // 3.6. При первой сесии или начале торговли
                
        if ( 0 == session_index || 0 == bar_time_old )
        {
          // 3.6.1. Удаляем стоп-лосс если был установлен отложеный ордер
          
          //OrdersModifySL( symbol, OP_BUY,  0.0 );
          //OrdersModifySL( symbol, OP_SELL, 0.0 );                    
        
          // 3.6.2. Очищаем переменные для информации о тренде
          
          trande_day_buy          = 0.0; 
          trande_day_sell         = 0.0;
          trande_cur_buy          = 0.0;
          trande_cur_sell         = 0.0;
          trande_rebound_max_buy  = 0.0;
          trande_rebound_max_sell = 0.0;
          
          trande_exist_direct_buy  = 0.0;
          trande_exist_direct_sell = 0.0;

          trande_exist_reverse_buy  = 0.0;
          trande_exist_reverse_sell = 0.0;                              
          
          // 3.6.3. Проверяем отсутствие тренда
          
          trande_exist_buy  = TrandeExist( OP_BUY,  session_index, Blue, trande_day_buy,  trande_cur_buy,  trande_rebound_max_buy,  trande_exist_direct_buy,  trande_exist_reverse_buy  );
          trande_exist_sell = TrandeExist( OP_SELL, session_index, Red,  trande_day_sell, trande_cur_sell, trande_rebound_max_sell, trande_exist_direct_sell, trande_exist_reverse_sell );          
        }        
        
        // 3.7 Вычисляем цену открытия сессии
                
        price_open_session_buy  = PriceOpenSessions( OP_BUY,  0 ); // для текущей сессии
        price_open_session_sell = PriceOpenSessions( OP_SELL, 0 ); // для текущей сессии

        // 3.8. Вычисляем новые цены покупки и продажи, а также расстояние ТЕЙК-ПРОФИТ( переменная "c" - это Bid )
        
        off_reason_buy  = CalcSessionAllowParams( OP_BUY,  price_open_session_buy,  price_open_session_sell, user_change_tp_buy,  user_price_open_limit_buy,  TimeCurrent(), trande_exist_buy,  trande_exist_direct_buy,  trande_exist_reverse_sell, allow_volume_buy,  allow_price_buy,  allow_dist_tp_buy ); // вычисляет цену сесси, по которой можно открывать ордер
        off_reason_sell = CalcSessionAllowParams( OP_SELL, price_open_session_sell, price_open_session_buy,  user_change_tp_sell, user_price_open_limit_sell, TimeCurrent(), trande_exist_sell, trande_exist_direct_sell, trande_exist_reverse_buy,  allow_volume_sell, allow_price_sell, allow_dist_tp_sell ); // вычисляет цену сесси, по которой можно открывать ордер

        // 3.9. Вычисляем новую цену тейк-профита в этой сессии для открытых ордеров
        
        CalcSessionTakeProfit( OP_BUY,  user_trade_on_buy,  allow_dist_tp_buy,  orders_tp_buy  );
        CalcSessionTakeProfit( OP_SELL, user_trade_on_sell, allow_dist_tp_sell, orders_tp_sell );
        
        // 3.10. Разрешаем торговлю в это время суток
        
        trade_disable_buy  = 0; // разрешаем торговлю
        trade_disable_sell = 0; // разрешаем торговлю      
      }
      else
        Print( "ERROR: Absent bars of history" );
    }
    else // торговля в это время суток запрещена
    {
      session_hours_begin = CntHoursSessionsBegin( Hour() ); // получаем кол-во часов до начала сессий      
      
      trade_disable_buy  = session_hours_begin; // запрещаем торговлю
      trade_disable_sell = session_hours_begin; // запрещаем торговлю
      
      // Очищаем переменные для информации о тренде
      
      trande_day_buy          = 0.0;
      trande_day_sell         = 0.0;
      trande_cur_buy          = 0.0;
      trande_cur_sell         = 0.0;
      trande_rebound_max_buy  = 0.0;
      trande_rebound_max_sell = 0.0;

      
      trande_exist_direct_buy  = 0.0;
      trande_exist_direct_sell = 0.0;

      trande_exist_reverse_buy  = 0.0;
      trande_exist_reverse_sell = 0.0;            
    }
    
    // 4. Защита при отскоке цены днем
    
    //if ( Hour() == sessions_time_end ) // если торговля закончилась
    //{
    //  DayReboundProtect( OP_BUY,  Ask, Bid );
    //  DayReboundProtect( OP_SELL, Bid, Ask );
   // }    
      
    // 5. Выводим на экран
      
    if ( MODE_VISUAL )
    {      
      // 5.1 Инфо о сессии
          
      if ( SESSION_INDEX_INVALID != session_index )            
        str = session_index;
      else
        str = "*";
                  
      SetText( label_session, str + "(" + Hour()+ ")/" + sessions_cnt + "; H:" + PriceToStr( session_height ) + 
               ", " + PriceToStrAsPips( session_dist_open ) + 
               "/"  + PriceToStrAsPips( session_dist_tp   ) + 
               "; FREEZ:" + PriceToStr( session_dist_zone_freez_small ) + "/" + PriceToStr( session_dist_zone_freez_big ) );
          
      // 5.2 Выставляем горизонтальные линии покупки и продажи
          
      HLineSet( line_dist_open_buy,  allow_price_buy,  color_label, line_style_dist_open );
      HLineSet( line_dist_open_sell, allow_price_sell, color_label, line_style_dist_open );
      
      // 5.3 Показываем цену безубыточности
              
      ArrowSet( arrow_buy,  CalcPriceZeroOrders( OP_BUY ),  Blue );
      ArrowSet( arrow_sell, CalcPriceZeroOrders( OP_SELL ), Red  );
    }
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| SessionTrade - торговля в сесси
//+-----------------------------------------------------------------+
  
void SessionTrade( int order_type, bool trade_on, int trade_disable, double price_open, double price_close, double user_change_tp, double user_price_open_limit,
                   string line_dist_open_name, string label_name, string arrow_name, color order_color, 
                   bool trande_exist, double trande_exist_direct, double trande_exist_reverse, double trande_dist_day, double trande_dist_cur, double trande_rebound_max,
                   double & allow_volume, double & allow_price, double & allow_dist_tp, double & orders_tp, bool & orders_open, string & off_reason )
{
  int ticket;
  string str, str_trande;
  double sl, tp; // общий стоп-лосс и тейк-профит
  double price_zero; // цена безубыточности
  double price_open_session; // цена открытия сессии
  
  // Проверка на открытие новых ордеров
  
  if ( 0 == trade_disable ) // если разрешено открывать ордера
  {       
    // 0. Проверка что все ордера закрылись для пересчета пераметров торговли
  
    if ( orders_open ) // если были открытые ордера
    {
      if ( 0 == OrdersCnt( order_type ) ) // если нет открытых ордеров
      {
        // Вычисляем новые параметры для сессии
          
        price_open_session = PriceOpenSessions( order_type, 0 ); // для текущей сессии
          
        off_reason = CalcSessionAllowParams( order_type, price_open_session, 0.0, user_change_tp, user_price_open_limit, TimeCurrent(), trande_exist, trande_exist_direct, trande_exist_reverse, allow_volume, allow_price, allow_dist_tp );
                       
        if ( MODE_VISUAL )
          HLineSet( line_dist_open_name, allow_price, color_label, line_style_dist_open );
              
        orders_open = false; // фиксируем что все ордера закрыты
      }
    }
    
    if ( MODE_VISUAL )
      allow_price = HLinePrice( line_dist_open_name ); // получаем цену по которой можно открывать ордер
          
    if ( 0.0 < allow_price ) // если есть цена
    {      
      if ( ( OP_BUY == order_type && price_open < allow_price ) || ( OP_SELL == order_type && price_open > allow_price ) ) // если хорошая цена
      { 
        if ( HaveFractal( symbol, order_type, allow_price ) ) // проверяем наличие фрактала
        {
          if ( trade_on ) // если разрешена торговля
          {
            // 1. Вычисляем точку безубыточности всех открытых ордеров и нового еще не открытого ордера
          
            price_zero = CalcPriceZeroOrders( order_type, allow_volume, price_open );
    
            // 2. Получаем значение цены стоп-лосс и тейк-профита
          
            sl = 0.0;
            tp = CalcPriceTakeProfitOrders( order_type, price_zero, allow_dist_tp );
    
            // 3. Открываем новый ордер            
            
            ticket = OrderSend( symbol, order_type, allow_volume, price_open, 3, sl, tp, NULL, magic_number ); // устанавливаем ордер            
          
            if ( ticket > 0 ) // если удалось открыть ордер
            {
              orders_open = true; // фиксируем что есть открытые ордера
             
              if ( OrderSelect( ticket, SELECT_BY_TICKET ) )
              {
                // 4. Запоминаем тейк-профит для этой сессии с учетом открытого нового ордера
              
                orders_tp = OrderTakeProfit();
              
                // 5. Вычисляем новые параметры для сессии
              
                off_reason = CalcSessionAllowParams( order_type, price_open, price_close, user_change_tp, user_price_open_limit, OrderOpenTime(), trande_exist, trande_exist_direct, trande_exist_reverse, allow_volume, allow_price, allow_dist_tp );
              
                // 6. Показываем точку безубыточности
              
                if ( MODE_VISUAL )
                {
                  ArrowSet( arrow_name, price_zero, order_color ); 
                  HLineSet( line_dist_open_name, allow_price, color_label, line_style_dist_open );
                  
                  str = "order open successfull";
                }
              }
              else
              {
                orders_tp = 0.0;
              
                str = MsgErrors( GetLastError() ) + " OrderSelect()";
              
                Print( str );
              }
            }
            else
            {
              str = MsgErrors( GetLastError() ) + "; OrderSend(" + OrderTypeToStr( order_type ) + "): volume=" + DoubleToStr( allow_volume, lot_precision ) + 
                " price=" + PriceToStr( price_open ) + " sl=" + PriceToStr( sl ) + " tp=" + PriceToStr( tp );
          
              Print( str );            
            }
          }
          else
            if ( MODE_VISUAL )
              str = "disable open order";
        }
        else
          if ( MODE_VISUAL )
            str = "wait fractal";
      }
      else
        if ( MODE_VISUAL )
          str = "wait price";
    }
    else
      if ( MODE_VISUAL )
        str = "off (" + off_reason + ")";
  }
  else
    if ( MODE_VISUAL )
      str = "...disable[" + trade_disable + "]";        
    
  if ( MODE_VISUAL )
  {    
    if ( 0.0 < trande_dist_day )
      str_trande = PriceToStrAsPips( -trande_dist_cur ) + "[" + KToStrPercent( -trande_dist_cur / trande_dist_day ) + "]/" + PriceToStrAsPips( trande_dist_day ) + 
            ", "   + PriceToStrAsPips( trande_rebound_max ) + "[" + KToStrPercent( trande_rebound_max / trande_dist_day ) + "]";
    else
      str_trande = "-";

    str = "L:" + DoubleToStr( allow_volume, lot_precision ) + 
      "; " + str_trande +
      " " + PriceToStrAsPips( trande_exist_direct ) + "/" + PriceToStrAsPips( trande_exist_reverse ) + "; TP:" + PriceToStrAsPips( allow_dist_tp ) + " -> " + str;
          
    SetText( label_name, str );
  }
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcSessionAllowParams - вычисляет обьем, цену и тейк-профит ордеров сесси
//+-----------------------------------------------------------------+

string CalcSessionAllowParams( int order_type, double price_open, double price_close, double user_change_tp, double user_price_open_limit, datetime datetime_cur, bool trande_exist, 
                               double trande_exist_direct, double trande_exist_reverse, double & allow_volume, double & allow_price, double & allow_dist_tp )
{   
  double price_zero; // точка безубыточности
  double dist_zero; // расстояние до точки безубыточности
  double dist_open; // расстояние открытия ордера
  double dist_trande; // максимальное расстояние которое прошла цена за этот торговый день
  int orders_total; // общеее кол-во открытых ордеров  
  int orders_sessions; // общеее кол-во открытых ордеров в этом торговом дне
  int orders_session_last; // кол-во открытых ордеров в последней сессии
  int orders_big; // кол-во открытых ордеров большого обьема
  int orders_small; // кол-во открытых ордеров маленького обьема
  double orders_volume; // обьем денег в лотах, всех открытых ордеров
  double orders_volume_k; // коэф. обьем денег в лотах, всех открытых ордеров
  double orders_drawdown; // просадка по ордерам
  double order_volume_first, order_volume_last; // обьем ордера  
  double order_open_price_good; // лучшая цена открытия ордеров
  double order_open_price_last; // цена открытия последнего ордера
  datetime order_open_time_first, order_open_time_last; // время открытия первого и последнего ордера
  string str;  
    
  // 1. Получаем информацию об открытых ордерах
      
  CalcDistanceFromOpenPrice( order_type, price_close, orders_total, orders_volume, orders_drawdown,
                             order_open_price_good,  order_open_price_last,
                             order_volume_first,     order_volume_last,
                             order_open_time_first,  order_open_time_last );  


 // 2. Вычисляем дистанцию тейк-профита для текущей сессии
  
  if ( 0.0 < user_change_tp ) // 2.1. Пользователь указал тейк-профит
  {
    allow_dist_tp = user_change_tp; // устанавливаем указаный пользователем тейк-профит
  }
  else // 2.2 Советник вычисляет тейк-профит
  {
    if ( orders_total >= orders_small_max ) // если ордера большого обьема
    {
      if ( session_dist_tp < session_dist_tp_big_min ) // проверяем на минимальное значение
        allow_dist_tp = session_dist_tp_big_min;
      else if ( session_dist_tp > session_dist_tp_big_max ) // проверяем на максимальное значение
        allow_dist_tp = session_dist_tp_big_max;
      else
        allow_dist_tp = session_dist_tp;  
    }
    else // ордера маленького обьема
    {
      if ( session_dist_tp < session_dist_tp_small_min ) // проверяем на минимальное значение
        allow_dist_tp = session_dist_tp_small_min;
      else if ( session_dist_tp > session_dist_tp_small_max ) // проверяем на максимальное значение
        allow_dist_tp = session_dist_tp_small_max;
      else
        allow_dist_tp = session_dist_tp;
    }
  }
  
  // 3. Запрещаем открывать новые ордера
  
  allow_volume = 0.0;
  allow_price = 0.0;  
  
  // 4. Проверяем отсутствие тренда
  
  if ( ! trande_exist )
  {  
    // 5. Запрещаем открывать большие обьемы во избежения больших просадок
  
    if ( 0.0 < order_volume_first )
      orders_volume_k = orders_volume / order_volume_first;
    else
      orders_volume_k = 0.0;
    
    if ( orders_volume_k < orders_volume_max_k ) // ограничиваем по обьему открытие ордеров
    { 
      if ( 0 == orders_total || ( LotsToMoney( orders_drawdown ) / CalcAccountBalanceUse() ) > - orders_drawdown_max_k ) // если просадка ниже максимального значения
      {
        // 6. Запрещаем открывать более 3 больших ордеров в одном торговом дне
  
        orders_sessions = CntOrdersSessionsShiftRange( order_type, datetime_cur, sessions_cnt, 0, order_volume_first, orders_small, orders_big ); // вычисляем кол-во ордеров в указаном диапазоне сессий
      
        //if ( MODE_VISUAL && OP_BUY == order_type )
        //  SetText( label_debug, "Orders(BUY) total=" + orders_total + " sessions=" + orders_sessions + " small=" + orders_small + " big=" + orders_big );

        if ( orders_sessions >= 0 && orders_big < orders_sessions_big_max )
        { 
          // 7. Запрещаем открывать все ордера маленького обьема и большого в одном торговом дне
          
          if ( orders_small < orders_small_max ) 
          {      
            // 8. Запрещаем открывать более 1 ордера большого обьема при наличии более 1 ордера маленького обьема в торговом дне
            
            if ( 0 == orders_big || orders_small < ( orders_small_max / 2.0 ) )
            {
              // 9. Запрещаем открывать более 2 ордеров в одной сессии
    
              orders_session_last = CntOrdersSessionsShiftRange( order_type, datetime_cur, 0, 0, order_volume_first, orders_session_last, orders_session_last ); // вычисляем кол-во ордеров в последней сессии
    
              if ( orders_session_last >= 0 && orders_session_last < 2 )
              {
                // 9.1. Определяем расстояние открытия ордера
      
                if ( OP_BUY == order_type )
                  dist_open = -session_dist_open;
                else
                  dist_open = session_dist_open;
            
                price_zero = CalcPriceZeroOrders( order_type ); // получаем точку безубыточности
                dist_zero = CalcPriceDistance( order_type, price_open, price_zero ); // вычисляем расстояние до точки безубыточности
                  
                // 9.2. Определяем ордера какаго обьема нужно устанавливать
                // На ордера повышеного обьема переходим в таких случаях:
                // а) установлено ордеров маленького обьема максимальное кол-во;
                // б) уже установлен ордер большого обьема;
                // в) далеко отошли от точки безубыточности при установленых более половины ордеров маленького обьема
                
                if ( orders_total >= orders_small_max || 0 != orders_big || ( orders_total >= ( orders_small_max / 2.0 ) && dist_zero < - multi_lot_dist_force ) )
                {
                  allow_price = CalcAllowPriceBig( order_type, price_open, dist_open, price_zero, trande_exist_direct, trande_exist_reverse,
                    orders_sessions, orders_big, order_open_price_last, datetime_cur, order_open_time_last );
                    
                  allow_volume = CalcAllowVolumeBig( order_type, dist_zero, order_volume_first, order_volume_last );                                    
                }
                else // если переходим на большой обьем
                {
                  allow_price = CalcAllowPriceSmall( order_type, price_open, dist_open, price_zero, trande_exist_direct, trande_exist_reverse, 
                    orders_sessions, orders_small, order_open_price_good, datetime_cur, order_open_time_last );
                
                  if ( order_volume_first > 0.0 ) // если есть открытый ордер
                    allow_volume = order_volume_first; // обычный обьем
                  else // если первый ордер
                    allow_volume = CalcVolumeFromBalanceFirst();                                      
                }
                
                // 10. Ограничиваем цену открытия ордера, которую указал пользователь
                
                if ( MODE_VISUAL )
                {
                  if ( 0.0 < user_price_open_limit ) // если пользователь задал ограничивающую цену открытия ордера
                  {
                    if ( OP_BUY == order_type )
                    {
                      if ( allow_price > user_price_open_limit )
                        allow_price = user_price_open_limit;
                    }
                    else
                    {
                      if ( allow_price < user_price_open_limit )
                        allow_price = user_price_open_limit;                    
                    }
                  }
                }
                
                //Print( "CalcSessionAllowParams(", OrderTypeToStr( order_type ), ")", " allow_volume=", allow_volume, ", allow_price=", PriceToStr( allow_price ), ", allow_dist_tp=", allow_dist_tp );
              }
              else
                if ( MODE_VISUAL )
                  str = "2 orders in one session";
            }
            else
              if ( MODE_VISUAL )
                str = "only one big order";
          }
          else
            if ( MODE_VISUAL )
              str = "max " + orders_small_max + " small orders";            
        }
        else
          if ( MODE_VISUAL )
            str = "max " + orders_sessions_big_max + " big orders";
      }
      else
        if ( MODE_VISUAL )
          str = "max " + KToStrPercent( orders_drawdown_max_k ) + " drawdown";
    }
    else
      if ( MODE_VISUAL )
        str = "max volume orders";
  }
  else
    if ( MODE_VISUAL )
      str = "trande exist";      
  
  return ( str );
}
//+-----------------------------------------------------------------+

void UserChangeTP( int order_type, double user_change_tp_new, double user_change_tp_old, double & orders_tp )
{
  if ( user_change_tp_new != user_change_tp_old && 0.0 < user_change_tp_new ) // если изменилось расстояние до тейк-профита
  {
    double price_zero;
        
    // 1. Вычисляем точку безубыточности всех открытых ордеров
          
    price_zero = CalcPriceZeroOrders( order_type );
    
    // 2. Получаем значение цены тейк-профита и устанавливаем глобальную переменную
    
    orders_tp = CalcPriceTakeProfitOrders( order_type, price_zero, user_change_tp_new );    
  }
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| UserPriceFromServ - преобразовывает цену ДЦ в пользовательскую
//+-----------------------------------------------------------------+

double UserPriceFromServ( int order_type, double price_serv )
{
  switch ( order_type )
  {
    case OP_BUY:
    case OP_BUYSTOP:
    case OP_BUYLIMIT:
    {
      return ( price_serv + USER_ORDER_LIMIT_OFFSET );
    } break;
    case OP_SELL:
    case OP_SELLSTOP:
    case OP_SELLLIMIT:
    {
      return ( price_serv - USER_ORDER_LIMIT_OFFSET );
    } break;
    default: {}
  }
      
  return ( 0.0 );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| UserPriceToServ - преобразовывает цену пользователя в ДЦ
//+-----------------------------------------------------------------+

double UserPriceToServ( int order_type, double price_user )
{
  switch ( order_type )
  {
    case OP_BUY:
    case OP_BUYSTOP:
    case OP_BUYLIMIT:
    {
      return ( price_user - USER_ORDER_LIMIT_OFFSET );
    } break;
    case OP_SELL:
    case OP_SELLSTOP:
    case OP_SELLLIMIT:
    {
      return ( price_user + USER_ORDER_LIMIT_OFFSET );
    } break;
    default: {}
  }
 
  return ( 0.0 );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| GetUserPriceOpenLimitFromServ - возвращает цену открытия ордера, которая ограничена пользователем (отложеный ордер)
//+-----------------------------------------------------------------+

double GetUserPriceOpenLimitFromServ( int order_type, int & ticket )
{
  int i;
 
  ticket = 0;
  
  for ( i = 0; i < OrdersTotal(); i++ ) // по всем ордерам
  {
    if ( OrderOpenSelect( order_type, i ) && OrderLots() <= lot_min )
    {
      ticket = OrderTicket();
      
      return ( UserPriceFromServ( order_type, OrderOpenPrice() ) );
    }
  }

  return ( 0.0 );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| SetUserPriceOpenLimitToServ - устанавливает цену открытия ордера, которая ограничена пользователем (отложеный ордер)
//+-----------------------------------------------------------------+

bool SetUserPriceOpenLimitToServ( int order_type, double user_price_open_limit )
{
  if ( 0.0 < user_price_open_limit )
  {      
    return ( 0 != OrderSend( symbol, order_type, lot_min, UserPriceToServ( order_type, user_price_open_limit ), 3, 0.0, 0.0, NULL, magic_number ) ); // устанавливаем отложеный ордер
  }
  
  return ( 0.0 );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| ModifyUserPriceOpenLimitToServ - модифицирует цену открытия ордера, которая ограничена пользователем (отложеный ордер)
//+-----------------------------------------------------------------+

bool ModifyUserPriceOpenLimitToServ( int order_type, double user_price_open_limit, int ticket )
{
 return ( OrderModify( ticket, UserPriceToServ( order_type, user_price_open_limit ), 0.0, 0.0, 0 ) );  
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| DelUserPriceOpenLimitFromServ - удаляет отложеный ордера, которая ограничена пользователем (отложеный ордер)
//+-----------------------------------------------------------------+

//bool DelUserPriceOpenLimitFromServ( int ticket )
//{
//  return ( OrderDelete( ticket ) );
//}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
// CheckUserPriceOpenLimit - проверяет цену ограниченя открытия ордеров
//+-----------------------------------------------------------------+

double CheckUserPriceOpenLimit( int order_type, double user_price_open_limit, double user_price_open_limit_old )
{
  int ticket; 
  double user_price_open_limit_server;
    
  // 1. Получаем ограничения открытия ордеров установленные пользователем из сервера ДЦ
    
  user_price_open_limit_server = GetUserPriceOpenLimitFromServ( order_type, ticket );
    
  //Print( "CheckUserPriceOpenLimit(", OrderTypeToStr( order_type ), ") user=", PriceToStr( user_price_open_limit ), 
  //                                                               ", server=", PriceToStr( user_price_open_limit_server ) );
  
  // 2. Проверяем, а не изменил ли пользователь ограничение через свойства советника
  
  if ( user_price_open_limit_old != user_price_open_limit ) // если неодинаковая цена ограничения
  {
    if ( 0.0 < user_price_open_limit ) // если пользователь задал ограничение по открытию ордеров
    {
      if ( 0 != ticket ) // если уже есть отложеный ордер на сервере ДЦ
      {
        ModifyUserPriceOpenLimitToServ( order_type, user_price_open_limit, ticket ); // модифицируем
      }
      else // иначе открываем новый отложеный ордер для хранения переменной ограничения
      {
        SetUserPriceOpenLimitToServ( order_type, user_price_open_limit ); // устанавливаем параметр на сервер
      }
    }
    //else // если пользователь убрал ограничение
    //{
    //  DelUserPriceOpenLimitFromServ( ticket ); // удаляем отложеный ордер
    //}
    
    return ( user_price_open_limit );
  }
  
  // 3. Проверяем, а не изменил ли пользователь ограничение через изменение цены отложеного ордера(удаленно)

  if ( user_price_open_limit_old != user_price_open_limit_server ) // если неодинаковая цена ограничения
  {    
    return ( user_price_open_limit_server );
  }
  
  return ( user_price_open_limit );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| DeletePingOrder() - удаляет пинг-ордер
//+-----------------------------------------------------------------+

void DeletePingOrder()
{
  int i;
  
  if ( user_trade_on_sell || user_trade_on_buy ) // если советнику разрешено выставлять ордера
  {
    for ( i = 0; i < OrdersTotal(); i++ ) // по всем ордерам
    {
      if ( OrderSelect( i, SELECT_BY_POS ) && OrderType() == PING_ORDER_TYPE && OrderOpenPrice() == PING_PRICE && OrderLots() == lot_min )
      {
        OrderDelete( OrderTicket() ); // удаляем ордер
        break;
      }
   }   
 }
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| GetStrUserMan() - возвращает строку с пользовательскими настройками
//+-----------------------------------------------------------------+

string GetStrUserMan()
{
  return ( "TRADE: "   + BoolToStr( user_trade_on_sell ) + "/" + BoolToStr( user_trade_on_buy ) +
           "; TP: "    + PriceToStrAsPips( user_change_tp_sell ) + "/" + PriceToStrAsPips( user_change_tp_buy ) +
           "; LIMIT: " + PriceToStr( user_price_open_limit_sell ) + "/" + PriceToStr( user_price_open_limit_buy ) +
           "; MAGIC: " + magic_number + ";" );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| isValidBarsHistory - проверяет правильность баров в истории
//+-----------------------------------------------------------------+

bool isValidBarsHistory()
{
  return ( true );
  
  int i;
  int hour_cur = TimeHour( TimeCurrent() );

  if ( iBars( symbol, PERIOD_H1 ) > bar_cnt_days * 24 )
  {    
    for ( i = 0; i < bar_cnt_days * 24; i++ )
    {
      if ( TimeHour( iTime( symbol, PERIOD_H1, i ) ) != hour_cur ) // если неправильный час
      {
        return ( false );
      }
      else // иначе переходим на следующий час
      {
        if ( hour_cur == 0 )
          hour_cur = 23;
        else          
          hour_cur--;
      }
    }
  }
  else
    return ( false );
    
  return ( true );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcTrandeExist - вычисляет что тренд существует
//+-----------------------------------------------------------------+

bool CalcTrandeExist( double dist_day, double dist_cur, double rebound_max, 
                      double & trande_exist_direct, double & trande_exist_reverse )
{
/*  if ( dist_day > trande_exist_distance ) // если сильное движение за день
  {
    if ( dist_cur < - dist_day * trande_exist_cur_k ) // если цена в конце дневного тренда, то возможно тренд продолжится
    {
      // При движении по тренду (в прямом направлении) увеличиваем расстояние открытия ордеров

      trande_exist_direct = dist_day * trande_exist_direct_k; // вычисляем расстояние открытия ордеров по тренду
        
      if ( rebound_max < dist_day * trande_exist_rebound_min_k ) // если не было отскока
      {
        // При движении против тренда (в обратном направлении) увеличиваем расстояние открытия ордеров
                
        trande_exist_reverse = dist_day * trande_exist_reverse_k; // вычисляем расстояние открытия ордеров в противоположном направлении тренда
        
        if ( dist_day > trande_exist_off ) // если далеко отошли и не было отскоков
        {
          trande_exist_direct = 0.0;
          
          return ( false ); // разрешаем торговлю
        }
      }
      else // если есть отскоки
      {
        //Print( "--------rebound_max=", rebound_max, " dist_day * trande_exist_rebound_max_k = ", dist_day * trande_exist_rebound_max_k );
        
        if ( dist_day < trande_exist_off || rebound_max < dist_day * trande_exist_rebound_max_k ) // если дистанция за день меньше указаной или не было большого отскока
          return ( false ); // разрешаем торговлю, но с увеличеным расстоянием открытия ордеров                   
      }
      
      trande_exist_direct = 0.0;
      
      return ( true ); // запрещаем торговлю
    }      
  }    
  */
  
  return ( false );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| TrandeExist - проверяет, что существует тренд
//+-----------------------------------------------------------------+

bool TrandeExist( int order_type, int session_index, color order_color,
                  double & dist_day, double & dist_cur, double & rebound_max,
                  double & trande_exist_direct, double & trande_exist_reverse )
{  
/*  bool trande_exist; 
  int orders_cnt; 
  int hour_l, hour_h, hour_rebound_begin, hour_rebound_end; // кол-во сессий назад
  double price_open_sessions; // цена открытия торгового дня

  // 0. Вычисляем цену открытия торгового дня
          
  price_open_sessions = PriceOpenSessions( order_type, session_index );
          
  // 1. Получаем информацию о трендовом движении за текущие сутки
  
  TrandeInfo( order_type, price_open_sessions, session_index, 24, dist_day, dist_cur, rebound_max, hour_l, hour_h, hour_rebound_begin, hour_rebound_end );
  
  trande_exist = CalcTrandeExist( dist_day, dist_cur, rebound_max, trande_exist_direct, trande_exist_reverse ); // проверяет, что торговля против тренда разрешена
        
  if ( MODE_VISUAL )
  {
    ArrowTrianglSet( order_type, ARROW_TRIANGL_LOW,  iTime( symbol, PERIOD_H1, hour_l ), iLow(  symbol, PERIOD_H1, hour_l ), order_color );
    ArrowTrianglSet( order_type, ARROW_TRIANGL_HIGH, iTime( symbol, PERIOD_H1, hour_h ), iHigh( symbol, PERIOD_H1, hour_h ), order_color );

    if ( OP_BUY == order_type )
    {
      ArrowTrianglSet( order_type, ARROW_TRIANGL_REBD_BEGIN, iTime( symbol, PERIOD_H1, hour_rebound_begin ), iLow(  symbol, PERIOD_H1, hour_rebound_begin ), order_color );
      ArrowTrianglSet( order_type, ARROW_TRIANGL_REBD_END,   iTime( symbol, PERIOD_H1, hour_rebound_end ),   iHigh( symbol, PERIOD_H1, hour_rebound_end ),   order_color );
    }
    else
    {
      ArrowTrianglSet( order_type, ARROW_TRIANGL_REBD_BEGIN, iTime( symbol, PERIOD_H1, hour_rebound_begin ), iHigh( symbol, PERIOD_H1, hour_rebound_begin ), order_color );
      ArrowTrianglSet( order_type, ARROW_TRIANGL_REBD_END,   iTime( symbol, PERIOD_H1, hour_rebound_end ),   iLow(  symbol, PERIOD_H1, hour_rebound_end ),   order_color );
    }
  }
  */
  
  // 2. Запрещаем торговлю если днем ранее был тренд, в этот день был отскок и есть открытые ордера
  
  /*orders_cnt = OrdersCnt( order_type );
  
  if ( orders_cnt >= ( orders_small_max / 2.0 ) && orders_cnt <= orders_small_max ) // если много открытых ордеров маленького обьема ??? может не только маленького
  {    
    double tmp;
    double dist_day_old, dist_cur_old, rebound_max_old;
    bool trande_exist_old;
    
    // 2.1. Получаем информацию о трендовом движении за прошлые сутки
  
    TrandeInfo( order_type, PriceOpenSessions( order_type, 24 ), 24, 24, dist_day_old, dist_cur_old, rebound_max_old, hour_l, hour_h, hour_rebound_begin, hour_rebound_end );
  
    trande_exist_old = CalcTrandeExist( dist_day_old, dist_cur_old, rebound_max_old, tmp, tmp ); // проверяет, что торговля против тренда разрешена
        
    if ( trande_exist_old ) // если днем ранее торговля была запрещена и в этот день был большой отскок
    {
    
      // 2.2. Получаем информацию о трендовом движении за текущие сутки + предыдущие
  
      TrandeInfo( order_type, price_open, 0, 24 * 2, dist_day, dist_cur, rebound_max, hour_l, hour_h, hour_rebound_begin, hour_rebound_end );
  
      Print("TrandeExist()=" + trande_exist_old, " dist_day48=", dist_day, " rebound_max48=", rebound_max );
    
      if ( rebound_max > dist_day * trande_exist_rebound_max_k ) // если был большой отскок
        trande_exist = true; // запрещаем торговать
    }
  }*/
  
  //return ( trande_exist );
  
  return ( false );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| TrandeInfo - информация о тренде
//+-----------------------------------------------------------------+

void TrandeInfo( int order_type, double price_open_sessions, int hours_offset, int hours_count,
                  double & dist_day, double & dist_cur, double & rebound_max, 
                  int & hour_l, int & hour_h, int & hour_rebound_begin, int & hour_rebound_end )
{
  int i, n, count;
  double l, h, x, rebound;
     
  count = hours_count + sessions_cnt / 2;
  
  hour_l = iLowest(  symbol, PERIOD_H1, MODE_LOW,  count, hours_offset + 1 ); // находим час с минимальной ценой
  hour_h = iHighest( symbol, PERIOD_H1, MODE_HIGH, count, hours_offset + 1 );  // находим час с максимальной ценой
  
  l = iLow(  symbol, PERIOD_H1, hour_l ); // получаем минимальное значение цены за текущий день  
  h = iHigh( symbol, PERIOD_H1, hour_h ); // получаем максимальное значение цены за текущий день  
  
  // 1. Вычисляем расстояние пройденое за сутки
  
  dist_day = h - l; 
  
  // 2. Вычисляем текущее расстояние
  
  if ( OP_BUY == order_type )
    x = h;
  else
    x = l;
    
  dist_cur = CalcPriceDistance( order_type, price_open_sessions, x ); // расстояние к цене открытия торгового дня
  
  // 3. Вычисляем максимальный отскок за то время которое не торговали

  rebound_max = 0.0;
  count = hours_count - sessions_cnt;
      
  for ( i = hours_offset + 1; i < count + hours_offset; i++ )
  {
    for ( n = i - 1; n > hours_offset; n-- ) // все предыдущие
    {
      if ( OP_BUY == order_type )
        rebound = iHigh( symbol, PERIOD_H1, n ) - iLow(  symbol, PERIOD_H1, i );
      else
        rebound = iHigh( symbol, PERIOD_H1, i ) - iLow(  symbol, PERIOD_H1, n );
            
      if ( rebound > rebound_max )
      {
        rebound_max = rebound; // запоминаем максимальный отскок
            
        hour_rebound_begin = i; // запоминаем индексы отскоков
        hour_rebound_end = n;
      }
    }
  }
}
//+-----------------------------------------------------------------+


//+-----------------------------------------------------------------+
//| DayReboundProtect - защита от отскока днем, когда торговля отключена и есть открытые ордера маленького обьема
//+-----------------------------------------------------------------+
/*
void DayReboundProtect( int order_type, double price_open, double price_close )
{
  double volume, sl, tp, po;
  double price_zero; // точка безубыточности  
  int orders_total; // общеее кол-во открытых ордеров  
  double orders_volume; // обьем денег в лотах, всех открытых ордеров  
  double orders_drawdown; // просадка по ордерам  
  double order_volume_first, order_volume_last; // обьем ордера
  double order_open_price_first, order_open_price_last; // цены открытия ордеров  
  datetime order_open_time_first, order_open_time_last; // время открытия первого и последнего ордера

    
  // 1. Получаем информацию об открытых ордерах
      
  CalcDistanceFromOpenPrice( order_type, price_close, orders_total, orders_volume, orders_drawdown,
                             order_open_price_first, order_open_price_last,
                             order_volume_first,     order_volume_last,
                             order_open_time_first,  order_open_time_last );
                             
  if ( order_volume_first >= order_volume_last && orders_total >= ( orders_small_max / 2.0 ) ) // если кол-во ордеров маленького обьема 50% и более, ордера большого обьема еще не устанавливались
  {  
    int i, ticket;
    int order_type_limit; // тип отложеного ордера
    double day_height; // средняя дневная высота бара
    double bar_height_cur, bar_height_early; // средняя высота бара за несколько дней: текущего, предыдущего и следующего часа, а также часом ранее
    datetime expiration;
    
    // 2. Определяем прогнозируемую ВЫСОТУ бара за сутки
      
    bar_height_cur  = 0.0; // сбрасываем высоту бара
      
    for ( i = 1; i <= bar_cnt_days; i++ ) // по всем дням
      bar_height_cur  = bar_height_cur + BarHeight( symbol, PERIOD_D1, 24 * i ); // накапливаем высоту бара
    
    bar_height_cur = bar_height_cur / bar_cnt_days; // усредняем
      
    bar_height_early = BarHeight( symbol, PERIOD_D1, 1 ); // высота бара днем ранее

    day_height = ( bar_height_cur   * bar_height_part_cur +
                   bar_height_early * bar_height_part_early ) /
                 ( bar_height_part_cur +
                   bar_height_part_early ); // вычисляем пропорционально долям
    
    // 3. Вычисляем расстояние в пипсах
    
    day_height = ND( day_height * curve_dist_redound_k, Digits );
    
    // 4. Вычисляем обьем ордера
    
    volume = ND( order_volume_first * multi_lot_max, lot_precision );
    
    // 5. Вычисляем цену в которую нужно установить отложеный ордер
    
    if ( OP_BUY == order_type )
    {
      po = price_open - day_height;
      sl = po - stop_level;
      order_type_limit = OP_BUYLIMIT;
    }
    else
    {
      po = price_open + day_height;
      sl = po + stop_level;
      order_type_limit = OP_SELLLIMIT;
    }
    
    // 6. Вычисляем точку безубыточности всех открытых ордеров и нового еще не открытого ордера

    price_zero = CalcPriceZeroOrders( order_type, volume, po );
    
    // 7. Получаем значение цены стоп-лосс и тейк-профита
              
    tp = CalcPriceTakeProfitOrders( order_type, price_zero, session_dist_tp_big_min );
    
    // 8. Вычисляем время до какого должен стоять отложеный ордер
        
    expiration = TimeCurrent() + ( ( sessions_time_begin - sessions_time_end ) * 3600 ) - 60; // - 60 секунд запас на перекрытие времени    
    
    // 9. Устанавливаем отложеный ордер до начала торгового дня
    
    ticket = OrderSend( symbol, order_type_limit, volume, po, 3, 0.0, tp, NULL, 0, expiration ); // устанавливаем отложеный ордер
          
    if ( ticket > 0 ) // если удалось установить отложеный ордер
      OrdersModifySL( symbol, order_type, sl );
  }
}*/
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| ShowInfo - показывает информацию
//+-----------------------------------------------------------------+

void ShowInfo( string symbol )
{ 
  int orders_cnt_buy, orders_cnt_sell;
  double orders_lots_buy,  orders_margin_buy,  orders_drawdown_buy,  orders_opv_buy;
  double orders_lots_sell, orders_margin_sell, orders_drawdown_sell, orders_opv_sell;
    
  // 1. Запрашиваем информацию об открытых ордерах
        
  OrdersInfo( OP_BUY,  Bid, orders_cnt_buy,  orders_lots_buy,  orders_margin_buy,  orders_drawdown_buy,  orders_opv_buy  );
  OrdersInfo( OP_SELL, Ask, orders_cnt_sell, orders_lots_sell, orders_margin_sell, orders_drawdown_sell, orders_opv_sell );
  
  // 2. Показываем информацию об ордерах и накапливаем просадку
  
  ShowOrdersInfo( info_buy,  orders_cnt_buy,  orders_lots_buy,  orders_margin_buy,  orders_drawdown_buy );
  ShowOrdersInfo( info_sell, orders_cnt_sell, orders_lots_sell, orders_margin_sell, orders_drawdown_sell );
          
  // 3. Показываем информацию о балансе, общей просадке, спред и плечо
  
  SetText( label_balance, "$" + DoubleToStr( AccountBalance(), 2 ) + "[" + DoubleToStr( LotsToMoney( orders_drawdown_buy + orders_drawdown_sell ) * 100.0 / AccountBalance(), 1 ) + "%]" );
  SetText( label_spread, " " + DoubleToStr( AccountLeverage(), 0 ) + "/" + DoubleToStr( MarketInfo( symbol, MODE_SPREAD ), 0 ) );
  
  // 4. Показываем линии стоп-лосса
  
  ShowStopLossOrders( OP_BUY,  line_stop_loss_buy,  orders_lots_buy,  orders_margin_buy,  orders_opv_buy  );
  ShowStopLossOrders( OP_SELL, line_stop_loss_sell, orders_lots_sell, orders_margin_sell, orders_opv_sell );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| ShowOrdersInfo - показывает информацию об ордерах
//+-----------------------------------------------------------------+

void ShowOrdersInfo( string label_info_name, int orders_cnt, double orders_lots, double orders_margin, double orders_drawdown )
{  
  double m;

  m = LotsToMoney( orders_drawdown );
  SetText( label_info_name,  "$" + DoubleToStr( m, 2 ) + "[" + DoubleToStr( MathAbs( m * 100.0 / AccountBalance() ), 1 ) + "%]; " +
    orders_cnt + "/L:" + DoubleToStr( orders_lots, lot_precision ) ); // + " M:$" +  LotsToMoney( orders_margin ) );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| ShowStopLossOrders - вычисляет StopLoss для всех открытых ордеров
//+-----------------------------------------------------------------+

void ShowStopLossOrders( int order_type, string line_stop_loss_name, double orders_lots, double orders_margin, double orders_opv )
{  
  double equity_min; // минимальное кол-во средств при котором начинают закрывать ордера, начиная с самого убыточного
  double m, stop_loss;
          
  equity_min = 0.6 * orders_margin; // уровень маржи 60%, соответствует минимальному кол-ву средств
  
  m = MoneyToLots( AccountBalance() ) - equity_min; // получаем сумму денег до которой ДЦ не имеет права закрывать самые убыточные ордера
  
  if ( OP_BUY == order_type )
    m = -m;

  if ( 0.0 < orders_lots )
  {
    stop_loss = ( m + orders_opv ) / orders_lots; // вычисляем общий StopLoss
    
    if ( stop_loss < 0.0 ) // если достаточно денег, то при BUY возможно отрицательный SL
      stop_loss = 0.0; // нормализируем SL
  }
  else
    stop_loss = 0.0;    
    
  HLineSet( line_stop_loss_name, stop_loss, color_text, line_style_stop_loss );    
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| PriceOpenSessions - возвращает цену открытия сессии
//+-----------------------------------------------------------------+

double PriceOpenSessions( int order_type, int shift )
{
  double c;
  
  c = iOpen( symbol, PERIOD_H1, shift );
  
  if ( OP_BUY == order_type )
     c = c + stop_level;

  //Print( "PriceOpenSessions(", OrderTypeToStr( order_type ), ") =", PriceToStr( c ) );
  
  return ( c );
}
//+------------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| SessionIndexByHour - возвращает индекс сессии относительно времени, начиная 0-...
//+-----------------------------------------------------------------+

int SessionIndexByHour( int hour )
{
  if ( IsNightSessions() )
  {
    if ( hour >= sessions_time_begin )
      return ( hour - sessions_time_begin );
  
    if ( hour < sessions_time_end )
      return ( 24 - sessions_time_begin + hour );  
  }
  else
  {
    if ( hour >= sessions_time_begin && hour < sessions_time_end )
      return ( hour - sessions_time_begin );
  }
  
  return ( SESSION_INDEX_INVALID );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CntHoursSessionsBegin - возвращает кол-во часов до начала сессий
//+-----------------------------------------------------------------+

int CntHoursSessionsBegin( int hour )
{  
  if ( IsNightSessions() )
  {
    if ( hour >= sessions_time_begin || hour < sessions_time_end )
      return ( 0 ); // можно торговать

    return ( sessions_time_begin - hour ); // вычисляем время через которое нужно выходить на рынок
  }
  else
  {
    if ( hour < sessions_time_begin )
      return ( sessions_time_begin - hour );
  
    if ( hour >= sessions_time_end )
      return ( 24 + sessions_time_begin - hour );
      
    return ( 0 ); // можно торговать
  }
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| IsNightSessions - возвращает true - если включена ночная торговля ( с 22:00 до 08:00 ) по сессиям
//+-----------------------------------------------------------------+

bool IsNightSessions()
{
  return ( sessions_time_begin >= sessions_time_end );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcPriceTakeProfitOrders - вычисляет общий тейк-профит всех ордеров
//+-----------------------------------------------------------------+

double CalcPriceTakeProfitOrders( int order_type, double price_zero, double allow_dist_tp )
{    
  if ( OP_BUY == order_type )
    return ( price_zero + allow_dist_tp );
  else if ( OP_SELL == order_type )
    return ( price_zero - allow_dist_tp );  

  return ( 0.0 );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcPriceZeroOrders - вычисляет точку безубыточности всех открытых ордеров и нового еще не открытого ордера
//+-----------------------------------------------------------------+

double CalcPriceZeroOrders( int order_type, double order_new_lots = 0.0, double order_new_price_open = 0.0 )
{ 
  int i;
  double opv, v;
  
  // Запоминаем обьем еще неоткрытого ордера
  
  v = order_new_lots; 
  opv = order_new_lots * order_new_price_open;

  // По всем открытым ордерам
  
  for ( i = 0; i < OrdersTotal(); i++ ) // по всем ордерам
  {
    if ( OrderOpenSelect( order_type, i ) )
    {
      v = v + OrderLots(); // накапливаем обьем
      opv = opv + OrderLots() * OrderOpenPrice(); // накапливаем цену открытия и обьем

    }
  }      
  
  if ( 0.0 < v )
    v = ( ND( opv / v, Digits ) ); // вычисляем точку без убыточности
    
  //Print( "CalcPriceZeroOrders(", OrderTypeToStr( order_type ), ") zero=", PriceToStr( v ) );
  
  return ( v );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcDistanceFromOpenPrice - вычисляет расстояние между ценой открытия первого/последнего ордера и текущей ценой, а также общий обьем
//+-----------------------------------------------------------------+

void CalcDistanceFromOpenPrice( int order_type, double price_close, int & orders_total, double & orders_volume, double & orders_drawdown,
                                double   & order_open_price_good,  double   & order_open_price_last,
                                double   & order_volume_first,     double   & order_volume_last,
                                datetime & order_open_time_first,  datetime & order_open_time_last )
{
  int i;
  double dist_cur, op;

  orders_total = 0;
  
  orders_volume   = 0.0;
  orders_drawdown = 0.0;
      
  order_open_price_good = 0.0;
  order_open_price_last = 0.0;
  
  order_volume_first = 0.0;
  order_volume_last  = 0.0;
  
  order_open_time_first = 0;
  order_open_time_last = 0;
      
  for ( i = 0; i < OrdersTotal(); i++ ) // по всем ордерам
  {
    if ( OrderOpenSelect( order_type, i ) )
    { 
      op = OrderOpenPrice(); // получаем цену открытия
      
      switch ( order_type )
      {
        case OP_BUY:
        //case OP_BUYSTOP:
        //case OP_BUYLIMIT:
        {
          dist_cur = price_close - op; // вычисляем расстояние до цены (при убытке расстояние отрицательное число)
          orders_drawdown = orders_drawdown + OrderLots() * dist_cur; // вычисляем просадку
          
          // Определяем лучшую цену открытия ордеров
      
          if ( op < order_open_price_good || order_open_price_good < digits_step ) // если цена открытия меньше или еще не устанавливалась
            order_open_price_good = op;

        } break;
        case OP_SELL:
        //case OP_SELLSTOP:
        //case OP_SELLLIMIT:
        {
          dist_cur = op - price_close; // вычисляем расстояние до цены (при убытке расстояние отрицательное число)
          orders_drawdown = orders_drawdown + OrderLots() * dist_cur; // вычисляем  просадку
          
          // Определяем лучшую цену открытия ордеров
          
          if ( op > order_open_price_good ) // если цена открытия больше
            order_open_price_good = op;

        } break;
        default: {}
      }
      
      // Первый ордер

      if ( 0 == order_open_time_first || OrderOpenTime() < order_open_time_first ) // если первый ордер
      {        
        order_volume_first = OrderLots(); // обьем ордера
        order_open_time_first = OrderOpenTime(); // запоминаем время первого ордера          
      }
        
      // Последний ордер

      if ( 0 == order_open_time_last || OrderOpenTime() > order_open_time_last ) // если последний ордер
      {
        order_open_price_last = OrderOpenPrice(); // запоминаем цену открытия
        order_volume_last = OrderLots(); // обьем ордера
        order_open_time_last = OrderOpenTime(); // запоминаем время последнего ордера
      }                
      
      // Накапливаем обьем
      
      orders_volume = orders_volume + OrderLots(); 
            
      orders_total++; // увеличиваем общее кол-во открытых ордеров
    }
  }  
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CntOrdersSessionsShiftRange - вычисляет кол-во ордеров в указаном диапазоне сессий
//+-----------------------------------------------------------------+

int CntOrdersSessionsShiftRange( int order_type, datetime datetime_cur, int shift_sessions_begin, int shift_sessions_end, double order_volume_first, int & orders_small, int & orders_big )
{
  int i;  
  int shift_sessions;
  
  if ( shift_sessions_begin >= shift_sessions_end )
  {
    orders_small = 0;
    orders_big   = 0;
    
    for ( i = 0; i < OrdersTotal(); i++ ) // по всем ордерам
    {
      if ( OrderOpenSelect( order_type, i ) )
      { 
        shift_sessions = ShiftSessionsAgo( datetime_cur, OrderOpenTime() ); // получаем сдвиг сесий назад открыт ордер
          
        if ( shift_sessions != -1 )
        {
          if ( shift_sessions_begin >= shift_sessions && shift_sessions_end <= shift_sessions )
          {
            if ( order_volume_first >= OrderLots() ) // если маленький обьем
              orders_small++; // увеличиваем кол-во открытых ордеров маленького обьема
            else
              orders_big++; // увеличиваем кол-во открытых ордеров большого обьема              
          }
        }
        else
          return ( -1 );
      }
    }
    
    return ( orders_small + orders_big );
  }
  
  return ( -1 );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcSessionDistanceOpenK - вычисляет коэф. умножения дистанции открытия в зависимости от индекса сессии
//+-----------------------------------------------------------------+
/*
double CalcSessionDistanceOpenK( int session_index, int cnt_sessions )
{     
  double x;
  
  if ( SESSION_INDEX_INVALID != session_index && cnt_sessions > 0 )
  {
    x = session_index / ( cnt_sessions - 1.0 ); // получаем число от 0 до 1
    
    return ( curve_dist_open_k * MathSin( curve_dist_open_freq * x - curve_dist_open_offset ) + curve_dist_open_b );    
  }
  else
    Print( "ERROR: CalcSessionDistanceOpenK()" );
  
  return ( 0.0 );
}*/
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcSessionDistanceTakeProfitK - вычисляет коэф. расстояния тейк-профита по формуле для указаной сессии
//+-----------------------------------------------------------------+
/*
double CalcSessionDistanceTakeProfitK( int session_index, int cnt_sessions )
{ 
  return ( curve_dist_tp_b );
  
  double x;
  
  if ( SESSION_INDEX_INVALID != session_index && cnt_sessions > 0 )
  {
    x = session_index / ( cnt_sessions - 1.0 ); // получаем число от 0 до 1
              
    return ( curve_dist_tp_k * MathSin( curve_dist_tp_freq * x - curve_dist_tp_offset ) + curve_dist_tp_b );
  }
  else
    Print( "ERROR: CalcSessionDistanceTakeProfitK()" );
  
  return ( 0.0 );
}*/
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcOrderMultiLotK - вычисляет коэф. умножения обьема ордера по линейному закону ( уравнение прямой y = k*x + b )
//+-----------------------------------------------------------------+

double CalcOrderMultiLotK( int order_type, double dist_zero )
{ 
  double multi_k; // коэф. умножения  
  
  // Чем дальше ушли от точки безубыточности тем больше нужен коэф. умножения

  if ( dist_zero <= - multi_lot_dist_force )
  {
    multi_k = ( ( multi_lot_max - multi_lot_min ) / multi_lot_dist_curve ) * ( - dist_zero - multi_lot_dist_force ) + multi_lot_min;

    // Ограничиваем коэф. умножения обьема лота
  
    if ( multi_k > multi_lot_max )
      multi_k = multi_lot_max;
    else if ( multi_k < multi_lot_min )
      multi_k = multi_lot_min;      
  }
  else
    multi_k = multi_lot_min;
    
  // Print( "CalcOrderMultiLotK(", OrderTypeToStr( order_type ), ") dist_zero=", PriceToStr( dist_zero ), " multi_lot_dist=", PriceToStr( multi_lot_dist ), " multi_k=", DoubleToStr( multi_k, 2 ) );
  
  return ( multi_k );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcAllowVolumeBig - вычисляет увеличеный обьем
//+-----------------------------------------------------------------+

double CalcAllowVolumeBig( int order_type, double dist_zero, double order_volume_first, double order_volume_last )
{
  double allow_volume;
  
  allow_volume = ND( order_volume_first * CalcOrderMultiLotK( order_type, dist_zero ), lot_precision ); // увеличиваем обьем
            
  // Запрещаем устанавливать обьем меньше предыдущего
  
  if ( order_volume_last > allow_volume )
    allow_volume = order_volume_last;
    
  return ( allow_volume );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcAllowPriceBig - вычисляет разрешенную цену для ордеров увеличеного обьема
//+-----------------------------------------------------------------+

double CalcAllowPriceBig( int order_type, double price_open, double dist_open, double price_zero,
                          double trande_exist_direct, double trande_exist_reverse, int orders_sessions_total, int orders_sessions_big,
                          double order_open_price_last, datetime datetime_cur, datetime order_open_time_last )
{
  double price;
  int shift_session_last; // кол-во сессий назад  
   
  shift_session_last = ShiftSessionsAgo( datetime_cur, order_open_time_last ); // смотрим сколько сессий назад открыт последний ордер
  
  // Запрещаем открывать последний ордер большого обьема в сесии близко
  
  if ( orders_sessions_big + 1 == orders_sessions_big_max )
  {
    switch ( shift_session_last )
    {
     case 0:
     case 1:  price = price_open + ND( dist_open * ( dist_open_last_big_k + 2.0 ), Digits );  break; // если открываем последний ордер большого обема в торговом дне
     case 2:  price = price_open + ND( dist_open * ( dist_open_last_big_k + 1.0 ), Digits );  break; // если открываем последний ордер большого обема в торговом дне
     default: price = price_open + ND( dist_open *   dist_open_last_big_k,         Digits ); // если открываем последний ордер большого обема в торговом дне
    }
  }
  else
  {
    switch ( shift_session_last )
    {
      case 0:
      case 1:  price = price_open + ND( dist_open * dist_open_second_big_k,       Digits ); break; // если открыт в этой или предыдущей сессии
      case 2:  price = price_open + ND( dist_open * dist_open_second_big_k / 2.0, Digits ); break; // если открыт 2 сессии назад
      default: price = price_open + dist_open;
    }
  }
  
  // Запрещаем открывать ордера с большим обьемом по цене меньшей предыдущего ордера в одном торговом дне
                    
  if ( orders_sessions_total > 0 )
  {
    order_open_price_last = order_open_price_last - dist_open; // около текущей цены
    
    if ( OP_BUY == order_type )
    {
      if ( price > order_open_price_last )
        price = order_open_price_last;
    }
    else
    {
      if ( price < order_open_price_last )
        price = order_open_price_last;
    }
  }

  return ( CalcFreezZonePrice( order_type, CalcTrandeExistReversePrice( order_type, price, trande_exist_direct, trande_exist_reverse ), price_zero, session_dist_zone_freez_big ) );
  //return ( CalcTrandeExistReversePrice( order_type, price, trande_exist_direct, trande_exist_reverse ) );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcAllowPriceSmall - вычисляет разрешенную цену для ордеров маленького обьема
//+-----------------------------------------------------------------+

double CalcAllowPriceSmall( int order_type, double price_open, double dist_open, double price_zero,
                            double trande_exist_direct,  double trande_exist_reverse, int orders_sessions_total, int orders_sessions_small,
                            double order_open_price_good, datetime datetime_cur, datetime order_open_time_last )
{
  double price;
  int shift_session_last; // кол-во сессий назад
   
  shift_session_last = ShiftSessionsAgo( datetime_cur, order_open_time_last ); // смотрим сколько сессий назад открыт последний ордер  
  
  // Запрещаем открывать последние ордера в торговом дне близко
  
  if ( orders_sessions_small > ( orders_small_max / 2.0 ) ) // если открыто ордеров маленького обьема более 50%
  {
    switch ( shift_session_last )
    {
      case 0:
      case 1:  price = price_open + ND( dist_open * ( dist_open_last_small_k + 0.5 ), Digits ); break; // если открыт в этой и предыдущей сессии 
      default: price = price_open + ND( dist_open * ( dist_open_last_small_k       ), Digits );
    }
    
    // Запрещаем открывать ордера с по цене меньшей предыдущего ордера в одном торговом дне
    
    //order_open_price_good = order_open_price_good - dist_open; // около текущей цены
    
    if ( OP_BUY == order_type )
    {
      if ( price > order_open_price_good )
        price = order_open_price_good;
    }
    else
    {
      if ( price < order_open_price_good )
        price = order_open_price_good;
    }    
  }
  else
  {
    switch ( shift_session_last )
    {
      case 0:
      case 1:  price = price_open + ND( dist_open * dist_open_second_small_k, Digits ); break; // если открыт в этой и предыдущей сессии 
      default: price = price_open + dist_open;
    }  
  }
  
//  Print("CalcAllowPriceSmall(", OrderTypeToStr( order_type ), ")", " price=", PriceToStr( price ) );
  
  return ( CalcFreezZonePrice( order_type, CalcTrandeExistReversePrice( order_type, price, trande_exist_direct, trande_exist_reverse ), price_zero, session_dist_zone_freez_small ) );  
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcTrandeExistReversePrice - вычисляет цену для ордеров при наличии реверсивного тренда
//+-----------------------------------------------------------------+

double CalcTrandeExistReversePrice( int order_type, double price_open, double trande_exist_direct, double trande_exist_reverse )
{  
/*  if ( OP_BUY == order_type )
    price_open = price_open - trande_exist_direct - trande_exist_reverse; // ограничиваем цену
  else
    price_open = price_open + trande_exist_direct + trande_exist_reverse; // ограничиваем цену
*/
//  Print("CalcTrandeExistReversePrice(", OrderTypeToStr( order_type ), ")", " price_open=", PriceToStr( price_open ) );
  
  return ( price_open );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcFreezZonePrice - вычисляет цену до которой нельзя выставлять ордера так как близко к точке безубыточности
//+-----------------------------------------------------------------+

double CalcFreezZonePrice( int order_type, double price_open, double price_zero, double session_dist_zone_freez )
{
  double price_freez;  

  if ( 0.0 < price_zero )
  {
    if ( OP_BUY == order_type )
    {
      price_freez = price_zero - session_dist_zone_freez; // находим цену заморозки
    
      if ( price_open > price_freez ) // если цена открытия ордеров больше цены заморозки
        price_open = price_freez; // ограничиваем цену открытия
    }
    else
    {
      price_freez = price_zero + session_dist_zone_freez; // находим цену заморозки
    
      if ( price_open < price_freez ) // если цена открытия ордеров меньше цены заморозки
        price_open = price_freez; // ограничиваем цену открытия
    }
  }

//  Print("CalcFreezZonePrice(", OrderTypeToStr( order_type ), ")", " price_open=", PriceToStr( price_open ), 
//                                                                 ", price_zero=", PriceToStr( price_zero ), 
//                                                    ", session_dist_zone_freez=", PriceToStr( session_dist_zone_freez ) );  

  return ( price_open );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcSessionTakeProfit - вычисляет обьем, цену и тейк-профит ордера сесси
//+-----------------------------------------------------------------+

void CalcSessionTakeProfit( int order_type, bool trade_on, double allow_dist_tp, double & orders_tp )
{
  double tp;
  double price_zero; // точка безубыточности
  
  if ( trade_on ) // если разрешено торговать
  {
    price_zero = CalcPriceZeroOrders( order_type ); // получаем точку безубыточности
  
    if ( 0.0 < price_zero )
    {
      tp = CalcPriceTakeProfitOrders( order_type, price_zero, allow_dist_tp );
    
      if ( MathAbs( tp - orders_tp ) > ( stop_level / 2.0 ) ) // если цена изменилась более чем на половину
        orders_tp = tp; // корректируем тейк-профит
    }
    else
      orders_tp = 0.0;
  }
}
//+-----------------------------------------------------------------+
          
//+-----------------------------------------------------------------+
// ShiftSessionsAgo - возвращает сдвиг сессий назад
//+-----------------------------------------------------------------+
 
int ShiftSessionsAgo( datetime dt_new, datetime dt_old )
{ 
  int d;
    
  if ( dt_new >= dt_old ) // если текущее время меньше прошлого
  {  
    d = TimeDayOfYear( dt_new ) - TimeDayOfYear( dt_old );
   
    // ??? SER баг при переходе через пятницу, проверяются только одни выходные
    
    if ( TimeDayOfWeek( dt_old ) > TimeDayOfWeek( dt_new ) ) // если был переход через выходные
      d = d - 2; // исключаем два дня выходных
    
    return ( ( 24 * d ) + ( TimeHour( dt_new ) - TimeHour( dt_old ) ) );
  }
  else
    Print( "ERROR: ShiftSessionsAgo() new=", TimeToStr( dt_new, TIME_DATE | TIME_MINUTES | TIME_SECONDS ), " old=", TimeToStr( dt_old, TIME_DATE | TIME_MINUTES | TIME_SECONDS ) );
    
  return ( -1 );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| OrdersInfo - информация о ордерах
//+-----------------------------------------------------------------+

void OrdersInfo( int order_type, double price_close, int & orders_cnt, double & orders_lots, double & orders_margin, double & orders_drawdown, double & orders_opv )
{
  int i;
  
  orders_cnt = 0;
  orders_lots = 0.0;
  orders_margin = 0.0;
  orders_drawdown = 0.0;
  orders_opv = 0.0;
  
  for ( i = 0; i < OrdersTotal(); i++ ) // по всем ордерам
  {
    if ( OrderOpenSelect( order_type, i ) )
    {  
      orders_cnt++; // накапливаем кол-во открытых ордеров
      orders_lots = orders_lots + OrderLots(); // накапливаем обьем
      orders_margin = orders_margin + OrderLots() / AccountLeverage() * OrderOpenPrice(); // накапливаем залог
      orders_opv = orders_opv + OrderLots() * OrderOpenPrice(); // накапливаем цену открытия и обьем
        
      switch ( order_type )
      {
        case OP_BUY:
        {
          orders_drawdown = orders_drawdown + OrderLots() * ( price_close - OrderOpenPrice() ) + MoneyToLots( OrderSwap() ); // вычисляем расстояние до цены (при убытке расстояние отрицательное число)          
        } break;          
        case OP_SELL:
        {
          orders_drawdown = orders_drawdown + OrderLots() * ( OrderOpenPrice() - price_close )+ MoneyToLots( OrderSwap() ); // вычисляем расстояние до цены (при убытке расстояние отрицательное число)
        } break;          
        default: {}
      }
    }
  }    
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| OrdersCnt - кол-во ордеров
//+-----------------------------------------------------------------+

int OrdersCnt( int order_type )
{
  int i;
  int orders_cnt;
  
  orders_cnt = 0;
  
  for ( i = 0; i < OrdersTotal(); i++ ) // по всем ордерам
  {
    if ( OrderOpenSelect( order_type, i ) )
      orders_cnt++;
  }
  
  return ( orders_cnt );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| OrdersModifyTP - изменяет TakeProfit для рыночных ордеров
//+-----------------------------------------------------------------+

void OrdersModifyTP( string symbol, int order_type, double price_close, double & orders_tp )
{
  if ( 0.0 < orders_tp )
  {
    int i;
    string str;
    bool orders_modify_successfull;
    
    orders_modify_successfull = true; // изменение ордеров прошло успешно
    
    for ( i = 0; i < OrdersTotal(); i++ ) // по всем ордерам
    {
      if ( OrderOpenSelect( order_type, i ) )
      {
        if ( MathAbs( orders_tp - OrderTakeProfit() ) >= digits_step ) // если не верный тейк-профит
        {
          if ( orders_modify_successfull ) // при первом заходе в цикл
          {
            // Запрещаем устнавливать тейк-профит близко к цене или за ценой,
            // отодвигаем тейк-профит дальше от цены в сторону увеличения
            
            if ( OP_BUY == order_type )
            {
              if ( ( price_close + stop_level ) - orders_tp > 0.0 ) // если близко к цене или за ценой
                orders_tp = price_close + stop_level; // изменяем разрешенный тейк-профит
            }
            else
            {
              if ( orders_tp - ( price_close - stop_level ) > 0.0 ) // если близко к цене или за ценой
                orders_tp = price_close - stop_level; // изменяем разрешенный тейк-профит
            }                 
          }
            
          if ( MathAbs( orders_tp - OrderTakeProfit() ) >= digits_step ) // если не верный тейк-профит
          {
            orders_modify_successfull = false; // не верный тейк-профит
                       
            if ( ! OrderModify( OrderTicket(), OrderOpenPrice(), OrderStopLoss(), orders_tp, 0 ) )
            {
              str = " OrdersModifyTP(" + OrderTypeToStr( order_type ) + "):" + "#" + OrderTicket() + " sl=" + PriceToStr( OrderStopLoss() ) +
                " tp=" + PriceToStr( orders_tp ) + "/" + PriceToStr( OrderTakeProfit() ) + " price=" + PriceToStr( price_close ) + "/" + PriceToStr( stop_level );
                
              Print( MsgErrors( GetLastError() ) + ";" + str );
            }
          }
        }
      }
    }
    
    if ( orders_modify_successfull ) // если все ордера изменены успешно
      orders_tp = 0.0; // отключаем модификацию ордеров
    
    //if ( MODE_VISUAL )
    //  SetText( label_debug, str );
  }
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| OrdersModifySL - изменяет StopLoss для рыночных ордеров
//+-----------------------------------------------------------------+
/*
void OrdersModifySL( string symbol, int order_type, double orders_sl )
{
  if ( 0.0 < orders_sl )
  {
    int i;
    string str;    
    
    for ( i = 0; i < OrdersTotal(); i++ ) // по всем ордерам
    {
      if ( OrderOpenSelect( order_type, i ) )
      {                       
        if ( ! OrderModify( OrderTicket(), OrderOpenPrice(), orders_sl, OrderTakeProfit(), 0 ) )
        {
          str = " OrdersModifySL(" + OrderTypeToStr( order_type ) + "):" + "#" + OrderTicket() +
            " sl=" + PriceToStr( orders_sl ) + "/" + PriceToStr( OrderStopLoss() );
                
          Print( MsgErrors( GetLastError() ) + ";" + str );
        }
      }
    }
        
    if ( MODE_VISUAL )
      SetText( label_debug, str );
  }
}*/
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| OrderOpenSelect - выбирает ордер
//+-----------------------------------------------------------------+

bool OrderOpenSelect( int order_type, int index_pos )
{
  if ( OrderSelect( index_pos, SELECT_BY_POS ) )
    return ( OrderType() == order_type && ( 0 == magic_number || OrderMagicNumber() == magic_number ) ); // && OrderCloseTime() == 0
  else
    Print( MsgErrors( GetLastError() ), " OrderSelect()" );
    
  return ( false );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcPriceDistance - вычисляет рсстояние между двумя ценами
//+-----------------------------------------------------------------+

double CalcPriceDistance( int order_type, double price_open, double price_zero )
{
  double distance;  
  
  if ( OP_BUY == order_type )
    distance = price_open - price_zero; // вычисляем расстояние до цены (при убытке расстояние отрицательное число)
  else
    distance = price_zero - price_open; // вычисляем расстояние до цены (при убытке расстояние отрицательное число)

  //Print( "CalcPriceDistance(", OrderTypeToStr( order_type ), ") distance=", PriceToStr( distance ), " price_open=", PriceToStr( price_open ), " price_zero=", PriceToStr( price_zero ) );
  
  return ( distance );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcVolumeByLotsAndPips - вычисляет обьем денег по лоту и расстоянию в пипсах
//+-----------------------------------------------------------------+

double CalcVolumeByLotsAndPips( double lots, double pips )
{
  return ( lots / pips );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcVolumeFromBalanceFirst() - вычисляет обьем так, чтобы депозита хватило на 0.0100 пипс прохода цены для начала торгов
//+-----------------------------------------------------------------+

double CalcVolumeFromBalanceFirst()
{
  double volume;
  
  volume = ND( CalcVolumeByLotsAndPips( MoneyToLots( CalcAccountBalanceUse() * balance_first_k ), 0.0100 ), lot_precision );
  
  if ( volume < lot_min )
    volume = lot_min;
  
  return ( volume );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcAccountBalanceUse() - вычисляет баланс депозита для использования
//+-----------------------------------------------------------------+

double CalcAccountBalanceUse()
{  
  return ( AccountBalance() * balance_use_k );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| MoneyToLot() - преобразовывает деньги в лоты
//+-----------------------------------------------------------------+

double MoneyToLots( double money )
{
  return ( money / 100000.0 );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| LotToMoney() - преобразовывает лоты в деньги
//+-----------------------------------------------------------------+

double LotsToMoney( double lots )
{
  return ( lots * 100000.0 );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| ReverseOrderType() - возвращает противоположный(встречный) тип ордера
//+-----------------------------------------------------------------+
/*
int ReverseOrderType( int order_type )
{
  int reverse_order_type;
  
  switch ( order_type )
  {
    case OP_BUY:       reverse_order_type = OP_SELL;      break;
    case OP_SELL:      reverse_order_type = OP_BUY;       break;
    case OP_BUYLIMIT:  reverse_order_type = OP_SELLLIMIT; break;
    case OP_SELLLIMIT: reverse_order_type = OP_BUYLIMIT;  break;
    case OP_BUYSTOP:   reverse_order_type = OP_SELLSTOP;  break;
    case OP_SELLSTOP:  reverse_order_type = OP_BUYSTOP;   break;
    default: { Print( "ERROR: ReverseOrderType()" ); }
  }

  return ( reverse_order_type );
}
//+-----------------------------------------------------------------+
*/
//+-----------------------------------------------------------------+
//| BarCenter - возращает центр бара
//+-----------------------------------------------------------------+
/*
double BarCenter( string symbol, int timeframe, int shift )
{  
  return ( iHigh( symbol, timeframe, shift ) - BarHeight( symbol, timeframe, shift ) / 2.0 );
}*/
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| BarHeight - возращает высоту бара в пипсах
//+-----------------------------------------------------------------+

double BarHeight( string symbol, int timeframe, int shift )
{
  
  return ( iHigh( symbol, timeframe, shift ) - iLow( symbol, timeframe, shift ) );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| HaveFractal - проверяет наличие фрактала некоторое время назад
//+-----------------------------------------------------------------+

bool HaveFractal( string symbol, int order_type, double price_open )
{
  int mode;
  double if3, if4, if5, if6, if7;
  
  if ( OP_BUY == order_type ) // если покупка
    mode = MODE_LOWER; // фрактал вниз
  else
    mode = MODE_UPPER;
  
  if3 = iFractals( symbol, fractal_timeframe, mode, 3 );
  if4 = iFractals( symbol, fractal_timeframe, mode, 4 );
  if5 = iFractals( symbol, fractal_timeframe, mode, 5 );
  //if6 = iFractals( symbol, fractal_timeframe, mode, 6 );
  //if7 = iFractals( symbol, fractal_timeframe, mode, 7 );
  
  if ( OP_BUY == order_type )
  {
    price_open = price_open - stop_level; // учитываем спред для цены открытия при покупке, так как iFractals возвращает цену Bid, для скорости меняем не if?, а price_open
    
    if ( ( if3 > 0.0 && if3 < price_open ) ||
         ( if4 > 0.0 && if4 < price_open ) ||
         ( if5 > 0.0 && if5 < price_open ) /*||
         ( if6 > 0.0 && if6 < price_open ) ||
         ( if7 > 0.0 && if7 < price_open )*/ )
    {
      /*if ( iHigh(  symbol, fractal_timeframe, 3 ) < price &&
           iHigh(  symbol, fractal_timeframe, 4 ) < price &&
           iHigh(  symbol, fractal_timeframe, 5 ) < price )*/

        //Print( "HaveFractal(", OrderTypeToStr( order_type ), ")", " price_open=", PriceToStr( price_open ), ", if3=", if3, ", if4=", if4, ", if5=", if5 );
        
        return ( true );
    }    
  }
  else
  {
    if ( if3 > price_open || if4 > price_open || if5 > price_open /*|| if6 > price_open || if7 > price_open */)
    {
      /*if ( iLow( symbol, fractal_timeframe, 3 ) > price &&
           iLow( symbol, fractal_timeframe, 4 ) > price &&
           iLow( symbol, fractal_timeframe, 5 ) > price )*/

        //Print( "HaveFractal(", OrderTypeToStr( order_type ), ")", " price_open=", PriceToStr( price_open ), ", if3=", if3, ", if4=", if4, ", if5=", if5 );
        
        return ( true );
    }
  }
    
  return ( false );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| HavePriceLowLips - проверяет что цена ниже губы алигатора
//+-----------------------------------------------------------------+
/*
bool HavePriceLowLips( string symbol, int order_type, double price )
{
  double value_lips; // губа алигатора
  
  value_lips = iAlligator( symbol, fractal_timeframe, 13, 8, 8, 5, 5, 2, MODE_SMA, PRICE_MEDIAN, MODE_GATORLIPS,  1 );
    
  if ( OP_BUY == order_type )
  {
    return ( price > value_lips );
  }
  else if ( OP_SELL == order_type )
  {
    return ( price < value_lips );
  }
  else
    Print( "ERROR: HaveAligatorLipsSleep(mode)" );

  return ( false );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| isPriceSleep - цена спит
//+-----------------------------------------------------------------+

bool isPriceSleep( string symbol, int timeframe, double sleep_ac, int shifts_ac, 
                                                 double sleep_ao, int shifts_ao,
                                                 double sleep_al, int shifts_al, string & comment )
{
  int i;
  double value_jaw;
  double value_teeth;
  double value_lips;

  // 1. Проверяем отсутствие скорости изменения цены
  
  for ( i = 1; i <= shifts_ac; i++ ) // по всем барам
  {
    if ( MathAbs( iAC( symbol, timeframe, i ) ) > sleep_ac ) // если есть скорость
    {
      comment = "AC not sleep";
      return ( false );
    }
  }

  // 2. Проверяем отсутствие движущей силы цены
  
  for ( i = 1; i <= shifts_ao; i++ ) // по всем барам
  {
    if ( MathAbs( iAO( symbol, timeframe, i ) ) > sleep_ao ) // если есть движущая сила
    {
      comment = "AO not sleep";
      return ( false );
    }
  }
  
  // 3. Проверяем что алигатор спит
  
  for ( i = 1; i <= shifts_al; i++ ) // по всем барам
  {
    value_jaw   = iAlligator( symbol, timeframe, 13, 8, 8, 5, 5, 2, MODE_SMA, PRICE_MEDIAN, MODE_GATORJAW,   i );
    value_teeth = iAlligator( symbol, timeframe, 13, 8, 8, 5, 5, 2, MODE_SMA, PRICE_MEDIAN, MODE_GATORTEETH, i );
    value_lips  = iAlligator( symbol, timeframe, 13, 8, 8, 5, 5, 2, MODE_SMA, PRICE_MEDIAN, MODE_GATORLIPS,  i );
    
    if ( MathAbs( value_jaw - value_lips  ) > sleep_al || // если губы  и зубы далеко от челюсти 
         MathAbs( value_jaw - value_teeth ) > sleep_al )
    {
      comment = "Aligator not sleep";
      return ( false ); // не спит
    }    
  }
 
  return ( true );   
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CalcSleepAC - вычисляет ускорение цены сна по прогнозируемой высоте бара
//+-----------------------------------------------------------------+

double CalcSleepAC( double bar_height )
{
  return ( 0.046 * bar_height - 0.0000503 );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| СalcSleepAO - вычисляет движущую силу цены сна по прогнозируемой высоте бара
//+-----------------------------------------------------------------+

double CalcSleepAO( double bar_height )
{
  return ( 0.099 * bar_height - 0.0001318 );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| СalcSleepAl - вычисляет сон алигатора по прогнозируемой высоте бара
//+-----------------------------------------------------------------+

double CalcSleepAl( double bar_height )
{
  return ( bar_height * 0.07 );
}
//+-----------------------------------------------------------------+
*/
//+-----------------------------------------------------------------+
//| HaveAligatorLipsSleep - алигатор собирается заснуть, подтянул губы
//+-----------------------------------------------------------------+
/*
bool HaveAligatorLipsSleep( string symbol, int mode, int timeframe )
{
  double value_jaw   = iAlligator( symbol, timeframe, 13, 8, 8, 5, 5, 2, MODE_SMA, PRICE_MEDIAN, MODE_GATORJAW,   1 );
  double value_teeth = iAlligator( symbol, timeframe, 13, 8, 8, 5, 5, 2, MODE_SMA, PRICE_MEDIAN, MODE_GATORTEETH, 1 );
  double value_lips  = iAlligator( symbol, timeframe, 13, 8, 8, 5, 5, 2, MODE_SMA, PRICE_MEDIAN, MODE_GATORLIPS,  1 );
  
  //SetText( label_debug, " jaw=" + DoubleToStr( value_jaw, Digits ) + " teeth=" + DoubleToStr( value_teeth, Digits ) + " lips=" + DoubleToStr( value_lips, Digits ) );
  if ( mode == MODE_UPPER )
  {
    return ( value_lips < value_teeth && value_lips > value_jaw );
  }
  else if ( mode == MODE_LOWER )
  {
    return ( value_lips > value_teeth && value_lips < value_jaw );
  }
  else
    Print( "ERROR: HaveAligatorLipsSleep(mode)" );

  return ( false );
}*/
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| ArrowSet - устанавливает стрелку цены
//+-----------------------------------------------------------------+

void ArrowSet( string name, double price_close, color arrow_color )
{
  if ( 0.0 < price_close )
  {
    if ( ObjectFind( name ) == -1 )
    {
      if ( ObjectCreate( name, OBJ_ARROW, 0, TimeCurrent(), price_close ) )
      {
        ObjectSet( name, OBJPROP_ARROWCODE, 6 );
        ObjectSet( name, OBJPROP_COLOR, arrow_color );
      }
      else    
        Print( MsgErrors( GetLastError() ), "; ", name );
    }
    else
    {
      if ( ! ObjectMove( name, 0, TimeCurrent(), price_close ) )
        Print( MsgErrors( GetLastError() ), "; ", name );
    }
  }
  else
    ObjectDelete( name );      
}
//+-----------------------------------------------------------------+
      
//+-----------------------------------------------------------------+
//| HLineSet - устанавливает линии покупки/продажи
//+-----------------------------------------------------------------+

void HLineSet( string name, double price_open, color color_line, int line_style )
{
  if ( 0.0 < price_open )
  {
    if ( ObjectFind( name ) == -1 )
      HLineCreate( name, TimeCurrent(), price_open, color_line, line_style );
    else
      HLineMove( name, TimeCurrent(), price_open );
  }
  else
    ObjectDelete( name );      
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| HLineCreate - создает горизонтальную линию
//+-----------------------------------------------------------------+

void HLineCreate( string name, datetime time, double price_open, color line_color = CLR_NONE, int line_style = STYLE_SOLID )
{
  if ( ObjectCreate( name, OBJ_HLINE, 0, time, price_open ) )
  {
    ObjectSet( name, OBJPROP_COLOR, line_color );
    ObjectSet( name, OBJPROP_STYLE, line_style );  
  }
  else
    Print( "ERROR: ObjectCreate: " +  name );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| HLineMove - смещает горизонтальную линию
//+-----------------------------------------------------------------+

void HLineMove( string name, datetime time, double price_open )
{
  if ( ! ObjectMove( name, 0, time, price_open ) )
    Print( MsgErrors( GetLastError() ), "; ", name );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| HLinePrice - возвращает цену горизонтальной линии
//+-----------------------------------------------------------------+

double HLinePrice( string name )
{
  return ( ObjectGet( name, OBJPROP_PRICE1 ) );    
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| CreateLabel - создает метку на экране
//+-----------------------------------------------------------------+

void CreateLabel( string name, string text, int corner, int x_offset, double y_line, color text_color = CLR_NONE, int font_size = 10, string font_name = "Arial Black" )
{
  if ( -1 == ObjectFind( name ) )
  {
    if ( ObjectCreate( name, OBJ_LABEL, 0, 0, 0 ) )
    {
      ObjectSetText( name, text, font_size, font_name, text_color );
      ObjectSet( name, OBJPROP_CORNER, corner );
      ObjectSet( name, OBJPROP_XDISTANCE, x_offset );
      ObjectSet( name, OBJPROP_YDISTANCE, y_line );
    }
    else
      Print( "ERROR: ObjectCreate" + name );
  }
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| ArrowTrianglSet - устанавливает метку в виде черточки
//+-----------------------------------------------------------------+

void ArrowTrianglSet( int order_type, int arrow_type, datetime dt, double price_open, color arrow_triang_color )
{
  string name;
  
  switch ( arrow_type )
  {
    case ARROW_TRIANGL_LOW:  name = "Low"; break;
    case ARROW_TRIANGL_HIGH: name = "High"; break;
    case ARROW_TRIANGL_REBD_BEGIN:  name = "ReBound_Begin"; break;
    case ARROW_TRIANGL_REBD_END:    name = "ReBound_End";   break;    
  }
  
  name = OrderTypeToStr( order_type ) + "_" + name + "_" + TimeToStr( dt );
  
  if ( -1 == ObjectFind( name ) )
  {
    if ( ObjectCreate( name, OBJ_ARROW, 0, dt, price_open ) )
    {
      ObjectSet( name, OBJPROP_ARROWCODE, 4 );
      ObjectSet( name, OBJPROP_COLOR, arrow_triang_color );
      ObjectSet( name, OBJPROP_CORNER, 2 );
    }
    else    
      Print( MsgErrors( GetLastError() ), "; ", name );  
  }
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| SetText - устанавливает текст
//+-----------------------------------------------------------------+

void SetText( string name, string text )
{
  ObjectSetText( name, text, font_size );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| ND - нормализует число с плавающей точкой до указаной точности
//+-----------------------------------------------------------------+

double ND( double value, int precision )
{ 
  return ( NormalizeDouble( value, precision ) ) ;
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| PriceToStr - преобразовывает цену в строку
//+-----------------------------------------------------------------+

string PriceToStr( double value )
{  
  return ( DoubleToStr( value, Digits ) );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| PriceToStrAsPips - преобразовывает цену в пипсы, а потом в строку
//+-----------------------------------------------------------------+

string PriceToStrAsPips( double value )
{  
  return ( DoubleToStr( value * 10000.0, 0 ) );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| KToStr - преобразовывает коэф. в строку
//+-----------------------------------------------------------------+

string KToStr( double k, int precision = 1 )
{
  return ( DoubleToStr( k , precision ) );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| KToStrPercent - преобразовывает коэф. в строку со знаком процента
//+-----------------------------------------------------------------+

string KToStrPercent( double k, int precision = 0 )
{
  return ( DoubleToStr( k * 100.0, precision ) + "%" );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| BoolToStr - преобразовывает булевое значение в строку
//+-----------------------------------------------------------------+

string BoolToStr( bool value )
{
  string str;
  
  if ( value )
    str = "ON";
  else
    str = "OFF";
    
  return ( str );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| OrderPriceNameAsStr - возвращает строку имени цены по типу ордера
//+-----------------------------------------------------------------+
/*
string OrderPriceNameAsStr( int order_type )
{
  string str;
  
  switch ( order_type )
  {
    case OP_BUY:       
    case OP_BUYLIMIT:
    case OP_BUYSTOP:   str = "Ask"; break;
        
    case OP_SELL:      
    case OP_SELLLIMIT: 
    case OP_SELLSTOP:  str = "Bid"; break;
    default: { Print( "ERROR: OrderPriceNameAsStr()" ); }
  }

  return ( str );
}
//+-----------------------------------------------------------------+

//+-----------------------------------------------------------------+
//| PriceOpenByOrderType - возвращает цену по типу ордера
//+-----------------------------------------------------------------+

double PriceOpenByOrderType( int order_type )
{
  switch ( order_type )
  {
    case OP_BUY:       
    case OP_BUYLIMIT:
    case OP_BUYSTOP:   return ( Ask ); break;
        
    case OP_SELL:      
    case OP_SELLLIMIT: 
    case OP_SELLSTOP:  return ( Bid ); break;
    default: { Print( "ERROR: PriceOpenByOrderType()" ); }
  }

  return ( 0.0 );
}*/
//+-----------------------------------------------------------------+


//+-----------------------------------------------------------------+
//| OrderTypeToStr - преобразовывает тип ордера в строку
//+-----------------------------------------------------------------+

string OrderTypeToStr( int order_type )
{
  string str;
  
  switch ( order_type )
  {
    case OP_BUY:       str = "BUY";       break;
    case OP_SELL:      str = "SELL";      break;
    case OP_BUYLIMIT:  str = "BUYLIMIT";  break;
    case OP_SELLLIMIT: str = "SELLLIMIT"; break;
    case OP_BUYSTOP:   str = "BUYSTOP";   break;
    case OP_SELLSTOP:  str = "SELLSTOP";  break;
    default: { Print( "ERROR: OrderTypeToStr()" ); }
  }  
  
  return ( str );
}
//+-----------------------------------------------------------------+

//+------------------------------------------------------------------+
//| MsgErrors - выдает текстовую строку ошибки
//+------------------------------------------------------------------+

string MsgErrors( int error_code )
{
  string str_error;
 
  switch( error_code )
  {
      case        0: str_error = " Нет ошибки";                                                    break;
      case        1: str_error = " Нет ошибки, но результат неизвестен";                           break;
      case        2: str_error = " Общая ошибка";                                                  break;
      case        3: str_error = " Неправильные параметры";                                        break;
      case        4: str_error = " Торговый сервер занят";                                         break;
      case        5: str_error = " Старая версия клиентского терминала";                           break;
      case        6: str_error = " Нет связи с торговым сервером";                                 break;
      case        7: str_error = " Недостаточно прав";                                             break;
      case        8: str_error = " Слишком частые запросы";                                        break;
      case        9: str_error = " Недопустимая операция нарушающая функционирование сервера";     break;
      case       64: str_error = " Счет заблокирован";                                             break;
      case       65: str_error = " Неправильный номер счета";                                      break;
      case      128: str_error = " Истек срок ожидания совершения сделки";                         break;
      case      129: str_error = " Неправильная цена";                                             break;
      case      130: str_error = " Неправильные стопы";                                            break;
      case      131: str_error = " Неправильный объем";                                            break;
      case      132: str_error = " Рынок закрыт";                                                  break;
      case      133: str_error = " Торговля запрещена";                                            break;
      case      134: str_error = " Недостаточно денег для совершения операции";                    break;
      case      135: str_error = " Цена изменилась";                                               break;
      case      136: str_error = " Нет цен";                                                       break;
      case      137: str_error = " Брокер занят";                                                  break;
      case      138: str_error = " Новые цены";                                                    break;
      case      139: str_error = " Ордер заблокирован и уже обрабатывается";                       break;
      case      140: str_error = " Разрешена только покупка";                                      break;
      case      141: str_error = " Слишком много запросов";                                        break;
      case      145: str_error = " Модификация запрещена, так как ордер слишком близок к рынку";   break;
      case      146: str_error = " Подсистема торговли занята";                                    break;
      case      147: str_error = " Использование даты истечения ордера запрещено брокером";        break;
 
      case     4000: str_error = " Нет ошибки";                                                   break;
      case     4001: str_error = " Неправильный указатель функции";                               break;
      case     4002: str_error = " Индекс массива - вне диапазона";                               break;
      case     4003: str_error = " Нет памяти для стека функций";                                 break;
      case     4004: str_error = " Переполнение стека после рекурсивного вызова";                 break;
      case     4005: str_error = " На стеке нет памяти для передачи параметров";                  break;
      case     4006: str_error = " Нет памяти для строкового параметра";                          break;
      case     4007: str_error = " Нет памяти для временной строки";                              break;
      case     4008: str_error = " Неинициализированная строка";                                  break;
      case     4009: str_error = " Неинициализированная строка в массиве";                        break;
      case     4010: str_error = " Нет памяти для строкового массива";                            break;
      case     4011: str_error = " Слишком длинная строка";                                       break;
      case     4012: str_error = " Остаток от деления на ноль";                                   break;
      case     4013: str_error = " Деление на ноль";                                              break;
      case     4014: str_error = " Неизвестная команда";                                          break;
      case     4015: str_error = " Неправильный переход";                                         break;
      case     4016: str_error = " Неинициализированный массив";                                  break;
      case     4017: str_error = " Вызовы DLL не разрешены";                                      break;
      case     4018: str_error = " Невозможно загрузить библиотеку";                              break;
      case     4019: str_error = " Невозможно вызвать функцию";                                   break;
      case     4020: str_error = " Вызовы внешних библиотечных функций не разрешены";             break;
      case     4021: str_error = " Недостаточно памяти для строки, возвращаемой из функции";      break;
      case     4022: str_error = " Система занята";                                               break;
      case     4050: str_error = " Неправильное количество параметров функции";                   break;
      case     4051: str_error = " Недопустимое значение параметра функции";                      break;
      case     4052: str_error = " Внутренняя ошибка строковой функции";                          break;
      case     4053: str_error = " Ошибка массива";                                               break;
      case     4054: str_error = " Неправильное использование массива-таймсерии";                 break;
      case     4055: str_error = " Ошибка пользовательского индикатора";                          break;
      case     4056: str_error = " Массивы несовместимы";                                         break;
      case     4057: str_error = " Ошибка обработки глобальныех переменных";                      break;
      case     4058: str_error = " Глобальная переменная не обнаружена";                          break;
      case     4059: str_error = " Функция не разрешена в тестовом режиме";                       break;
      case     4060: str_error = " Функция не подтверждена";                                      break;
      case     4061: str_error = " Ошибка отправки почты";                                        break;
      case     4062: str_error = " Ожидается параметр типа string";                               break;
      case     4063: str_error = " Ожидается параметр типа integer";                              break;
      case     4064: str_error = " Ожидается параметр типа double";                               break;
      case     4065: str_error = " В качестве параметра ожидается массив";                        break;
      case     4066: str_error = " Запрошенные исторические данные в состоянии обновления";       break;
      case     4067: str_error = " Ошибка при выполнении торговой операции";                      break;
      case     4099: str_error = " Конец файла";                                                  break;
      case     4100: str_error = " Ошибка при работе с файлом";                                   break;
      case     4101: str_error = " Неправильное имя файла";                                       break;
      case     4102: str_error = " Слишком много открытых файлов";                                break;
      case     4103: str_error = " Невозможно открыть файл";                                      break;
      case     4104: str_error = " Несовместимый режим доступа к файлу";                          break;
      case     4105: str_error = " Ни один ордер не выбран";                                      break;
      case     4106: str_error = " Неизвестный символ";                                           break;
      case     4107: str_error = " Неправильный параметр цены для торговой функции";              break;
      case     4108: str_error = " Неверный номер тикета";                                        break;
      case     4109: str_error = " Торговля не разрешена";                                        break;
      case     4110: str_error = " Длинные позиции не разрешены";                                 break;
      case     4111: str_error = " Короткие позиции не разрешены";                                break;
      case     4200: str_error = " Объект уже существует";                                        break;
  }
   
  return ( "ERROR:" + error_code + "; " + str_error );
}
//+------------------------------------------------------------------+


