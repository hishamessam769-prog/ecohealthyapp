# خطة نقل بيانات الـMVP

1. تجميد الكتابة في النظام القديم وأخذ نسخة كاملة.
2. تحميل Customers بعد تطبيع الهاتف وكشف التكرار؛ لا يُدمج عميلان تلقائيًا دون مراجعة.
3. تحميل Packages/Menu كإصدارات Effective-dated.
4. تحميل Orders ثم بناء Invoice Lines من المصدر؛ لا يُنقل `totalPaid` كقيمة موثوقة.
5. تحميل Payments وإعادة حساب allocations من المبالغ المتحققة فقط. أي إثبات ناقص يسجل `MISSING_LEGACY_EVIDENCE`.
6. تحميل Subscriptions وإنشاء Opening Entitlement Ledger بعد اعتماد فرق الرصيد.
7. تحميل Deliveries كتاريخ؛ الأحداث الناقصة تظل Migration Issue ولا تُخترع.
8. تحميل Sales Owners، والعناوين، والمناطق؛ المفقود يذهب إلى Queue مراجعة.
9. إنشاء Opening Deferred Revenue عبر قيد افتتاحي معتمد، لا بقسمة إجمالي الطلب على الأيام.
10. تشغيل تقارير `eco_migration_duplicate_customers_v` و`eco_migration_payment_differences_v` و`eco_migration_missing_proof_v`، ثم توقيع Finance/Operations.

الانتقال يكون Development → Staging rehearsal → Production. الرجوع يكون PITR أو migration تعويضية؛ لا تُحذف سجلات التاريخ.

