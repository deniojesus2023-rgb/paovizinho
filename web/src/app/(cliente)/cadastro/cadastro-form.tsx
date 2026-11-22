"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

type Props = {
  unidades: { id: string; condominio: string }[];
  celular: string;
  next: string | null;
};

export function CadastroForm({ unidades, celular, next }: Props) {
  const router = useRouter();
  const supabase = useRef(createClient()).current;

  const [nome, setNome] = useState("");
  const [unidadeId, setUnidadeId] = useState(unidades.length === 1 ? unidades[0].id : "");
  const [bloco, setBloco] = useState("");
  const [apto, setApto] = useState("");
  const [referencia, setReferencia] = useState("");
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  const completo = nome.trim() && unidadeId && bloco.trim() && apto.trim();

  async function salvar(e: React.FormEvent) {
    e.preventDefault();
    if (!completo || salvando) return;
    setErro(null);
    setSalvando(true);
    const { error } = await supabase.rpc("completar_cadastro", {
      p_nome: nome,
      p_unidade_id: unidadeId,
      p_bloco: bloco,
      p_apto: apto,
      p_referencia: referencia || null,
    });
    if (error) {
      setSalvando(false);
      setErro(error.message || "Não deu para salvar agora. Tenta de novo.");
      return;
    }
    router.replace(next ?? "/inicio");
    router.refresh();
  }

  return (
    <main style={{ flex: 1, display: "flex", flexDirection: "column", minHeight: "100dvh" }}>
      <div className="topo-tela">
        <button type="button" className="btn-icone icone" onClick={() => router.push("/")} aria-label="Voltar">
          arrow_back
        </button>
        <strong>Cadastro</strong>
        <span style={{ width: 44 }} />
      </div>

      <form onSubmit={salvar} style={{ flex: 1, display: "flex", flexDirection: "column" }}>
        <div style={{ padding: "0 20px 24px", display: "flex", flexDirection: "column", gap: 20 }}>
          <div className="progresso">
            <span className="ativo" />
            <span className="ativo" />
          </div>

          <div style={{ display: "grid", gap: 6 }}>
            <h1 className="titulo" style={{ fontSize: 24 }}>Onde você mora?</h1>
            <p className="subtitulo">Assim a gente leva até a sua porta.</p>
          </div>

          <label className="campo">
            <span>Seu nome</span>
            <input className="input" autoComplete="given-name" value={nome} onChange={(e) => setNome(e.target.value)} autoFocus />
          </label>

          <label className="campo">
            <span>Celular (WhatsApp)</span>
            <input className="input" value={celular} readOnly style={{ color: "var(--texto-suave)" }} />
          </label>

          <label className="campo">
            <span>Condomínio</span>
            <select className="input" value={unidadeId} onChange={(e) => setUnidadeId(e.target.value)}>
              <option value="" disabled>
                Escolha o seu condomínio
              </option>
              {unidades.map((u) => (
                <option key={u.id} value={u.id}>
                  {u.condominio}
                </option>
              ))}
            </select>
          </label>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
            <label className="campo">
              <span>Bloco / Torre</span>
              <input className="input" value={bloco} onChange={(e) => setBloco(e.target.value)} />
            </label>
            <label className="campo">
              <span>Apartamento</span>
              <input className="input" inputMode="numeric" value={apto} onChange={(e) => setApto(e.target.value)} />
            </label>
          </div>

          <label className="campo">
            <span>Ponto de referência</span>
            <input
              className="input"
              placeholder="Ex.: portaria 2, interfone 52"
              value={referencia}
              onChange={(e) => setReferencia(e.target.value)}
            />
          </label>

          {erro && (
            <div className="erro" role="alert">
              <span className="icone" style={{ fontSize: 18 }}>error</span>
              {erro}
            </div>
          )}
        </div>

        <div className="rodape-fixo">
          <button type="submit" className="btn btn-primario" disabled={!completo || salvando}>
            {salvando ? "Salvando…" : "Começar a pedir"}
          </button>
        </div>
      </form>
    </main>
  );
}
