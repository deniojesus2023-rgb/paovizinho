import Link from "next/link";
import { connection } from "next/server";
import { obterPerfil } from "@/lib/perfil";
import { createClient } from "@/lib/supabase/server";

function saudacao() {
  const hora = Number(
    new Intl.DateTimeFormat("pt-BR", { hour: "numeric", hour12: false, timeZone: "America/Sao_Paulo" }).format(new Date()),
  );
  return hora < 12 ? "Bom dia" : hora < 18 ? "Boa tarde" : "Boa noite";
}

// Etapa 1: só a casca do Início. O cardápio, a sacola e o pedido chegam na etapa 2.
export default async function Inicio() {
  await connection(); // a saudação depende da hora atual
  const sessao = await obterPerfil();
  const cliente = sessao?.perfil.cliente;

  let endereco: string | null = null;
  if (cliente) {
    const supabase = await createClient();
    const { data } = await supabase
      .from("enderecos")
      .select("bloco, apto")
      .eq("cliente_id", cliente.id)
      .eq("principal", true)
      .maybeSingle();
    if (data) endereco = `Bloco ${data.bloco} · ${data.apto}`;
  }

  return (
    <main style={{ padding: "16px 20px 40px", display: "flex", flexDirection: "column", gap: 24 }}>
      <header style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/marca/logo-horizontal-cor.svg" alt="pão vizinho" style={{ width: 120 }} />
        {endereco ? (
          <span style={{ display: "flex", alignItems: "center", gap: 4, fontSize: 13, fontWeight: 700, color: "var(--texto-suave)" }}>
            <span className="icone" style={{ fontSize: 18, color: "var(--laranja)" }}>location_on</span>
            {endereco}
          </span>
        ) : (
          <Link href="/entrar" style={{ fontSize: 13, fontWeight: 700 }}>Entrar</Link>
        )}
      </header>

      <div style={{ display: "grid", gap: 4 }}>
        <h1 className="titulo" style={{ fontSize: 28, fontWeight: 500 }}>
          {saudacao()}{cliente ? `, ${cliente.nome.split(" ")[0]}` : ""}.
        </h1>
        <p className="titulo" style={{ fontSize: 28 }}>Vai o de sempre?</p>
      </div>

      <div
        style={{
          border: "1px solid var(--borda)",
          background: "var(--superficie)",
          borderRadius: 20,
          padding: 20,
          display: "grid",
          gap: 8,
          boxShadow: "var(--sombra-card)",
        }}
      >
        <span className="label-secao">Em breve</span>
        <p style={{ margin: 0, fontSize: 15, lineHeight: 1.5 }}>
          O cardápio fresquinho e a sacola chegam na próxima etapa.
        </p>
      </div>

      {sessao && (
        <form action="/auth/sair" method="post">
          <button type="submit" className="btn btn-contorno">Sair</button>
        </form>
      )}
    </main>
  );
}
