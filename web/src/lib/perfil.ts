import "server-only";
import { createClient } from "@/lib/supabase/server";
import type { Perfil } from "@/lib/supabase/database.types";

export { destinoPadrao, podeAcessar } from "@/lib/destino";

/** Usuário logado + perfil (cliente e/ou funcionário). null se não logado. */
export async function obterPerfil() {
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  if (!data?.claims) return null;

  const { data: perfil } = await supabase.rpc("meu_perfil");
  return {
    userId: data.claims.sub,
    perfil: (perfil ?? { cliente: null, funcionario: null }) as Perfil,
  };
}
