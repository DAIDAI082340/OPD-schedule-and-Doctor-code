# 門診時段交叉查詢與醫師代碼查詢系統 - 視覺設計與字體色彩規格存檔書
# (Design Tokens & Color Palette Specification Archive)

> **存檔日期**：2026-09-22  
> **適用版本**：v0.9.6 及後續版本  
> **系統狀態**：正式定案標準規範（已通過臨床易讀性與視覺對比驗證）

---

## 1. 全域字體與排版規範 (Typography System)

| 屬性 | 規格設定 | 說明與設計意圖 |
| :--- | :--- | :--- |
| **字體家族 (font-family)** | `"Microsoft JhengHei", "微軟正黑體", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "PingFang TC", sans-serif` | Windows 原生 ClearType 點陣微調最佳化，徹底杜絕 WebFont 在不同縮放下邊緣發散或發虛模糊問題。 |
| **平滑化渲染** | `-webkit-font-smoothing: antialiased; text-rendering: optimizeLegibility;` | 強化邊緣對比度與筆畫扎實感。 |
| **全域基礎字級** | `17.5px` (body) | 臨床護理站與醫師看診螢幕高易讀性標準。 |
| **大課表醫師姓名** | `1.08rem`（約 18.9px）｜ **`font-weight: 900`（特粗 / Black）** | 如鋼印般清晰扎實，首要辨識焦點。 |
| **大課表診間號碼** | `0.96em` ｜ **`font-weight: 800`（極粗 / Extra Bold）** | 診間括號緊隨姓名同行，水平對齊。 |
| **標籤與按鈕文字** | `1.02rem` ｜ **`font-weight: 800`** | 浮凸膠囊立體感。 |
| **彈窗時段標題** | `0.96rem` ｜ **`font-weight: 800`** ｜ 字母間距 `0.04em` | 清晰標明「上午診 / 下午診 / 夜診」。 |
| **彈窗診間號碼** | `1.16rem` ｜ **`font-weight: 800`** | 數字放大醒目。 |

---

## 2. 基準醫師色系 (Base Doctor Palette)

作為比對矩陣之「定錨基準」，底色沉穩、大氣不死黑，與淡彩比對名單形成明確階層。

| 項目 | 規格代碼 / CSS 數值 | 預覽與用途 |
| :--- | :--- | :--- |
| **色系名稱** | **深墨青海藍 (Pine Slate Navy)**（推薦方案 A） | 基準醫師專屬代表色 |
| **底色 (Background)** | **`#284E59`** | `.base-doc-pill`, `.selected-tag.base-tag` |
| **文字顏色 (Text)** | **`#FFFFFF`**（純白） | 高反差純白字 |
| **文字字重 (Weight)** | **`font-weight: 900`** | 微軟正黑體特粗 |
| **邊框 (Border)** | `none` | 無邊框設計 |
| **立體陰影 (Shadow)** | `box-shadow: 0 3px 8px rgba(25, 50, 58, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.4), inset 0 -1px 2px rgba(0, 0, 0, 0.2);` | 雙層微浮凸光影 |
| **Hover 浮雕陰影** | `box-shadow: 0 6px 14px rgba(25, 50, 58, 0.42), inset 0 1px 1.5px rgba(255, 255, 255, 0.5);` | 滑鼠懸停立體反饋 |
| **對比度** | **8.2 : 1**（純白文字 vs #284E59 底色） | 大幅超越 WCAG AAA 標準 (7:1) |

---

## 3. 比對科別：彩虹馬卡龍 6 色【再刷淡版】(Rainbow Pastel Macaron Palette)

依照加入比對順序，以「科別」為單位輪流依序分配。同科底下的所有醫師統一共用該科代表色。  
**文字深度統一採用深墨海藍 `#1E3545` 粗體字**，在 92%~96% 超淡柔光底色上對比度高達 **12:1 以上**！

### 🎨 輪流分配順序：1粉 ➔ 4綠 ➔ 3黃 ➔ 5藍 ➔ 2橘 ➔ 6紫

```
[加入順序 1] 🌸 淡淡櫻花粉 #FFEBF0  (字體 #1E3545 粗體)
[加入順序 2] 🍵 淡淡薄荷綠 #E2F8EB  (字體 #1E3545 粗體)
[加入順序 3] 🍋 淡淡香草黃 #FFF9D2  (字體 #1E3545 粗體)
[加入順序 4] 🩵 淡淡晴空藍 #E0F4FE  (字體 #1E3545 粗體)
[加入順序 5] 🍑 淡淡蜜桃杏 #FFF0E2  (字體 #1E3545 粗體)
[加入順序 6] 🪻 淡淡薰衣紫 #F1E9FA  (字體 #1E3545 粗體)
```

### 📋 詳細色碼規格表

| 順序編號 | 色系名稱 | 底色色碼 (HEX) | 邊框色彩 (Border) | 文字色彩 (Text) | 文字字重 | 陰影規格 (Box Shadow) | 視覺特色說明 |
| :---: | :--- | :---: | :---: | :---: | :---: | :--- | :--- |
| **1** | 🌸 **淡淡櫻花粉**<br>(Sakura Pink) | **`#FFEBF0`** | `1px solid rgba(244, 114, 182, 0.35)` | **`#1E3545`** | 800 | `0 2px 6px rgba(30, 53, 69, 0.06), inset 0 1px 2px rgba(255, 255, 255, 0.95)` | 極淡櫻花柔暈，清透明亮（明度 96%） |
| **4** | 🍵 **淡淡薄荷綠**<br>(Mint Green) | **`#E2F8EB`** | `1px solid rgba(52, 211, 153, 0.35)` | **`#1E3545`** | 800 | `0 2px 6px rgba(30, 53, 69, 0.06), inset 0 1px 2px rgba(255, 255, 255, 0.95)` | 舒緩嫩芽薄荷，清新自然（明度 94%） |
| **3** | 🍋 **淡淡香草黃**<br>(Vanilla Yellow) | **`#FFF9D2`** | `1px solid rgba(251, 191, 36, 0.35)` | **`#1E3545`** | 800 | `0 2px 6px rgba(30, 53, 69, 0.06), inset 0 1px 2px rgba(255, 255, 255, 0.95)` | 柔和香草奶油鵝黃，輕盈乾淨（明度 92%） |
| **5** | 🩵 **淡淡晴空藍**<br>(Glacier Blue) | **`#E0F4FE`** | `1px solid rgba(56, 189, 248, 0.35)` | **`#1E3545`** | 800 | `0 2px 6px rgba(30, 53, 69, 0.06), inset 0 1px 2px rgba(255, 255, 255, 0.95)` | 純淨透亮淡天藍，澄澈開闊（明度 94%） |
| **2** | 🍑 **淡淡蜜桃杏**<br>(Peach Apricot) | **`#FFF0E2`** | `1px solid rgba(251, 146, 60, 0.35)` | **`#1E3545`** | 800 | `0 2px 6px rgba(30, 53, 69, 0.06), inset 0 1px 2px rgba(255, 255, 255, 0.95)` | 淡淡甜杏乳霜橘，溫潤不刺眼（明度 95%） |
| **6** | 🪻 **淡淡薰衣紫**<br>(Lavender Purple) | **`#F1E9FA`** | `1px solid rgba(192, 132, 252, 0.35)` | **`#1E3545`** | 800 | `0 2px 6px rgba(30, 53, 69, 0.06), inset 0 1px 2px rgba(255, 255, 255, 0.95)` | 淡雅粉紫丁香，柔美沉靜（明度 95%） |

---

## 4. 醫師個人門診時刻表彈窗卡片色系 (Modal Slot Cards)

點選任何醫師膠囊後彈出的「每週門診時刻表彈窗」時段卡片規格：

| 時段卡片 | 底色 (Background) | 邊框 (Border) | 文字與診間 (Text) | 陰影 (Box Shadow) |
| :--- | :---: | :---: | :---: | :--- |
| **上午診 (`.slot-morning`)** | **`#FFF9D2`**（香草黃） | `1px solid rgba(251, 191, 36, 0.4)` | **`#1E3545`**（字重 800） | `0 2px 6px rgba(30, 53, 69, 0.06), inset 0 1px 2px rgba(255, 255, 255, 0.95)` |
| **下午診 (`.slot-afternoon`)** | **`#FFF0E2`**（蜜桃杏） | `1px solid rgba(251, 146, 60, 0.4)` | **`#1E3545`**（字重 800） | `0 2px 6px rgba(30, 53, 69, 0.06), inset 0 1px 2px rgba(255, 255, 255, 0.95)` |
| **夜診 (`.slot-night`)** | **`#E0F4FE`**（晴空藍） | `1px solid rgba(56, 189, 248, 0.4)` | **`#1E3545`**（字重 800） | `0 2px 6px rgba(30, 53, 69, 0.06), inset 0 1px 2px rgba(255, 255, 255, 0.95)` |

---

## 5. 警示與特殊標籤色系 (Badges & Alerts)

| 標籤項目 | 底色 (Background) | 文字色彩 (Text) | 字重 | 陰影 / 樣式 |
| :--- | :---: | :---: | :---: | :--- |
| **📅 特定看診日標籤 (`.pill-specific-date-badge`)** | **`#B76E79`**（經典珠寶玫瑰金） | `#FFFFFF`（純白） | 800 | `box-shadow: 0 1.5px 3px rgba(0,0,0,0.25); border-radius: 6px;` |
| **⚠️ 停診標籤 (`.pill-suspension-badge`)** | **`#b91c1c`**（深紅） | `#FFFFFF`（純白） | 800 | `box-shadow: 0 1.5px 3px rgba(0, 0, 0, 0.28); border-radius: 4px;` |
| **⚠️ 網掛不開放 (`.badge-web-closed`)** | **`#c2410c`**（橙紅） | `#FFFFFF`（純白） | 800 | `box-shadow: 0 1.5px 3px rgba(0, 0, 0, 0.25); border-radius: 4px;` |
| **醫師代碼標籤 (`.doc-code-tag`)** | `#e2edf1` | `#203e45` | 800 | 等寬字體 (`ui-monospace, SFMono-Regular, monospace`) |

---

## 6. JavaScript 程式碼直接複製常數 (JavaScript Constants Snippet)

若日後需要整包程式碼還原或在其他模組中調用，可直接使用以下物件定義：

```javascript
// 基準醫師代表色（深墨青海藍 #284E59，純白微軟正黑體粗字）
const baseDoctorColor = {
  id: "baseDeepOcean",
  bg: "#284E59",
  border: "none",
  text: "#ffffff",
  shadow: "0 3px 8px rgba(25, 50, 58, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.4), inset 0 -1px 2px rgba(0, 0, 0, 0.2)"
};

// 比對科別專屬色彩池：彩虹馬卡龍 6 色再刷淡版（1粉, 4綠, 3黃, 5藍, 2橘, 6紫）
// 文字深度統一採用基準底色 #1E3545 深墨海藍微軟正黑體粗字
const departmentPalette = [
  { id: "sakurapink",     name: "淡淡櫻花粉 (Sakura Pink)",     bg: "#FFEBF0", border: "1px solid rgba(244, 114, 182, 0.35)", text: "#1E3545", shadow: "0 2px 6px rgba(30, 53, 69, 0.06), inset 0 1px 2px rgba(255, 255, 255, 0.95)" }, // 1
  { id: "mintgreen",      name: "淡淡薄荷綠 (Mint Green)",      bg: "#E2F8EB", border: "1px solid rgba(52, 211, 153, 0.35)",  text: "#1E3545", shadow: "0 2px 6px rgba(30, 53, 69, 0.06), inset 0 1px 2px rgba(255, 255, 255, 0.95)" }, // 4
  { id: "vanillayellow",  name: "淡淡香草黃 (Vanilla Yellow)",  bg: "#FFF9D2", border: "1px solid rgba(251, 191, 36, 0.35)",  text: "#1E3545", shadow: "0 2px 6px rgba(30, 53, 69, 0.06), inset 0 1px 2px rgba(255, 255, 255, 0.95)" }, // 3
  { id: "glacierblue",    name: "淡淡晴空藍 (Glacier Blue)",    bg: "#E0F4FE", border: "1px solid rgba(56, 189, 248, 0.35)",  text: "#1E3545", shadow: "0 2px 6px rgba(30, 53, 69, 0.06), inset 0 1px 2px rgba(255, 255, 255, 0.95)" }, // 5
  { id: "peachapricot",   name: "淡淡蜜桃杏 (Peach Apricot)",   bg: "#FFF0E2", border: "1px solid rgba(251, 146, 60, 0.35)",  text: "#1E3545", shadow: "0 2px 6px rgba(30, 53, 69, 0.06), inset 0 1px 2px rgba(255, 255, 255, 0.95)" }, // 2
  { id: "lavenderpurple", name: "淡淡薰衣紫 (Lavender Purple)", bg: "#F1E9FA", border: "1px solid rgba(192, 132, 252, 0.35)", text: "#1E3545", shadow: "0 2px 6px rgba(30, 53, 69, 0.06), inset 0 1px 2px rgba(255, 255, 255, 0.95)" }  // 6
];
```

---

## 7. 歷代備用色彩方案庫 (Alternative / Backup Palette Archives)

本章節完整封存歷次改版驗證過的優質色彩方案。若未來因特殊看診環境（如高對比螢幕、戶外巡迴醫療、投影簡報）、節慶視覺更替或個人偏好需要切換，可直接從此處**一鍵複製套用**！

---

### 🗄️ 備用方案 1：加深 60% 極深墨海藍方案 (v0.9.5 規格)
- **視覺特色**：基準醫師厚重沉邃、份量感極強，純白字如黑夜星光般醒目。
- **適用情境**：需要最高度視覺權威感、強烈黑白階層區隔時。

```javascript
// 備用方案 1 - 基準醫師：加深 60% 極深墨海藍
const backupBaseDoctor_v095 = {
  id: "baseDeepOcean60",
  bg: "#1E3545",
  border: "none",
  text: "#ffffff",
  shadow: "0 4px 10px rgba(18, 32, 43, 0.38), inset 0 1px 1.5px rgba(255, 255, 255, 0.35), inset 0 -1px 2px rgba(0, 0, 0, 0.3)"
};
// 比對科別：同主要方案（彩虹馬卡龍 6 色再刷淡版）
```

---

### 🗄️ 備用方案 2：Horizon 湖水天青 ＆ 手繪色卡 1~5 號方案 (v0.9.2 ~ v0.9.4 規格)
- **視覺特色**：優雅莫蘭迪秋麥金黃、紫藤柔灰紫、珊瑚粉與暖沙褐，具備如文藝畫作般典雅柔和的大地質感。
- **適用情境**：秋冬季風格、溫馨舒緩門診情境。

```javascript
// 備用方案 2 - 基準醫師：Horizon 湖水天青 #558E9B
const backupBaseDoctor_Horizon = {
  id: "baseHorizon",
  bg: "#558E9B",
  border: "none",
  text: "#ffffff",
  shadow: "0 3px 8px rgba(85, 142, 155, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.7), inset 0 -1px 2px rgba(0, 0, 0, 0.06)"
};

// 備用方案 2 - 比對科別（手繪色卡 1~5 號）：
const backupDepartmentPalette_Card1to5 = [
  { id: "buttercup",       name: "Buttercup (秋麥金黃)",       bg: "#E7C676", border: "none", text: "#0E4369", shadow: "0 3px 8px rgba(231, 198, 118, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.7)" }, // 1
  { id: "wisteriapurple",  name: "Wisteria Purple (紫藤柔灰紫)", bg: "#C6B3CA", border: "none", text: "#0E4369", shadow: "0 3px 8px rgba(198, 179, 202, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.7)" }, // 2
  { id: "rose",            name: "Rose (蜜桃珊瑚玫瑰粉)",      bg: "#E89B88", border: "none", text: "#0E4369", shadow: "0 3px 8px rgba(232, 155, 136, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.7)" }, // 3
  { id: "fairytaledream",  name: "Fairytale Dream (童話夢境)",  bg: "#F9D0CD", border: "none", text: "#0E4369", shadow: "0 3px 8px rgba(249, 208, 205, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.7)" }, // 4
  { id: "tumbleweed",      name: "Tumbleweed (風滾草暖沙褐)",   bg: "#D1A996", border: "none", text: "#0E4369", shadow: "0 3px 8px rgba(209, 169, 150, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.7)" }  // 5
];

// 門診時刻表彈窗：色卡-3 前 3 色
// 上午：Golden Dune #F4D9A6 ｜ 下午：Coral Reef #FFB5A7 ｜ 夜診：Ocean Mist #B7DCD6 (字體 #0E4369)
```

---

### 🗄️ 備用方案 3：自然草甸植物物語 (Botanical Stories) 高明度淡彩 10 色 (v0.9.0 ~ v0.9.1 規格)
- **視覺特色**：收錄 Morning Sky 澄空藍、Ocean Mist 湖水青、鼠尾草綠等 10 款清甜淡彩。
- **適用情境**：同時比對超過 6 個科別的大規模交叉查詢，需要高達 10 款互不重複的高明度淡彩。

```javascript
// 備用方案 3 - 比對科別：自然草甸植物物語 10 款淡彩
const backupDepartmentPalette_Botanical10 = [
  { id: "morningsky",    name: "Morning Sky (晨曦澄空藍)",   bg: "#D6E4FA", border: "none", text: "#0E4369", shadow: "0 3px 8px rgba(214, 228, 250, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.7)" },
  { id: "oceanmist",     name: "Ocean Mist (清透湖水青)",    bg: "#B7DCD6", border: "none", text: "#0E4369", shadow: "0 3px 8px rgba(183, 220, 214, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.7)" },
  { id: "sage",          name: "Sage Leaf (鼠尾草綠)",       bg: "#D6EAD4", border: "none", text: "#0E4369", shadow: "0 3px 8px rgba(214, 234, 212, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.7)" },
  { id: "sakura",        name: "Sakura Pink (櫻花淡粉)",     bg: "#F7E1E6", border: "none", text: "#0E4369", shadow: "0 3px 8px rgba(247, 225, 230, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.7)" },
  { id: "peach",         name: "Peach (蜜桃粉杏)",          bg: "#FFD6A5", border: "none", text: "#0E4369", shadow: "0 3px 8px rgba(255, 214, 165, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.7)" },
  { id: "lilac",         name: "Lilac (丁香淡紫)",          bg: "#E6D6F7", border: "none", text: "#0E4369", shadow: "0 3px 8px rgba(230, 214, 247, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.7)" },
  { id: "lemoncream",    name: "Lemon Cream (檸檬鵝黃)",     bg: "#FFF6D6", border: "none", text: "#0E4369", shadow: "0 3px 8px rgba(255, 246, 214, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.7)" },
  { id: "coralreef",     name: "Coral Reef (珊瑚橘粉)",      bg: "#FFB5A7", border: "none", text: "#0E4369", shadow: "0 3px 8px rgba(255, 181, 167, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.7)" },
  { id: "goldendune",    name: "Golden Dune (金沙暖黃)",     bg: "#F4D9A6", border: "none", text: "#0E4369", shadow: "0 3px 8px rgba(244, 217, 166, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.7)" },
  { id: "oatmilk",       name: "Oat Milk (燕麥奶褐)",        bg: "#EAD8B0", border: "none", text: "#0E4369", shadow: "0 3px 8px rgba(234, 216, 176, 0.35), inset 0 1px 1.5px rgba(255, 255, 255, 0.7)" }
];
```

---

### 🗄️ 備用方案 4：Spring Meadow 自然草甸 12 色經典原色方案 (v0.8.0 規格)
- **視覺特色**：經典自然草甸色系，包含磚紅珊瑚、橄欖苔綠、柔湖水藍、秋麥金黃等。
- **適用情境**：偏愛自然質樸原木感之臨床顯示風格。

```javascript
// 備用方案 4 - 比對科別：Spring Meadow 12 色原色
const backupDepartmentPalette_Meadow12 = [
  { id: "terracotta",    name: "磚紅珊瑚 (Coral Terracotta)", bg: "#C96349", border: "none", text: "#ffffff", shadow: "0 3px 8px rgba(201, 99, 73, 0.35)" },
  { id: "sageleaf",      name: "鼠尾草綠 (Sage Leaf)",        bg: "#84A48B", border: "none", text: "#ffffff", shadow: "0 3px 8px rgba(132, 164, 139, 0.35)" },
  { id: "lilacmist",     name: "紫丁香粉紫 (Lilac Mist)",     bg: "#A386A9", border: "none", text: "#ffffff", shadow: "0 3px 8px rgba(163, 134, 169, 0.35)" },
  { id: "olivemoss",     name: "橄欖苔綠 (Olive Moss)",      bg: "#88895B", border: "none", text: "#ffffff", shadow: "0 3px 8px rgba(136, 137, 91, 0.35)" },
  { id: "warmpeach",     name: "蜜桃珊瑚粉 (Warm Peach)",     bg: "#E89B88", border: "none", text: "#2c3e50", shadow: "0 3px 8px rgba(232, 155, 136, 0.35)" },
  { id: "springlake",    name: "柔湖水藍 (Spring Lake)",      bg: "#7BB2BA", border: "none", text: "#ffffff", shadow: "0 3px 8px rgba(123, 178, 186, 0.35)" },
  { id: "rosewood",      name: "暖赤褐 (Rosewood)",          bg: "#A36361", border: "none", text: "#ffffff", shadow: "0 3px 8px rgba(163, 99, 97, 0.35)" },
  { id: "duskyheather",  name: "粉紫灰 (Dusky Heather)",      bg: "#C6B3CA", border: "none", text: "#2c3e50", shadow: "0 3px 8px rgba(198, 179, 202, 0.35)" },
  { id: "softamber",     name: "秋麥金黃 (Soft Amber)",       bg: "#E7C676", border: "none", text: "#2c3e50", shadow: "0 3px 8px rgba(231, 198, 118, 0.35)" },
  { id: "celadonmint",   name: "薄荷清綠 (Celadon Mint)",     bg: "#AECBB8", border: "none", text: "#2c3e50", shadow: "0 3px 8px rgba(174, 203, 184, 0.35)" },
  { id: "oatmilkbrow",   name: "燕麥奶褐 (Oat Milk)",        bg: "#D1A996", border: "none", text: "#2c3e50", shadow: "0 3px 8px rgba(209, 169, 150, 0.35)" },
  { id: "softapricot",   name: "暖杏橙 (Soft Apricot)",       bg: "#F79E70", border: "none", text: "#2c3e50", shadow: "0 3px 8px rgba(247, 158, 112, 0.35)" }
];
```

---

### 🗄️ 備用方案 5：高飽和度強烈互斥色盤 (v0.4.0 ~ v0.7.0 規格)
- **視覺特色**：翡翠綠、活力橙、皇家紫、石榴紅等 8 款高飽和度互斥色。
- **適用情境**：極端老舊低對比度螢幕、遠距離投影、或需要一眼強烈區分各專科時。

```javascript
// 備用方案 5 - 比對科別：8 色高對比互斥色
const backupDepartmentPalette_HighContrast8 = [
  { id: "emerald",    name: "翡翠綠", bg: "#059669", border: "none", text: "#ffffff", shadow: "0 3px 8px rgba(5, 150, 105, 0.3)" },
  { id: "amber",      name: "活力橙", bg: "#d97706", border: "none", text: "#ffffff", shadow: "0 3px 8px rgba(217, 119, 6, 0.3)" },
  { id: "violet",     name: "皇家紫", bg: "#7c3aed", border: "none", text: "#ffffff", shadow: "0 3px 8px rgba(124, 58, 237, 0.3)" },
  { id: "crimson",    name: "石榴紅", bg: "#dc2626", border: "none", text: "#ffffff", shadow: "0 3px 8px rgba(220, 38, 38, 0.3)" },
  { id: "caramel",    name: "焦糖棕", bg: "#92400e", border: "none", text: "#ffffff", shadow: "0 3px 8px rgba(146, 64, 14, 0.3)" },
  { id: "slateblack", name: "沉穩黑", bg: "#1f2937", border: "none", text: "#ffffff", shadow: "0 3px 8px rgba(31, 41, 55, 0.3)" },
  { id: "cyan",       name: "電光青", bg: "#0891b2", border: "none", text: "#ffffff", shadow: "0 3px 8px rgba(8, 145, 178, 0.3)" },
  { id: "magenta",    name: "鮮洋紅", bg: "#db2777", border: "none", text: "#ffffff", shadow: "0 3px 8px rgba(219, 39, 119, 0.3)" }
];
```

---

## 8. 專屬品牌識別標誌規格 (Official App Logo & Brand DNA Specifications)

> **定案日期**：2026-09-23  
> **正式定案款式**：**3D 浮雕立體金框徽章 (款式 B 滿版金框版)**  
> **核心設計 DNA 承諾**：永久銘記並嚴格遵循「**黃金立體邊框**」、「**3D 浮雕微光風格**」與「**右下角『卉』字草木圖騰**」，作為本系統未來所有視覺衍生（App 圖示、Header 導覽列、名牌胸章、院內公文）之不可撼動基準。

### 8.1 三大核心視覺基因 (Brand Core DNA)

| 核心基因 | 視覺元素與規格 | 象徵意涵與設計規範 |
| :--- | :--- | :--- |
| **🥇 黃金立體邊框**<br>(3D Gold Squircle Frame) | • 3D 金屬立體拉絲黃金圓角框。<br>• 具備細緻的高光倒角、金屬微反光與環境立體陰影。<br>• **滿版金框貼齊 (款式 B)**：金框精準包覆整個 App 圓角邊界，整顆 App 猶如一枚沉甸甸的純金勳章。 | 象徵醫療臨床專業的**卓越品質、權威可信與尊榮感**。 |
| **🎨 3D 浮雕微光風格**<br>(Tactile 3D Emboss Style) | • **底座質感**：暖象牙亞麻紙紋／柔和皮革布紋肌理（`#FAF8F5`），徹底告別死白反光。<br>• **雕刻色彩**：湖水青瓷深綠（`#2D5A5B`）立體陰影，具備手感溫潤之陶石浮雕質感。<br>• **圖騰組合**：<br>  1. **立體放大鏡**（內嵌核對勾選與衝刺向上箭頭，象徵秒級速查與正確核對）。<br>  2. **時鐘排班矩陣**（時鐘指針與刻度，精確象徵門診時段與時間管理）。<br>  3. **環形網絡軌道節點**（弧形環帶與端點圓珠，象徵跨科聯通與交叉比對）。 | 兼具現代科技數位效率與自然手作溫度，**層次深邃、視覺厚實大氣**。 |
| **🌿 右下角「卉」字圖騰**<br>(The "卉" Botanical Emblem) | • 位於圖騰右下角，由草木葉脈與流暢線條交織勾勒而成的**「卉」**字草本紋章。<br>• 筆法圓融流暢，如初生嫩葉與中西醫療藥草之芽。 | **「卉」本義為百草之總稱**。象徵生機勃勃、仁心濟世、草木療癒與患者康復長青，為數位排班工具注入深厚的**醫療生命力與人文關懷**。 |

### 8.2 品牌色彩色票與代碼 (Logo Palette Tokens)

```json
{
  "logo_brand_dna": {
    "border_frame": {
      "type": "3D Brushed Metallic Gold Squircle",
      "primary_gold": "#D4AF37",
      "highlight_gold": "#F3E5AB",
      "shadow_bronze": "#8C6D23",
      "style": "Flush Edge (款式 B 滿版金框)"
    },
    "background_surface": {
      "name": "Warm Ivory Linen Texture (暖象牙亞麻紙紋)",
      "hex": "#FAF8F5",
      "finish": "Tactile Matte (溫潤不反光)"
    },
    "embossed_graphic": {
      "name": "Deep Lake Sage Green (湖水青瓷深綠)",
      "hex": "#2D5A5B",
      "accent_teal": "#3A6E70",
      "shadow_depth": "Soft 3D Deboss"
    },
    "botanical_emblem": {
      "character": "卉 (Hùi)",
      "symbolism": "草木百花、仁心濟世、生機盎然、健康長青",
      "position": "Bottom-Right Quadrant"
    }
  }
}
```


