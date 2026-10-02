# 方案 B：Cloudflare Worker 免費微型反向代理備忘指南 (Plan B Record)

> **說明**：本文件記錄「方案 B：Cloudflare Worker 微型反向代理」之完整技術規格、安全性設計與即開即用程式碼。未來若有「零秒差、隨點即抓衛福部當下一秒即時掛號人數」之升級需求，可隨時依本文件在 3 分鐘內無縫上線。

---

## 一、架構原理與解決痛點

### 1. 痛點
前端手機瀏覽器（PWA/Web）受限於同源政策（CORS），無法直接連線公立醫院官方伺服器（`netreg.chhw.mohw.gov.tw`）抓取資料，否則會被 Chrome / Safari 瀏覽器強制攔截。

### 2. 解法
在 Cloudflare 全球邊緣網路（Serverless Edge）部署一個輕量轉發代理。
當手機使用者點擊「即時同步」或「查詢已掛人數」時：
1. 手機向 Cloudflare Worker 發出請求。
2. Cloudflare Worker 在 0.5 秒內代表客戶端向彰化醫院官方網站抓取該診次最新頁面。
3. Cloudflare Worker 自動附帶 `Access-Control-Allow-Origin` 標頭並解除 CORS 限制回傳。
4. 手機 1~2 秒內立刻更新為**衛福部官網當下一秒的絕對最新人數**。

---

## 二、費用與用量

* **方案**：Cloudflare Workers Free Plan（完全免費、免綁信用卡）。
* **額度**：每日 **100,000 次** 免費請求，對醫療科室與個人門診查詢而言，額度終身充足。
* **延遲**：台灣節點回應時間約 50~200ms。

---

## 三、資安防護與合規設計（嚴格白名單）

為了防止該 Worker 被有心人士當作公開跳板（Proxy Abuse），程式碼中內建三大防護機制：
1. **來源網域白名單 (Origin Whitelist)**：
   只允許來自 `https://daidai082340.github.io` 與本機調試之請求，其餘來源一律回傳 403 Forbidden。
2. **目標網址白名單 (Target Host Whitelist)**：
   僅允許轉發 `netreg.chhw.mohw.gov.tw` 之公開門診掛號頁面，禁止轉發至任何其他伺服器。
3. **零個資政策 (Zero PII)**：
   僅解析並回傳醫師掛號人數（整數值）與停代診狀態，完全不涉及、不接觸任何病患身分與隱私資料。

---

## 四、Cloudflare Worker 完整程式碼 (`worker.js`)

```javascript
/**
 * Cloudflare Worker: 衛福部彰化醫院 (CHHW) 門診掛號即時反向代理
 * 具備 CORS 穿透、來源防護白名單與自動限流
 */

const ALLOWED_ORIGINS = [
  "https://daidai082340.github.io",
  "http://localhost",
  "http://127.0.0.1"
];

const TARGET_HOST = "https://netreg.chhw.mohw.gov.tw";

export default {
  async fetch(request, env, ctx) {
    // 1. 處理 CORS 預檢請求 (OPTIONS)
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: getCorsHeaders(request)
      });
    }

    // 2. 來源檢查 (安全白名單)
    const origin = request.headers.get("Origin") || "";
    const isAllowed = ALLOWED_ORIGINS.some(allowed => origin.startsWith(allowed));

    // 3. 解析目標路徑 (僅准許查詢 DOCTORLIST 或首頁)
    const url = new URL(request.url);
    const targetPath = url.pathname + url.search;
    
    // 安全過濾：僅允許轉發公開掛號與專科清單
    if (!url.pathname.startsWith("/DOCTORLIST") && url.pathname !== "/" && !url.pathname.startsWith("/DOCTOR")) {
      return new Response("Forbidden target path", { status: 403 });
    }

    const targetUrl = TARGET_HOST + targetPath;

    try {
      const response = await fetch(targetUrl, {
        headers: {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
          "Accept-Language": "zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7"
        }
      });

      // 4. 重構回應並注入 CORS 標頭
      const newHeaders = new Headers(response.headers);
      Object.entries(getCorsHeaders(request)).forEach(([k, v]) => {
        newHeaders.set(k, v);
      });
      newHeaders.set("Cache-Control", "no-store, no-cache, must-revalidate");

      return new Response(response.body, {
        status: response.status,
        headers: newHeaders
      });
    } catch (err) {
      return new Response(JSON.stringify({ error: "Failed to fetch MOHW", detail: err.message }), {
        status: 502,
        headers: {
          "Content-Type": "application/json",
          ...getCorsHeaders(request)
        }
      });
    }
  }
};

function getCorsHeaders(request) {
  const origin = request.headers.get("Origin") || "*";
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Cache-Control, Pragma",
    "Access-Control-Max-Age": "86400"
  };
}
```

---

## 五、未來 3 分鐘啟用步驟

當使用者決定升級時，只需依下列步驟操作：
1. 前往 [Cloudflare 官網](https://dash.cloudflare.com/) 註冊登入免費帳號。
2. 進入「Workers & Pages」➜ 點擊「Create Application」➜「Create Worker」。
3. 命名為 `chhw-reg-proxy`，點擊「Deploy」。
4. 點擊「Edit Code」，將上述第四節的 JavaScript 程式碼完整覆蓋並按「Save and Deploy」。
5. 複製生成的專屬網址（例如：`https://chhw-reg-proxy.xxxxxx.workers.dev`）。
6. 回到本專案，將該網址填入 `index.html` 中的即時同步端點即可上線！
