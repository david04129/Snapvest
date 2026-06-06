# Phase A：Supabase Anonymous Auth 驗證指南

> 對應程式：iOS `SupabaseAuthService`、migration `022_authenticated_rls_read_policies.sql`  
> Phase A **不強制** JWT；未登入時仍 fallback legacy anon。  
> **部署前必做：** Supabase Dashboard 啟用 Anonymous Sign-In + 執行 migration 022。

---

## 部署前準備（Supabase Dashboard）

### 1. 啟用 Anonymous Sign-In

1. 開啟 [Supabase Dashboard](https://supabase.com/dashboard) → 你的專案  
2. **Authentication** → **Providers**  
3. 找到 **Anonymous Sign-Ins** → **Enable** → Save  

### 2. 執行 RLS migration

在 **SQL Editor** 貼上並執行：

`backend/supabase/migrations/022_authenticated_rls_read_policies.sql`

或本機：

```bash
cd backend && supabase db push
```

### 3. （可選）重新部署 fetch-prices-batch

若已改 `_shared/authContext.ts`：

```bash
cd backend && supabase functions deploy fetch-prices-batch
```

---

## 驗證一：Anonymous Sign-In API（curl）

在終端機設定：

```bash
export SUPABASE_URL="https://你的專案.supabase.co"
export SUPABASE_ANON_KEY="你的 publishable 或 anon key"
```

### 步驟 1 — 匿名註冊

```bash
curl -s -X POST "$SUPABASE_URL/auth/v1/signup" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"data":{}}' | jq .
```

**預期：**

- HTTP 200  
- JSON 含 `access_token`、`refresh_token`  
- `user.is_anonymous` 為 `true`  
- `user.id` 為 UUID  

**若失敗：** 回 `"Anonymous sign-ins are disabled"` → 回 Dashboard 啟用 Provider。

### 步驟 2 — 用 JWT 讀股價 REST

從上一步複製 `access_token`：

```bash
export ACCESS_TOKEN="貼上 access_token"

curl -s "$SUPABASE_URL/rest/v1/asset_price_snapshots?select=asset_type,symbol,current_price&limit=1" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq .
```

**預期：** 回傳陣列（可能 0 或 1 筆），**不是** `permission denied` 或 401。

**若 401 / 空且錯誤：** migration 022 未執行或未 GRANT `authenticated`。

### 步驟 3 — Token 刷新

```bash
export REFRESH_TOKEN="貼上 refresh_token"

curl -s -X POST "$SUPABASE_URL/auth/v1/token?grant_type=refresh_token" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"refresh_token\":\"$REFRESH_TOKEN\"}" | jq .
```

**預期：** 新的 `access_token` 與相同 `user.id`。

---

## 驗證二：iOS App（Debug）

### 步驟 1 — 乾淨首次登入

1. Xcode **Debug** scheme  
2. **刪除 Simulator 上的 Snapvest**（長按刪 App，清 Keychain session）  
3. Run App，等 Splash 完成進首頁  
4. 開 **Xcode Console**，搜尋 `SupabaseAuthService`  

**預期 log：**

```text
[SupabaseAuthService] anonymous sign-in userId=xxxxxxxx…
```

### 步驟 2 — 確認股價仍正常

1. 進 **投資** Tab，確認持股有價格  
2. **下拉刷新**（距上次 ≥60 秒）  
3. Console 應有 `fetchPrices chunk batch` 成功，**無**大量 REST fallback  

### 步驟 3 — 第二次冷啟動（session 持久化）

1. 完全關閉 App（Swipe up）  
2. 再開 App  
3. Console **不應**再出現新的 `anonymous sign-in`（應走 Keychain refresh 或沿用 token）  

### 步驟 4 — 抓包（可選，Charles / Proxyman）

過濾 `supabase.co`：

| 請求 | 預期 Header |
|------|-------------|
| 首次 `/auth/v1/signup` | 1 次 |
| `/functions/v1/fetch-prices-batch` | `apikey` + `Authorization: Bearer eyJ…`（使用者 JWT，非 publishable 本體） |
| `/rest/v1/asset_price_snapshots` | 同上 |

### 步驟 5 — 示範模式

1. 設定 → 進入 **示範模式**  
2. Console **不應**在示範期間再 signup  
3. 退出示範 → 回到真實資料 → 雲端請求恢復帶 JWT  

---

## 驗證三：Regression（確保沒弄壞）

| 項目 | 操作 | 預期 |
|------|------|------|
| 匯入 CSV | 匯入含 buy 的 CSV | 預覽驗價通過、可匯入 |
| 買進表單 | 新增一筆 buy | 參考價正常 |
| 首頁刷新 | 下拉 | 總資產更新 |
| 無網路 | 飛航模式開 App | 若有本機快照 → 降級提示，不 crash |
| Anonymous 關閉 | Dashboard 關閉 Anonymous 後刪 App 重裝 | App 仍可 fallback anon 讀價（Phase A）；Console 有 ensureSession failed |

---

## 驗證四：Supabase Dashboard 後台

1. **Authentication** → **Users**  
2. 跑過 App 後應看到 **Anonymous** 使用者（數量 ≈ 測試裝置數）  
3. 每個 user 有唯一 UUID  

---

## 常見問題

| 現象 | 原因 | 處理 |
|------|------|------|
| signup 422 / anonymous disabled | Provider 未開 | Dashboard 啟用 |
| REST 401 with JWT | migration 022 未跑 | 執行 SQL |
| 每次冷啟都 signup | Keychain 未寫入或 refresh 失敗 | 查 Console 錯誤；Simulator 刪 App 重試 |
| batch 仍 200 但 App 無價 | 與 Auth 無關 | 查 Cloud Run / snapshot 資料 |

---

## Phase B 預告（尚未實作）

- Edge 強制或優先 JWT 限流（`sub`）  
- fetch-or-create 短快取 + rate limit  
- track-symbols-batch  
