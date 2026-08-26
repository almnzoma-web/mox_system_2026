export default async function handler(req, res) {
  // تفعيل السماح للطلبات (CORS)
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // رابط Google Apps Script الخاص بك
  const googleScriptUrl = 'https://script.google.com/macros/s/AKfycbw3wYlv9U3x6U--mFKiv6usAasKEq0T8SQCSuOblQrDn1-X4MZ4iQ850J2YFjasUwtA/exec';

  try {
    const action = req.query.action || (req.method === 'POST' ? req.body.action : 'getByGuardianMoxId');
    
    // بناء استعلام البارامترات لتمريرها بقوة لجوجل سكريبت
    const params = new URLSearchParams();
    params.append('action', action);

    // جمع كافة البارامترات الواردة سواء من الـ Query أو الـ Body
    const sourceData = req.method === 'POST' ? { ...req.query, ...req.body } : req.query;

    for (const [key, value] of Object.entries(sourceData)) {
      if (value !== undefined && value !== null) {
        params.append(key, value);
      }
    }

    const targetUrl = `${googleScriptUrl}?${params.toString()}`;

    // تنفيذ الطلب إلى Google Apps Script
    const response = await fetch(targetUrl, {
      method: req.method === 'POST' ? 'POST' : 'GET',
      headers: {
        'Content-Type': 'application/json',
      },
      ...(req.method === 'POST' ? { body: JSON.stringify(req.body) } : {}),
    });

    const responseText = await response.text();

    let data;
    try {
      data = JSON.parse(responseText);
    } catch (e) {
      // إذا كان الرد ليس JSON صافياً (مثل صفحة خطأ HTML من جوجل)
      return res.status(500).json({
        success: false,
        message: 'Invalid response from cloud database',
        raw: responseText.substring(0, 200),
      });
    }

    // إرجاع النتيجة مباشرة للتطبيق
    return res.status(200).json(data);

  } catch (error) {
    console.error('Vercel Store API Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error processing store request',
      error: error.message,
    });
  }
}