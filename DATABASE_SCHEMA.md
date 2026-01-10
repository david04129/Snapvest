# 資料庫 Schema 設計

## Supabase / PostgreSQL Schema

### 1. users (使用者)
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  display_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 2. accounts (帳戶)
```sql
CREATE TABLE accounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL, -- 'stock_tw', 'stock_us', 'crypto', 'cash'
  currency TEXT NOT NULL DEFAULT 'TWD', -- 'TWD', 'USD', etc.
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 3. transactions (交易流水帳)
```sql
CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id UUID REFERENCES accounts(id) ON DELETE CASCADE,
  type TEXT NOT NULL, -- 'buy', 'sell', 'deposit', 'withdraw', 'dividend', 'fee'
  asset_type TEXT NOT NULL, -- 'stock_tw', 'stock_us', 'crypto', 'cash'
  symbol TEXT NOT NULL, -- '2330', 'AAPL', 'BTC'
  quantity DECIMAL(18, 8) NOT NULL,
  price DECIMAL(18, 8) NOT NULL,
  currency TEXT NOT NULL,
  fee DECIMAL(18, 8) DEFAULT 0,
  notes TEXT,
  transaction_date TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_transactions_account_date ON transactions(account_id, transaction_date DESC);
```

### 4. holdings (當前持股)
```sql
CREATE TABLE holdings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id UUID REFERENCES accounts(id) ON DELETE CASCADE,
  asset_type TEXT NOT NULL,
  symbol TEXT NOT NULL,
  quantity DECIMAL(18, 8) NOT NULL,
  average_cost DECIMAL(18, 8) NOT NULL,
  currency TEXT NOT NULL,
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(account_id, asset_type, symbol)
);

CREATE INDEX idx_holdings_account ON holdings(account_id);
```

### 5. prices (股價快照)
```sql
CREATE TABLE prices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_type TEXT NOT NULL, -- 'stock_tw', 'stock_us', 'crypto'
  symbol TEXT NOT NULL,
  price DECIMAL(18, 8) NOT NULL,
  currency TEXT NOT NULL,
  price_date DATE NOT NULL,
  source TEXT, -- API 來源
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(asset_type, symbol, price_date)
);

CREATE INDEX idx_prices_symbol_date ON prices(asset_type, symbol, price_date DESC);
```

### 6. fx_rates (匯率)
```sql
CREATE TABLE fx_rates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  from_currency TEXT NOT NULL,
  to_currency TEXT NOT NULL,
  rate DECIMAL(18, 8) NOT NULL,
  rate_date DATE NOT NULL,
  source TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(from_currency, to_currency, rate_date)
);

CREATE INDEX idx_fx_rates_date ON fx_rates(rate_date DESC);
```

### 7. liabilities (負債)
```sql
CREATE TABLE liabilities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id UUID REFERENCES accounts(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  principal DECIMAL(18, 2) NOT NULL,
  interest_rate DECIMAL(5, 2) NOT NULL,
  monthly_payment DECIMAL(18, 2) NOT NULL,
  remaining_balance DECIMAL(18, 2) NOT NULL,
  currency TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 8. snapshots (資產快照)
```sql
CREATE TABLE snapshots (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  snapshot_date DATE NOT NULL,
  total_assets DECIMAL(18, 2) NOT NULL,
  total_liabilities DECIMAL(18, 2) NOT NULL,
  total_cash DECIMAL(18, 2) NOT NULL,
  total_investments DECIMAL(18, 2) NOT NULL,
  unrealized_gain_loss DECIMAL(18, 2) NOT NULL,
  realized_gain_loss DECIMAL(18, 2) NOT NULL,
  base_currency TEXT NOT NULL DEFAULT 'TWD',
  snapshot_data JSONB, -- 詳細快照資料
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, snapshot_date)
);

CREATE INDEX idx_snapshots_user_date ON snapshots(user_id, snapshot_date DESC);
```

## 建議

1. **使用 Supabase**：因為需要複雜的查詢和關聯，PostgreSQL 比 Firestore 更適合
2. **索引優化**：為常用查詢欄位建立索引
3. **資料分區**：prices 和 snapshots 表可考慮按日期分區
4. **即時訂閱**：使用 Supabase Realtime 訂閱價格更新

