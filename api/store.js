export default async function handler(request) {
  try {
    const url = new URL(request.url, `https://${request.headers.host}`);
    
    // 1. محاولة التقاط الـ guardianMoxId من الـ Query Parameters
    let guardianMoxId = (url.searchParams.get('guardianMoxId') || '').trim();

    // 2. إذا لم يوجد، نقوم باستخراجه من الـ Path (مثلاً /api/store/MOX249-00010001)
    if (!guardianMoxId) {
      const segments = url.pathname.split('/').filter(Boolean);
      // إذا كان المسار يحتوي على قيمة بعد كلمة store
      const storeIndex = segments.indexOf('store');
      if (storeIndex !== -1 && segments.length > storeIndex + 1) {
        guardianMoxId = segments[storeIndex + 1].trim();
      }
    }

    guardianMoxId = guardianMoxId.toUpperCase();

    if (!guardianMoxId) {
      return new Response(
        JSON.stringify({ success: false, message: 'guardianMoxId is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json; charset=UTF-8', 'Access-Control-Allow-Origin': '*' } }
      );
    }

    const scriptUrl = 'https://script.google.com/macros/s/AKfycbwr2cnnxQ8cUA6A7tsFJvUZdzE9xL5nADKBx5P6gJh5Z13NBkq7PIyptu3vYGqkCPzE/exec';
    const googleUrl = `${scriptUrl}?action=getByGuardianMoxId&guardianMoxId=${encodeURIComponent(guardianMoxId)}`;

    const response = await fetch(googleUrl);
    const text = await response.text();

    let data;
    try {
      data = JSON.parse(text);
    } catch (e) {
      return new Response(
        JSON.stringify({ success: false, message: 'Google Apps Script returned invalid JSON', raw: text }),
        { status: 502, headers: { 'Content-Type': 'application/json; charset=UTF-8', 'Access-Control-Allow-Origin': '*' } }
      );
    }

    return new Response(
      JSON.stringify(data),
      { status: 200, headers: { 'Content-Type': 'application/json; charset=UTF-8', 'Cache-Control': 'no-store', 'Access-Control-Allow-Origin': '*' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, message: 'Store API error', error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json; charset=UTF-8', 'Access-Control-Allow-Origin': '*' } }
    );
  }
}