import { redirect } from "next/navigation";
import { caminhoSeguro, destinoPadrao } from "@/lib/destino";
import { obterPerfil } from "@/lib/perfil";
import { createClient } from "@/lib/supabase/server";
import { mascararCelular } from "@/lib/telefone";
import { CadastroForm } from "./cadastro-form";

export default async function Cadastro({ searchParams }: PageProps<"/cadastro">) {
  const next = caminhoSeguro((await searchParams).next);
  const sessao = await obterPerfil();
  if (!sessao) redirect("/entrar?next=/cadastro");
  if (sessao.perfil.cliente || sessao.perfil.funcionario) redirect(next ?? destinoPadrao(sessao.perfil));

  const supabase = await createClient();
  const [{ data: unidades }, { data: claims }] = await Promise.all([
    supabase.from("unidades").select("id, condominio").eq("ativa", true).order("condominio"),
    supabase.auth.getClaims(),
  ]);

  return (
    <CadastroForm
      unidades={unidades ?? []}
      celular={mascararCelular(String(claims?.claims.phone ?? ""))}
      next={next}
    />
  );
}
