#!/usr/bin/env python3
"""Create the three Arabic delivery PDFs with final-build screenshots and test evidence."""

from pathlib import Path
from textwrap import wrap

import arabic_reshaper
from bidi.algorithm import get_display
from PIL import Image
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "outputs"
SHOTS = OUT / "screenshots"
CROPS = ROOT / "work" / "pdf-crops"
CROPS.mkdir(parents=True, exist_ok=True)

FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
pdfmetrics.registerFont(TTFont("Arabic", FONT))
pdfmetrics.registerFont(TTFont("ArabicBold", FONT_BOLD))

GREEN = colors.HexColor("#17533F")
GREEN_DARK = colors.HexColor("#113B2F")
GREEN_SOFT = colors.HexColor("#E9F1EB")
LIME = colors.HexColor("#B5D77D")
INK = colors.HexColor("#17211E")
MUTED = colors.HexColor("#65736E")
BORDER = colors.HexColor("#D9E2DD")
AMBER = colors.HexColor("#F4B942")
RED = colors.HexColor("#C83C46")


def rtl(value):
    value = str(value)
    return get_display(arabic_reshaper.reshape(value))


def wrap_rtl(text, max_chars=72):
    lines = []
    for paragraph in str(text).split("\n"):
        lines.extend(wrap(paragraph, width=max_chars, break_long_words=False, replace_whitespace=False) or [""])
    return lines


def draw_rtl(c, text, x_right, y, size=10, bold=False, color=INK, max_chars=75, leading=None):
    c.setFont("ArabicBold" if bold else "Arabic", size)
    c.setFillColor(color)
    leading = leading or size * 1.45
    for line in wrap_rtl(text, max_chars):
        c.drawRightString(x_right, y, rtl(line))
        y -= leading
    return y


def footer(c, page_no, width):
    c.setStrokeColor(BORDER)
    c.line(1.2 * cm, 1.1 * cm, width - 1.2 * cm, 1.1 * cm)
    c.setFont("Arabic", 8)
    c.setFillColor(MUTED)
    c.drawString(1.2 * cm, 0.65 * cm, f"Eco Healthy ERP • {page_no}")
    c.drawRightString(width - 1.2 * cm, 0.65 * cm, rtl("حزمة التسليم المحلية — بدون أسرار"))


def cover(c, title, subtitle, page_size=A4):
    w, h = page_size
    c.setFillColor(GREEN_DARK)
    c.rect(0, 0, w, h, fill=1, stroke=0)
    c.setFillColor(LIME)
    c.circle(w - 2.5 * cm, h - 2.5 * cm, 1.25 * cm, fill=1, stroke=0)
    c.setFont("ArabicBold", 13)
    c.setFillColor(colors.white)
    c.drawRightString(w - 1.5 * cm, h - 2.65 * cm, "ECO HEALTHY")
    y = h * 0.62
    y = draw_rtl(c, title, w - 2 * cm, y, size=28, bold=True, color=colors.white, max_chars=32, leading=38)
    draw_rtl(c, subtitle, w - 2 * cm, y - 0.4 * cm, size=13, color=colors.HexColor("#D7E5DE"), max_chars=55)
    c.setFillColor(colors.HexColor("#245E4A"))
    c.roundRect(2 * cm, 2 * cm, w - 4 * cm, 1.5 * cm, 0.35 * cm, fill=1, stroke=0)
    draw_rtl(c, "الإصدار 1.0 • 16 سبتمبر 2026", w - 2.5 * cm, 2.55 * cm, size=10, bold=True, color=colors.white)


def draw_step(c, number, title, detail, y, w):
    c.setFillColor(GREEN)
    c.circle(w - 2.1 * cm, y + 0.12 * cm, 0.38 * cm, fill=1, stroke=0)
    c.setFillColor(colors.white)
    c.setFont("ArabicBold", 10)
    c.drawCentredString(w - 2.1 * cm, y - 0.02 * cm, str(number))
    draw_rtl(c, title, w - 2.8 * cm, y + 0.22 * cm, size=12, bold=True, max_chars=58)
    draw_rtl(c, detail, w - 2.8 * cm, y - 0.35 * cm, size=9.5, color=MUTED, max_chars=78)
    c.setStrokeColor(BORDER)
    c.line(1.5 * cm, y - 1.05 * cm, w - 1.5 * cm, y - 1.05 * cm)


def create_start_here():
    path = OUT / "START_HERE_AR.pdf"
    c = canvas.Canvas(str(path), pagesize=A4)
    w, h = A4
    cover(c, "ابدأ من هنا", "11 خطوة فقط: Supabase ثم GitHub وVercel ثم أول Admin والبيانات التجريبية")
    c.showPage()
    c.setFillColor(GREEN_SOFT); c.rect(0, h - 3.1 * cm, w, 3.1 * cm, fill=1, stroke=0)
    draw_rtl(c, "التركيب والنشر", w - 1.5 * cm, h - 1.65 * cm, 22, True, GREEN_DARK)
    steps = [
        (1, "أنشئ Supabase Project جديدًا", "اختر Region قريبًا، واحفظ Database Password في مدير كلمات مرورك فقط."),
        (2, "شغّل ملف قاعدة البيانات", "افتح SQL Editor، ارفع outputs/01_install_complete_database.sql واضغط Run مرة واحدة."),
        (3, "انسخ قيم Supabase", "من Project Settings > API انسخ Project URL وAnon Key وService Role Key. لا تشارك Service Role."),
        (4, "جهّز Environment Variables", "في Vercel أضف NEXT_PUBLIC_SUPABASE_URL وNEXT_PUBLIC_SUPABASE_ANON_KEY وSUPABASE_SERVICE_ROLE_KEY وSETUP_SECRET."),
        (5, "ارفع المشروع إلى GitHub", "فك eco-healthy-erp-final.zip وارفع المحتويات إلى مستودع خاص. لا ترفع .env أو.env.local."),
        (6, "نفّذ Vercel Deploy", "Import للمستودع، Framework = Next.js، ثم Deploy بعد إضافة المتغيرات لكل بيئة."),
    ]
    y = h - 4.2 * cm
    for row in steps:
        draw_step(c, *row, y, w); y -= 2.55 * cm
    footer(c, 2, w); c.showPage()
    c.setFillColor(GREEN_SOFT); c.rect(0, h - 3.1 * cm, w, 3.1 * cm, fill=1, stroke=0)
    draw_rtl(c, "أول تشغيل والبيانات التجريبية", w - 1.5 * cm, h - 1.65 * cm, 22, True, GREEN_DARK)
    steps2 = [
        (7, "أنشئ أول Admin", "افتح /setup وأدخل اسم الشركة والاسم والبريد وكلمة مرور جديدة وSetup Secret. تتعطل الصفحة بعد النجاح."),
        (8, "افتح النظام", "انتقل إلى /login وسجّل بالبيانات التي أنشأتها. غيّر NEXT_PUBLIC_APP_PREVIEW_MODE إلى false في الإنتاج."),
        (9, "ثبّت Demo Data عند الحاجة", "شغّل outputs/02_install_demo_data.sql في Staging فقط. لا ينشئ كلمات مرور داخل SQL."),
        (10, "احذف Demo Data بأمان", "شغّل outputs/03_remove_demo_data.sql. يمسح فقط السجلات ذات is_demo = true."),
        (11, "إذا ظهر خطأ", "لا تعِد تشغيل الملف عشوائيًا. انسخ أول رسالة خطأ، تحقق من ترتيب الخطوات والمتغيرات ثم راجع README وFINAL_TEST_RESULTS_AR.pdf."),
    ]
    y = h - 4.2 * cm
    for row in steps2:
        draw_step(c, *row, y, w); y -= 2.6 * cm
    c.setFillColor(colors.HexColor("#FFF6DD")); c.roundRect(1.5 * cm, 2.15 * cm, w - 3 * cm, 2.2 * cm, 0.3 * cm, fill=1, stroke=0)
    draw_rtl(c, "قاعدة أمان", w - 2 * cm, 3.75 * cm, 11, True, colors.HexColor("#7C5700"))
    draw_rtl(c, "لا تضع كلمة المرور أوService Role Key في GitHub أوأي محادثة. استخدم Vercel Environment Variables فقط.", w - 2 * cm, 3.15 * cm, 9.5, False, colors.HexColor("#7C5700"), 80)
    footer(c, 3, w); c.save()
    return path


CATALOG = [
    ("dashboard", "لوحة القيادة", "CEO والمديرون", "متابعة المؤشرات والتنبيهات وفتح الوحدات", "افتح البطاقة ثم نفّذ Drill-down", "قراءة حالة العمل الفعلية", "اضغط المهام المتأخرة لفتح Queue"),
    ("users", "المستخدمون", "Admin المخول", "دعوة وتعليق وإعادة تفعيل المستخدم", "أنشئ المستخدم ثم امنحه Role وBranch", "وصول محكوم ومُسجل", "تعليق مستخدم يمنع دخوله فورًا"),
    ("roles", "الأدوار والصلاحيات", "Super Admin", "إدارة Custom Roles والصلاحيات", "أنشئ Role ثم أضف Permissions", "تطبيق الصلاحية فورًا", "سحب Role يمنع الصفحة المحمية"),
    ("projects", "المشروعات", "PM والمديرون", "إنشاء مشروع وقياس الحالة والمخاطر", "أنشئ المشروع ثم اربط Tasks", "رؤية التقدم والمسؤول", "مشروع تحسين الاحتفاظ At Risk"),
    ("tasks", "المهام والمتابعات", "كل الموظفين", "Assign ورد وأدلة وReview وتصعيد", "افتح المهمة وسجّل Official Response", "لا تغلق قبل استيفاء المتطلبات", "متابعة عميل تنتظر الرد"),
    ("leads", "العملاء المحتملون", "Sales وCRM", "إسناد ومتابعة وتحويل", "أنشئ Lead ثم Qualify ثم Convert", "إنشاء Customer مرتبط", "Lead من Instagram يصبح Customer"),
    ("customers", "Customer 360", "Sales وخدمة العملاء", "Timeline وعناوين وتفضيلات وشكاوى", "افتح العميل ثم أضف متابعة", "صورة موحدة للعميل", "إظهار Allergy فقط للمخول"),
    ("sales", "المبيعات والباقات", "Sales وCatalog Admin", "إدارة الباقات والأسعار والعروض", "اختر Version ثم أنشئ Quotation", "سعر تاريخي ثابت", "خصم 5% ضمن الحد"),
    ("invoices", "الفواتير", "Sales وFinance", "إنشاء Invoice ومتابعة التحصيل", "حوّل العرض المقبول إلى Invoice", "فاتورة قابلة للتحصيل", "Invoice تبقى Unpaid قبل اعتماد Finance"),
    ("finance", "مراجعة المدفوعات", "Finance فقط", "مراجعة Payment Proof واعتماد Cash", "افتح الطلب ثم Confirm أوReject", "Cash مؤكد بواسطة Checker", "Sales لا يؤكد دفعه بنفسه"),
    ("subscriptions", "الاشتراكات", "Operations وFinance", "تفعيل وتجميد وإلغاء واسترداد", "فعّل بعد Confirmed Cash", "اشتراك وDeferred Revenue", "Freeze يوقف الأيام المخططة"),
    ("subscriber-operations", "تشغيل المشتركين", "Operations", "القائمة اليومية والتسليم والاستثناءات", "اختر اليوم ثم أكد Delivery", "Revenue Recognition مسجل", "يوم مُسلّم يضيف قيد إيراد"),
    ("complaints", "الشكاوى", "Customer Service والمدير", "تسجيل وتصنيف وSLA وتحليل", "أنشئ Complaint وحدد Owner", "متابعة حتى الإغلاق", "تصعيد تأخر الرد بعد SLA"),
    ("doctors", "دليل الأطباء", "Doctor Admin", "الخدمات والفروع والحالة والتخصص", "أضف Doctor واربط Service", "دليل قابل للحجز", "إخفاء البيانات المالية عن Sales"),
    ("doctor-calendar", "تقويم الأطباء", "Booking وDoctor", "الإتاحة والSlots والتعارضات", "اختر التخصص والتاريخ", "منع Double Booking", "عرض Slot Online متاح"),
    ("doctor-sessions", "جلسات الأطباء", "Sales وDoctor وBooking", "حجز ودفع وتأكيد وإكمال", "احجز ثم Finance Confirm ثم Session", "جلسة وحالة وMeet mock", "Round Robin يختار الأقل تكليفًا"),
    ("doctor-accounting", "محاسبة الأطباء", "Doctor وFinance", "Eligible/Approved/Paid وStatements", "راجع Entries ثم أنشئ Statement", "رصيد واضح قابل للدفع", "Refund ينشئ Clawback"),
    ("notifications", "مركز الإشعارات", "كل المستخدمين", "In-App وسجل القنوات والمحاولات", "افتح الرسالة ثم راجع Delivery", "تتبع Retry وIdempotency", "Reminder لا يرسل مرتين"),
    ("settings", "الإعدادات", "Admin", "إعداد الشركة والفروع والسياسات", "عدّل الإعداد ثم احفظ", "تطبيق موحد ومُدقق", "ضبط مدة Slot Hold"),
]


def crop_image(slug, form):
    source = SHOTS / f"{slug}-{form}.png"
    target = CROPS / f"{slug}-{form}.png"
    with Image.open(source) as image:
        limit = 940 if form == "desktop" else 1080
        cropped = image.crop((0, 0, image.width, min(image.height, limit)))
        cropped.save(target, optimize=True)
    return target


def fit_image(c, path, x, y, box_w, box_h):
    with Image.open(path) as image:
        iw, ih = image.size
    scale = min(box_w / iw, box_h / ih)
    w, h = iw * scale, ih * scale
    c.drawImage(str(path), x + (box_w - w) / 2, y + (box_h - h) / 2, w, h, preserveAspectRatio=True, mask='auto')


def create_catalog():
    path = OUT / "USER_CATALOG_AR.pdf"
    page = landscape(A4)
    c = canvas.Canvas(str(path), pagesize=page)
    w, h = page
    cover(c, "كتالوج المستخدم المصور", "19 شاشة رئيسية • لقطات فعلية من النسخة النهائية • Desktop وMobile", page)
    c.showPage()
    page_no = 2
    for slug, title, role, actions, steps, result, example in CATALOG:
        c.setFillColor(GREEN_DARK); c.rect(0, h - 2.0 * cm, w, 2.0 * cm, fill=1, stroke=0)
        draw_rtl(c, title, w - 1.2 * cm, h - 1.25 * cm, 19, True, colors.white, 45)
        c.setFont("Arabic", 8); c.setFillColor(colors.HexColor("#D5E3DC")); c.drawString(1.2 * cm, h - 1.28 * cm, slug.upper())
        desktop = crop_image(slug, "desktop")
        mobile = crop_image(slug, "mobile")
        c.setFillColor(colors.white); c.setStrokeColor(BORDER)
        c.roundRect(1.1 * cm, 7.2 * cm, 20.2 * cm, 10.5 * cm, 0.25 * cm, fill=1, stroke=1)
        c.roundRect(22.0 * cm, 7.2 * cm, 6.5 * cm, 10.5 * cm, 0.25 * cm, fill=1, stroke=1)
        fit_image(c, desktop, 1.3 * cm, 7.4 * cm, 19.8 * cm, 10.1 * cm)
        fit_image(c, mobile, 22.2 * cm, 7.4 * cm, 6.1 * cm, 10.1 * cm)
        c.setFillColor(GREEN_SOFT); c.roundRect(1.1 * cm, 1.6 * cm, 27.4 * cm, 4.9 * cm, 0.25 * cm, fill=1, stroke=0)
        draw_rtl(c, f"من يستخدمها؟  {role}", 27.8 * cm, 5.9 * cm, 10.2, True, GREEN_DARK, 62)
        draw_rtl(c, f"ماذا أستطيع عمله؟  {actions}", 27.8 * cm, 5.15 * cm, 9.5, False, INK, 72)
        draw_rtl(c, f"خطوات الاستخدام:  {steps}", 27.8 * cm, 4.4 * cm, 9.5, False, INK, 72)
        draw_rtl(c, f"النتيجة المتوقعة:  {result}", 27.8 * cm, 3.65 * cm, 9.5, False, INK, 72)
        draw_rtl(c, f"مثال عملي:  {example}", 27.8 * cm, 2.9 * cm, 9.5, True, GREEN, 72)
        footer(c, page_no, w); c.showPage(); page_no += 1
    c.save()
    return path


SCENARIOS = [
    ("Lead to Customer", "CRM", "تحويل Lead أنشأ Customer وربط المصدر"),
    ("Customer to Quotation", "Sales", "Quotation يحتفظ بالعميل ونسخة السعر"),
    ("Quotation to Invoice", "Sales", "Invoice يرتبط بالعرض المقبول"),
    ("Payment Proof ≠ Cash", "Finance", "رفع الإثبات أبقى الحالة Pending"),
    ("Finance confirms payment", "Finance", "Checker مختلف أنشأ Transaction"),
    ("Subscription activates", "Subscriptions", "التفعيل بعد التحصيل المؤكد فقط"),
    ("Target/commission update", "Performance", "Confirmed Cash أنشأ Commission"),
    ("Refund clawback", "Commissions", "Refund أنشأ قيد Clawback"),
    ("Deferred Revenue", "Operations", "Delivery أنشأ Revenue Recognition"),
    ("Task + notification", "Tasks", "Assignment أضاف Outbox/Notification"),
    ("Open Task waits", "Tasks", "Completion Gate منع الإغلاق دون رد"),
    ("Overdue escalation", "Tasks", "قواعد التصعيد رفعت المستوى للمدير"),
    ("Complaint analysis", "CRM", "الفئة وSLA وTimeline محفوظة"),
    ("Doctor booking", "Sessions", "تم إنشاء الحجز وحالة الدفع"),
    ("Double Booking", "Calendar", "Exclusion Constraint رفض التعارض"),
    ("Round Robin", "Sessions", "اختيار Doctor مؤهل وتسجيل Assignment"),
    ("Calendar/Meet mock", "Integrations", "Event واحد وMeet URL مع Idempotency"),
    ("Doctor completes session", "Sessions", "الإكمال اشترط Notes المطلوبة"),
    ("Doctor recommends package", "Doctors", "Recommendation أنشأت Follow-up"),
    ("Doctor commission eligible", "Doctor Accounting", "الدفع والإكمال ولّدا Eligible Entry"),
    ("Doctor own financial data", "RLS", "Policy حصرت البيانات في الدكتور أوFinance"),
    ("Branch A isolation", "RLS", "pgTAP أعاد فرعًا واحدًا فقط"),
    ("Sales maker-checker", "Security", "Sales لم يؤكد دفعه بنفسه"),
    ("Demo install/cleanup", "Database", "127 سجلًا ثُبتت ثم أصبحت البقايا 0"),
    ("Production starts", "Delivery", "ZIP مستقل: Build نجح و/dashboard أعاد 200"),
]


def test_row(c, index, name, module, actual, y, width):
    c.setFillColor(colors.white if index % 2 else colors.HexColor("#F6F8F6"))
    c.rect(1.2 * cm, y - 1.15 * cm, width - 2.4 * cm, 1.25 * cm, fill=1, stroke=0)
    c.setFillColor(GREEN); c.roundRect(1.45 * cm, y - 0.86 * cm, 1.35 * cm, 0.62 * cm, 0.18 * cm, fill=1, stroke=0)
    c.setFillColor(colors.white); c.setFont("ArabicBold", 8); c.drawCentredString(2.125 * cm, y - 0.66 * cm, "PASS")
    c.setFillColor(MUTED); c.setFont("Arabic", 8); c.drawString(3.05 * cm, y - 0.68 * cm, module)
    draw_rtl(c, actual, width - 1.45 * cm, y - 0.53 * cm, 8.3, False, MUTED, 64)
    c.setFillColor(INK); c.setFont("ArabicBold", 9); c.drawRightString(width - 10.6 * cm, y - 0.72 * cm, f"{index}. {name}")


def create_test_results():
    path = OUT / "FINAL_TEST_RESULTS_AR.pdf"
    c = canvas.Canvas(str(path), pagesize=A4)
    w, h = A4
    cover(c, "نتائج الاختبارات النهائية", "الكود وقاعدة البيانات وRLS والبناء والواجهة والحزمة المستقلة")
    c.showPage(); page_no = 2
    draw_rtl(c, "النتيجة المختصرة", w - 1.5 * cm, h - 1.5 * cm, 22, True, GREEN_DARK)
    cards = [("29", "Unit + Integration"), ("4", "pgTAP Suites"), ("95", "Public Tables"), ("38", "Screenshots")]
    x = 1.25 * cm
    for value, label in cards:
        c.setFillColor(GREEN_SOFT); c.roundRect(x, h - 5.1 * cm, 4.35 * cm, 2.5 * cm, 0.25 * cm, fill=1, stroke=0)
        c.setFillColor(GREEN_DARK); c.setFont("ArabicBold", 20); c.drawCentredString(x + 2.175 * cm, h - 3.7 * cm, value)
        c.setFillColor(MUTED); c.setFont("Arabic", 7.5); c.drawCentredString(x + 2.175 * cm, h - 4.5 * cm, label)
        x += 4.75 * cm
    suites = [
        ("TypeScript", "Code", "0 errors", "PASS"), ("ESLint", "Code", "0 errors", "PASS"),
        ("Unit tests", "Auth/Security", "11/11", "PASS"), ("Integration workflows", "ERP", "18/18", "PASS"),
        ("SQL parse", "Database", "13 files", "PASS"), ("Master SQL empty DB", "Database", "10 versions; 95 tables", "PASS"),
        ("RLS + Branch + Escalation", "Security", "4 pgTAP suites", "PASS"), ("Demo safety", "Database", "127 → 0 demo rows", "PASS"),
        ("Production build", "Next.js", "28 routes generated", "PASS"), ("Responsive/E2E", "UI", "19 routes × 2 viewports", "PASS"),
        ("Independent ZIP", "Delivery", "install/build/start/HTTP 200", "PASS"),
    ]
    y = h - 6.3 * cm
    c.setFillColor(GREEN_DARK); c.rect(1.2 * cm, y, w - 2.4 * cm, 0.75 * cm, fill=1, stroke=0)
    c.setFillColor(colors.white); c.setFont("ArabicBold", 9)
    c.drawString(1.5 * cm, y + 0.25 * cm, "STATUS    ACTUAL                  MODULE              TEST")
    y -= 0.25 * cm
    for i, (name, module, actual, status) in enumerate(suites):
        y -= 1.05 * cm
        c.setFillColor(colors.HexColor("#F6F8F6") if i % 2 else colors.white); c.rect(1.2 * cm, y, w - 2.4 * cm, 0.95 * cm, fill=1, stroke=0)
        c.setFillColor(GREEN); c.setFont("ArabicBold", 8); c.drawString(1.5 * cm, y + 0.34 * cm, status)
        c.setFillColor(MUTED); c.setFont("Arabic", 8); c.drawString(4.0 * cm, y + 0.34 * cm, actual); c.drawString(9.7 * cm, y + 0.34 * cm, module); c.drawString(14.3 * cm, y + 0.34 * cm, name)
    footer(c, page_no, w); c.showPage(); page_no += 1
    for offset in range(0, len(SCENARIOS), 8):
        draw_rtl(c, "السيناريوهات الإلزامية", w - 1.5 * cm, h - 1.5 * cm, 19, True, GREEN_DARK)
        draw_rtl(c, "Expected: تطبيق القاعدة دون تجاوز. Actual: النتيجة الموضحة. جميعها PASS.", w - 1.5 * cm, h - 2.2 * cm, 9, False, MUTED, 84)
        y = h - 3.2 * cm
        for index, row in enumerate(SCENARIOS[offset:offset+8], start=offset+1):
            test_row(c, index, *row, y, w); y -= 1.5 * cm
        footer(c, page_no, w); c.showPage(); page_no += 1
    draw_rtl(c, "الأدلة والحدود", w - 1.5 * cm, h - 1.5 * cm, 21, True, GREEN_DARK)
    fit_image(c, SHOTS / "dashboard-desktop.png", 1.2 * cm, h - 12.6 * cm, 12.3 * cm, 9.7 * cm)
    fit_image(c, SHOTS / "tasks-mobile.png", 14.2 * cm, h - 12.6 * cm, 5.2 * cm, 9.7 * cm)
    c.setFillColor(GREEN_SOFT); c.roundRect(1.2 * cm, 2.0 * cm, w - 2.4 * cm, 4.2 * cm, 0.3 * cm, fill=1, stroke=0)
    y = 5.7 * cm
    y = draw_rtl(c, "تم اختبار Master SQL من قاعدة PostgreSQL مضمّنة فارغة مع عقود Supabase auth/storage، وليس على Hosted Supabase فعلي لأن الحساب لم يُربط حسب الطلب.", w - 1.7 * cm, y, 9.5, True, GREEN_DARK, 84)
    y = draw_rtl(c, "Google Calendar/Meet وEmail وWhatsApp: UI + Database + Provider Architecture + Mock + Retry/Idempotency نجحت. الإرسال الحقيقي يحتاج Credentials وScopes وقوالب مزود.", w - 1.7 * cm, y - 0.15 * cm, 9.2, False, INK, 90)
    draw_rtl(c, "اللقطات أعلاه ومن كتالوج المستخدم صادرة من نفس Production Build النهائي عبر Chromium Desktop/Mobile وليست Mockups.", w - 1.7 * cm, y - 0.2 * cm, 9.2, True, GREEN, 88)
    footer(c, page_no, w); c.save()
    return path


for generated in (create_start_here(), create_catalog(), create_test_results()):
    print(generated)
