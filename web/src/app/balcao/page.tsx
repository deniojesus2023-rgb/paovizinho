import { AreaRestrita } from "@/components/area-restrita";

export const instant = false;

// Etapa 3: kanban (Novos · Separando · Prontos) com Realtime e a máquina de status.
export default function Balcao() {
  return (
    <AreaRestrita area="balcao" titulo="Balcão">
      <p className="subtitulo">Login da equipe funcionando. O quadro de pedidos chega na etapa 3.</p>
    </AreaRestrita>
  );
}
