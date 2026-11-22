"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { destinoAposLogin } from "@/lib/destino";
import { celularValido, mascararCelular, paraE164, soDigitos } from "@/lib/telefone";
import type { Perfil } from "@/lib/supabase/database.types";

const ESPERA_REENVIO = 30; // segundos (igual ao max_frequency do Auth)

export function EntrarForm({ next }: { next: string | null }) {
  const router = useRouter();
  const supabase = useRef(createClient()).current;

  const [etapa, setEtapa] = useState<"celular" | "codigo">("celular");
  const [celular, setCelular] = useState("");
  const [codigo, setCodigo] = useState("");
  const [enviando, setEnviando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [espera, setEspera] = useState(0);
  const codigoRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (espera <= 0) return;
    const t = setTimeout(() => setEspera((s) => s - 1), 1000);
    return () => clearTimeout(t);
  }, [espera]);

  async function enviarCodigo() {
    setErro(null);
    if (!celularValido(celular)) {
      setErro("Confere o número: DDD + celular com 9 dígitos.");
      return;
    }
    setEnviando(true);
    const { error } = await supabase.auth.signInWithOtp({ phone: paraE164(celular) });
    setEnviando(false);
    if (error) {
      setErro(
        error.status === 429
          ? "Calma, já mandamos um código. Espera uns segundinhos e tenta de novo."
          : "Não conseguimos mandar o código agora. Tenta de novo em instantes.",
      );
      return;
    }
    setCodigo("");
    setEtapa("codigo");
    setEspera(ESPERA_REENVIO);
    setTimeout(() => codigoRef.current?.focus(), 50);
  }

  async function confirmarCodigo(valor = codigo) {
    if (valor.length !== 6 || enviando) return;
    setErro(null);
    setEnviando(true);
    const { error } = await supabase.auth.verifyOtp({ phone: paraE164(celular), token: valor, type: "sms" });
    if (error) {
      setEnviando(false);
      setErro("Código errado ou vencido. Confere no WhatsApp e tenta de novo.");
      return;
    }
    const { data } = await supabase.rpc("meu_perfil");
    const perfil = (data ?? { cliente: null, funcionario: null }) as Perfil;
    router.replace(destinoAposLogin(perfil, next));
    router.refresh();
  }

  function voltar() {
    if (etapa === "codigo") {
      setEtapa("celular");
      setErro(null);
    } else {
      router.push("/");
    }
  }

  return (
    <main style={{ flex: 1, display: "flex", flexDirection: "column", minHeight: "100dvh" }}>
      <div className="topo-tela">
        <button type="button" className="btn-icone icone" onClick={voltar} aria-label="Voltar">
          arrow_back
        </button>
        <strong>Cadastro</strong>
        <span style={{ width: 44 }} />
      </div>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (etapa === "celular") enviarCodigo();
          else confirmarCodigo();
        }}
        style={{ flex: 1, display: "flex", flexDirection: "column" }}
      >
        <div style={{ padding: "0 20px 24px", display: "flex", flexDirection: "column", gap: 20 }}>
          <div className="progresso">
            <span className="ativo" />
            <span />
          </div>

          {etapa === "celular" ? (
            <>
              <div style={{ display: "grid", gap: 6 }}>
                <h1 className="titulo" style={{ fontSize: 24 }}>Qual é o seu celular?</h1>
                <p className="subtitulo">A gente manda um código pelo WhatsApp para você entrar.</p>
              </div>
              <label className="campo">
                <span>Celular (WhatsApp)</span>
                <input
                  className="input"
                  type="tel"
                  inputMode="numeric"
                  autoComplete="tel-national"
                  placeholder="(11) 98765-4321"
                  value={celular}
                  onChange={(e) => setCelular(mascararCelular(e.target.value))}
                  autoFocus
                />
              </label>
            </>
          ) : (
            <>
              <div style={{ display: "grid", gap: 6 }}>
                <h1 className="titulo" style={{ fontSize: 24 }}>Digite o código</h1>
                <p className="subtitulo">
                  Mandamos 6 números no WhatsApp do <strong style={{ color: "var(--chocolate)" }}>{celular}</strong>.
                </p>
              </div>
              <label className="campo">
                <span>Código</span>
                <input
                  ref={codigoRef}
                  className="input"
                  type="text"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  placeholder="••••••"
                  maxLength={6}
                  value={codigo}
                  onChange={(e) => {
                    const v = soDigitos(e.target.value).slice(0, 6);
                    setCodigo(v);
                    if (v.length === 6) confirmarCodigo(v);
                  }}
                  style={{ fontFamily: "var(--fonte-titulo)", fontSize: 24, fontWeight: 700, letterSpacing: "0.4em", textAlign: "center" }}
                />
              </label>
              <div style={{ display: "flex", justifyContent: "space-between" }}>
                <button type="button" className="btn-texto" onClick={() => setEtapa("celular")}>
                  Trocar número
                </button>
                <button type="button" className="btn-texto" disabled={espera > 0 || enviando} onClick={enviarCodigo}>
                  {espera > 0 ? `Reenviar em ${espera}s` : "Reenviar código"}
                </button>
              </div>
            </>
          )}

          {erro && (
            <div className="erro" role="alert">
              <span className="icone" style={{ fontSize: 18 }}>error</span>
              {erro}
            </div>
          )}
        </div>

        <div className="rodape-fixo">
          <button
            type="submit"
            className="btn btn-primario"
            disabled={enviando || (etapa === "celular" ? !celularValido(celular) : codigo.length !== 6)}
          >
            {enviando ? "Aguarde…" : etapa === "celular" ? "Receber código no WhatsApp" : "Entrar"}
          </button>
          {etapa === "celular" && (
            <p style={{ margin: "12px 0 0", textAlign: "center", fontSize: 12, color: "var(--texto-suave)" }}>
              Ao continuar, você aceita os{" "}
              <Link href="#" style={{ color: "var(--chocolate)", fontWeight: 700 }}>Termos</Link> e a{" "}
              <Link href="#" style={{ color: "var(--chocolate)", fontWeight: 700 }}>Privacidade</Link>.
            </p>
          )}
        </div>
      </form>
    </main>
  );
}
