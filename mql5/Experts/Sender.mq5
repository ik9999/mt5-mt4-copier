//+------------------------------------------------------------------+
//|                                                       Sender.mq5 |
//|                   Copyright 2009-2017, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2009-2017, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.0"

#include <Trade\PositionInfo.mqh>
#include "inc/ArrayListClass.mqh"

input string InpFileName = "positions.csv";
input string InpFilePath = "copier_cache\\";

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

CArrayListClass<PositionData> *positions_list;
CPositionInfo *selected_position;

void write_to_file() {
	string file_path = InpFilePath + InpFileName;
	PrintFormat("Writing to csv: %s", file_path);
	int handle = FileOpen(file_path, FILE_WRITE|FILE_SHARE_WRITE|FILE_SHARE_READ|FILE_ANSI, ",");
	if(handle != INVALID_HANDLE) {
		for (int i = 0; i < positions_list.size(); i++) {
			PositionData *pos_data = positions_list.get(i);
			int symbol_digits = (int)SymbolInfoInteger(pos_data.symbol, SYMBOL_DIGITS);
			FileWrite(
				handle, IntegerToString(pos_data.id), pos_data.symbol, DoubleToString(pos_data.tp_price, symbol_digits), DoubleToString(pos_data.sl_price, symbol_digits),
				IntegerToString(pos_data.open_time_ts), DoubleToString(pos_data.volume, 2), IntegerToString((int)pos_data.is_buy)
			);
		}
		FileClose(handle);
	} else {
		PrintFormat("File opening failed. Path: %s. Error: %d", file_path, GetLastError());
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

void refresh_pos_list() {
	positions_list.clear();
	selected_position = new CPositionInfo();
	int pos_count = PositionsTotal();
	for (int idx = 0; idx < pos_count; idx++) {
		bool is_selected = selected_position.SelectByIndex(idx);
		if (!is_selected) {
			PrintFormat("Error selecting position by idx: %d", idx);
			continue;
		}
		double volume = selected_position.Volume();
		ENUM_POSITION_TYPE pos_type = selected_position.PositionType();
		long id = selected_position.Identifier();
		double open_price = selected_position.PriceOpen();
		double stop_loss = selected_position.StopLoss();
		double take_profit = selected_position.TakeProfit();
		string comment = selected_position.Comment();
		datetime open_time = selected_position.Time();
		string symbol = selected_position.Symbol();
		PositionData *position_data = new PositionData(id, symbol, take_profit, stop_loss, (long)open_time, volume, pos_type == POSITION_TYPE_BUY);
		positions_list.add(position_data);
	}
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
void OnInit(void) {
	positions_list = new CArrayListClass<PositionData>();
	refresh_pos_list();
	write_to_file();
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(void) {
	int pos_count = PositionsTotal();
	bool update_file = false;
	PositionData *pos_data = NULL;
	for (int idx = 0; idx < pos_count; idx++) {
		bool is_selected = selected_position.SelectByIndex(idx);
		if (!is_selected) {
			PrintFormat("OnTick: Error selecting position by idx: %d", idx);
			continue;
		}
		double volume = selected_position.Volume();
		ENUM_POSITION_TYPE pos_type = selected_position.PositionType();
		long id = selected_position.Identifier();
		double open_price = selected_position.PriceOpen();
		double stop_loss = selected_position.StopLoss();
		double take_profit = selected_position.TakeProfit();
		long open_time_ts = (long)selected_position.Time();
		string symbol = selected_position.Symbol();
		bool position_found = false;
		for (int j = 0; j < positions_list.size(); j++) {
			pos_data = positions_list.get(j);
			if ((pos_data.open_time_ts == open_time_ts) && (pos_data.symbol == symbol) && (pos_data.id == id)) {
				position_found = true;
				break;
			}
		}
		if (!position_found) {
			Print("OnTick: New position. Refresh file.");
			update_file = true;
			break;
		}
		if (!equal_prices(pos_data.tp_price, take_profit) || !equal_prices(pos_data.sl_price, stop_loss) || !equal_prices(pos_data.volume, volume)) {
			Print("OnTick: Position Changed. Refresh file.");
			update_file = true;
		}
	}
	if (!update_file) {
		for (int j = 0; j < positions_list.size(); j++) {
			pos_data = positions_list.get(j);
			bool is_selected = selected_position.SelectByTicket(pos_data.id);
			if (!is_selected) {
				PrintFormat("OnTick: Cant select position: %d. Refresh file.", pos_data.id);
				update_file = true;
				break;
			}
		}
	}
	if (update_file) {
		refresh_pos_list();
		write_to_file();
	}
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
	delete(selected_position);
	delete(positions_list);
}
