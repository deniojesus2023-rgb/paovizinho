// Tipos do banco usados até a etapa 1 (banco + autenticação).
// Para gerar a versão completa a partir do Supabase local:
//   npm run db:types
// (substitui este arquivo pelo gerado pelo Supabase CLI)

export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type FuncaoFuncionario = "dono" | "gerente" | "balcao" | "entrega";

type Tabela<Row, Insert = Partial<Row>> = {
  Row: Row;
  Insert: Insert;
  Update: Partial<Row>;
  Relationships: [];
};

export type Unidade = {
  id: string;
  nome: string;
  condominio: string;
  endereco: string | null;
  aberta: boolean;
  taxa_entrega: number;
  horarios: Json;
  ativa: boolean;
  created_at: string;
};

export type Cliente = {
  id: string;
  auth_user_id: string | null;
  nome: string;
  telefone: string;
  created_at: string;
};

export type Endereco = {
  id: string;
  cliente_id: string;
  unidade_id: string;
  apelido: string;
  bloco: string;
  apto: string;
  referencia: string | null;
  principal: boolean;
  created_at: string;
};

export type Funcionario = {
  id: string;
  auth_user_id: string | null;
  nome: string;
  telefone: string;
  funcao: FuncaoFuncionario;
  unidade_id: string | null;
  turno: string | null;
  ativo: boolean;
  created_at: string;
};

export type Perfil = {
  cliente: { id: string; nome: string; telefone: string } | null;
  funcionario: {
    id: string;
    nome: string;
    funcao: FuncaoFuncionario;
    unidade_id: string | null;
    turno: string | null;
  } | null;
};

export type Database = {
  public: {
    Tables: {
      unidades: Tabela<Unidade>;
      clientes: Tabela<Cliente>;
      enderecos: Tabela<Endereco>;
      funcionarios: Tabela<Funcionario>;
    };
    Views: Record<string, never>;
    Functions: {
      completar_cadastro: {
        Args: { p_nome: string; p_unidade_id: string; p_bloco: string; p_apto: string; p_referencia?: string | null };
        Returns: string;
      };
      meu_perfil: { Args: Record<string, never>; Returns: Json };
      definir_recebendo_pedidos: { Args: { p_unidade_id: string; p_aberta: boolean }; Returns: undefined };
    };
    Enums: {
      funcao_funcionario: FuncaoFuncionario;
    };
    CompositeTypes: Record<string, never>;
  };
};
