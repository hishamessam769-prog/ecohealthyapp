# سيناريوهات قبول الإنتاج

نفّذ السيناريوهات على Staging بحساب مستقل لكل دور. سجّل Request ID وError ID ونتيجة قاعدة البيانات.

1. اعتماد دفعة ينشئ Subscription واحدة؛ الإعادة بنفس المفتاح لا تكرر شيئًا.
2. Partial Payment لا يفعّل الطلب بلا Credit معتمد.
3. Sales Agent A يُمنع من UUID عميل Sales Agent B؛ Manager لا يرى خارج فريقه.
4. Kitchen يُمنع من payments/invoices/commissions؛ Rider يُمنع من Route غيره؛ Investor يُمنع من PII.
5. Pause يغير Schedule/Expected End طبقًا للPreview، وSkip يحترم سياسة Plan.
6. Delivered مرتين وOffline Sync مكرر يستهلك Entitlement مرة واحدة.
7. Rider Cash يبقى في العهدة حتى Finance Receipt/Reconciliation.
8. Partial fulfillment يعترف بالجزء المخصص فقط ويبقي الباقي Deferred.
9. Refund ينشئ Journal/Reversal/Clawback دون حذف Credit الأصلي.
10. Commission تبقى Pending حتى Rule؛ تحمل للشهر التالي؛ Manager أسفل Gate نتيجته صفر.
11. تغيير Gate/tiers ينطبق على الإصدار المستقبلي فقط، وتداخل Tiers مرفوض.
12. A-la-carte لا يدخل MRR/ARR؛ Renewal Rate يستخدم Cycles المستحقة فقط.
13. Close يرفض unallocated/unreconciled/unbalanced/material blockers.
14. Build وTypecheck وUnit/Migration/E2E كلها تنجح.

