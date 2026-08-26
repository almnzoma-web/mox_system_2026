export default async function handler(request) {
  const start = Date.now();

  try {
    const url = new URL(
      request.url,
      `https://${request.headers.host}`
    );

    // 1. محاولة استخراج guardianMoxId من الـ Query التقليدي
    let guardianMoxId = (
      url.searchParams.get("guardianMoxId") || ""
    ).trim().toUpperCase();

    // 2. إذا لم يوجد في الـ Query، نستخرجه من مسار الـ URL (Path Segments) مثل /store/MOX249-...
    if (!guardianMoxId) {
      const pathSegments = url.pathname.split("/").filter(Boolean);
      // إذا كان المسار يحتوي على جزء بعد store (مثل /store/MOX249-...)
      const storeIndex = pathSegments.indexOf("store");
      if (storeIndex !== -1 && pathSegments[storeIndex + 1]) {
        guardianMoxId = pathSegments[storeIndex + 1].trim().toUpperCase();
      } else if (pathSegments.length > 0 && pathSegments[0] !== "api") {
        // أو إذا كان الرابط موجهاً مباشرة للمعرف
        guardianMoxId = pathSegments[pathSegments.length - 1].trim().toUpperCase();
      }
    }

    const action = (
      url.searchParams.get("action") || ""
    ).trim().toLowerCase();

    // ============================================================
    // GOOGLE APPS SCRIPT
    // ============================================================

    const scriptUrl =
      "https://script.google.com/macros/s/AKfycbw3wYlv9U3x6U--mFKiv6usAasKEq0T8SQCSuOblQrDn1-X4MZ4iQ850J2YFjasUwtA/exec";

    let googleUrl = "";

    if (guardianMoxId && guardianMoxId.startsWith("MOX")) {
      googleUrl =
        `${scriptUrl}?action=getUserByGuardianMoxId&guardianMoxId=${encodeURIComponent(
          guardianMoxId
        )}`;

      console.log(
        "[MOX VERCEL] MODE: getUserByGuardianMoxId from Path/Query"
      );
      console.log(
        "[MOX VERCEL] guardianMoxId:",
        guardianMoxId
      );
    }
    else if (action === "getall") {
      googleUrl =
        `${scriptUrl}?action=getAll`;

      console.log(
        "[MOX VERCEL] MODE: getAll"
      );
    }
    else {
      return json(
        {
          success: false,
          status: "error",
          message: "Valid guardianMoxId or action=getAll is required",
          pathReceived: url.pathname
        },
        400
      );
    }

    console.log(
      "[MOX VERCEL] GOOGLE URL:",
      googleUrl
    );

    // ============================================================
    // GOOGLE REQUEST TIMEOUT
    // ============================================================

    const controller = new AbortController();
    const timeout = setTimeout(() => {
      controller.abort();
    }, 20000);

    let response;
    try {
      response = await fetch(
        googleUrl,
        {
          method: "GET",
          headers: {
            Accept: "application/json"
          },
          signal: controller.signal,
          redirect: "follow",
          cache: "no-store"
        }
      );
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

    if (data && data.ok === false) {
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

    if (
      data &&
      data.ok === true &&
      data.user === null
    ) {
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
          status: "invalid_user_response",
          elapsedMs: elapsed,
          message: "Google returned a response without a valid user object",
          google: data
        },
        502
      );
    }

    const returnedGuardian =
      String(
        user.guardianMoxId ||
        user.GuardianMoxId ||
        user.guardian_mox_id ||
        ""
      )
        .trim()
        .toUpperCase();

    return json(
      {
        success: true,
        status: "success",
        guardianMoxId: returnedGuardian || guardianMoxId,
        user: user,
        data: user,
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
          message: "Google Apps Script did not respond within 20 seconds"
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