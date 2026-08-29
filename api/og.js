// ============================================================
// MOX DIGITAL
// PUBLIC STORE API
//
// Vercel -> Google Apps Script -> Google Sheets
//
// الرابط العام:
// /api/store?guardianMoxId=MOX249-00010001
// ============================================================

export default async function handler(request) {

  // ==========================================================
  // CORS
  // ==========================================================

  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  };

  // ==========================================================
  // OPTIONS
  // ==========================================================

  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  // ==========================================================
  // GET ONLY
  // ==========================================================

  if (request.method !== "GET") {
    return new Response(
      JSON.stringify({
        success: false,
        message: "Method not allowed",
      }),
      {
        status: 405,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json; charset=UTF-8",
        },
      }
    );
  }

  try {

    // ========================================================
    // READ URL
    // ========================================================

    const url = new URL(
      request.url,
      `https://${request.headers.get("host") || "mox-2026.vercel.app"}`
    );

    const guardianMoxId =
      (url.searchParams.get("guardianMoxId") || "")
        .trim()
        .toUpperCase();

    console.log(
      "[MOX STORE] guardianMoxId:",
      guardianMoxId
    );

    // ========================================================
    // VALIDATE ID
    // ========================================================

    if (!guardianMoxId) {

      return new Response(
        JSON.stringify({
          success: false,
          message: "guardianMoxId is required",
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type":
              "application/json; charset=UTF-8",
          },
        }
      );
    }

    // ========================================================
    // BASIC GUARDIAN ID VALIDATION
    //
    // مثال:
    // MOX249-00010001
    // ========================================================

    if (!/^MOX\d+-\d+$/.test(guardianMoxId)) {

      return new Response(
        JSON.stringify({
          success: false,
          message: "Invalid guardianMoxId",
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type":
              "application/json; charset=UTF-8",
          },
        }
      );
    }

    // ========================================================
    // GOOGLE APPS SCRIPT
    // ========================================================

    const scriptUrl =
      "https://script.google.com/macros/s/AKfycbyjUvfKEcii4ck2klEIgPjSXDzss3AipUV6nHpVlqsoJ7gdhefx_Ua8AdHENIbX8HGg/exec";

    const googleUrl =
      `${scriptUrl}` +
      `?action=getUserByGuardianMoxId` +
      `&guardianMoxId=${encodeURIComponent(guardianMoxId)}`;

    console.log(
      "[MOX STORE] Google URL:",
      googleUrl
    );

    // ========================================================
    // TIMEOUT
    //
    // لا نسمح للمتجر بالبقاء في جاري التحميل بلا نهاية.
    // ========================================================

    const controller =
      new AbortController();

    const timeout =
      setTimeout(() => {
        controller.abort();
      }, 8000);

    let response;

    try {

      response = await fetch(
        googleUrl,
        {
          method: "GET",

          redirect: "follow",

          cache: "no-store",

          headers: {
            "Accept": "application/json",
          },

          signal: controller.signal,
        }
      );

    } finally {

      clearTimeout(timeout);

    }

    // ========================================================
    // GOOGLE HTTP STATUS
    // ========================================================

    console.log(
      "[MOX STORE] Google status:",
      response.status
    );

    if (!response.ok) {

      const errorText =
        await response.text();

      console.error(
        "[MOX STORE] Google HTTP ERROR:",
        errorText.substring(0, 500)
      );

      return new Response(
        JSON.stringify({
          success: false,
          message:
            "Google Apps Script request failed",

          googleStatus:
            response.status,

          raw:
            errorText.substring(0, 200),
        }),
        {
          status: 502,

          headers: {
            ...corsHeaders,

            "Content-Type":
              "application/json; charset=UTF-8",

            "Cache-Control":
              "no-store",
          },
        }
      );
    }

    // ========================================================
    // READ RESPONSE
    // ========================================================

    const text =
      await response.text();

    console.log(
      "[MOX STORE] Google response:",
      text.substring(0, 300)
    );

    // ========================================================
    // EMPTY RESPONSE
    // ========================================================

    if (!text || !text.trim()) {

      return new Response(
        JSON.stringify({
          success: false,
          message:
            "Google Apps Script returned empty response",
        }),
        {
          status: 502,

          headers: {
            ...corsHeaders,

            "Content-Type":
              "application/json; charset=UTF-8",

            "Cache-Control":
              "no-store",
          },
        }
      );
    }

    // ========================================================
    // JSON PARSE
    // ========================================================

    let data;

    try {

      data =
        JSON.parse(text);

    } catch (error) {

      console.error(
        "[MOX STORE] Invalid JSON from Google"
      );

      console.error(
        "[MOX STORE] Raw response:",
        text.substring(0, 500)
      );

      return new Response(
        JSON.stringify({
          success: false,

          message:
            "Google Apps Script returned invalid JSON",

          raw:
            text.substring(0, 200),
        }),
        {
          status: 502,

          headers: {
            ...corsHeaders,

            "Content-Type":
              "application/json; charset=UTF-8",

            "Cache-Control":
              "no-store",
          },
        }
      );
    }

    // ========================================================
    // SUCCESS
    // ========================================================

    console.log(
      "[MOX STORE] SUCCESS:",
      guardianMoxId
    );

    return new Response(
      JSON.stringify(data),
      {
        status: 200,

        headers: {
          ...corsHeaders,

          "Content-Type":
            "application/json; charset=UTF-8",

          "Cache-Control":
            "no-store, no-cache, must-revalidate",

          "Pragma":
            "no-cache",
        },
      }
    );

  } catch (error) {

    // ========================================================
    // TIMEOUT
    // ========================================================

    if (
      error &&
      error.name === "AbortError"
    ) {

      console.error(
        "[MOX STORE] Google request TIMEOUT"
      );

      return new Response(
        JSON.stringify({
          success: false,

          message:
            "Google Apps Script request timeout",

          timeout:
            true,
        }),
        {
          status: 504,

          headers: {
            ...corsHeaders,

            "Content-Type":
              "application/json; charset=UTF-8",

            "Cache-Control":
              "no-store",
          },
        }
      );
    }

    // ========================================================
    // GENERAL ERROR
    // ========================================================

    console.error(
      "[MOX STORE] API ERROR:",
      error
    );

    return new Response(
      JSON.stringify({
        success: false,

        message:
          "Store API error",

        error:
          error?.message ||
          String(error),
      }),
      {
        status: 500,

        headers: {
          ...corsHeaders,

          "Content-Type":
            "application/json; charset=UTF-8",

          "Cache-Control":
            "no-store",
        },
      }
    );
  }
}