export default async function handler(request) {
  const start = Date.now();

  try {
    const url = new URL(
      request.url,
      `https://${request.headers.host}`
    );

    const method = request.method || "GET";

    // 1. استخراج guardianMoxId من المسار أو الـ Query
    let guardianMoxId = (
      url.searchParams.get("guardianMoxId") || ""
    ).trim().toUpperCase();

    if (!guardianMoxId) {
      const pathSegments = url.pathname.split("/").filter(Boolean);
      const storeIndex = pathSegments.indexOf("store");
      
      if (storeIndex !== -1 && pathSegments[storeIndex + 1]) {
        guardianMoxId = pathSegments[storeIndex + 1].trim().toUpperCase();
      } else if (pathSegments.length > 0) {
        const lastSegment = pathSegments[pathSegments.length - 1];
        if (lastSegment && lastSegment.toUpperCase().startsWith("MOX")) {
          guardianMoxId = lastSegment.trim().toUpperCase();
        }
      }
    }

    const action = (
      url.searchParams.get("action") || ""
    ).trim().toLowerCase();

    // ============================================================
    // GOOGLE APPS SCRIPT
    // ============================================================
    const scriptUrl =
      "https://script.google.com/macros/s/AKfycbxvpSQ4lKhKkakGQ8jUGSUppC2Q5AIF5dzdWG-mbb99daQx_neMzlhzmPbCBZEYnUfS/exec";

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

    // 2. معالجة طلبات التعديل والحفظ (POST) القادمة من _startSubscription
    if (method === "POST") {
      let bodyData = {};
      try {
        const contentType = request.headers.get("content-type") || "";
        if (contentType.includes("application/json")) {
          bodyData = await request.json();
        } else {
          const textBody = await request.text();
          try { bodyData = JSON.parse(textBody); } catch (_) {}
        }
      } catch (_) {}

      // دمج بيانات الـ URL مع الـ Body لضمان وصول guardianMoxId وتواريخ التفعيل
      const mergedParams = { 
        guardianMoxId: guardianMoxId || bodyData.guardianMoxId, 
        ...bodyData 
      };

      fetchOptions.body = JSON.stringify(mergedParams);
      
      // إذا كان هناك action محدد، نمرره في الرابط، وإلا نفترض action الحفظ التلقائي
      const postAction = mergedParams.action || "save";
      googleUrl = `${scriptUrl}?action=${encodeURIComponent(postAction)}`;

      console.log("[MOX VERCEL] POST MODE -> Action:", postAction, "ID:", mergedParams.guardianMoxId);
    } 
    // 3. معالجة طلبات القراءة (GET)
    else {
      if (guardianMoxId && guardianMoxId.startsWith("MOX")) {
        googleUrl = `${scriptUrl}?action=getUserByGuardianMoxId&guardianMoxId=${encodeURIComponent(guardianMoxId)}`;
        console.log("[MOX VERCEL] GET MODE: getUserByGuardianMoxId ->", guardianMoxId);
      } 
      else if (action === "getall") {
        googleUrl = `${scriptUrl}?action=getAll`;
        console.log("[MOX VERCEL] GET MODE: getAll");
      } 
      else {
        return json(
          {
            success: false,
            status: "error",
            message: "Valid guardianMoxId or action is required",
            pathReceived: url.pathname
          },
          400
        );
      }
    }

    // ============================================================
    // تنفيذ الاتصال مع تحكم بالزمن (Timeout)
    // ============================================================
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 25000);
    fetchOptions.signal = controller.signal;

    let response;
    try {
      response = await fetch(googleUrl, fetchOptions);
    } finally {
      clearTimeout(timeout);
    }

    const elapsed = Date.now() - start;
    const text = await response.text();

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

    // دعم استجابات قوقل سواء كانت success أو ok
    const isSuccess = data.success === true || data.ok === true || data.status === "success";

    if (data && isSuccess === false && method === "GET") {
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

    const user = data.user || data.data || (isSuccess ? data.user : null);

    // لو كان طلب GET ولم نجد مستخدم
    if (guardianMoxId && method === "GET" && !user) {
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

    // إرجاع النتيجة للعميل متوافقة تماماً مع ما ينتظره main و _startSubscription
    return json(
      {
        ...data,
        success: true,
        status: "success",
        guardianMoxId: guardianMoxId,
        user: user || data,
        data: user || data,
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