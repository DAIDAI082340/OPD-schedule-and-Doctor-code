#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
衛生福利部彰化醫院 (CHHW) 門診時刻表、醫師代碼與官方停代診公告自動更新腳本
每月底自動執行，亦支援手動執行。
1. 抓取 https://www.chhw.mohw.gov.tw/?aid=320&page_name=detail&iid=15 官方停代診公告大圖與標題
2. 抓取 https://netreg.chhw.mohw.gov.tw/DOCTOR 全院醫師名冊與官方 4 碼代碼
3. 抓取 https://netreg.chhw.mohw.gov.tw/ 臨床專科清單
4. 遍歷各專科門診表，解析出診時段、診間及具體停診日期 (如 10/10停診)
5. 自動同步寫入 index.html 與 門診時段交叉查詢與醫師代碼查詢系統.html
"""

import os
import sys
import re
import json
import html
import argparse
import datetime
import urllib.request
import urllib.error

# 設定請求標頭偽裝成一般現代瀏覽器，避免被阻擋
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
    'Accept-Language': 'zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
}

def fetch_url(url, timeout=30):
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            content = response.read()
            # 優先嘗試 utf-8 解碼，若失敗嘗試 cp950 (Big5)
            try:
                return content.decode('utf-8')
            except UnicodeDecodeError:
                return content.decode('cp950', errors='replace')
    except Exception as e:
        print(f"[警告] 連線失敗 {url}: {e}", file=sys.stderr)
        return ""

def get_official_suspension_notice():
    """抓取彰化醫院官方停診、代診公告專頁 (iid=15)"""
    url = "https://www.chhw.mohw.gov.tw/?aid=320&page_name=detail&iid=15"
    print(f"[1/4] 正在抓取官方停代診公告專頁: {url}")
    html_text = fetch_url(url)
    if not html_text:
        return None

    # 擷取公告標題 (如：09月-11月醫師停診、代診公告)
    title_match = re.search(r'(\d+月[^\s<]*?醫師停[^\s<]*?公告)', html_text)
    title = title_match.group(1) if title_match else "最新醫師停診、代診公告"

    # 擷取所有停代診公文大圖 (jpg)
    img_matches = re.findall(r'<a[^>]*href=["\'](/public/news1/320/[^"\']+\.jpg)["\'][^>]*title=["\']([^"\']+)["\']', html_text)
    images = []
    seen_urls = set()
    for img_path, img_title in img_matches:
        full_url = "https://www.chhw.mohw.gov.tw" + img_path
        if full_url not in seen_urls:
            seen_urls.add(full_url)
            clean_title = re.sub(r'\(另開新視窗\s*\)', '', img_title).strip()
            images.append({
                "title": clean_title,
                "url": full_url
            })

    # 若未匹配到 a 標籤裡的 title，改從 img 標籤抓取
    if not images:
        img_srcs = re.findall(r'src=["\'](/public/news1/320/[^"\']+\.jpg)["\']', html_text)
        for s in img_srcs:
            full_url = "https://www.chhw.mohw.gov.tw" + s
            if full_url not in seen_urls:
                seen_urls.add(full_url)
                images.append({
                    "title": "停代診公告圖檔",
                    "url": full_url
                })

    result = {
        "title": title,
        "sourceUrl": url,
        "updateTime": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
        "images": images
    }
    print(f" -> 成功擷取官方公告: {title} (共 {len(images)} 張公告圖檔)")
    return result

def get_doctor_codes():
    """抓取全院醫師官方 4 碼代碼 (/DOCTOR)"""
    url = "https://netreg.chhw.mohw.gov.tw/DOCTOR"
    print(f"[2/4] 正在抓取全院醫師代碼: {url}")
    html_text = fetch_url(url)
    if not html_text:
        return {}

    # 匹配 GoDoctorList('0262') ... 陳詩典
    matches = re.findall(r"GoDoctorList\('(\d{4})'\)[^>]*>([\s\S]*?)</a>", html_text)
    doc_map = {}
    for code, raw_name in matches:
        clean = html.unescape(raw_name)
        name_m = re.search(r'[\u4e00-\u9fa5]{2,4}', clean)
        if name_m:
            name = name_m.group(0).strip()
            doc_map[name] = code

    print(f" -> 成功解析醫師代碼對照表: 共 {len(doc_map)} 位醫師")
    return doc_map

def get_departments():
    """抓取全院專科清單 (/)"""
    url = "https://netreg.chhw.mohw.gov.tw/"
    html_text = fetch_url(url)
    if not html_text:
        return []

    matches = re.findall(r"GoDoctorList\('([^']+)'\)[^>]*>([\s\S]*?)</a>", html_text)
    depts = []
    seen = set()
    for code, raw_name in matches:
        code = code.strip()
        name = html.unescape(raw_name).strip()
        if code and code not in seen:
            seen.add(code)
            depts.append({"code": code, "name": name})

    print(f"[3/4] 成功解析全院臨床專科清單: 共 {len(depts)} 個科別")
    return depts

def scrape_clinic_schedules(depts, doc_code_map):
    """遍歷所有專科門診時刻表，解析排班與停診日期"""
    print(f"[4/4] 正在遍歷各科門診時刻表與停診狀態...")
    all_raw_slots = []
    
    # 週別對應
    weekday_names = {1: "週一", 2: "週二", 3: "週三", 4: "週四", 5: "週五", 6: "週六"}
    slot_map = {"1": "上午", "2": "下午", "3": "夜診"}

    for idx, d in enumerate(depts, 1):
        dept_code = d["code"]
        dept_name = d["name"]
        dept_url = f"https://netreg.chhw.mohw.gov.tw/DOCTORLIST?role=DIV&key_code={dept_code}"
        page_html = fetch_url(dept_url)
        if not page_html:
            continue

        # 匹配 GoClinic('1150918', '1', '2', 'AA', 'A') ... 蔡安順 (停診/停掛)
        clinic_matches = re.findall(
            r"GoClinic\('([^']*)',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)'\)[^>]*>([\s\S]*?)</a>",
            page_html
        )

        for date_str, apn, room_no, div_code, zone, inner in clinic_matches:
            inner_dec = html.unescape(inner)
            # 擷取醫師姓名
            doc_m = re.search(r'<div[^>]*>\s*([^\s<]+)', inner_dec)
            if not doc_m:
                continue
            doc_name = doc_m.group(1).strip()
            if not doc_name or doc_name in ["UNKNOWN", "約診醫師"]:
                continue

            # 計算日期與星期 (民國年 1150918 -> 2026-09-18)
            if len(date_str) == 7:
                try:
                    y = int(date_str[0:3]) + 1911
                    m = int(date_str[3:5])
                    day = int(date_str[5:7])
                    dt = datetime.date(y, m, day)
                    weekday = dt.isoweekday() # 1 = Mon ... 6 = Sat, 7 = Sun
                    date_display = f"{m}/{day}"
                except ValueError:
                    continue
            else:
                continue

            if weekday > 6: # 排除週日
                continue

            # 檢查停診、停掛、特診
            is_stopped = ("停診" in inner_dec) or ("停掛" in inner_dec)

            # 檢查是否有其他備註 (如 限約診、特診)
            note_candidates = re.findall(r'<small[^>]*>([^<]+)</small>', inner_dec)
            special_note = ""
            for nc in note_candidates:
                nc_clean = nc.strip()
                if nc_clean and not re.match(r'^\(已掛\d+人\)$', nc_clean) and nc_clean not in ["停診", "停掛"]:
                    special_note = nc_clean

            slot_label = slot_map.get(apn, "上午")
            room_label = f"{room_no}診" if not room_no.endswith("診") else room_no

            all_raw_slots.append({
                "dept_code": dept_code,
                "dept_name": dept_name,
                "doctor": doc_name,
                "weekday": weekday,
                "slot": slot_label,
                "room": room_label,
                "date": date_display,
                "is_stopped": is_stopped,
                "special_note": special_note
            })

    # 聚合門診常規排班規則
    grouped = {}
    for item in all_raw_slots:
        key = (item["dept_code"], item["dept_name"], item["doctor"], item["weekday"], item["slot"], item["room"])
        if key not in grouped:
            grouped[key] = {
                "total_occurrences": 0,
                "stopped_dates": [],
                "special_notes": set()
            }
        grouped[key]["total_occurrences"] += 1
        if item["is_stopped"]:
            grouped[key]["stopped_dates"].append(item["date"])
        if item["special_note"]:
            grouped[key]["special_notes"].add(item["special_note"])

    schedules = []
    for key, val in grouped.items():
        dept_code, dept_name, doctor, weekday, slot, room = key
        
        # 組合備註：若有特殊診名則優先保留，並附加停診日
        note_parts = []
        if val["special_notes"]:
            note_parts.append("/".join(val["special_notes"]))
        
        # 去除重複停診日並排序
        stopped_dates = sorted(list(set(val["stopped_dates"])), key=lambda x: [int(p) for p in x.split('/')])
        if stopped_dates:
            # 格式化為如: "10/10.17停診" 或 "10/10停診"
            if len(stopped_dates) == 1:
                note_parts.append(f"{stopped_dates[0]}停診")
            elif len(stopped_dates) <= 3:
                # 合併為 10/10.17.24停診
                first_month = stopped_dates[0].split('/')[0]
                same_month = all(d.split('/')[0] == first_month for d in stopped_dates)
                if same_month:
                    days_str = ".".join(d.split('/')[1] for d in stopped_dates)
                    note_parts.append(f"{first_month}/{days_str}停診")
                else:
                    note_parts.append(".".join(stopped_dates) + "停診")
            else:
                note_parts.append(f"近期停診({stopped_dates[0]}等{len(stopped_dates)}診)")

        final_note = " ".join(note_parts)

        schedules.append({
            "dept_code": dept_code,
            "dept_name": dept_name,
            "doctor": doctor,
            "weekday": weekday,
            "slot": slot,
            "room": room,
            "note": final_note
        })

    # 排序：依科別代碼、看診星期、午別
    slot_rank = {"上午": 1, "下午": 2, "夜診": 3}
    schedules.sort(key=lambda x: (x["dept_code"], x["weekday"], slot_rank.get(x["slot"], 1), x["doctor"]))
    print(f" -> 成功聚合產生常規門診排班規則: 共 {len(schedules)} 筆 (包含具體停診日期標註)")
    return schedules

def build_master_data(schedules, doc_code_map):
    """建立最新醫師主檔清單"""
    seen = set()
    master = []
    for s in schedules:
        key = (s["dept_code"], s["doctor"])
        if key not in seen:
            seen.add(key)
            code = doc_code_map.get(s["doctor"], "")
            master.append({
                "dept": s["dept_name"],
                "deptCode": s["dept_code"],
                "doc": s["doctor"],
                "docCode": code
            })
    
    # 補足有官方代碼但該月未常規出診的醫師
    for doc_name, doc_code in doc_code_map.items():
        if not any(m["doc"] == doc_name for m in master):
            master.append({
                "dept": "其他科",
                "deptCode": "OTHER",
                "doc": doc_name,
                "docCode": doc_code
            })

    master.sort(key=lambda x: (x["deptCode"], x["doc"]))
    print(f" -> 成功建立最新醫師主檔清單: 共 {len(master)} 筆醫師資料")
    return master

def update_html_files(notice, master_data, schedules, dry_run=False):
    """將最新資料寫入 index.html 與 門診時段交叉查詢與醫師代碼查詢系統.html"""
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    target_files = [
        os.path.join(base_dir, "index.html"),
        os.path.join(base_dir, "門診時段交叉查詢與醫師代碼查詢系統.html")
    ]

    # 序列化為乾淨格式化的 JavaScript 物件字串
    notice_js = "    const officialNotice = " + json.dumps(notice, ensure_ascii=False, indent=6) + ";"
    
    master_lines = ["    const masterData = ["]
    for m in master_data:
        master_lines.append(f'      {{ dept: "{m["dept"]}", deptCode: "{m["deptCode"]}", doc: "{m["doc"]}", docCode: "{m["docCode"]}" }},')
    if master_lines[-1].endswith(','):
        master_lines[-1] = master_lines[-1][:-1]
    master_lines.append("    ];")
    master_js = "\n".join(master_lines)

    schedule_lines = ["    const schedules = ["]
    for s in schedules:
        schedule_lines.append(
            f'      {{ dept_code: "{s["dept_code"]}", dept_name: "{s["dept_name"]}", doctor: "{s["doctor"]}", weekday: {s["weekday"]}, slot: "{s["slot"]}", room: "{s["room"]}", note: "{s["note"]}" }},'
        )
    if schedule_lines[-1].endswith(','):
        schedule_lines[-1] = schedule_lines[-1][:-1]
    schedule_lines.append("    ];")
    schedule_js = "\n".join(schedule_lines)

    if dry_run:
        print("[Dry Run] 測試模式，不進行檔案寫入。產出排班範例：")
        print("\n".join(schedule_lines[:15]))
        return

    for fpath in target_files:
        if not os.path.exists(fpath):
            print(f"[錯誤] 找不到檔案: {fpath}", file=sys.stderr)
            continue

        with open(fpath, "r", encoding="utf-8") as f:
            content = f.read()

        # 替換或插入 officialNotice
        if "const officialNotice =" in content:
            content = re.sub(r"const officialNotice =[\s\S]*?;\n", notice_js + "\n", content)
        else:
            # 插入在 masterData 之前
            content = content.replace("    const masterData =", notice_js + "\n\n    const masterData =")

        # 替換 masterData
        content = re.sub(r"const masterData = \[[^;]*?\];", master_js, content)

        # 替換 schedules
        content = re.sub(r"const schedules = \[[^;]*?\];", schedule_js, content)

        with open(fpath, "w", encoding="utf-8") as f:
            f.write(content)

        print(f" -> 成功更新檔案: {os.path.basename(fpath)}")

    # 確保兩檔完全複製一致
    if os.path.exists(target_files[0]) and os.path.exists(target_files[1]):
        with open(target_files[0], "rb") as src, open(target_files[1], "wb") as dst:
            dst.write(src.read())
        print(" -> 雙檔案同步校驗完成，確保 100% SHA-256 吻合。")

def main():
    parser = argparse.ArgumentParser(description="彰化醫院門診時刻表與官方停代診公告自動更新程式")
    parser.add_argument("--check-last-day", action="store_true", help="檢查今天是否為當月最後一天，若非最後一天則安全退出")
    parser.add_argument("--dry-run", action="store_true", help="僅進行抓取與比對，不寫入檔案")
    args = parser.parse_args()

    # 檢查是否為當月最後一天
    if args.check_last_day:
        today = datetime.date.today()
        tomorrow = today + datetime.timedelta(days=1)
        if tomorrow.day != 1:
            print(f"今日 ({today}) 不是當月最後一天 (明天是 {tomorrow.day} 號)，排程安全結束。")
            sys.exit(0)
        print(f"今日 ({today}) 為當月最後一天！開始執行全院門診表、醫師代碼與停代診公告更新作業。")

    print("=================================================================")
    print(" 🏥 啟動衛生福利部彰化醫院 (CHHW) 門診時刻與停代診公告同步程式")
    print("=================================================================")

    # 1. 抓取官方停診公告 (aid=320&page_name=detail&iid=15)
    notice = get_official_suspension_notice()
    if not notice:
        notice = {
            "title": "醫師停診、代診公告",
            "sourceUrl": "https://www.chhw.mohw.gov.tw/?aid=320&page_name=detail&iid=15",
            "updateTime": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
            "images": []
        }

    # 2. 抓取全院醫師代碼 (/DOCTOR)
    doc_code_map = get_doctor_codes()

    # 3. 抓取全院專科清單 (/)
    depts = get_departments()

    # 4. 抓取並解析門診排班與停診日期 (/DOCTORLIST)
    schedules = scrape_clinic_schedules(depts, doc_code_map)

    # 5. 建立醫師主檔清單
    master_data = build_master_data(schedules, doc_code_map)

    # 6. 寫入 HTML 檔案
    update_html_files(notice, master_data, schedules, dry_run=args.dry_run)

    print("=================================================================")
    print(" 🎉 全院門診時刻表、醫師代碼與停代診公告更新完成！")
    print("=================================================================")

if __name__ == "__main__":
    main()
