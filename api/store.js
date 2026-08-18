// ============================================================
// MOX DIGITAL
// PUBLIC STORE API
//
// Vercel
//    ↓
// Google Apps Script
//    ↓
// Google Sheets
//
// IMPORTANT:
// Google Apps Script may return HTTP redirects.
// We therefore handle redirects manually.
// ============================================================


// ============================================================
// GOOGLE APPS SCRIPT
// ============================================================

const GOOGLE_SCRIPT_URL =
  "https://script.google.com/macros/s/AKfycbys7rhJQx5mY4lSpyAvDBZOHhexQO-vW7Y4pfVurAVJIZvb8gXI8_RXcvGPep8iU6Q/exec";


// ============================================================
// TIMEOUT
// ============================================================

const REQUEST_TIMEOUT_MS = 7000;


// ============================================================
// MAX REDIRECTS
// ============================================================

const MAX_REDIRECTS = 5;


// ============================================================
// CORS HEADERS
// ============================================================

const CORS_HEADERS = {

  "Access-Control-Allow-Origin": "*",

  "Access-Control-Allow-Methods":
    "GET, OPTIONS",

  "Access-Control-Allow-Headers":
    "Content-Type",

};


// ============================================================
// JSON RESPONSE
// ============================================================

function jsonResponse(
  data,
  status = 200
) {

  return new Response(
    JSON.stringify(data),

    {
      status,

      headers: {

        ...CORS_HEADERS,

        "Content-Type":
          "application/json; charset=UTF-8",

        "Cache-Control":
          "no-store, no-cache, must-revalidate",

        "Pragma":
          "no-cache",

      },

    }
  );
}


// ============================================================
// FETCH WITH TIMEOUT
// ============================================================

async function fetchWithTimeout(
  targetUrl
) {

  const controller =
    new AbortController();

  const timeout =
    setTimeout(
      () => controller.abort(),
      REQUEST_TIMEOUT_MS
    );

  try {

    return await fetch(
      targetUrl,
      {

        method: "GET",

        redirect: "manual",

        cache: "no-store",

        headers: {

          "Accept":
            "application/json",

        },

        signal:
          controller.signal,

      }
    );

  } finally {

    clearTimeout(timeout);

  }
}


// ============================================================
// READ GOOGLE RESPONSE
//
// Handles:
// 301
// 302
// 303
// 307
// 308
// ============================================================

async function fetchGoogleJson(
  firstUrl
) {

  let currentUrl =
    firstUrl;


  for (
    let redirectCount = 0;
    redirectCount <= MAX_REDIRECTS;
    redirectCount++
  ) {

    console.log(
      "[MOX GOOGLE] Request:",
      redirectCount,
      currentUrl
    );


    let response;


    try {

      response =
        await fetchWithTimeout(
          currentUrl
        );

    } catch (error) {

      if (
        error?.name ===
        "AbortError"
      ) {

        throw new Error(
          `Google request timeout after ${REQUEST_TIMEOUT_MS}ms`
        );

      }

      throw error;
    }


    console.log(
      "[MOX GOOGLE] Status:",
      response.status
    );


    // ======================================================
    // REDIRECT
    // ======================================================

    if (
      response.status === 301 ||
      response.status === 302 ||
      response.status === 303 ||
      response.status === 307 ||
      response.status === 308
    ) {

      const location =
        response.headers.get(
          "location"
        );


      console.log(
        "[MOX GOOGLE] Redirect:",
        location
      );


      if (!location) {

        throw new Error(
          "Google returned redirect without Location header"
        );

      }


      currentUrl =
        new URL(
          location,
          currentUrl
        ).toString();


      continue;
    }


    // ======================================================
    // HTTP ERROR
    // ======================================================

    if (!response.ok) {

      const errorText =
        await response.text();


      throw new Error(
        `Google HTTP ${response.status}: ${errorText.substring(0, 300)}`
      );

    }


    // ======================================================
    // FINAL RESPONSE
    // ======================================================

    const text =
      await response.text();


    console.log(
      "[MOX GOOGLE] Final response length:",
      text.length
    );


    if (
      !text ||
      !text.trim()
    ) {

      throw new Error(
        "Google returned empty response"
      );

    }


    // ======================================================
    // JSON
    // ======================================================

    try {

      return JSON.parse(
        text
      );

    } catch (error) {

      console.error(
        "[MOX GOOGLE] Invalid JSON:"
      );

      console.error(
        text.substring(
          0,
          500
        )
      );


      throw new Error(
        "Google returned invalid JSON"
      );

    }

  }


  throw new Error(
    `Too many Google redirects. Maximum allowed: ${MAX_REDIRECTS}`
  );
}


// ============================================================
// MAIN HANDLER
// ============================================================

export default async function handler(
  request
) {

  const startedAt =
    Date.now();


  try {

    // ========================================================
    // OPTIONS
    // ========================================================

    if (
      request.method ===
      "OPTIONS"
    ) {

      return new Response(
        null,
        {
          status: 204,
          headers:
            CORS_HEADERS,
        }
      );

    }


    // ========================================================
    // ONLY GET
    // ========================================================

    if (
      request.method !==
      "GET"
    ) {

      return jsonResponse(
        {
          success: false,

          message:
            "Method not allowed",
        },
        405
      );

    }


    // ========================================================
    // READ URL
    // ========================================================

    const url =
      new URL(
        request.url,
        `https://${request.headers.get("host") || "mox-2026.vercel.app"}`
      );


    // ========================================================
    // GUARDIAN MOX ID
    // ========================================================

    const guardianMoxId =
      (
        url.searchParams.get(
          "guardianMoxId"
        ) || ""
      )
        .trim()
        .toUpperCase();


    console.log(
      "[MOX STORE] Guardian:",
      guardianMoxId
    );


    // ========================================================
    // REQUIRED
    // ========================================================

    if (
      !guardianMoxId
    ) {

      return jsonResponse(
        {
          success: false,

          message:
            "guardianMoxId is required",
        },
        400
      );

    }


    // ========================================================
    // VALIDATE
    // ========================================================

    if (
      !/^MOX\d+-\d+$/.test(
        guardianMoxId
      )
    ) {

      return jsonResponse(
        {
          success: false,

          message:
            "Invalid guardianMoxId",

          guardianMoxId,
        },
        400
      );

    }


    // ========================================================
    // BUILD GOOGLE URL
    // ========================================================

    const googleUrl =
      `${GOOGLE_SCRIPT_URL}` +
      `?action=getByGuardianMoxId` +
      `&guardianMoxId=${encodeURIComponent(
        guardianMoxId
      )}`;


    console.log(
      "[MOX STORE] Calling Google..."
    );


    // ========================================================
    // CALL GOOGLE
    // ========================================================

    const data =
      await fetchGoogleJson(
        googleUrl
      );


    // ========================================================
    // SUCCESS
    // ========================================================

    const elapsedMs =
      Date.now() -
      startedAt;


    console.log(
      "[MOX STORE] SUCCESS in",
      elapsedMs,
      "ms"
    );


    return jsonResponse(
      {
        ...data,

        guardianMoxId,

        elapsedMs,
      },
      200
    );


  } catch (error) {

    // ========================================================
    // ERROR
    // ========================================================

    const elapsedMs =
      Date.now() -
      startedAt;


    console.error(
      "[MOX STORE] ERROR:",
      error
    );


    // ========================================================
    // TIMEOUT
    // ========================================================

    if (
      String(
        error?.message || ""
      ).toLowerCase()
        .includes(
          "timeout"
        )
    ) {

      return jsonResponse(
        {
          success: false,

          status:
            "google_timeout",

          message:
            "Google Apps Script request timed out",

          elapsedMs,
        },
        504
      );

    }


    // ========================================================
    // GENERAL ERROR
    // ========================================================

    return jsonResponse(
      {
        success: false,

        status:
          "store_api_error",

        message:
          "Store API error",

        error:
          error?.message ||
          String(error),

        elapsedMs,
      },
      502
    );

  }

}