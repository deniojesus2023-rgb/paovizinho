import { redirect } from "next/navigation";
import { caminhoSeguro, destinoAposLogin } from "@/lib/destino";
import { obterPerfil } from "@/lib/perfil";
import { EntrarForm } from "./entrar-form";

export default async function Entrar({ searchParams }: PageProps<"/entrar">) {
  const next = caminhoSeguro((await searchParams).next);
  const sessao = await obterPerfil();
  if (sessao) redirect(destinoAposLogin(sessao.perfil, next));

  return <EntrarForm next={next} />;
}
