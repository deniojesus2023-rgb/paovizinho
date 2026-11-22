// Hook "Send SMS" do Supabase Auth: entrega o código de login pelo WhatsApp.
// Docs: https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook
//
// Variáveis (supabase secrets set …):
//   SEND_SMS_HOOK_SECRET   "v1,whsec_…" (gerado no painel ao criar o hook)
//   WHATSAPP_PROVIDER      "meta" | "zapi" | "log" (log = só imprime, para desenvolvimento)
//   — Meta (API oficial do WhatsApp Cloud):
//   META_WA_TOKEN, META_WA_PHONE_NUMBER_ID, META_WA_TEMPLATE (modelo de autenticação, ex.: "codigo_login")
//   — Z-API:
//   ZAPI_INSTANCE, ZAPI_TOKEN, ZAPI_CLIENT_TOKEN
import { Webhook } from "npm:standardwebhooks@1.0.0";

type HookPayload = {
  user: { id: string; phone: string };
  sms: { otp: string };
};

const env = (k: string) => Deno.env.get(k) ?? "";

async function enviarMeta(telefone: string, codigo: string) {
  const res = await fetch(
    `https://graph.facebook.com/v21.0/${env("META_WA_PHONE_NUMBER_ID")}/messages`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env("META_WA_TOKEN")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        messaging_product: "whatsapp",
        to: telefone,
        type: "template",
        template: {
          name: env("META_WA_TEMPLATE") || "codigo_login",
          language: { code: "pt_BR" },
          components: [
            { type: "body", parameters: [{ type: "text", text: codigo }] },
            // modelos de autenticação têm botão "copiar código"
            { type: "button", sub_type: "url", index: "0", parameters: [{ type: "text", text: codigo }] },
          ],
        },
      }),
    },
  );
  if (!res.ok) throw new Error(`Meta ${res.status}: ${await res.text()}`);
}

async function enviarZapi(telefone: string, codigo: string) {
  const res = await fetch(
    `https://api.z-api.io/instances/${env("ZAPI_INSTANCE")}/token/${env("ZAPI_TOKEN")}/send-text`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "Client-Token": env("ZAPI_CLIENT_TOKEN") },
      body: JSON.stringify({
        phone: telefone,
        message: `Pão Vizinho: seu código é *${codigo}*. Ele vale por alguns minutos. Não compartilhe com ninguém.`,
      }),
    },
  );
  if (!res.ok) throw new Error(`Z-API ${res.status}: ${await res.text()}`);
}

function erro(status: number, message: string) {
  return new Response(JSON.stringify({ error: { http_code: status, message } }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  const corpo = await req.text();
  const segredo = env("SEND_SMS_HOOK_SECRET").replace("v1,whsec_", "");

  let payload: HookPayload;
  try {
    payload = new Webhook(segredo).verify(corpo, Object.fromEntries(req.headers)) as HookPayload;
  } catch {
    return erro(401, "Assinatura inválida");
  }

  const telefone = payload.user.phone.replace(/\D/g, "");
  const codigo = payload.sms.otp;

  try {
    switch (env("WHATSAPP_PROVIDER") || "log") {
      case "meta":
        await enviarMeta(telefone, codigo);
        break;
      case "zapi":
        await enviarZapi(telefone, codigo);
        break;
      default:
        console.log(`[send-sms] código para ${telefone}: ${codigo}`);
    }
  } catch (e) {
    console.error("[send-sms]", e);
    return erro(502, "Não foi possível enviar o código pelo WhatsApp");
  }

  return new Response("{}", { headers: { "Content-Type": "application/json" } });
});
