import { redirect } from "next/navigation";
import { obterPerfil, podeAcessar } from "@/lib/perfil";

const NOMES = { dono: "Dono", gerente: "Gerente", balcao: "Balcão", entrega: "Entrega" } as const;

/** Guarda das áreas da equipe. A RLS continua sendo a barreira real no banco. */
export async function AreaRestrita({
  area,
  titulo,
  children,
}: {
  area: "balcao" | "admin";
  titulo: string;
  children?: React.ReactNode;
}) {
  const sessao = await obterPerfil();
  if (!sessao) redirect(`/entrar?next=/${area}`);
  const f = sessao.perfil.funcionario;
  if (!podeAcessar(f?.funcao, area)) redirect(f ? "/balcao" : "/inicio");

  return (
    <div style={{ minHeight: "100dvh", background: "var(--areia-2)" }}>
      <header
        style={{
          height: 68,
          background: "var(--superficie)",
          borderBottom: "1px solid var(--borda)",
          display: "flex",
          alignItems: "center",
          gap: 16,
          padding: "0 24px",
        }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/marca/logo-horizontal-cor.svg" alt="pão vizinho" style={{ width: 120 }} />
        <span style={{ width: 1, height: 28, background: "var(--borda)" }} />
        <span className="label-secao" style={{ fontSize: 11 }}>{titulo}</span>
        <span style={{ flex: 1 }} />
        <span style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <span
            style={{
              width: 36,
              height: 36,
              borderRadius: 999,
              background: "var(--caramelo)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontWeight: 700,
            }}
          >
            {f!.nome[0]}
          </span>
          <span style={{ display: "grid", gap: 1 }}>
            <strong style={{ fontSize: 14 }}>{f!.nome}</strong>
            <span style={{ fontSize: 12, color: "var(--texto-suave)" }}>
              {NOMES[f!.funcao]}
              {f!.turno ? ` · ${f!.turno}` : ""}
            </span>
          </span>
        </span>
        <form action="/auth/sair" method="post">
          <button type="submit" className="btn-icone icone" aria-label="Sair" title="Sair">logout</button>
        </form>
      </header>
      <main style={{ padding: 24 }}>{children}</main>
    </div>
  );
}
