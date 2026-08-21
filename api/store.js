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

    const scriptUrl =
      "https://script.google.com/macros/s/AKfycbwMbCQ9eFNjHDQbt6MDltnhKyqWQXiQL8_6eBE8Omcd5dhfVEglkHreeIXCx-5Yq3pp/exec";

    // ============================================================
    // تحديد الطلب
    // ============================================================

    let googleUrl;

    // ------------------------------------------------------------
    // GET USER BY GUARDIAN MOX ID
    // ------------------------------------------------------------

    if (guardianMoxId) {
      googleUrl =
        `${scriptUrl}?action=getByGuardianMoxId&guardianMoxId=${encodeURIComponent(
          guardianMoxId
        )}`;

      console.log(
        "[MOX VERCEL] MODE: getByGuardianMoxId"
      );

      console.log(
        "[MOX VERCEL] ID:",
        guardianMoxId
      );
    }

    // ------------------------------------------------------------
    // GET ALL USERS
    // ------------------------------------------------------------

    else if (action === "getall") {
      googleUrl =
        `${scriptUrl}?action=getAll`;

      console.log(
        "[MOX VERCEL] MODE: getAll"
      );
    }

    // ------------------------------------------------------------
    // INVALID REQUEST
    // ------------------------------------------------------------

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
      "[MOX VERCEL] START"
    );

    console.log(
      "[MOX VERCEL] GOOGLE URL:",
      googleUrl
    );

    // ============================================================
    // INTERNAL TIMEOUT
    // ============================================================

    const controller = new AbortController();

    const timeout = setTimeout(() => {
      controller.abort();
    }, 20000);

    let response;

    try {
      response = await fetch(googleUrl, {
        method: "GET",

        headers: {
          Accept: "application/json"
        },

        signal: controller.signal,

        redirect: "follow",

        cache: "no-store"
      });
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

          status: "google_error",

          googleStatus:
            response.status,

          elapsedMs:
            Date.now() - start,

          message:
            "Google Apps Script returned an error",

          raw:
            text.substring(0, 500)
        },
        502
      );
    }

    // ============================================================
    // JSON CHECK
    // ============================================================

    let data;

    try {
      data =
        JSON.parse(text);
    } catch (error) {
      return json(
        {
          success: false,

          status: "invalid_json",

          elapsedMs:
            Date.now() - start,

          message:
            "Google Apps Script returned invalid JSON",

          raw:
            text.substring(0, 500)
        },
        502
      );
    }

    // ============================================================
    // SUCCESS
    // ============================================================

    return json(
      {
        ...(
          Array.isArray(data)
            ? {
                success: true,
                status: "success",
                users: data
              }
            : data
        ),

        vercel: {
          success: true,

          elapsedMs:
            Date.now() - start
        }
      },
      200
    );

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
      error.name ===
      "AbortError"
    ) {
      return json(
        {
          success: false,

          status: "timeout",

          elapsedMs:
            elapsed,

          message:
            "Vercel could not receive a response from Google within 8 seconds"
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

        status: "vercel_error",

        elapsedMs:
          elapsed,

        message:
          error.message ||
          "Vercel Store API error"
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