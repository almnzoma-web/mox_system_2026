// api/og.js

export default async function handler(request) {
  try {
    const requestUrl = new URL(request.url);

    // ============================================================
    // نقرأ guardianMoxId فقط
    // ============================================================

    const guardianMoxId =
      requestUrl.searchParams.get('guardianMoxId')?.trim().toUpperCase() || '';

    // ============================================================
    // إذا لم توجد هوية MOX
    // ============================================================

    if (!guardianMoxId) {
      return new Response(
        `
        <!DOCTYPE html>
        <html lang="ar" dir="rtl">
        <head>
          <meta charset="UTF-8">
          <title>MOX Digital App</title>
          <meta
            name="description"
            content="المنظومة أونلاين - MOX Digital App"
          >
        </head>
        <body>
          <h1>MOX Digital App</h1>
        </body>
        </html>
        `,
        {
          status: 200,
          headers: {
            'Content-Type': 'text/html; charset=UTF-8',
            'Cache-Control': 'no-store',
          },
        },
      );
    }

    // ============================================================
    // رابط المتجر الحقيقي
    // ============================================================

    const storeUrl =
      `https://mox-2026.vercel.app/store/${encodeURIComponent(guardianMoxId)}`;

    // ============================================================
    // القيم الافتراضية
    // ============================================================

    let storeName = 'MOX Digital App';

    let storeDesc =
      'المنظومة أونلاين - الحل الرقمي لإدارة متجرك.';

    let storeImage =
      'https://mox-2026.vercel.app/default-logo.png';

    // ============================================================
    // Google Apps Script
    // ============================================================

    const scriptUrl =
      'https://script.google.com/macros/s/AKfycbwr2cnnxQ8cUA6A7tsFJvUZdzE9xL5nADKBx5P6gJh5Z13NBkq7PIyptu3vYGqkCPzE/exec';

    // ============================================================
    // جلب كل العملاء
    // ثم البحث عن guardianMoxId
    // ============================================================

    try {
      const cloudUrl =
        `${scriptUrl}?action=getAll`;

      const response = await fetch(cloudUrl, {
        headers: {
          'Accept': 'application/json',
        },
      });

      if (response.ok) {
        const data = await response.json();

        if (Array.isArray(data)) {
          for (const item of data) {
            if (!item || typeof item !== 'object') {
              continue;
            }

            const rowGuardianMoxId =
              String(item.guardianMoxId || '')
                .trim()
                .toUpperCase();

            // ======================================================
            // المطابقة تكون مع guardianMoxId فقط
            // ======================================================

            if (rowGuardianMoxId !== guardianMoxId) {
              continue;
            }

            // ======================================================
            // اسم المتجر
            // ======================================================

            storeName =
              String(
                item.storeName ||
                item.shopName ||
                item.businessName ||
                item.name ||
                'MOX Digital App',
              ).trim();

            // ======================================================
            // وصف المتجر
            // ======================================================

            storeDesc =
              String(
                item.storeDesc ||
                item.storeDescription ||
                item.description ||
                'متجر رقمي يعمل عبر منظومة موكس.',
              ).trim();

            // ======================================================
            // صورة المتجر
            // ======================================================

            storeImage =
              String(
                item.storeImage ||
                item.logoUrl ||
                item.logo ||
                'https://mox-2026.vercel.app/default-logo.png',
              ).trim();

            break;
          }
        }
      }
    } catch (error) {
      console.error('[MOX OG] Cloud error:', error);
    }

    // ============================================================
    // حماية HTML من بعض الأحرف الخاصة
    // ============================================================

    const escapeHtml = (value) =>
      String(value)
        .replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');

    const safeStoreName = escapeHtml(storeName);
    const safeStoreDesc = escapeHtml(storeDesc);
    const safeStoreImage = escapeHtml(storeImage);
    const safeStoreUrl = escapeHtml(storeUrl);

    // ============================================================
    // HTML الخاص بالـ Meta
    // ============================================================

    const html = `
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>

  <meta charset="UTF-8">

  <title>${safeStoreName} | MOX Digital App</title>

  <meta
    name="description"
    content="${safeStoreDesc}"
  >

  <!-- ==========================================================
       Open Graph
       ========================================================== -->

  <meta property="og:type" content="website">

  <meta
    property="og:url"
    content="${safeStoreUrl}"
  >

  <meta
    property="og:title"
    content="${safeStoreName}"
  >

  <meta
    property="og:description"
    content="${safeStoreDesc}"
  >

  <meta
    property="og:image"
    content="${safeStoreImage}"
  >

  <meta
    property="og:site_name"
    content="MOX Digital App - المنظومة أونلاين"
  >

  <meta
    property="og:locale"
    content="ar_AR"
  >

  <!-- ==========================================================
       Twitter / WhatsApp-style crawlers
       ========================================================== -->

  <meta
    name="twitter:card"
    content="summary_large_image"
  >

  <meta
    name="twitter:title"
    content="${safeStoreName}"
  >

  <meta
    name="twitter:description"
    content="${safeStoreDesc}"
  >

  <meta
    name="twitter:image"
    content="${safeStoreImage}"
  >

  <meta
    name="twitter:url"
    content="${safeStoreUrl}"
  >

</head>

<body>
  <h1>${safeStoreName}</h1>
  <p>${safeStoreDesc}</p>
</body>

</html>
`;

    return new Response(html, {
      status: 200,
      headers: {
        'Content-Type': 'text/html; charset=UTF-8',

        // لا نريد أن تحفظ Meta نسخة قديمة أثناء الاختبار
        'Cache-Control': 'no-store, no-cache, must-revalidate',
      },
    });
  } catch (error) {
    console.error('[MOX OG] Fatal error:', error);

    return new Response(
      '<html><head><title>MOX Digital App</title></head><body>MOX Digital App</body></html>',
      {
        status: 200,
        headers: {
          'Content-Type': 'text/html; charset=UTF-8',
        },
      },
    );
  }
}