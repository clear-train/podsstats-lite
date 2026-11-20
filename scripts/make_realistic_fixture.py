#!/usr/bin/env python3
"""生成一个结构上完全仿真 Apple「导出所有健康数据」的 export.xml，用于验证解析器。

真实的 export.xml 特点，这里全部复刻：
  · 带 DOCTYPE + DTD 内部子集，<!DOCTYPE HealthData [ ... ]>
  · 根节点 <HealthData locale="zh_CN">，紧跟 <ExportDate> 与 <Me .../>（自闭合）
  · 数十种无关类型混排，耳机音量只占其中一小撮
  · 中英文混用的 sourceName / device
  · 耳机音量有 quantity（数值）和 category（字符串事件）两种
  · Record 上还有子节点 <MetadataEntry>
  · 另外混入 <Correlation>、<Workout>、<ActivitySummary>、<ClinicalRecord>

用法: python3 scripts/make_realistic_fixture.py <输出路径> [天数]
"""
import sys
from datetime import datetime, timedelta, timezone

TZ = timezone(timedelta(hours=8))


def fmt(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S ") + "+0800"


def rec(rtype, src, unit, start, end, value, device=None, extra_meta=None, ver="17.4"):
    dev = device or f"&lt;&lt;HKDevice: 0x1, name:{src}&gt;&gt;"
    head = (
        f'  <Record type="{rtype}" sourceName="{src}" sourceVersion="{ver}" '
        f'device="{dev}" unit="{unit}" creationDate="{fmt(end)}" '
        f'startDate="{fmt(start)}" endDate="{fmt(end)}"'
    )
    if extra_meta:
        out = head + f' value="{value}">\n'
        for k, v in extra_meta:
            out += f'   <MetadataEntry key="{k}" value="{v}"/>\n'
        out += "  </Record>\n"
        return out
    return head + f' value="{value}"/>\n'


def build(days):
    now = datetime.now(TZ).replace(minute=0, second=0, microsecond=0)
    start_day = (now - timedelta(days=days - 1)).replace(hour=0, minute=0, second=0)
    out = []
    out.append('<?xml version="1.0" encoding="UTF-8"?>\n')
    out.append("<!DOCTYPE HealthData [\n")
    out.append("<!-- HealthKit Export Version: 14 -->\n")
    out.append("<!ELEMENT HealthData (ExportDate,Me,(Record|Correlation|Workout|ActivitySummary|ClinicalRecord)*)>\n")
    out.append('<!ATTLIST HealthData locale CDATA #REQUIRED>\n')
    out.append("<!ELEMENT ExportDate EMPTY>\n")
    out.append("<!ATTLIST ExportDate value CDATA #REQUIRED>\n")
    out.append("<!ELEMENT Me EMPTY>\n")
    out.append("<!ELEMENT Record (MetadataEntry)*>\n")
    out.append("<!ELEMENT MetadataEntry EMPTY>\n")
    out.append("<!ELEMENT Correlation (MetadataEntry)*>\n")
    out.append("<!ELEMENT Workout (MetadataEntry)*>\n")
    out.append("<!ELEMENT ActivitySummary EMPTY>\n")
    out.append("]>\n")
    out.append('<HealthData locale="zh_CN">\n')
    out.append(f' <ExportDate value="{fmt(now)}"/>\n')
    out.append(' <Me HKCharacteristicTypeIdentifierDateOfBirth="1999-05-12" '
               'HKCharacteristicTypeIdentifierBiologicalSex="HKBiologicalSexMale" '
               'HKCharacteristicTypeIdentifierBloodType="HKBloodTypeNotSet" '
               'HKCharacteristicTypeIdentifierFitzpatrickSkinType="HKFitzpatrickSkinTypeNotSet"/>\n')

    day = start_day
    while day <= now:
        # ---- 干扰类型：步数 / 心率 / 能量 / 血氧 ... ----
        for h in range(7, 23):
            t = day + timedelta(hours=h, minutes=(h * 7) % 60)
            out.append(rec("HKQuantityTypeIdentifierStepCount", "李钦凯的 iPhone", "count",
                           t, t + timedelta(minutes=5), (h * 137) % 800 + 12))
            # 心率按 5 分钟一条，接近真实 Apple Watch 密度
            for mm in range(0, 60, 5):
                ht = day + timedelta(hours=h, minutes=mm)
                out.append(rec("HKQuantityTypeIdentifierHeartRate", "Apple Watch", "count/min",
                               ht, ht + timedelta(minutes=1), (mm + h * 13) % 40 + 58,
                               device="&lt;&lt;HKDevice: 0x2, name:Apple Watch&gt;&gt;"))
            if h % 3 == 0:
                out.append(rec("HKQuantityTypeIdentifierActiveEnergyBurned", "Apple Watch", "kcal",
                               t, t + timedelta(minutes=10), round(((h * 31) % 60) / 3.0, 3)))
                out.append(rec("HKQuantityTypeIdentifierEnvironmentalAudioExposure", "iPhone", "dBASPL",
                               t, t + timedelta(minutes=2), round(45 + (h * 17) % 30 + 0.5, 2)))
        t = day + timedelta(hours=8)
        out.append(rec("HKQuantityTypeIdentifierBodyMass", "健康", "kg", t, t, 70.5))
        out.append(rec("HKQuantityTypeIdentifierHeight", "健康", "cm", t, t, 175))
        out.append(rec("HKQuantityTypeIdentifierOxygenSaturation", "Apple Watch", "%",
                       day + timedelta(hours=3), day + timedelta(hours=3, minutes=1), 98))
        out.append(rec("HKCategoryTypeIdentifierSleepAnalysis", "Apple Watch",
                       "HKCategoryTypeIdentifierSleepAnalysis",
                       day - timedelta(hours=1), day + timedelta(hours=7),
                       "HKCategoryValueSleepAnalysisAsleepCore"))
        out.append(rec("HKCategoryTypeIdentifierMindfulSession", "正念", "HKCategoryTypeIdentifierMindfulSession",
                       day + timedelta(hours=22), day + timedelta(hours=22, minutes=10),
                       "HKCategoryValueNotApplicable"))
        out.append(f' <Workout workoutActivityType="HKWorkoutActivityTypeRunning" duration="31.5" '
                   f'durationUnit="min" totalDistance="5.2" totalDistanceUnit="km" '
                   f'totalEnergyBurned="320" totalEnergyBurnedUnit="kcal" '
                   f'sourceName="Apple Watch" sourceVersion="17.4" creationDate="{fmt(day + timedelta(hours=19))}" '
                   f'startDate="{fmt(day + timedelta(hours=19))}" endDate="{fmt(day + timedelta(hours=19, minutes=31))}">\n'
                   f'  <MetadataEntry key="HKExternalUUID" value="A1B2C3D4-0000-0000-0000-00000000{day.day:04d}"/>\n'
                   f' </Workout>\n')
        out.append(f' <Correlation type="HKCorrelationTypeIdentifierBloodPressure" '
                   f'sourceName="健康" sourceVersion="17.4" creationDate="{fmt(day + timedelta(hours=9))}" '
                   f'startDate="{fmt(day + timedelta(hours=9))}" endDate="{fmt(day + timedelta(hours=9))}">\n'
                   f'  <MetadataEntry key="HKMetadataKeySyncVersion" value="1"/>\n'
                   f' </Correlation>\n')
        out.append(f' <ActivitySummary dateComponents="{{\'year\': 2026, \'month\': {day.month}, \'day\': {day.day}}}" '
                   f'activeEnergyBurned="420.5" activeEnergyBurnedGoal="500" '
                   f'appleExerciseTime="22" appleExerciseTimeGoal="30" appleStandHours="11" appleStandHoursGoal="12"/>\n')

        # ---- 目标：耳机音量（quantity）----
        for (bh, minutes) in ((8, 45), (12, 30), (15, 60), (20, 70)):
            if (day.day + bh) % 5 == 0:
                continue
            cursor = day + timedelta(hours=bh, minutes=(day.day * 3) % 20)
            end = cursor + timedelta(minutes=minutes)
            base = 58 + (day.day * 7 + bh) % 18
            while cursor < end:
                span = 90 + (cursor.minute % 3) * 15
                sample_end = min(end, cursor + timedelta(seconds=span))
                db = round(min(100.0, max(35.0, base + ((cursor.minute * 13) % 17) - 8)), 1)
                out.append(rec(
                    "HKQuantityTypeIdentifierHeadphoneAudioExposure", "AirPods Pro", "dBASPL",
                    cursor, sample_end, db,
                    device="&lt;&lt;HKDevice: 0x3, name:AirPods Pro, manufacturer:Apple Inc., "
                           "model:AirPods Pro, hardware:Bluetooth&gt;&gt;",
                    extra_meta=[("HKMetadataKeyAudioExposureDuration", str(span)),
                                ("HKMetadataKeySyncIdentifier", f"HP-{day.day}-{cursor.hour}-{cursor.minute}"),
                                ("HKMetadataKeySyncVersion", "1")]))
                cursor = sample_end
                # 段内断档：摘下 / 断开
                if (cursor.minute + cursor.hour) % 11 == 0:
                    cursor += timedelta(minutes=4)

        # ---- 目标：耳机音量过响事件（category，非数值）----
        if day.day % 7 == 0:
            t = day + timedelta(hours=21, minutes=15)
            out.append(rec("HKCategoryTypeIdentifierHeadphoneAudioExposureEvent", "iPhone",
                           "HKCategoryTypeIdentifierHeadphoneAudioExposureEvent",
                           t, t + timedelta(minutes=1),
                           "HKCategoryValueAudioExposureEventLoudEnvironment"))
        day += timedelta(days=1)

    out.append("</HealthData>\n")
    return "".join(out)


if __name__ == "__main__":
    path = sys.argv[1]
    days = int(sys.argv[2]) if len(sys.argv) > 2 else 60
    data = build(days)
    with open(path, "w", encoding="utf-8") as f:
        f.write(data)
    print(f"已生成 {path}（{days} 天，{len(data) / 1048576:.1f} MB）")
