export default async function handler(request) {
  const start = Date.now();

  try {
    const url = new URL(request.url, `https://${request.headers.host}`);
    
    // استخراج الـ ID من مسار الـ URL مباشرة (سواء كان في الرابط كـ /store/MOX... أو كـ query)
    const pathSegments = url.pathname.split("/").filter(Boolean);
    let guardianMoxId = "";

    const storeIdx = pathSegments.indexOf("store");
    if (storeIdx !== -1 && pathSegments[storeIdx + 1]) {
      guardianMoxId = pathSegments[storeIdx + 1].trim().toUpperCase();
    } else if (pathSegments.length > 0) {
      guardianMoxId = pathSegments[pathSegments.length - 1].trim().toUpperCase();
    }

    // احتياطاً لو جاء في الـ Query
    if (!guardianMoxId) {
      guardianMoxId = (url.searchParams.get("guardianMoxId") || "").trim().toUpperCase();
    }

    const action = (url.searchParams.get("action") || "").trim().toLowerCase();

    const scriptUrl = "https://script.google.com/macros/s/AKfycbw3wYlv9U3x6U--mFKiv6usAasKEq0T8SQCSuOblQrDn1-X4MZ4iQ850J2YFjasUwtA/exec";
    let googleUrl = "";

    if (guardianMoxId && guardianMoxId.startsWith("MOX")) {
      googleUrl = `${scriptUrl}?action=getUserByGuardianMoxId&guardianMoxId=${encodeURIComponent(guardianMoxId)}`;
    } else if (action === "getall") {
      googleUrl = `${scriptUrl}?action=getAll`;
    } else {
      return json({ success: false, message: "Invalid or missing guardianMoxId", path: url.pathname }, 400);
    }

    // جلب البيانات من قوقل مع تحكم بالزمن (Timeout)
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 20000);

    let response;
    try {
      response = await fetch(googleUrl, {
        method: "GET",
        headers: { Accept: "application/json" },
        signal: controller.signal,
        redirect: "follow",
        cache: "no-store"
      });
    } finally {
      clearTimeout(timeout);
    }

    const text = await response.text();

    if (!response.ok || !text.trim()) {
      return json({ success: false, message: "Google Apps Script error or empty response", raw: text.substring(0, 500) }, 502);
    }

    let data;
    try {
      data = JSON.parse(text);
    } catch (e) {
      return json({ success: false, message: "Invalid JSON from Google", raw: text.substring(0, 500) }, 502);
    }

    // التأكد من بنية الرد المتوافقة مع الـ main
    const user = data.user || data.data || (data.ok ? data.user : null);

    if (!user) {
      return json({ success: false, message: "لم يتم العثور على المتجر في القاعدة", guardianMoxId }, 404);
    }

    return json({
      success: true,
      status: "success",
      guardianMoxId: guardianMoxId,
      user: user,
      data: user,
      vercel: { success: true, elapsedMs: Date.now() - start }
    }, 200);

  } catch (error) {
    return json({ success: false, message: error.message || "Vercel internal error" }, 500);
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