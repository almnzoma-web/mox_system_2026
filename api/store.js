export default async function handler(request) {
  const start = Date.now();

  try {
    const url = new URL(
      request.url,
      `https://${request.headers.host}`
    );

    const guardianMoxId = (
      url.searchParams.get("guardianMoxId") || ""
    )
      .trim()
      .toUpperCase();

    if (!guardianMoxId) {
      return json({
        success: false,
        status: "error",
        message: "guardianMoxId is required"
      }, 400);
    }

    const scriptUrl =
      "https://script.google.com/macros/s/AKfycbys7rhJQx5mY4lSpyAvDBZOHhexQO-vW7Y4pfVurAVJIZvb8gXI8_RXcvGPep8iU6Q/exec";

    const googleUrl =
      `${scriptUrl}?action=getByGuardianMoxId&guardianMoxId=${encodeURIComponent(
        guardianMoxId
      )}`;

    console.log("[MOX VERCEL] START");
    console.log("[MOX VERCEL] ID:", guardianMoxId);

    // --------------------------------------------------
    // TIMEOUT داخلي
    // --------------------------------------------------

    const controller = new AbortController();

    const timeout = setTimeout(() => {
      controller.abort();
    }, 8000);

    let response;

    try {
      response = await fetch(googleUrl, {
        method: "GET",
        headers: {
          "Accept": "application/json"
        },
        signal: controller.signal,
        redirect: "follow",
        cache: "no-store"
      });
    } finally {
      clearTimeout(timeout);
    }

    const elapsed = Date.now() - start;

    console.log(
      "[MOX VERCEL] GOOGLE RESPONSE:",
      response.status,
      elapsed + "ms"
    );

    const text = await response.text();

    console.log(
      "[MOX VERCEL] RESPONSE LENGTH:",
      text.length
    );

    if (!response.ok) {
      return json({
        success: false,
        status: "google_error",
        googleStatus: response.status,
        elapsedMs: elapsed,
        message: "Google Apps Script returned an error",
        raw: text.substring(0, 500)
      }, 502);
    }

    let data;

    try {
      data = JSON.parse(text);
    } catch (error) {
      return json({
        success: false,
        status: "invalid_json",
        elapsedMs: elapsed,
        message: "Google Apps Script returned invalid JSON",
        raw: text.substring(0, 500)
      }, 502);
    }

    return json({
      ...data,
      vercel: {
        success: true,
        elapsedMs: Date.now() - start
      }
    }, 200);

  } catch (error) {

    const elapsed = Date.now() - start;

    console.error(
      "[MOX VERCEL ERROR]",
      error
    );

    if (error.name === "AbortError") {
      return json({
        success: false,
        status: "timeout",
        elapsedMs: elapsed,
        message:
          "Vercel could not receive a response from Google within 8 seconds"
      }, 504);
    }

    return json({
      success: false,
      status: "vercel_error",
      elapsedMs: elapsed,
      message: error.message || "Vercel Store API error"
    }, 500);
  }
}


function json(data, status = 200) {
  return new Response(
    JSON.stringify(data),
    {
      status,
      headers: {
        "Content-Type":
          "application/json; charset=UTF-8",

        "Access-Control-Allow-Origin": "*",

        "Cache-Control":
          "no-store, no-cache, must-revalidate"
      }
    }
  );
}