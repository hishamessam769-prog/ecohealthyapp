# Runbook النسخ والاستعادة

- يوميًا: راقب PITR ونجاح النسخ وإشعار الفشل.
- أسبوعيًا: تحقق من قابلية قراءة dump وأحجام الجداول.
- شهريًا: Restore إلى مشروع معزول، شغّل schema migration، قارن counts/checksums، اختبر Login وInvoice→Payment→Delivery، ثم وثّق RPO/RTO.
- لا تحفظ service-role أو dumps غير مشفرة في GitHub.
- Recovery: اعزل Production، حدد restore point، استعد إلى مشروع جديد، نفّذ smoke tests، بدّل Environment atomically، ثم احتفظ بالمشروع القديم للـforensics.

