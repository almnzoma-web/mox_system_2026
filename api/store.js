export default async function handler(request) {
  const start = Date.now();

  try {
    const url = new URL(
      request.url,
      `https://${request.headers.host}`
    );

    const method = request.method || "GET";

    // استخراج البارامترات سواء من الـ URL (GET) أو من الـ Body (POST)
    let queryParams = {};
    url.searchParams.forEach((val, key) => {
      queryParams[key] = val;
    });

    let bodyData = {};
    if (method === "POST") {
      try {
        const contentType = request.headers.get("content-type") || "";
        if (contentType.includes("application/json")) {
          bodyData = await request.json();
        } else {
          const textBody = await request.text();
          try { bodyData = JSON.parse(textBody); } catch (_) {}
        }
      } catch (_) {}
    }

    // دمج البارامترات لضمان شمولية البيانات
    const params = { ...queryParams, ...bodyData };

    const action = (params.action || "").trim().toLowerCase();
    const guardianMoxId = (params.guardianMoxId || "").trim().toUpperCase();

    // ============================================================
    // GOOGLE APPS SCRIPT
    // ============================================================

    const scriptUrl =
      "https://script.google.com/macros/s/AKfycbw3wYlv9U3x6U--mFKiv6usAasKEq0T8SQCSuOblQrDn1-X4MZ4iQ850J2YFjasUwtA/exec";

    let googleUrl = scriptUrl;
    let fetchOptions = {
      method: method,
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json"
      },
      redirect: "follow",
      cache: "no-store"
    };

    // ============================================================
    // تحديد مسار الطلب (GET أو POST) بناءً على منطقك القديم
    // ============================================================

    if (method === "POST") {
      // طلبات الحفظ والتعديل والتسجيل توجه بالكامل كـ POST مع إرسال البيانات في الـ body
      fetchOptions.body = JSON.stringify(params);
      
      // إذا أُرسل action صراحة نمرره في الرابط لضمان استقباله في doPost
      if (action) {
        googleUrl = `${scriptUrl}?action=${encodeURIComponent(action)}`;
      }

      console.log("[MOX VERCEL] MODE: POST ACTION ->", action || "save");
    } 
    else {
      // منطق الـ GET القديم الأصلي الخاص بك
      if (guardianMoxId && !action) {
        googleUrl = `${scriptUrl}?action=getUserByGuardianMoxId&guardianMoxId=${encodeURIComponent(guardianMoxId)}`;
        console.log("[MOX VERCEL] MODE: getUserByGuardianMoxId", guardianMoxId);
      } 
      else if (action === "getall" || action === "getalldata") {
        googleUrl = `${scriptUrl}?action=getAll`;
        console.log("[MOX VERCEL] MODE: getAll");
      } 
      else if (action) {
        // أي action آخر قادم عبر الـ GET
        const searchParams = new URLSearchParams();
        for (const [k, v] of Object.entries(params)) {
          if (v !== undefined && v !== null) searchParams.append(k, v);
        }
        googleUrl = `${scriptUrl}?${searchParams.toString()}`;
        console.log("[MOX VERCEL] MODE: CUSTOM GET ACTION ->", action);
      } 
      else {
        return json(
          {
            success: false,
            status: "error",
            message: "guardianMoxId or action is required"
          },
          400
        );
      }
    }

    console.log("[MOX VERCEL] GOOGLE URL:", googleUrl);

    // ============================================================
    // GOOGLE REQUEST TIMEOUT
    // ============================================================

    const controller = new AbortController();
    const timeout = setTimeout(() => {
      controller.abort();
    }, 25000); // 25 ثانية لضمان راحة قوقل سكريبت في معالجة التواريخ

    fetchOptions.signal = controller.signal;

    let response;
    try {
      response = await fetch(googleUrl, fetchOptions);
    } finally {
      clearTimeout(timeout);
    }

    const elapsed = Date.now() - start;
    console.log("[MOX VERCEL] GOOGLE RESPONSE:", response.status, elapsed + "ms");

    const text = await response.text();
    console.log("[MOX VERCEL] RESPONSE LENGTH:", text.length);

    if (!response.ok) {
      return json(
        {
          success: false,
          status: "google_error",
          googleStatus: response.status,
          elapsedMs: elapsed,
          message: "Google Apps Script returned an HTTP error",
          raw: text.substring(0, 1000)
        },
        502
      );
    }

    if (!text.trim()) {
      return json(
        {
          success: false,
          status: "empty_response",
          elapsedMs: elapsed,
          message: "Google Apps Script returned an empty response"
        },
        502
      );
    }

    let data;
    try {
      data = JSON.parse(text);
    } catch (error) {
      return json(
        {
          success: false,
          status: "invalid_json",
          elapsedMs: elapsed,
          message: "Google Apps Script returned invalid JSON",
          raw: text.substring(0, 1000)
        },
        502
      );
    }

    // التعامل المرن مع استجابات قوقل (سواء كانت success: true أو ok: true)
    const isSuccess = data.success === true || data.ok === true || data.status === "success";

    if (data && isSuccess === false) {
      return json(
        {
          success: false,
          status: "google_application_error",
          elapsedMs: elapsed,
          message: data.message || "Google Apps Script rejected the request",
          google: data
        },
        404
      );
    }

    // إذا كان طلب بحث عن متجر (GET)
    if (guardianMoxId && method === "GET") {
      if (data.user === null || (data.success && !data.user && !data.moxId)) {
        return json(
          {
            success: false,
            status: "store_not_found",
            elapsedMs: elapsed,
            message: "لم يتم العثور على المتجر",
            guardianMoxId: guardianMoxId
          },
          404
        );
      }
    }

    // إعادة النتيجة مباشرة كما هي للعميل لضمان التوافق التام مع main
    return json(
      {
        ...data,
        success: true,
        vercel: {
          success: true,
          elapsedMs: elapsed
        }
      },
      200
    );

  } catch (error) {
    const elapsed = Date.now() - start;
    console.error("[MOX VERCEL ERROR]", error);

    if (error && error.name === "AbortError") {
      return json(
        {
          success: false,
          status: "timeout",
          elapsedMs: elapsed,
          message: "Google Apps Script did not respond within 25 seconds"
        },
        504
      );
    }

    return json(
      {
        success: false,
        status: "vercel_error",
        elapsedMs: elapsed,
        message: error && error.message ? error.message : "Vercel Store API error"
      },
      500
    );
  }
}

// ================================================================
// JSON RESPONSE
// ================================================================

function json(data, status = 200) {
  return new Response(
    JSON.stringify(data),
    {
      status,
      headers: {
        "Content-Type": "application/json; charset=UTF-8",
        "Access-Control-Allow-Origin": "*",
        "Cache-Control": "no-store, no-cache, must-revalidate"
      }
    }
  );
}