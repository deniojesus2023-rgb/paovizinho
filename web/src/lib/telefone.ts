/** Telefones brasileiros. No banco: E.164 sem "+" (5511987654321). */

export function soDigitos(v: string) {
  return v.replace(/\D/g, "");
}

/** Máscara enquanto digita: (11) 98765-4321 */
export function mascararCelular(v: string) {
  const d = soDigitos(v).replace(/^55(?=\d{10,11}$)/, "").slice(0, 11);
  if (d.length <= 2) return d.length ? `(${d}` : "";
  if (d.length <= 6) return `(${d.slice(0, 2)}) ${d.slice(2)}`;
  if (d.length <= 10) return `(${d.slice(0, 2)}) ${d.slice(2, 6)}-${d.slice(6)}`;
  return `(${d.slice(0, 2)}) ${d.slice(2, 7)}-${d.slice(7)}`;
}

/** Celular válido: DDD + 9 + 8 dígitos. */
export function celularValido(v: string) {
  return /^[1-9]{2}9\d{8}$/.test(soDigitos(v));
}

/** "(11) 98765-4321" → "+5511987654321" (formato do Supabase Auth) */
export function paraE164(v: string) {
  return `+55${soDigitos(v)}`;
}
