// ذاكرة مؤقتة بسيطة داخل Vercel لمنع الذهاب لجوجل في كل طلب وتفادي الـ Timeout
const memoryCache = new Map();
const CACHE_TTL = 5 * 60 * 1000; // 5 دقائق كاش

export default async function handler(request) {
  const start = Date.now();

  try {
    const url = new URL(
      request.url,
      `https://${request.headers.host}`
    );

    const action = (
      url.searchParams.get("action") || ""
    )
      .trim()
      .toLowerCase();

    const guardianMoxId = (
      url.searchParams.get("guardianMoxId") || ""
    )
      .trim()
      .toUpperCase();

    // ============================================================
    // التحقق من الكاش السريع لتفادي ضغط جوجل والـ Timeout
    // ============================================================
    const cacheKey = guardianMoxId || action || "getall";
    if (memoryCache.has(cacheKey)) {
      const cached = memoryCache.get(cacheKey);
      if (Date.now() - cached.time < CACHE_TTL) {
        console.log("[MOX VERCEL] Serving from Memory Cache:", cacheKey);
        return json(cached.data, 200);
      } else {
        memoryCache.delete(cacheKey);
      }
    }

    // ============================================================
    // GOOGLE APPS SCRIPT (الرابط الجديد)
    // ============================================================

    const scriptUrl =
      "https://script.google.com/macros/s/AKfycbyZopgVkCqIEQyJHVsjs1AT07MGG6swOFGgdOkwgYwvpA-UVySfUlyA_gOHr_-XtWsj/exec";

    // ============================================================
    // تحديد طلب المتجر
    // ============================================================

    let googleUrl = "";

    // ============================================================
    // GET USER BY GUARDIAN MOX ID
    // ============================================================

    if (guardianMoxId) {
      googleUrl =
        `${scriptUrl}?action=getUserByGuardianMoxId&guardianMoxId=${encodeURIComponent(
          guardianMoxId
        )}`;

      console.log(
        "[MOX VERCEL] MODE: getUserByGuardianMoxId"
      );

      console.log(
        "[MOX VERCEL] guardianMoxId:",
        guardianMoxId
      );
    }

    // ============================================================
    // GET ALL
    // ============================================================

    else if (action === "getall") {
      googleUrl =
        `${scriptUrl}?action=getAll`;

      console.log(
        "[MOX VERCEL] MODE: getAll"
      );
    }

    // ============================================================
    // INVALID REQUEST
    // ============================================================

    else {
      return json(
        {
          success: false,
          status: "error",
          message:
            "guardianMoxId or action=getAll is required"
        },
        400
      );
    }

    console.log(
      "[MOX VERCEL] GOOGLE URL:",
      googleUrl
    );

    // ============================================================
    // GOOGLE REQUEST TIMEOUT (تم رفع المهلة إلى 25 ثانية)
    // ============================================================

    const controller =
      new AbortController();

    const timeout =
      setTimeout(() => {
        controller.abort();
      }, 25000);

    let response;

    try {
      response =
        await fetch(
          googleUrl,
          {
            method: "GET",

            headers: {
              Accept:
                "application/json"
            },

            signal:
              controller.signal,

            redirect:
              "follow",

            cache:
              "no-store"
          }
        );
    } finally {
      clearTimeout(timeout);
    }

    const elapsed =
      Date.now() - start;

    console.log(
      "[MOX VERCEL] GOOGLE RESPONSE:",
      response.status,
      elapsed + "ms"
    );

    // ============================================================
    // READ RESPONSE
    // ============================================================

    const text =
      await response.text();

    console.log(
      "[MOX VERCEL] RESPONSE LENGTH:",
      text.length
    );

    // ============================================================
    // GOOGLE HTTP ERROR
    // ============================================================

    if (!response.ok) {
      return json(
        {
          success: false,

          status:
            "google_error",

          googleStatus:
            response.status,

          elapsedMs:
            Date.now() - start,

          message:
            "Google Apps Script returned an HTTP error",

          raw:
            text.substring(0, 1000)
        },
        502
      );
    }

    // ============================================================
    // EMPTY RESPONSE
    // ============================================================

    if (!text.trim()) {
      return json(
        {
          success: false,

          status:
            "empty_response",

          elapsedMs:
            Date.now() - start,

          message:
            "Google Apps Script returned an empty response"
        },
        502
      );
    }

    // ============================================================
    // JSON
    // ============================================================

    let data;

    try {
      data =
        JSON.parse(text);
    } catch (error) {
      return json(
        {
          success: false,

          status:
            "invalid_json",

          elapsedMs:
            Date.now() - start,

          message:
            "Google Apps Script returned invalid JSON",

          raw:
            text.substring(0, 1000)
        },
        502
      );
    }

    // ============================================================
    // GOOGLE SAID FAILURE
    // ============================================================

    if (
      data &&
      data.ok === false
    ) {
      return json(
        {
          success: false,

          status:
            "google_application_error",

          elapsedMs:
            Date.now() - start,

          message:
            data.message ||
            "Google Apps Script rejected the request",

          google:
            data
        },
        404
      );
    }

    // ============================================================
    // GOOGLE RETURNED NO USER
    // ============================================================

    if (
      data &&
      data.ok === true &&
      data.user === null
    ) {
      return json(
        {
          success: false,

          status:
            "store_not_found",

          elapsedMs:
            Date.now() - start,

          message:
            "لم يتم العثور على المتجر",

          guardianMoxId:
            guardianMoxId
        },
        404
      );
    }

    // ============================================================
    // استخراج المستخدم
    // ============================================================

    const user =
      data &&
      typeof data.user === "object" &&
      data.user !== null
        ? data.user
        : null;

    if (!user) {
      return json(
        {
          success: false,

          status:
            "invalid_user_response",

          elapsedMs:
            Date.now() - start,

          message:
            "Google returned a response without a valid user object",

          google:
            data
        },
        502
      );
    }

    // ============================================================
    // التحقق الأمني من guardianMoxId
    // ============================================================

    const returnedGuardian =
      String(
        user.guardianMoxId ||
        user.GuardianMoxId ||
        user.guardian_mox_id ||
        ""
      )
        .trim()
        .toUpperCase();

    if (
      guardianMoxId &&
      returnedGuardian !== guardianMoxId
    ) {
      return json(
        {
          success: false,

          status:
            "guardian_mismatch",

          elapsedMs:
            Date.now() - start,

          message:
            "guardianMoxId returned by Google does not match requested ID",

          requested:
            guardianMoxId,

          returned:
            returnedGuardian
        },
        403
      );
    }

    // ============================================================
    // النجاح تجهيز النتيجة للإرجاع وللحفظ في الكاش
    // ============================================================

    const responsePayload = {
      success: true,
      status: "success",
      guardianMoxId: returnedGuardian,
      user: user,
      data: user,
      vercel: {
        success: true,
        elapsedMs: Date.now() - start
      }
    };

    // حفظ النتيجة في الكاش لتكون الطلبات القادمة فورية تماماً
    memoryCache.set(cacheKey, {
      time: Date.now(),
      data: responsePayload
    });

    return json(responsePayload, 200);

  } catch (error) {
    const elapsed =
      Date.now() - start;

    console.error(
      "[MOX VERCEL ERROR]",
      error
    );

    // ============================================================
    // TIMEOUT
    // ============================================================

    if (
      error &&
      error.name ===
        "AbortError"
    ) {
      return json(
        {
          success: false,

          status:
            "timeout",

          elapsedMs:
            elapsed,

          message:
            "Google Apps Script did not respond within 25 seconds"
        },
        504
      );
    }

    // ============================================================
    // OTHER ERROR
    // ============================================================

    return json(
      {
        success: false,

        status:
          "vercel_error",

        elapsedMs:
          elapsed,

        message:
          error &&
          error.message
            ? error.message
            : "Vercel Store API error"
      },
      500
    );
  }
}


// ================================================================
// JSON RESPONSE
// ================================================================

function json(
  data,
  status = 200
) {
  return new Response(
    JSON.stringify(data),
    {
      status,

      headers: {
        "Content-Type":
          "application/json; charset=UTF-8",

        "Access-Control-Allow-Origin":
          "*",

        "Cache-Control":
          "no-store, no-cache, must-revalidate"
      }
    }
  );
}