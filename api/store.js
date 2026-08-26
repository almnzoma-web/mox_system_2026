export default async function handler(request) {
  const start = Date.now();

  try {
    const url = new URL(
      request.url,
      `https://${request.headers.host}`
    );

    const method = request.method.toUpperCase();
    const action = (url.searchParams.get("action") || "").trim().toLowerCase();
    const guardianMoxId = (url.searchParams.get("guardianMoxId") || "").trim().toUpperCase();

    const scriptUrl =
      "https://script.google.com/macros/s/AKfycbw3wYlv9U3x6U--mFKiv6usAasKEq0T8SQCSuOblQrDn1-X4MZ4iQ850J2YFjasUwtA/exec";

    let googleUrl = scriptUrl;
    let fetchOptions = {
      method: method,
      headers: {
        Accept: "application/json",
      },
      redirect: "follow",
      cache: "no-store",
    };

    // ============================================================
    // معالجة طلبات الحفظ أو التحديث (POST)
    // ============================================================
    if (method === "POST") {
      let bodyData = {};
      try {
        bodyData = await request.json();
      } catch (_) {
        // لو البيانات جابت بدن فرم أو بارامترات عادية
      }

      // دمج الـ query parameters مع الـ body لضمان وصول كل الحقول (مثل تاريخ النشر والتفعيل والجلسات)
      const params = new URLSearchParams();
      url.searchParams.forEach((val, key) => params.append(key, val));
      
      for (const [key, val] of Object.entries(bodyData)) {
        params.set(key, val);
      }

      // إذا لم يكن action موجوداً، نحدده افتراضياً كحفظ
      if (!params.has("action")) {
        params.set("action", "save");
      }

      googleUrl = `${scriptUrl}?${params.toString()}`;
      console.log("[MOX VERCEL] MODE: POST/SAVE", googleUrl);

    } 
    // ============================================================
    // معالجة طلبات الجلب (GET)
    // ============================================================
    else if (method === "GET") {
      if (guardianMoxId) {
        googleUrl = `${scriptUrl}?action=getUserByGuardianMoxId&guardianMoxId=${encodeURIComponent(guardianMoxId)}`;
        console.log("[MOX VERCEL] MODE: getUserByGuardianMoxId", guardianMoxId);
      } else if (action === "getall") {
        googleUrl = `${scriptUrl}?action=getAll`;
        console.log("[MOX VERCEL] MODE: getAll");
      } else {
        // دعم تمرير أي action آخر قادم في الـ GET
        const params = url.searchParams.toString();
        googleUrl = `${scriptUrl}?${params}`;
        console.log("[MOX VERCEL] MODE: CUSTOM GET", googleUrl);
      }
      
      fetchOptions.method = "GET";
    } else {
      return json({ success: false, status: "error", message: "Method not allowed" }, 405);
    }

    // ============================================================
    // إرسال الطلب إلى Google Apps Script
    // ============================================================
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 20000);
    fetchOptions.signal = controller.signal;

    let response;
    try {
      response = await fetch(googleUrl, fetchOptions);
    } finally {
      clearTimeout(timeout);
    }

    const elapsed = Date.now() - start;
    const text = await response.text();

    console.log("[MOX VERCEL] GOOGLE RESPONSE:", response.status, elapsed + "ms");
    console.log("[MOX VERCEL] RESPONSE:", text.substring(0, 1000));

    if (!response.ok) {
      return json({
        success: false,
        status: "google_error",
        googleStatus: response.status,
        elapsedMs: elapsed,
        message: "Google Apps Script returned an HTTP error",
        raw: text.substring(0, 1000)
      }, 502);
    }

    if (!text.trim()) {
      return json({ success: false, status: "empty_response", elapsedMs: elapsed, message: "Google Apps Script returned an empty response" }, 502);
    }

    let data;
    try {
      data = JSON.parse(text);
    } catch (_) {
      return json({ success: false, status: "invalid_json", elapsedMs: elapsed, message: "Google Apps Script returned invalid JSON", raw: text.substring(0, 1000) }, 502);
    }

    if (data && data.ok === false) {
      return json({
        success: false,
        status: "google_application_error",
        elapsedMs: elapsed,
        message: data.message || "Google Apps Script rejected the request",
        google: data
      }, 404);
    }

    // لو الطلب كان جلب مستخدم ولم يوجد
    if (method === "GET" && guardianMoxId && data && data.ok === true && data.user === null) {
      return json({
        success: false,
        status: "store_not_found",
        elapsedMs: elapsed,
        message: "لم يتم العثور على المتجر",
        guardianMoxId: guardianMoxId
      }, 404);
    }

    // استجابة ناجحة عامة
    return json({
      success: true,
      status: "success",
      data: data.user || data,
      vercel: { success: true, elapsedMs: elapsed }
    }, 200);

  } catch (error) {
    const elapsed = Date.now() - start;
    console.error("[MOX VERCEL ERROR]", error);

    if (error && error.name === "AbortError") {
      return json({ success: false, status: "timeout", elapsedMs: elapsed, message: "Google Apps Script did not respond within 20 seconds" }, 504);
    }

    return json({
      success: false,
      status: "vercel_error",
      elapsedMs: elapsed,
      message: error && error.message ? error.message : "Vercel Store API error"
    }, 500);
  }
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=UTF-8",
      "Access-Control-Allow-Origin": "*",
      "Cache-Control": "no-store, no-cache, must-revalidate"
    }
  });
}