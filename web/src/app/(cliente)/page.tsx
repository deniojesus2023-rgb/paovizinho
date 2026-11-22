import Link from "next/link";
import { redirect } from "next/navigation";
import { destinoPadrao, obterPerfil } from "@/lib/perfil";
import styles from "./boas-vindas.module.css";

export default async function BoasVindas() {
  const sessao = await obterPerfil();
  if (sessao) redirect(destinoPadrao(sessao.perfil));

  return (
    <main className={styles.tela}>
      <div className={styles.padrao} aria-hidden />
      <div className={styles.topo}>
        <div className={styles.simbolo}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/marca/simbolo-cor.svg" alt="" width={96} />
        </div>
      </div>

      <section className={styles.folha}>
        <span className={styles.alca} />
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/marca/logo-horizontal-cor.svg" alt="pão vizinho" className={styles.logo} />
        <h1 className={`titulo ${styles.chamada}`}>
          Seu pãozinho,
          <br />
          pertinho de casa.
        </h1>
        <p className={styles.texto}>Peça do apê e receba fresquinho na porta, ou retire no balcão.</p>
        <div className={styles.acoes}>
          <Link href="/entrar" className="btn btn-primario grande">
            <span className="icone" style={{ fontSize: 22 }}>chat</span>
            Entrar com WhatsApp
          </Link>
          <Link href="/inicio" className="btn btn-contorno">
            Só dar uma olhada
          </Link>
        </div>
        <p className={styles.legal}>
          Ao continuar, você aceita os <a href="#">Termos</a> e a <a href="#">Privacidade</a>.
        </p>
      </section>
    </main>
  );
}
