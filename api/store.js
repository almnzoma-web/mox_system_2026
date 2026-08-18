export default async function handler(request) {
  try {
    const url = new URL(request.url, `https://${request.headers.host}`);
    const guardianMoxId = (url.searchParams.get('guardianMoxId') || '').trim().toUpperCase();

    if (!guardianMoxId) {
      return new Response(
        JSON.stringify({ success: false, message: 'guardianMoxId is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json; charset=UTF-8', 'Access-Control-Allow-Origin': '*' } }
      );
    }

    const scriptUrl = 'https://script.google.com/macros/s/AKfycbwr2cnnxQ8cUA6A7tsFJvUZdzE9xL5nADKBx5P6gJh5Z13NBkq7PIyptu3vYGqkCPzE/exec';
    const googleUrl = `${scriptUrl}?action=getByGuardianMoxId&guardianMoxId=${encodeURIComponent(guardianMoxId)}`;

    const response = await fetch(googleUrl);
    const text = await response.text();

    let data;
    try {
      data = JSON.parse(text);
    } catch (e) {
      return new Response(
        JSON.stringify({ success: false, message: 'Google Apps Script returned invalid JSON' }),
        { status: 502, headers: { 'Content-Type': 'application/json; charset=UTF-8', 'Access-Control-Allow-Origin': '*' } }
      );
    }

    return new Response(
      JSON.stringify(data),
      { status: 200, headers: { 'Content-Type': 'application/json; charset=UTF-8', 'Cache-Control': 'no-store', 'Access-Control-Allow-Origin': '*' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, message: 'Store API error', error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json; charset=UTF-8', 'Access-Control-Allow-Origin': '*' } }
    );
  }
}