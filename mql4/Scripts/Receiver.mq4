//+------------------------------------------------------------------+
//|                                                     Receiver.mq4 |
//+------------------------------------------------------------------+
#property copyright "q"
#property link      "http://www.mql4.com/ru/users/Urain"
#property show_inputs

#include "inc/ArrayListClass.mqh"

input string InpFileName = "positions.csv";
input string InpFilePath = "copier_cache\\";
input uint InpSleepIntervalMsc = 1000;

class PositionData {
	public:
		long id;
		string symbol;
		double tp_price;
		double sl_price;
		long open_time_ts;
		double volume;
		bool is_buy;

		PositionData(long _id, string _symbol, double _tp_price, double _sl_price, long _open_time_ts, double _volume, bool _is_buy) {
			id = _id;
			symbol = _symbol;
			tp_price = _tp_price;
			sl_price = _sl_price;
			open_time_ts = _open_time_ts;
			volume = _volume;
			is_buy = _is_buy;
		}
};

CArrayListClass<PositionData> *mt5_positions_list;

bool refresh_mt5_positions() {
	string file_path = InpFilePath + InpFileName;
	int handle = FileOpen(file_path,FILE_CSV|FILE_READ|FILE_SHARE_READ|FILE_SHARE_WRITE,",");
	int prev_size = mt5_positions_list.size();
	if(handle != INVALID_HANDLE) {
		mt5_positions_list.clear();
		while (!FileIsEnding(handle)) {
			long id = StringToInteger(FileReadString(handle));
			string symbol = FileReadString(handle);
			double tp_price = StringToDouble(FileReadString(handle));
			double sl_price = StringToDouble(FileReadString(handle));
			long open_time_ts = StringToInteger(FileReadString(handle));
			double volume = StringToDouble(FileReadString(handle));
			long is_buy = (bool)StringToInteger(FileReadString(handle));
			PositionData *pos_data = new PositionData(id, symbol, tp_price, sl_price, open_time_ts, volume, is_buy);
			mt5_positions_list.add(pos_data);
		}
		FileClose(handle);
		if (mt5_positions_list.size() != prev_size) {
			PrintFormat("New positions file size: %d", mt5_positions_list.size());
		}
		return true;
	} else {
		PrintFormat("File opening failed. Path: %s. Error: %d", file_path, GetLastError());
		return false;
	}
}

bool valid_price(double value) {
	return value > 0.0000001 && value != EMPTY_VALUE;
}

bool close_numbers(double val1, double val2) {
	return MathAbs(val1 - val2) < 0.0000001;
}

bool equal_prices(double val1, double val2) {
	if (!valid_price(val1) && !valid_price(val2)) {
		return true;
	}
	return close_numbers(val1, val2);
}

int digits(string symbol) {
	return MarketInfo(symbol, MODE_DIGITS);
}

double price_close(string symbol,int cmd) {
	if (cmd % 2 == 1) {
		return MarketInfo(symbol, MODE_ASK);
	} else {
		return MarketInfo(symbol, MODE_BID);
	}
}

bool update_orders() {
	int orders_total = OrdersTotal();
	string str_parts[];
	PositionData *pos_data = NULL;
	int orders_matched = 0;
	int pos_idx = 0;
	int i = 0;
	bool select_res = false;
	string comment = "";
	for (i = orders_total - 1; i >= 0; i--) {
		select_res = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
		if (!select_res) {
			PrintFormat("OrderSelect Error: %d", i);
			continue;
		}
		comment = OrderComment();
		if (comment == "") {
			continue;
		}
		int str_parts_num = StringSplit(comment, StringGetCharacter(":", 0), str_parts);
		if (str_parts_num != 2) {
			continue;
		}
		long pos_id = IntegerToString(str_parts[0]);
		long open_time_ts = IntegerToString(str_parts[1]);

		bool order_found = false;
		for (pos_idx = 0; pos_idx < mt5_positions_list.size(); pos_idx++) {
			pos_data = mt5_positions_list.get(pos_idx);
			if ((pos_data.id == pos_id) && (pos_data.open_time_ts == open_time_ts)) {
				order_found = true;
				break;
			}
		}
		if (!order_found) {
			PrintFormat("Order %s not in file. Close it.", comment);
			bool closing_res = OrderClose(OrderTicket(), OrderLots(), price_close(OrderSymbol(), OrderType()), MarketInfo(OrderSymbol(), MODE_SPREAD));
			if (!closing_res) {
				PrintFormat("Error closing order %s. Error: %d", comment, GetLastError());
				return false;
			}
			continue;
		}
		orders_matched += 1;
		if (!equal_prices(pos_data.tp_price, OrderTakeProfit()) || !equal_prices(pos_data.sl_price, OrderStopLoss())) {
			PrintFormat("Order %s in file has changed. Update it.", comment);
			double new_sl_price = OrderStopLoss();
			if (!equal_prices(pos_data.sl_price, OrderStopLoss())) {
				new_sl_price = NormalizeDouble(pos_data.sl_price, digits(pos_data.symbol));
			}
			double new_tp_price = OrderTakeProfit();
			if (!equal_prices(pos_data.tp_price, OrderTakeProfit())) {
				new_tp_price = NormalizeDouble(pos_data.tp_price, digits(pos_data.symbol));
			}
			bool modify_res = OrderModify(OrderTicket(), OrderOpenPrice(), new_sl_price, new_tp_price, 0);
			if (!modify_res) {
				PrintFormat("Error OrderModify. Order: %s. Error: %d", comment, GetLastError());
				return false;
			}
		}
	}
	if (orders_matched < mt5_positions_list.size()) {
		PrintFormat("There are mt5 positions without corresponding MT4 orders. Checking.");
		for (pos_idx = 0; pos_idx < mt5_positions_list.size(); pos_idx++) {
			pos_data = mt5_positions_list.get(pos_idx);
			bool match_found = false;
			for (i = orders_total - 1; i >= 0; i--) {
				select_res = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
				if (!select_res) {
					PrintFormat("OrderSelect Error: %d", i);
					continue;
				}
				comment = OrderComment();
				if (comment == "") {
					continue;
				}
				int _str_parts_num = StringSplit(comment, StringGetCharacter(":", 0), str_parts);
				if (_str_parts_num != 2) {
					continue;
				}
				long _pos_id = IntegerToString(str_parts[0]);
				long _open_time_ts = IntegerToString(str_parts[1]);
				if ((pos_data.id == _pos_id) && (pos_data.open_time_ts == _open_time_ts)) {
					match_found = true;
					break;
				}
			}
			if (match_found) {
				continue;
			}
			PrintFormat("Order %d:%d not found. Creating it.", pos_data.id, pos_data.open_time_ts);
			int cmd = 0;
			double price = 0.0;
			if (pos_data.is_buy) {
				cmd = OP_BUY;
				price = MarketInfo(pos_data.symbol, MODE_ASK);
			} else {
				cmd = OP_SELL;
				price = MarketInfo(pos_data.symbol, MODE_BID);
			}
			double sl_price = 0.0;
			if (valid_price(pos_data.sl_price)) {
				sl_price = NormalizeDouble(pos_data.sl_price, digits(pos_data.symbol));
			}
			double tp_price = 0.0;
			if (valid_price(pos_data.tp_price)) {
				tp_price = NormalizeDouble(pos_data.tp_price, digits(pos_data.symbol));
			}
			string _comment = StringFormat("%d:%d", pos_data.id, pos_data.open_time_ts);
			bool order_send_res = OrderSend(pos_data.symbol, cmd, NormalizeDouble(pos_data.volume, 2), price, MarketInfo(pos_data.symbol, MODE_SPREAD), sl_price, tp_price, _comment);
			if (!order_send_res) {
				PrintFormat("Error OrderSend. Order: %s. Error: %d", _comment, GetLastError());
				return false;
			}
		}
	}
	return true;
}

int start() {
	mt5_positions_list = new CArrayListClass<PositionData>();
	Print("Started Receiver");
	while(!IsStopped()) {
		bool refresh_res = refresh_mt5_positions();
		if (refresh_res) {
			bool update_orders_res = update_orders();
			if (!update_orders_res) {
				Print("update_orders() error");
			}
		} else {
			Print("refresh_mt5_positions() error");
		}
		PrintFormat("Number of positions: %d", mt5_positions_list.size());
		uint start_time = GetTickCount();
		uint end_time = GetTickCount();
		if (end_time - start_time >= InpSleepIntervalMsc) {
			continue;
		}
		uint sleep_time_msc = InpSleepIntervalMsc - (end_time - start_time);
		Sleep(sleep_time_msc);
	}
	delete(mt5_positions_list);
	Print("Stopping Receiver");
	return 1;
}
