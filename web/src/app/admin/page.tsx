import { AreaRestrita } from "@/components/area-restrita";

export const instant = false;

// Etapa 7: visão geral, cardápio e estoque, equipe, unidades.
export default function Admin() {
  return (
    <AreaRestrita area="admin" titulo="Painel">
      <p className="subtitulo">Login do dono/gerente funcionando. O painel chega na etapa 7.</p>
    </AreaRestrita>
  );
}
