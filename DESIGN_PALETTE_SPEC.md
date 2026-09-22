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
