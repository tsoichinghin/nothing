import ccxt
import pandas as pd
import csv
import re
import numpy as np
from scipy.stats import norm
import time
from datetime import datetime
import pytz
import sys

success_symbols = [
    "SAGA/USDT", "1000SATS/USDT", "POL/USDT", "S/USDT", "NOT/USDT", "AI/USDT",
    "RONIN/USDT", "AEVO/USDT", "DOGS/USDT", "HMSTR/USDT", "PORTAL/USDT", "NTRN/USDT",
    "TRIBE/USDT", "OSMO/USDT", "BCC/USDT", "CETUS/USDT", "EPS/USDT", "DYM/USDT", "OP/USDT",
    "BLUR/USDT", "JUP/USDT", "BONK/USDT", "ILV/USDT", "NPXS/USDT", "ALCX/USDT", "EIGEN/USDT",
    "IO/USDT", "XAI/USDT", "SEI/USDT", "MULTI/USDT", "STRK/USDT", "ZK/USDT", "BNSOL/USDT",
    "UFT/USDT", "SCR/USDT", "MC/USDT", "BSW/USDT", "ETH/USDT", "APT/USDT", "MIR/USDT",
    "TNSR/USDT", "TIA/USDT", "GMT/USDT", "SYN/USDT", "REZ/USDT", "LUMIA/USDT", "PYTH/USDT",
    "NEIRO/USDT", "BEAMX/USDT", "IQ/USDT", "CFX/USDT", "COMBO/USDT", "KLAY/USDT", "WLD/USDT",
    "MBOX/USDT", "HOOK/USDT", "ALT/USDT", "PIXEL/USDT", "PLA/USDT", "AMB/USDT", "ZRO/USDT",
    "ORN/USDT", "GALA/USDT", "ETHFI/USDT", "ENA/USDT", "GTC/USDT", "OMNI/USDT", "GMX/USDT",
    "MAV/USDT", "BAL/USDT", "FIDA/USDT", "RAY/USDT", "API3/USDT", "MANTA/USDT", "ZEN/USDT",
    "BADGER/USDT", "SCRT/USDT", "GNO/USDT", "FXS/USDT", "BTC/USDT", "MOB/USDT", "LEVER/USDT",
    "METIS/USDT", "C98/USDT", "FORTH/USDT", "LTC/USDT", "WIF/USDT", "TRB/USDT", "BTT/USDT",
    "CVX/USDT", "AGIX/USDT", "ACE/USDT", "W/USDT", "TLM/USDT", "TVK/USDT",
    "BOME/USDT", "AXS/USDT", "POLYX/USDT", "YGG/USDT", "ARB/USDT", "1INCH/USDT",
    "IOTA/USDT", "GXS/USDT", "RNDR/USDT", "PEOPLE/USDT", "BCHABC/USDT", "LOKA/USDT", "QKC/USDT",
    "T/USDT", "QI/USDT", "PDA/USDT", "PERL/USDT", "AGLD/USDT", "VIC/USDT",
    "HC/USDT", "CATI/USDT", "G/USDT", "CHR/USDT", "BB/USDT", "WAXP/USDT",
    "ARK/USDT", "ID/USDT", "FIS/USDT", "NFP/USDT",
    "NEO/USDT", "MATIC/USDT", "IOST/USDT", "KEEP/USDT", "ADA/USDT", "WAN/USDT", "OMG/USDT",
    "PNUT/USDT", "GAS/USDT", "RAMP/USDT", "AERGO/USDT",
    "ICX/USDT", "LQTY/USDT", "BEAM/USDT", "WBETH/USDT", "WBTC/USDT", "LUNA/USDT",
    "BANANA/USDT"
]

test_symbols = [
    "SAGA/USDT", "1000SATS/USDT", "POL/USDT"
]

stable_coin = [
    "USDC/USDT", "BUSD/USDT", "DAI/USDT", "TUSD/USDT", "USDP/USDT", "GUSD/USDT", "EURS/USDT", "USDD/USDT", "USDGLO/USDT",
    "USDE/USDT", "USDTB/USDT", "FDUSD/USDT", "USD1/USDT", "LUSD/USDT", "CUSD/USDT", "RSR/USDT", "OUSD/USDT", "HUSD/USDT",
    "AMPL/USDT", "USDS/USDT", "GHO/USDT", "BITUSD/USDT", "BITEUR/USDT", "BITCNY/USDT", "UST/USDT"
]

dfs_by_symbol = {}
dfs_by_timesamps = {}
closed_trades = {}

# 回测配置
TIMEFRAME_1M = '30m'
TIMEFRAME_5M = '5m'
TIMEFRAME_15M = '15m'
TIMEFRAME_30M = '30m'
TIMEFRAME_1H = '1h'
TIMEFRAME_2H = '2h'
TIMEFRAME_4H = '4h'
TIMEFRAME_8H = '8h'
TIMEFRAME_12H = '12h'
INITIAL_CAPITAL = 1000.0
#CSV_FILE = '/Users/tsoichinghin/OneDrive/python/program_trade/csv/backtest_results.csv'
CSV_FILE = '/root/backtest_results.csv'
#WIN_LOSS_NUMBER_FILE = '/Users/tsoichinghin/OneDrive/python/program_trade/csv/profit_or_loss_number.csv'
WIN_LOSS_NUMBER_FILE = '/root/profit_or_loss_number.csv'
START_DATE_1M = '2025-01-01 00:00:00'  # 1m 回测开始时间 06-15 11:00
START_DATE_5M = '2023-01-01 00:00:00'  # 5m 回测开始时间
START_DATE_15M = '2023-01-01 00:00:00'  # 15m 回测开始时间
START_DATE_30M = '2024-12-30 00:00:00'  # 30m 回测开始时间（早两天）
START_DATE_1H = '2017-01-01 00:00:00'  # 1h 回测开始时间
START_DATE_2H = '2017-01-01 00:00:00'  # 2h 回测开始时间
START_DATE_4H = '2017-01-01 00:00:00'  # 4h 回测开始时间
START_DATE_8H = '2017-01-01 00:00:00'  # 8h 回测开始时间
START_DATE_12H = '2017-01-01 00:00:00'  # 12h 回测开始时间

# 初始化交易所
exchange = ccxt.binance({
    'enableRateLimit': True,
    'options': {
        'defaultType': 'spot',
    }
})

# 全局变量
max_time = 0
capital = INITIAL_CAPITAL
target_profit = INITIAL_CAPITAL * 4
saving_capital = 0
saving_round = 0
reset_round = 0
decrease_round = 0
current_position = None
trade_count = 0
profitable_trades = 0
total_profit_amount = 0
max_loss_amount = 0
max_loss_trade_amount = 0
trade_statistics = {} 
max_loss_trade_info = {}
max_loss_percentage = 0
max_loss_percentage_info = {}
min_profit_trade_info = {}
min_profit_percentage = 100
Fail_Symbols = ['BTC/USDT', 'ETH/USDT', 'BNB/USDT', 'BCC/USDT', 'NEO/USDT', 'LTC/USDT', 'QTUM/USDT', 'ADA/USDT', 'XRP/USDT', 'XLM/USDT', 'TRX/USDT', 'ETC/USDT', 'VET/USDT', 'BCHABC/USDT', 'LINK/USDT', 'WAVES/USDT', 'BTT/USDT', 'ONG/USDT', 'HOT/USDT', 'ZIL/USDT', 'ZRX/USDT', 'FET/USDT', 'BAT/USDT', 'XMR/USDT', 'ZEC/USDT', 'IOST/USDT', 'CELR/USDT', 'NANO/USDT', 'OMG/USDT', 'THETA/USDT', 'ENJ/USDT', 'MITH/USDT', 'MATIC/USDT', 'ONE/USDT', 'FTM/USDT', 'ALGO/USDT', 'GTO/USDT', 'ERD/USDT', 'DOGE/USDT', 'DUSK/USDT', 'ANKR/USDT', 'COCOS/USDT', 'MTL/USDT', 'TOMO/USDT', 'PERL/USDT', 'KEY/USDT', 'DOCK/USDT', 'WAN/USDT', 'FUN/USDT', 'CVC/USDT', 'CHZ/USDT', 'BAND/USDT', 'BEAM/USDT', 'REN/USDT', 'RVN/USDT', 'HC/USDT', 'HBAR/USDT', 'NKN/USDT', 'STX/USDT', 'ARPA/USDT', 'IOTX/USDT', 'RLC/USDT', 'MCO/USDT', 'CTXC/USDT', 'BCH/USDT', 'TROY/USDT', 'FTT/USDT', 'DREP/USDT', 'ETHBEAR/USDT', 'TCT/USDT', 'BTS/USDT', 'BNT/USDT', 'LTO/USDT', 'EOSBEAR/USDT', 'XRPBEAR/USDT', 'STRAT/USDT', 'AION/USDT', 'COTI/USDT', 'WTC/USDT', 'XZC/USDT', 'SOL/USDT', 'CTSI/USDT', 'HIVE/USDT', 'BTCDOWN/USDT', 'GXS/USDT', 'ARDR/USDT', 'LEND/USDT', 'MDT/USDT', 'STMX/USDT', 'PNT/USDT', 'COMP/USDT', 'SC/USDT', 'ZEN/USDT', 'SNX/USDT', 'ETHUP/USDT', 'ETHDOWN/USDT', 'ADAUP/USDT', 'ADADOWN/USDT', 'LINKUP/USDT', 'VTHO/USDT', 'DGB/USDT', 'GBP/USDT', 'MKR/USDT', 'DCR/USDT', 'STORJ/USDT', 'BNBUP/USDT', 'BNBDOWN/USDT', 'XTZUP/USDT', 'XTZDOWN/USDT', 'YFI/USDT', 'BAL/USDT', 'BLZ/USDT', 'IRIS/USDT', 'KMD/USDT', 'ANT/USDT', 'CRV/USDT', 'SAND/USDT', 'OCEAN/USDT', 'RSR/USDT', 'WNXM/USDT', 'BZRX/USDT', 'SUSHI/USDT', 'YFII/USDT', 'RUNE/USDT', 'EOSUP/USDT', 'EOSDOWN/USDT', 'TRXDOWN/USDT', 'XRPUP/USDT', 'XRPDOWN/USDT', 'DOTUP/USDT', 'DOTDOWN/USDT', 'BEL/USDT', 'WING/USDT', 'LTCUP/USDT', 'LTCDOWN/USDT', 'UNI/USDT', 'NBS/USDT', 'AVAX/USDT', 'HNT/USDT', 'UNIUP/USDT', 'UNIDOWN/USDT', 'ORN/USDT', 'UTK/USDT', 'XVS/USDT', 'ALPHA/USDT', 'AAVE/USDT', 'NEAR/USDT', 'SXPUP/USDT', 'SXPDOWN/USDT', 'FILDOWN/USDT', 'YFIUP/USDT', 'YFIDOWN/USDT', 'INJ/USDT', 'AKRO/USDT', 'DNT/USDT', 'UNFI/USDT', 'ROSE/USDT', 'AAVEUP/USDT', 'AAVEDOWN/USDT', 'SKL/USDT', 'SUSHIUP/USDT', 'SUSHIDOWN/USDT', 'XLMDOWN/USDT', 'GRT/USDT', 'JUV/USDT', 'REEF/USDT', 'OG/USDT', 'BTCST/USDT', 'TRU/USDT', 'TWT/USDT', 'FIRO/USDT', 'LIT/USDT', 'SFP/USDT', 'DODO/USDT', 'CAKE/USDT', 'BADGER/USDT', 'OM/USDT', 'DEGO/USDT', 'RAMP/USDT', 'SUPER/USDT', 'CFX/USDT', 'EPS/USDT', 'AUTO/USDT', 'TLM/USDT', '1INCHDOWN/USDT', 'BTG/USDT', 'MIR/USDT', 'BAR/USDT', 'FORTH/USDT', 'BAKE/USDT', 'BURGER/USDT', 'SHIB/USDT', 'ICP/USDT', 'AR/USDT', 'MDX/USDT', 'LPT/USDT', 'NU/USDT', 'XVG/USDT', 'ATA/USDT', 'GTC/USDT', 'TORN/USDT', 'KEEP/USDT', 'PHA/USDT', 'BOND/USDT', 'DEXE/USDT', 'CLV/USDT', 'QNT/USDT', 'TVK/USDT', 'MINA/USDT', 'RAY/USDT', 'FARM/USDT', 'ALPACA/USDT', 'REQ/USDT', 'TRIBE/USDT', 'XEC/USDT', 'DYDX/USDT', 'VIDT/USDT', 'GALA/USDT', 'ILV/USDT', 'YGG/USDT', 'FIDA/USDT', 'FRONT/USDT', 'CVP/USDT', 'RARE/USDT', 'AUCTION/USDT', 'DAR/USDT', 'BNX/USDT', 'MOVR/USDT', 'ENS/USDT', 'KP3R/USDT', 'VGX/USDT', 'JASMY/USDT', 'AMP/USDT', 'PLA/USDT', 'RNDR/USDT', 'ALCX/USDT', 'FXS/USDT', 'VOXEL/USDT', 'CVX/USDT', 'PEOPLE/USDT', 'OOKI/USDT', 'SPELL/USDT', 'JOE/USDT', 'ACH/USDT', 'IMX/USDT', 'LOKA/USDT', 'SCRT/USDT', 'BTTC/USDT', 'XNO/USDT', 'WOO/USDT', 'ASTR/USDT', 'APE/USDT', 'BIFI/USDT', 'MULTI/USDT', 'MOB/USDT', 'NEXO/USDT', 'GAL/USDT', 'LDO/USDT', 'EPX/USDT', 'OP/USDT', 'LEVER/USDT', 'LUNC/USDT', 'NEBL/USDT', 'POLYX/USDT', 'APT/USDT', 'HFT/USDT', 'PHB/USDT', 'HOOK/USDT', 'MAGIC/USDT', 'HIFI/USDT', 'AGIX/USDT', 'SYN/USDT', 'VIB/USDT', 'SSV/USDT', 'LQTY/USDT', 'AMB/USDT', 'USTC/USDT', 'GAS/USDT', 'QKC/USDT', 'ID/USDT', 'RDNT/USDT', 'EDU/USDT', 'SUI/USDT', 'PEPE/USDT', 'FLOKI/USDT', 'AST/USDT', 'PENDLE/USDT', 'ARKM/USDT', 'WLD/USDT', 'SEI/USDT', 'CYBER/USDT', 'ARK/USDT', 'TIA/USDT', 'ORDI/USDT', 'BEAMX/USDT', 'PIVX/USDT', 'BLUR/USDT', 'VANRY/USDT', 'JTO/USDT', 'BONK/USDT', 'ACE/USDT', 'NFP/USDT', 'AI/USDT', 'XAI/USDT', 'MANTA/USDT', 'JUP/USDT', 'DYM/USDT', 'PIXEL/USDT', 'STRK/USDT', 'PORTAL/USDT', 'PDA/USDT', 'WIF/USDT', 'METIS/USDT', 'BOME/USDT', 'ETHFI/USDT', 'ENA/USDT', 'W/USDT', 'SAGA/USDT', 'TAO/USDT', 'OMNI/USDT', 'REZ/USDT', 'BB/USDT', 'NOT/USDT', 'ZK/USDT', 'LISTA/USDT', 'ZRO/USDT', 'G/USDT', 'RENDER/USDT', 'SLF/USDT', 'NEIRO/USDT', 'TURBO/USDT', 'CATI/USDT', 'HMSTR/USDT', 'EIGEN/USDT', 'SCR/USDT', 'COW/USDT', 'CETUS/USDT', 'PNUT/USDT', 'ACT/USDT', 'USUAL/USDT', 'THE/USDT', 'ACX/USDT', 'ORCA/USDT', 'MOVE/USDT', 'ME/USDT', 'VANA/USDT', '1000CAT/USDT', 'PENGU/USDT', 'D/USDT', 'CGPT/USDT', 'COOKIE/USDT', 'SOLV/USDT', 'TRUMP/USDT', 'ANIME/USDT', 'HEI/USDT']

# 创建 CSV 文件并写入标题
with open(CSV_FILE, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['Trade Number', 'Direction', 'Symbol', 'Reason', 'Open Time', 'Close Time',
                     'Open Price', 'Close Price', 'Gain', 'Change_percentage', 'Capital', 'saving_capital', 'saving_round', 'reset_round', 'Profit or Loss'])

def get_all_symbols():
    """获取所有交易对"""
    markets = exchange.fetch_markets()
    return [market['symbol'] for market in markets if market['quote'] == 'USDT' and ':USDT' not in market['symbol']]

def is_large_cap(symbol):
    """檢查幣種市值是否足夠大（例如超過 1億美元）"""
    markets = exchange.load_markets()
    market_info = markets.get(symbol, {})
    
    # 根據市場信息中的市值設定條件（這裡僅用舉例）
    if 'quote' in market_info and 'active' in market_info and market_info['active']:
        quote_symbol = symbol.replace('/USDT', '')
        ticker = exchange.fetch_ticker(symbol)
        market_cap = ticker['last'] * ticker['quoteVolume']  # 假設取用最新價格和最近成交量估算市值
        return market_cap >= 1e8  # 大於 1 億美元
        
    return False

def fetch_all_ohlcv(symbol, timeframe, since, end_time=None):
    all_ohlcv = []
    limit = 1000  # MEXC 每次請求最大 1000 條
    if end_time is None:
        end_time = int(time.time() * 1000)
    
    current_since = since
    
    while current_since < end_time:
        try:
            ohlcv = exchange.fetch_ohlcv(symbol, timeframe, current_since, limit)
            
            if not ohlcv:
                current_since += 24 * 60 * 60 * 1000  # 推進一天
                continue
            
            all_ohlcv.extend(ohlcv)
            current_since = ohlcv[-1][0] + 1
            
            time.sleep(0.1)  # 遵守 CCXT 速率限制
            
        except ccxt.BaseError as e:
            print(f"Error fetching data for {symbol}: {str(e)}")
            current_since += 24 * 60 * 60 * 1000  # 推進一天
            continue
    
    return all_ohlcv

def get_historical_data(symbol, timeframe, starttime):
    """獲取完整歷史數據"""
    since = exchange.parse8601(starttime)
    all_ohlcv = fetch_all_ohlcv(symbol, timeframe, since)
    df = pd.DataFrame(all_ohlcv, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])
    df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms')
    df = df.sort_values('timestamp').reset_index(drop=True)
    return df

def filter_10_symbols(symbols):
    filtered_symbols = []

    for symbol in symbols:
        try:
            df = exchange.fetch_ohlcv(symbol, '1m', limit=1)
            if len(df) == 0:
                print(f"{symbol}: 歷史數據為空，跳過")
                continue
            df = pd.DataFrame(df, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])
            df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms')
            df = df.sort_values('timestamp').reset_index(drop=True)
            current_price = df['close'].iloc[-1]
            if current_price >= 100:
                filtered_symbols.append(symbol)
        except Exception as e:
            print(f"檢查 {symbol} 時發生錯誤: {str(e)}")

    return filtered_symbols

def filter_symbols(symbols):
    """過濾支持 0.1% 價差的交易對"""
    filtered_symbols = []
    markets = exchange.load_markets()  # 一次性載入市場數據
    
    for symbol in symbols:
        try:
            # 獲取歷史數據以取得當前價格
            df = get_historical_data(symbol)
            if len(df) == 0:
                print(f"{symbol}: 歷史數據為空，跳過")
                continue
            current_price = df['close'].iloc[-1]
            if current_price <= 0:
                print(f"{symbol}: 價格無效 ({current_price})，跳過")
                continue
            
            # 獲取價格精度（MEXC 返回的是 tick_size）
            tick_size = markets[symbol]['precision']['price']  # 直接使用 API 返回的浮點數
            
            # 計算 0.01% 價差
            price_difference = current_price * 0.0001  # 0.01%
            
            # 檢查 0.1% 價差是否足夠
            if price_difference >= tick_size:
                print(f"{symbol}:支持0.01%價差")
                filtered_symbols.append(symbol)
            else:
                print(f"{symbol}:不支持0.01%價差")
        except Exception as e:
            print(f"檢查 {symbol} 時發生錯誤: {str(e)}")
    return filtered_symbols

def wilder_ema(series, length):
    alpha = 1.0 / length
    ema = pd.Series(index=series.index, dtype=float)
    
    for i in range(len(series)):
        if i < length - 1:
            ema.iloc[i] = np.nan  # 前 length-1 期為 NaN
        elif i == length - 1:
            # 手動計算 SMA，模仿 pine_sma，將 NaN 轉為 0
            sma_sum = 0.0
            for j in range(length):
                sma_sum += 0 if pd.isna(series.iloc[j]) else series.iloc[j]
            ema.iloc[i] = sma_sum / length
        else:
            # Wilder EMA 公式，確保前值有效
            ema.iloc[i] = alpha * (0 if pd.isna(series.iloc[i]) else series.iloc[i]) + \
                         (1 - alpha) * (0 if pd.isna(ema.iloc[i-1]) else ema.iloc[i-1])
    
    return ema

def is_pivot_low(series, i, left, right):
    if i < left or i >= len(series) - right:
        return False
    val = series.iloc[i]
    if pd.isna(val):
        return False
    for j in range(i - left, i + right + 1):
        if j != i and not pd.isna(series.iloc[j]) and series.iloc[j] <= val - 1e-8:
            return False
    return True

def is_pivot_high(series, i, left, right):
    if i < left or i >= len(series) - right:
        return False
    val = series.iloc[i]
    if pd.isna(val):
        return False
    for j in range(i - left, i + right + 1):
        if j != i and not pd.isna(series.iloc[j]) and series.iloc[j] >= val + 1e-8:
            return False
    return True

def calculate_indicators(df):
    # MA
    df['ma5'] = df['close'].rolling(window=5).mean()
    df['ma10'] = df['close'].rolling(window=10).mean()
    df['ma20'] = df['close'].rolling(window=20).mean()
    df['ma200'] = df['close'].rolling(window=200).mean()

    # EMA
    df['ema10'] = df['close'].ewm(span=10, adjust=False).mean()
    df['ema20'] = df['close'].ewm(span=20, adjust=False).mean()
    df['ema50'] = df['close'].ewm(span=50, adjust=False).mean()
    df['ema60'] = df['close'].ewm(span=60, adjust=False).mean()
    df['ema100'] = df['close'].ewm(span=100, adjust=False).mean()
    df['ema200'] = df['close'].ewm(span=200, adjust=False).mean()

    df['highest_high'] = df['high'].rolling(window=55, min_periods=1).max()
    df['lowest_low'] = df['low'].rolling(window=55, min_periods=1).min()

    # 計算20周期平均振幅
    df['amplitude'] = (df['high'] - df['low']) / df['low'] * 100
    df['amplitude'] = df['amplitude'].where(df['low'] != 0, 0)
    df['avg_amplitude_20'] = df['amplitude'].rolling(window=20, min_periods=20).mean()
    df['amplitude_real_10'] = (df['high'] - df['low']).rolling(window=10, min_periods=10).mean()
    df['avg_volume_20'] = df['volume'].rolling(window=20, min_periods=20).mean()

    # RSI 計算
    delta = df['close'].diff()
    gain = delta.where(delta > 0, 0)
    loss = -delta.where(delta < 0, 0)
    avg_gain_7 = wilder_ema(gain, 7)
    avg_gain_14 = wilder_ema(gain, 14)
    avg_gain_25 = wilder_ema(gain, 25)
    avg_gain_35 = wilder_ema(gain, 35)
    avg_gain_100 = wilder_ema(gain, 100)
    avg_loss_7 = wilder_ema(loss, 7)
    avg_loss_14 = wilder_ema(loss, 14)
    avg_loss_25 = wilder_ema(loss, 25)
    avg_loss_35 = wilder_ema(loss, 35)
    avg_loss_100 = wilder_ema(loss, 100)
    rs_7 = avg_gain_7 / avg_loss_7.replace(0, np.nan)
    rs_14 = avg_gain_14 / avg_loss_14.replace(0, np.nan)
    rs_25 = avg_gain_25 / avg_loss_25.replace(0, np.nan)
    rs_35 = avg_gain_35 / avg_loss_35.replace(0, np.nan)
    rs_100 = avg_gain_100 / avg_loss_100.replace(0, np.nan)
    df['rsi7'] = 100 - (100 / (1 + rs_7))
    df['rsi14'] = 100 - (100 / (1 + rs_14))
    df['rsi25'] = 100 - (100 / (1 + rs_25))
    df['rsi35'] = 100 - (100 / (1 + rs_35))
    df['rsi100'] = 100 - (100 / (1 + rs_100))
    df['rsi14_cumsum'] = 0.0  # 初始化累加求和列
    cumsum = 0.0  # 當前累加值
    for i in range(1, len(df)):
        if df['rsi14'].iloc[i] < 30:
            # RSI14 < 30，計算當前週期累加值並加到總和
            cumsum += (30 - df['rsi14'].iloc[i])
        else:
            # RSI14 >= 30，重置累加值
            cumsum = 0.0
        df.loc[i, 'rsi14_cumsum'] = cumsum  # 使用 .loc 進行賦值

    # KDJ
    low_9 = df['low'].rolling(9).min()
    high_9 = df['high'].rolling(9).max()
    rsv = (df['close'] - low_9) / (high_9 - low_9) * 100
    df['k'] = rsv.ewm(span=3, adjust=False).mean()
    df['d'] = df['k'].ewm(span=3, adjust=False).mean()
    df['j'] = 3 * df['k'] - 2 * df['d']

    # MACD 計算
    exp12 = df['close'].ewm(span=12, adjust=False).mean()
    exp26 = df['close'].ewm(span=26, adjust=False).mean()
    df['macd'] = exp12 - exp26
    df['signal'] = df['macd'].ewm(span=9, adjust=False).mean()
    df['histogram'] = df['macd'] - df['signal']
    window = 200
    percentile_high = 90
    percentile_low = 10
    df['macd_90th'] = df['macd'].rolling(window=window, min_periods=window).quantile(percentile_high / 100)
    df['macd_10th'] = df['macd'].rolling(window=window, min_periods=window).quantile(percentile_low / 100)
    df['signal_90th'] = df['signal'].rolling(window=window, min_periods=window).quantile(percentile_high / 100)
    df['signal_10th'] = df['signal'].rolling(window=window, min_periods=window).quantile(percentile_low / 100)
    df['macd_above_90th'] = False
    df['macd_below_10th'] = False
    df['signal_above_90th'] = False
    df['signal_below_10th'] = False
    mask = df['macd'].notnull() & (df.index >= window - 1)  # 確保有 200 周期數據
    df.loc[mask, 'macd_above_90th'] = df['macd'] > df['macd_90th']
    df.loc[mask, 'macd_below_10th'] = df['macd'] < df['macd_10th']
    df.loc[mask, 'signal_above_90th'] = df['signal'] > df['signal_90th']
    df.loc[mask, 'signal_below_10th'] = df['signal'] < df['signal_10th']

    # atr
    df['previous_close'] = df['close'].shift(1)  # 前一收盤價
    df['tr1'] = df['high'] - df['low']  # 當期高低差
    df['tr2'] = (df['high'] - df['previous_close']).abs()  
    df['tr3'] = (df['low'] - df['previous_close']).abs()  
    df['tr'] = df[['tr1', 'tr2', 'tr3']].max(axis=1)  # True Range
    df['atr'] = df['tr'].ewm(alpha=1/14, adjust=False).mean()  # 14周期Wilder EMA
    
    # ADX
    df['plus_dm'] = np.where(
        (df['high'] - df['high'].shift(1)) > (df['low'].shift(1) - df['low']),
        np.maximum(df['high'] - df['high'].shift(1), 0),
        0
    )
    df['minus_dm'] = np.where(
        (df['low'].shift(1) - df['low']) > (df['high'] - df['high'].shift(1)),
        np.maximum(df['low'].shift(1) - df['low'], 0),
        0
    )
    df['tr_smooth'] = df['tr'].ewm(alpha=1/14, adjust=False).mean()
    df['plus_dm_smooth'] = df['plus_dm'].ewm(alpha=1/14, adjust=False).mean()
    df['minus_dm_smooth'] = df['minus_dm'].ewm(alpha=1/14, adjust=False).mean()
    df['plus_di'] = (df['plus_dm_smooth'] / df['tr_smooth']) * 100
    df['minus_di'] = (df['minus_dm_smooth'] / df['tr_smooth']) * 100
    df['dx'] = abs(df['plus_di'] - df['minus_di']) / (df['plus_di'] + df['minus_di']) * 100
    df['dx'] = df['dx'].fillna(0)  # 處理除以零的情況
    df['adx'] = df['dx'].ewm(alpha=1/14, adjust=False).mean()

    # MACD 背離檢測參數
    lbL = 1
    lbR = 0
    rangeLower = 0
    rangeUpper = 60
    divergence = 'Histogram'
    divsrc = 'Wicks'

    # 選擇背離數據來源
    osc = df['histogram']
    srch = df['high'] if divsrc == 'Wicks' else df[['open', 'close']].max(axis=1)
    srcl = df['low'] if divsrc == 'Wicks' else df[['open', 'close']].min(axis=1)

    # 初始化背離列
    df['bull_divergence'] = False
    df['bear_divergence'] = False
    df['pivot_low'] = False
    df['pivot_high'] = False

    # 計算20周期收盤價均值，用於標準化 histogram
    close_mean = df['close'].rolling(window=20, min_periods=20).mean()

    # 計算每個 K 線的背離
    for i in range(lbL + lbR, len(df)):
        plFound = is_pivot_low(osc, i - lbR, lbL, lbR)
        phFound = is_pivot_high(osc, i - lbR, lbL, lbR)

        if plFound:
            df.at[df.index[i - lbR], 'pivot_low'] = True
        if phFound:
            df.at[df.index[i - lbR], 'pivot_high'] = True

        # 獲取當前周期的 avg_amplitude_20
        amplitude_threshold = df['avg_amplitude_20'].iloc[i - lbR] * 0.001 if not pd.isna(df['avg_amplitude_20'].iloc[i - lbR]) else 0

        if plFound:
            bars = bars_since(osc, is_pivot_low, i - lbR)
            if rangeLower <= bars <= rangeUpper and (i - bars) >= 0:
                osc_val = osc.iloc[i - lbR]
                prev_osc_val = osc.iloc[i - bars]
                price_val = srcl.iloc[i - lbR]
                prev_price_val = srcl.iloc[i - bars]
                # 價格相對差異
                price_diff_pct = abs(price_val - prev_price_val) / prev_price_val * 100 if prev_price_val != 0 else 0
                price_valid = not pd.isna(price_diff_pct) and price_diff_pct >= amplitude_threshold
                # 標準化 histogram
                close_mean_val = close_mean.iloc[i - lbR]
                prev_close_mean_val = close_mean.iloc[i - bars]
                osc_relative = osc_val / close_mean_val * 100 if close_mean_val != 0 else 0
                prev_osc_relative = prev_osc_val / prev_close_mean_val * 100 if prev_close_mean_val != 0 else 0
                osc_diff_pct = abs(osc_relative - prev_osc_relative)
                osc_valid = not pd.isna(osc_diff_pct) and osc_diff_pct >= amplitude_threshold
                oscHL = osc_val > prev_osc_val
                priceLL = price_val < prev_price_val
                if oscHL and priceLL and osc_valid and price_valid:
                    df.at[df.index[i - lbR], 'bull_divergence'] = True

        if phFound:
            bars = bars_since(osc, is_pivot_high, i - lbR)
            if rangeLower <= bars <= rangeUpper and (i - bars) >= 0:
                osc_val = osc.iloc[i - lbR]
                prev_osc_val = osc.iloc[i - bars]
                price_val = srch.iloc[i - lbR]
                prev_price_val = srch.iloc[i - bars]
                # 價格相對差異
                price_diff_pct = abs(price_val - prev_price_val) / prev_price_val * 100 if prev_price_val != 0 else 0
                price_valid = not pd.isna(price_diff_pct) and price_diff_pct >= amplitude_threshold
                # 標準化 histogram
                close_mean_val = close_mean.iloc[i - lbR]
                prev_close_mean_val = close_mean.iloc[i - bars]
                osc_relative = osc_val / close_mean_val * 100 if close_mean_val != 0 else 0
                prev_osc_relative = prev_osc_val / prev_close_mean_val * 100 if prev_close_mean_val != 0 else 0
                osc_diff_pct = abs(osc_relative - prev_osc_relative)
                osc_valid = not pd.isna(osc_diff_pct) and osc_diff_pct >= amplitude_threshold
                oscLH = osc_val < prev_osc_val
                priceHH = price_val > prev_price_val
                if oscLH and priceHH and osc_valid and price_valid:
                    df.at[df.index[i - lbR], 'bear_divergence'] = True

    # 布林通道
    df['ma20'] = df['close'].rolling(window=20).mean()
    df['std20'] = df['close'].rolling(window=20).std()
    df['boll_upper'] = df['ma20'] + (df['std20'] * 2)
    df['boll_lower'] = df['ma20'] - (df['std20'] * 2)

    return df

def bars_since(series, condition, i):
    prev_idx = -1
    for j in range(i - 1, max(0, i - 60), -1):
        if condition(series, j, 5, 1):
            prev_idx = j
            break
    if prev_idx == -1:
        return np.inf
    return i - prev_idx

def boll_check_conditions(row, prev_row):
    long_boll_cond = prev_row['low'] <= prev_row['boll_upper'] and row['low'] > row['boll_upper']
    short_boll_cond = prev_row['high'] >= prev_row['boll_lower'] and row['high'] < row['boll_lower']
    adx_cond = row['adx'] >= 30
    if long_boll_cond and adx_cond:
        return 'long', True
    elif short_boll_cond and adx_cond:
        return 'short', True
    return None, False

def ma_check_conditions(row, prev_row):
    long_ma_cond = prev_row['close'] > prev_row['ma5'] and prev_row['ma5'] > prev_row['ma20'] and prev_row['ma10'] < prev_row['ma20'] and row['close'] > row['ma5'] and row['ma5'] > row['ma10'] and row['ma10'] > row['ma20']
    short_ma_cond = prev_row['close'] < prev_row['ma5'] and prev_row['ma5'] < prev_row['ma20'] and prev_row['ma10'] > prev_row['ma20'] and row['close'] < row['ma5'] and row['ma5'] < row['ma10'] and row['ma10'] < row['ma20']
    adx_cond = row['adx'] >= 30
    if long_ma_cond and adx_cond:
        return 'long', True
    elif short_ma_cond and adx_cond:
        return 'short', True
    return None, False

def swing_check_conditions(row, prev_row, prev_prev_row):
    long_swing_cond = prev_prev_row['low'] < prev_prev_row['boll_lower'] and prev_prev_row['high'] > prev_prev_row['boll_lower'] and prev_prev_row['close'] < prev_prev_row['open'] and prev_row['close'] > prev_row['open'] and prev_row['high'] > prev_row['boll_lower'] and row['close'] > row['open']
    short_swing_cond = prev_prev_row['high'] > prev_prev_row['boll_upper'] and prev_prev_row['low'] < prev_prev_row['boll_upper'] and prev_prev_row['close'] > prev_prev_row['open'] and prev_row['close'] < prev_row['open'] and prev_row['low'] < prev_row['boll_upper'] and row['close'] < row['open']
    adx_cond = row['adx'] <= 15
    if long_swing_cond and adx_cond:
        return 'long', True
    elif short_swing_cond and adx_cond:
        return 'short', True
    return None, False

def rsi_20_100_check_conditions(row, prev_row):
    long_rsi_cond = row['rsi25'] > row['rsi100'] and prev_row['close'] < prev_row['ema60'] and row['close'] > row['ema60']
    short_rsi_cond = row['rsi25'] < row['rsi100'] and prev_row['close'] > prev_row['ema60'] and row['close'] < row['ema60']
    adx_cond = row['adx'] >= 30
    if long_rsi_cond and adx_cond:
        return 'long', True
    elif short_rsi_cond and adx_cond:
        return 'short', True
    return None, False

def macd_check_conditions(row, prev_row):
    long_macd_cond = row['signal'] < 0 and row['macd'] > row['signal'] and prev_row['macd'] < prev_row['signal']
    short_macd_cond = row['signal'] > 0 and row['macd'] < row['signal'] and prev_row['macd'] > prev_row['signal']
    long_percentile_cond = row['macd_below_10th'] and row['signal_below_10th'] and prev_row['macd_below_10th'] and prev_row['signal_below_10th']
    short_percentile_cond = row['macd_above_90th'] and row['signal_above_90th'] and prev_row['macd_above_90th'] and prev_row['signal_above_90th']
    adx_cond = row['adx'] <= 15
    if long_macd_cond and long_percentile_cond and adx_cond:
        return 'long', True
    elif short_macd_cond and short_percentile_cond and adx_cond:
        return 'short', True
    
    return None, False

def vk_check_conditions(row, prev_row):
    long_vk_cond = row['volume'] > prev_row['avg_volume_20'] * 1.5 and row['low'] < prev_row['low'] and row['close'] > prev_row['high'] and row['close'] > row['open']
    short_vk_cond = row['volume'] > prev_row['avg_volume_20'] * 1.5 and row['high'] > prev_row['high'] and row['close'] < prev_row['low'] and row['close'] < row['open']
    adx_cond = row['adx'] >= 30
    if long_vk_cond and adx_cond:
        return 'long', True
    elif short_vk_cond and adx_cond:
        return 'short', True
    return None, False

def drsi_check_conditions(row):
    long_drsi_cond = row['close'] > row['ema50'] and row['rsi35'] - row['rsi7'] >= 20
    short_drsi_cond = row['close'] < row['ema50'] and row['rsi7'] - row['rsi35'] >= 20
    adx_cond = row['adx'] <= 15
    if long_drsi_cond and adx_cond:
        return 'long', True
    elif short_drsi_cond and adx_cond:
        return 'short', True
    return None, False

def check_exit_conditions(row):
    """检查平仓条件(新增histogram验证)"""
    global current_position
    exit_reason = None
    direction = current_position['direction']
    try:
        if direction == 'long':
            if current_position['saving_stop_loss'] is not None and row['low'] <= current_position['saving_stop_loss']:
                exit_reason = 'saving_stop_loss'
                return exit_reason
            elif row['low'] <= current_position['stop_loss']:
                exit_reason = 'Stop_Loss'
                return exit_reason
            elif row['high'] >= current_position['take_profit']:
                exit_reason = 'Take_Profit'
                return exit_reason
        elif direction == 'short':
            if current_position['saving_stop_loss'] is not None and row['high'] >= current_position['saving_stop_loss']:
                exit_reason = 'saving_stop_loss'
                return exit_reason
            elif row['high'] >= current_position['stop_loss']:
                exit_reason = 'Stop_Loss'
                return exit_reason
            elif row['low'] <= current_position['take_profit']:
                exit_reason = 'Take_Profit'
                return exit_reason
        return exit_reason
    except Exception as e:
        print(f"Exit condition check error: {str(e)}")
        return exit_reason
    
def fetch_df_depend_on_symbol(symbol):
    """根据交易对获取历史数据"""
    try:
        ohlcv = exchange.fetch_ohlcv(symbol, '1h', limit=1)
        close = ohlcv[-1][4] if ohlcv else None
        if close is None:
            print(f"获取 {symbol} 的历史数据失败，收盘价为空")
            return None, None
        if close >= 1000:
            print(f"正在獲取歷史數據... {symbol} (1h)")
            df = get_historical_data(symbol, TIMEFRAME_1H, START_DATE_1H)
            capital_leverage = 0.2 * 8
            print(f"獲取到 {len(df)} 根 1h K線數據")
        elif close >= 500:
            print(f"正在獲取歷史數據... {symbol} (2h)")
            df = get_historical_data(symbol, TIMEFRAME_2H, START_DATE_2H)
            capital_leverage = 0.2 * 4
            print(f"獲取到 {len(df)} 根 2h K線數據")
        elif close >= 100:
            print(f"正在獲取歷史數據... {symbol} (4h)")
            df = get_historical_data(symbol, TIMEFRAME_4H, START_DATE_4H)
            capital_leverage = 0.2 * 2
            print(f"獲取到 {len(df)} 根 4h K線數據")
        elif close >= 1:
            print(f"正在獲取歷史數據... {symbol} (8h)")
            df = get_historical_data(symbol, TIMEFRAME_8H, START_DATE_8H)
            capital_leverage = 0.2
            print(f"獲取到 {len(df)} 根 8h K線數據")
        else:
            print(f"正在獲取歷史數據... {symbol} (12h)")
            df = get_historical_data(symbol, TIMEFRAME_12H, START_DATE_12H)
            capital_leverage = 0.1
            print(f"獲取到 {len(df)} 根 12h K線數據")
        return df, capital_leverage
    except Exception as e:
        print(f"获取 {symbol} 的历史数据时发生错误: {str(e)}")
        return None, None
    
def saving_stop_loss(row, prev_row):
    global current_position
    if current_position['saving_stop_loss'] is None:
        if current_position['direction'] == 'long':
            #if row['high'] >= current_position['entry_price'] * 1.001:
                #current_position['saving_stop_loss'] = current_position['entry_price']
            if prev_row['low'] > current_position['entry_price'] * 1.001 and row['low'] > prev_row['low']:
                current_position['saving_stop_loss'] = prev_row['low']
        elif current_position['direction'] == 'short':
            if prev_row['high'] < current_position['entry_price'] * 0.999 and row['high'] < prev_row['high']:
                current_position['saving_stop_loss'] = prev_row['high']
    else:
        if current_position['direction'] == 'long':
            #if row['high'] >= current_position['saving_stop_loss'] * 1.002:
                #current_position['saving_stop_loss'] = current_position['saving_stop_loss'] * 1.001
            if prev_row['low'] > current_position['saving_stop_loss'] and row['low'] > prev_row['low']:
                current_position['saving_stop_loss'] = prev_row['low']
        elif current_position['direction'] == 'short':
            if prev_row['high'] < current_position['saving_stop_loss'] and row['high'] < prev_row['high']:
                current_position['saving_stop_loss'] = prev_row['high']
    
def run_backtest(symbol):
    global capital, current_position, trade_count, profitable_trades, dfs_by_symbol, dfs_by_timesamps

    print(f"正在獲取歷史數據... {symbol} (1h)")
    df = get_historical_data(symbol, TIMEFRAME_1H, START_DATE_1H)
    capital_leverage = 1
    print(f"獲取到 {len(df)} 根 1h K線數據")

    print(f"計算 {symbol} 的指標...")
    df = calculate_indicators(df)

    print(f"開始回測... {symbol}")
    for i in range(22, len(dfs_by_timesamps)):  # 跳过前两行确保指标计算准确
        row = dfs_by_timesamps.iloc[i]
        prev_row = dfs_by_timesamps.iloc[i-1]

        # 检查平仓
        if current_position:
            round += 1
            #saving_stop_loss(row, prev_row)
            exit_reason = check_exit_conditions(row)
            if exit_reason:
                close_trade(row, exit_reason, capital_leverage)
            elif round >= 20:
                close_trade(row, 'Round_Limit', capital_leverage)
                continue
        
        # 检查开仓
        if not current_position:
            direction, open_condition = boll_check_conditions(row, prev_row)
            if open_condition:
                if direction == 'long':
                    stop_loss = row['close'] - (row['boll_upper'] - row['ma20'])
                    take_profit = row['close'] + ((row['boll_upper'] - row['ma20']) * 1.5)
                elif direction == 'short':
                    stop_loss = row['close'] + (row['ma20'] - row['boll_lower'])
                    take_profit = row['close'] - ((row['ma20'] - row['boll_lower']) * 1.5)
                round = 0
                execute_trade(row, symbol, take_profit, stop_loss, direction)
            else:
                continue
    
    if current_position:
        print(f"{symbol} 最後賣出: 現在價格: {row['close']}")
        close_trade(row, 'End_of_Data', capital_leverage)

    print(f"回測完成！{symbol}")

def run_backtest_by_timsamps():
    global capital, current_position, trade_count, profitable_trades, dfs_by_symbol, dfs_by_timesamps, closed_trades

    capital_leverage = 1

    # 獲取所有唯一時間戳
    unique_timestamps = dfs_by_timesamps['timestamp'].unique()

    for timestamp in unique_timestamps:
        print(f"回測時間：{timestamp}")
        # 獲取當前時間戳的所有數據
        current_timestamp_data = dfs_by_timesamps[dfs_by_timesamps['timestamp'] == timestamp]
        if timestamp == unique_timestamps[0]:
            continue
        #elif timestamp == unique_timestamps[1]:
            #continue
        #elif timestamp == unique_timestamps[2]:
            #continue

        # 迭代當前時間戳的所有股票
        for symbol in current_timestamp_data['symbol'].unique():
            row = current_timestamp_data[current_timestamp_data['symbol'] == symbol].iloc[0]

            previous_timestamp = unique_timestamps[unique_timestamps.tolist().index(timestamp) -1]
            previous_timestamp_data = dfs_by_timesamps[dfs_by_timesamps['timestamp'] == previous_timestamp]
            if symbol in previous_timestamp_data['symbol'].values:
                prev_row = previous_timestamp_data[previous_timestamp_data['symbol'] == symbol].iloc[0]
            else:
                continue

            #prev_timestamp = unique_timestamps[unique_timestamps.tolist().index(timestamp) - 1]
            #prev_prev_timestamp = unique_timestamps[unique_timestamps.tolist().index(timestamp) - 2]
            #prev_prev_prev_timestamp = unique_timestamps[unique_timestamps.tolist().index(timestamp) - 3]
            #prev_data_exists = symbol in dfs_by_timesamps[dfs_by_timesamps['timestamp'] == prev_timestamp]['symbol'].values
            #prev_prev_data_exists = symbol in dfs_by_timesamps[dfs_by_timesamps['timestamp'] == prev_prev_timestamp]['symbol'].values
            #prev_prev_prev_data_exists = symbol in dfs_by_timesamps[dfs_by_timesamps['timestamp'] == prev_prev_prev_timestamp]['symbol'].values
            #if prev_data_exists and prev_prev_data_exists and prev_prev_prev_data_exists:
                #prev_row = dfs_by_timesamps[
                    #(dfs_by_timesamps['timestamp'] == prev_timestamp) & 
                    #(dfs_by_timesamps['symbol'] == symbol)
                #].iloc[0]
                #prev_prev_row = dfs_by_timesamps[
                    #(dfs_by_timesamps['timestamp'] == prev_prev_timestamp) & 
                    #(dfs_by_timesamps['symbol'] == symbol)
                #].iloc[0]
                #prev_prev_prev_row = dfs_by_timesamps[
                    #(dfs_by_timesamps['timestamp'] == prev_prev_prev_timestamp) & 
                    #(dfs_by_timesamps['symbol'] == symbol)
                #].iloc[0]
            #else:
                #continue

            # 检查平仓
            if current_position:
                current_timestamp_index = unique_timestamps.tolist().index(timestamp)
                for future_timestamp in unique_timestamps[current_timestamp_index + 1:]: # 从下一个时间戳开始迭代
                    round += 1
                    try:
                        future_row = dfs_by_timesamps[(dfs_by_timesamps['timestamp'] == future_timestamp) & (dfs_by_timesamps['symbol'] == symbol)].iloc[0]
                        exit_reason = check_exit_conditions(future_row)
                        if exit_reason:
                            close_trade(exit_reason, capital_leverage, future_row)
                            closed_trades[symbol] = future_timestamp
                            break
                        elif round >= 20:
                            exit_reason = 'Round_Limit'
                            close_trade(exit_reason, capital_leverage, future_row)
                            closed_trades[symbol] = future_timestamp
                            break
                    except Exception as e:
                        print(f"Error: {e}")
                        close_trade(reason="Error", capital_leverage=capital_leverage)
                        continue
                if exit_reason is None:
                    try:
                        last_row = dfs_by_timesamps[(dfs_by_timesamps['timestamp'] == unique_timestamps[-1]) & (dfs_by_timesamps['symbol'] == symbol)].iloc[0]
                        print(f"{symbol} 最後賣出: 現在價格: {last_row['close']}")
                        close_trade('End_of_Data', capital_leverage, last_row)
                        closed_trades[symbol] = unique_timestamps[-1]
                    except Exception as e:
                        print(f"Error: {e}")
                        close_trade(reason="Error", capital_leverage=capital_leverage)
                        continue

            # 检查开仓
            if not current_position:
                if symbol in closed_trades and timestamp <= closed_trades[symbol]:
                    continue
                if row is None or prev_row is None:
                    continue
                direction, open_condition = ma_check_conditions(row=row, prev_row=prev_row)
                if open_condition:
                    if direction == 'long':
                        stop_loss = row['close'] - (prev_row['boll_upper'] - prev_row['ma20'])
                        take_profit = row['close'] + ((prev_row['boll_upper'] - prev_row['ma20']) * 1.5)
                    elif direction == 'short':
                        stop_loss = row['close'] + (prev_row['ma20'] - prev_row['boll_lower'])
                        take_profit = row['close'] - ((prev_row['ma20'] - prev_row['boll_lower']) * 1.5)
                    round = 0
                    execute_trade(row, symbol, take_profit, stop_loss, direction)
                else:
                    continue

    print(f"所有回測完成！")

def execute_trade(row, symbol, take_profit, stop_loss, direction):
    global current_position
    current_position = {
        'symbol': symbol,
        'entry_price': row['close'],
        'entry_time': row['timestamp'],
        'direction': direction,
        'entry_ts': row['timestamp'],
        'take_profit': take_profit,
        'stop_loss': stop_loss,
        'saving_stop_loss': None
    }

def close_trade(reason, capital_leverage, row=None):
    global capital, trade_count, profitable_trades, current_position, trade_statistics, total_profit_amount, max_loss_amount, max_loss_trade_amount
    global max_loss_trade_info, max_loss_percentage, max_loss_percentage_info, max_time, min_profit_trade_info, min_profit_percentage
    global target_profit, saving_capital, saving_round, reset_round, decrease_round
    direction = current_position['direction']
    if row is not None:
        if not row.empty:
            timesampe = row['timestamp']
        else:
            timesampe = "Error"
    else:
        timesampe = "Error"
    
    if direction == 'long':
        if reason == 'Stop_Loss':
            left_price = current_position['stop_loss']
            exit_price = left_price * 0.9995
        elif reason == 'saving_stop_loss':
            left_price = current_position['saving_stop_loss']
            exit_price = left_price * 0.9995
        elif reason == 'Take_Profit':
            left_price = current_position['take_profit']
            exit_price = left_price * 0.9995
        elif row is None and reason == 'Error':
            left_price = current_position['entry_price']
            exit_price = left_price * 0.9995
        else:
            left_price = row['close']
            exit_price = left_price * 0.9995
    elif direction == 'short':
        if reason == 'Stop_Loss':
            left_price = current_position['stop_loss']
            exit_price = left_price * 1.0005
        elif reason == 'saving_stop_loss':
            left_price = current_position['saving_stop_loss']
            exit_price = left_price * 1.0005
        elif reason == 'Take_Profit':
            left_price = current_position['take_profit']
            exit_price = left_price * 1.0005
        elif row is None and reason == 'Error':
            left_price = current_position['entry_price']
            exit_price = left_price * 1.0005
        else:
            left_price = row['close']
            exit_price = left_price * 1.0005
    
    if direction == 'long':
        crypto_amount = capital * capital_leverage / current_position['entry_price']
        crypto_amount_after_fee = crypto_amount * 0.99955
        after_exit_usdt_amount = crypto_amount_after_fee * exit_price
        after_exit_usdt_amount_after_fee = after_exit_usdt_amount * 0.99955
        pnl = after_exit_usdt_amount_after_fee - capital * capital_leverage
        change_percentage = abs(pnl) / capital * capital_leverage * 100
    elif direction == 'short':
        crypto_amount = capital * capital_leverage / current_position['entry_price']
        crypto_amount_after_fee = crypto_amount * 1.00045
        after_exit_usdt_amount = crypto_amount_after_fee * exit_price
        after_exit_usdt_amount_after_fee = after_exit_usdt_amount * 1.00045
        pnl = capital * capital_leverage - after_exit_usdt_amount_after_fee
        change_percentage = abs(pnl) / capital * capital_leverage * 100
    if pnl < 0:
        change_percentage = -change_percentage
        change_percentage = f"{change_percentage:.2f}%"
    elif pnl > 0:
        change_percentage = f"{change_percentage:.2f}%"

    symbol = current_position['symbol']
    if symbol not in trade_statistics:
        trade_statistics[symbol] = {
            'profit_trades': 0,
            'loss_trades': 0,
            'total_trades': 0
        }
    
    profit_status = 'Profit' if pnl > 0 else 'Loss'

    if pnl > 0:
        total_profit_amount += pnl
        trade_statistics[symbol]['profit_trades'] += 1
        trade_statistics[symbol]['total_trades'] += 1
        profitable_trades += 1
        profit_percentage_amount = (pnl / capital)
        profit_percentage = f"{(pnl / capital):.2%}"

        if 'min_profit_percentage' not in locals():
            min_profit_percentage = float('inf')  # 或者其他适合的初始值

        if profit_percentage_amount < min_profit_percentage:
            min_profit_percentage = profit_percentage
            min_profit_trade_info = {
            'trade_number': trade_count + 1,  # 当前交易次数 + 1
            'open_time': current_position['entry_time'],
            'close_time': timesampe,
            'open_price': current_position['entry_price'],
            'close_price': left_price,
            'gain': pnl,
            'capital': capital,
            'profit_percentage': profit_percentage
            }
    else:
        max_loss_amount += abs(pnl)
        loss_percentage_amount = (abs(pnl) / capital)
        loss_percentage = f"{(abs(pnl) / capital):.2%}"
        if loss_percentage_amount > max_loss_percentage:
            max_loss_percentage = loss_percentage_amount
            max_loss_percentage_info = {
            'trade_number': trade_count + 1,  # 当前交易次数 + 1
            'open_time': current_position['entry_time'],
            'close_time': timesampe,
            'open_price': current_position['entry_price'],
            'close_price': left_price,
            'gain': pnl,
            'capital': capital,
            'loss_percentage': loss_percentage
            }
        if abs(pnl) > max_loss_trade_amount:
            max_loss_trade_amount = abs(pnl)
            max_loss_trade_info = {
            'trade_number': trade_count + 1,  # 当前交易次数 + 1
            'open_time': current_position['entry_time'],
            'close_time': timesampe,
            'open_price': current_position['entry_price'],
            'close_price': left_price,
            'gain': pnl,
            'capital': capital,
            'loss_percentage': loss_percentage
            }
        trade_statistics[symbol]['loss_trades'] += 1
        trade_statistics[symbol]['total_trades'] += 1
    
    if pnl < 0 and abs(pnl) > capital:
        capital = 0
    else:
        capital += pnl

    # 新增目標利潤機制判斷
    if capital >= target_profit:
        half_capital = target_profit / 2
        saving_round += 1
        saving_capital += half_capital
        capital -= half_capital
        target_profit = half_capital * 4
        print(f"第{saving_round}次達到目標利潤，轉出一半資本到儲蓄: {half_capital:.2f} USDT，更新資本: {capital:.2f}，新目標利潤: {target_profit:.2f}")
    elif capital == 0:
        if saving_capital >= 1000:
            capital = 1000
            reset_round += 1
            saving_capital -= 1000
            target_profit = 4000
            print(f"資本等於 0 USDT，從儲蓄中提取1000 USDT，更新資本: {capital:.2f} USDT，重置目標利潤: {target_profit:.2f} USDT")
        elif saving_capital != 0:
            capital = saving_capital
            saving_capital = 0
            reset_round += 1
            target_profit = capital * 4
            print(f"資本等於 0 USDT，且儲蓄不足1000，從儲蓄中提取所有USDT，更新資本: {capital:.2f} USDT，重置目標利潤: {target_profit:.2f} USDT")
        else:
            print("資本為0，且儲蓄為0，退出程式。")
            sys.exit(1)
    elif capital < 600:
        if saving_capital >= 500:
            reset_round += 1
            saving_capital -= 500
            capital += 500
            target_profit = 4000
            print(f"資本低於600 USDT，從儲蓄中提取500 USDT，更新資本: {capital:.2f} USDT，重置目標利潤: {target_profit:.2f} USDT")
        else:
            if capital <= target_profit / 8:
                target_profit = target_profit / 2
                print(f"資本低於600 USDT且儲蓄不足500 USDT，無法重置，當前資本: {capital:.2f} USDT，且更新目標利潤: {target_profit:.2f} USDT")
    elif capital <= target_profit / 8:
        decrease_round += 1
        target_profit = target_profit / 2
        print(f"第{decrease_round}次資本低於目標利潤的1/8，更新目標利潤: {target_profit:.2f} USDT")
    
    trade_count += 1


    if row is None:
        pass
    else:
        if not row.empty:
            duration = (row['timestamp'] - current_position['entry_time']).total_seconds() / 60  # 持仓时间（分钟
            if duration > max_time:
                max_time = duration

    # 写入CSV
    with open(CSV_FILE, 'a', newline='') as f:
        writer = csv.writer(f)
        entry_price_precision = len(str(current_position['entry_price']).split('.')[1]) if '.' in str(current_position['entry_price']) else 0 # 获取 entry_price 的小数位数
        formatted_left_price = f"{left_price:.{entry_price_precision}f}"
        writer.writerow([
            trade_count,
            current_position['direction'],
            current_position['symbol'],
            reason,
            current_position['entry_time'],
            timesampe,
            current_position['entry_price'],
            formatted_left_price,
            f"{pnl:.2f}",
            change_percentage,
            capital,
            saving_capital,
            saving_round,
            reset_round,
            profit_status
        ])
    
    current_position = None

def print_statistics():
    global capital, saving_round, saving_capital, reset_round

    saving_capital += capital
    capital = 0

    growth_rate = (saving_capital / INITIAL_CAPITAL - 1) * 100
    print(f"\n=== 回測结果 ===")
    print(f"初始本金: {INITIAL_CAPITAL} USDT")
    print(f"最終本金: {saving_capital} USDT")
    print(f"儲蓄輪次: {saving_round}")
    print(f"重置輪次: {reset_round}")
    print(f"資金少於1/8目標利潤輪次: {decrease_round}")
    print(f"總交易次數: {trade_count}")
    print(f"盈利交易次數: {profitable_trades}")
    print(f"勝率: {profitable_trades/trade_count * 100:.2f}%" if trade_count > 0 else "無交易")
    print(f"本金增長率: {growth_rate:.2f}%")
    print(f"最長持倉時間: {max_time:.2f} 分鐘")
    if max_loss_amount > 0:  # 確保不為零以避免除以零的情況
        profit_factor = total_profit_amount / max_loss_amount
    else:
        profit_factor = float('inf')  # 若沒有虧損，Profit Factor 可視為無限大
    print(f"獲利因子: {profit_factor:.2f}")
    print(f"全部交易中的最大跌幅: {max_loss_percentage:.2%}")

    if max_loss_percentage_info:
        print("\n=== 最大跌幅虧損交易 ===")
        print(f"交易編號: {max_loss_percentage_info['trade_number']}")
        print(f"開倉時間: {max_loss_percentage_info['open_time']}")
        print(f"平倉時間: {max_loss_percentage_info['close_time']}")
        print(f"開倉價格: {max_loss_percentage_info['open_price']}")
        print(f"平倉價格: {max_loss_percentage_info['close_price']}")
        print(f"獲利/虧損: {max_loss_percentage_info['gain']}")
        print(f"交易前本金: {max_loss_percentage_info['capital']}")
        print(f"虧損百分比: {max_loss_percentage_info['loss_percentage']}")

    if max_loss_trade_info:
        print("\n=== 最大金額虧損交易 ===")
        print(f"交易編號: {max_loss_trade_info['trade_number']}")
        print(f"開倉時間: {max_loss_trade_info['open_time']}")
        print(f"平倉時間: {max_loss_trade_info['close_time']}")
        print(f"開倉價格: {max_loss_trade_info['open_price']}")
        print(f"平倉價格: {max_loss_trade_info['close_price']}")
        print(f"獲利/虧損: {max_loss_trade_info['gain']}")
        print(f"交易前本金: {max_loss_trade_info['capital']}")
        print(f"虧損百分比: {max_loss_trade_info['loss_percentage']}")
    
    if min_profit_trade_info:
        print("\n=== 最小獲利交易 ===")
        print(f"交易編號: {min_profit_trade_info['trade_number']}")
        print(f"開倉時間: {min_profit_trade_info['open_time']}")
        print(f"平倉時間: {min_profit_trade_info['close_time']}")
        print(f"開倉價格: {min_profit_trade_info['open_price']}")
        print(f"平倉價格: {min_profit_trade_info['close_price']}")
        print(f"獲利/虧損: {min_profit_trade_info['gain']}")
        print(f"交易前本金: {min_profit_trade_info['capital']}")
        print(f"獲利百分比: {min_profit_trade_info['profit_percentage']}")

    fail_symbols = []
    for symbol, stats in trade_statistics.items():
        profit_trades = stats['profit_trades']
        loss_trades = stats['loss_trades']
        if loss_trades > 0 and profit_trades > 0 and loss_trades > profit_trades:  # 确保有盈亏记录
            fail_symbols.append(symbol)
    print(f"\nFail Symbols: {fail_symbols}")

    with open(WIN_LOSS_NUMBER_FILE, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['Symbol', 'Profit Trades', 'Loss Trades', 'Total Trades', 'Win Rate'])  # 写入标题
        for symbol, stats in trade_statistics.items():
            win_rate = (stats['profit_trades'] / stats['total_trades'] * 100) if stats['total_trades'] > 0 else 0
            writer.writerow([symbol, stats['profit_trades'], stats['loss_trades'], stats['total_trades'], f"{win_rate:.2f}%"])

def fetch_all_data(symbols):
    global dfs_by_symbol, dfs_by_timesamps
    all_data = []  
    count = 0
    print("正在獲取歷史數據...")
    for symbol in symbols:
        count += 1
        print(f"獲取第（{count}/{len(symbols)}）個數據：{symbol}")
        df = get_historical_data(symbol, TIMEFRAME_1H, START_DATE_1H)
        print(f"計算第（{count}/{len(symbols)}）個指標：{symbol}")
        df = calculate_indicators(df)
        df['symbol'] = symbol
        all_data.append(df)
    
    # 合併所有數據到一個 DataFrame
    print("合併數據...")
    dfs_by_timesamps = pd.concat(all_data, ignore_index=True)
    # 按時間戳排序
    dfs_by_timesamps = dfs_by_timesamps.sort_values('timestamp').reset_index(drop=True)
    print(f"合併數據框包含 {len(dfs_by_timesamps)} 行")

    #dfs_by_symbol = {symbol: dfs_by_timesamps[dfs_by_timesamps['symbol'] == symbol] for symbol in symbols}

def remove_symbols(symbols):
    new_symbols = []
    for symbol in symbols:
        if not re.search(r"(UP|DOWN|BULL|BEAR)/USDT$", symbol):  # 注意這裡的 not
            new_symbols.append(symbol)
    return new_symbols

if __name__ == "__main__":
    #symbols = get_all_symbols()  # 获取所有交易对
    #symbols = [symbol for symbol in symbols if is_large_cap(symbol)]
    #print("=== 只選擇市值超過 1 億美元的幣種 ===")
    #symbols = [symbol for symbol in symbols if symbol not in Fail_Symbols]
    #print("只保留不在Fail Symbols list內的symbol")
    #pattern = r'(\w*USD\w*/USDT|\w*/USD/USDT)'
    #symbols = [symbol for symbol in symbols if not re.search(pattern, symbol)]
    #symbols = filter_symbols(symbols)
    #symbols = filter_10_symbols(symbols)
    #symbols = ['BTC/USDT', 'ETH/USDT']
    #symbols = remove_symbols(symbols)
    #symbols = [symbol for symbol in symbols if symbol not in stable_coin]
    print(f"交易對數量為{len(success_symbols)}：{success_symbols}")
    fetch_all_data(success_symbols)
    #for index, symbol in enumerate(symbols, start=1):  # 从1开始计数
        #print(f"正在處理第 {index}/{total_symbols} 個交易對: {symbol}")
        #run_backtest(symbol)
    run_backtest_by_timsamps()
    print_statistics()
