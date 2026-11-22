import type { FuncaoFuncionario, Perfil } from "@/lib/supabase/database.types";

/** Para onde mandar a pessoa depois do login. */
export function destinoPadrao(perfil: Perfil) {
  const f = perfil.funcionario;
  if (f) return f.funcao === "dono" || f.funcao === "gerente" ? "/admin" : "/balcao";
  return perfil.cliente ? "/inicio" : "/cadastro";
}

export function podeAcessar(funcao: FuncaoFuncionario | undefined, area: "balcao" | "admin") {
  if (!funcao) return false;
  return area === "admin" ? funcao === "dono" || funcao === "gerente" : true;
}

/** Aceita só caminhos internos (evita redirecionamento aberto). */
export function caminhoSeguro(next: string | string[] | undefined | null) {
  const v = Array.isArray(next) ? next[0] : next;
  return v && v.startsWith("/") && !v.startsWith("//") && !v.startsWith("/\\") ? v : null;
}

/** Destino após o login, respeitando ?next= quando fizer sentido. */
export function destinoAposLogin(perfil: Perfil, next: string | null) {
  if (!perfil.cliente && !perfil.funcionario) {
    return next ? `/cadastro?next=${encodeURIComponent(next)}` : "/cadastro";
  }
  return next ?? destinoPadrao(perfil);
}
