# Walleaf Website

這個資料夾是 `walleafapp.com` 的靜態官網，可直接部署到 Cloudflare Pages。

## 頁面

- `/`：首頁
- `/privacy/`：隱私權政策
- `/terms/`：服務條款
- `/disclaimer/`：免責聲明

## Cloudflare Pages 設定

1. Cloudflare Dashboard → Workers & Pages
2. Create application → Pages
3. Connect to Git
4. 選擇這個 repo
5. Build settings：
   - Framework preset: `None`
   - Build command: 留空
   - Build output directory: `website`
6. Deploy
7. 部署成功後，到 Custom domains 綁定 `walleafapp.com`

## 上架前請確認

- `https://walleafapp.com/` 可開啟
- `https://walleafapp.com/privacy/` 可開啟
- `https://walleafapp.com/terms/` 可開啟
- `https://walleafapp.com/disclaimer/` 可開啟
- `support@walleafapp.com` 可收到信

## 待正式確認

目前法律文件使用：

- 營運者：`Walleaf 團隊`
- 聯絡信箱：`support@walleafapp.com`
- 生效日期：`2026 年 6 月 7 日`

正式送審前，建議再確認營運者名稱是否要改成個人姓名或公司名稱。
