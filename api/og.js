// api/og.js

export const config = {
  runtime: 'edge',
};

export default async function handler(request) {
  const { searchParams } = new URL(request.url);
  const guardianMoxId = searchParams.get('mox');

  // [هام جداً]: إذا لم يتم تمرير MoxID، يتم توجيهه للرابط الافتراضي
  if (!guardianMoxId) {
    return new Response('الصفحة الرئيسية - MOX Digital', { status: 200 });
  }

  // 1. رابط جلب بيانات المتجر الخاص بك (استبدله بالرابط الفعلي لجلب بيانات العميل إذا وجد)
  const storeDataUrl = `https://api.your-backend.com/get-store-by-mox/${guardianMoxId}`;
  
  let storeName = 'MOX Digital';
  let storeDesc = 'المنظومة أونلاين - الحل الأمثل لمتاجرك الرقمية.';
  let storeImage = 'https://mox-2026.vercel.app/default-logo.png';
  
  // الاعتماد المباشر على الرابط الخاص بالمتجر والـ activeMoxForUrl
  let storeUrl = `https://mox-2026.vercel.app/?mox=${guardianMoxId}`;

  try {
    const response = await fetch(storeDataUrl);
    const data = await response.json();
    
    if (data && data.success) {
      storeName = data.storeName;
      storeDesc = data.storeDesc;
      storeImage = data.storeImage;
    }
  } catch (e) {
    console.error('Error fetching store data for OG:', e);
  }

  // 2. توليد استجابة HTML تحتوي على Meta Tags وربطها بالرابط الصحيح
  const html = `
    <!DOCTYPE html>
    <html lang="ar" dir="rtl">
      <head>
        <meta charset="UTF-8">
        <title>${storeName} | متجر MOX الرقمي</title>
        <meta name="description" content="${storeDesc}">

        <!-- Open Graph / Facebook -->
        <meta property="og:type" content="website">
        <meta property="og:url" content="${storeUrl}">
        <meta property="og:title" content="${storeName}">
        <meta property="og:description" content="${storeDesc}">
        <meta property="og:image" content="${storeImage}">
        <meta property="og:site_name" content="MOX Digital - المنظومة أونلاين">
        <meta property="og:locale" content="ar_AR">

        <!-- Twitter -->
        <meta name="twitter:card" content="summary_large_image">
        <meta name="twitter:url" content="${storeUrl}">
        <meta name="twitter:title" content="${storeName}">
        <meta name="twitter:description" content="${storeDesc}">
        <meta name="twitter:image" content="${storeImage}">

        <!-- إعادة توجيه العميل إلى رابط المتجر المباشر بعد قراءة الـ Meta Tags -->
        <meta http-equiv="refresh" content="0;url=${storeUrl}">
      </head>
      <body>
        <h1>جاري تحميل متجر ${storeName}...</h1>
      </body>
    </html>
  `;

  return new Response(html, {
    status: 200,
    headers: {
      'Content-Type': 'text/html',
      'Cache-Control': 's-maxage=86400, stale-while-revalidate',
    },
  });
}