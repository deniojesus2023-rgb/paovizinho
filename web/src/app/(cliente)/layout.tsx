// Páginas por usuário: leem a sessão no servidor e podem bloquear a renderização.
// (Cache Components; ver node_modules/next/dist/docs/01-app/02-guides/authentication-with-cache-components.md)
export const instant = false;

export default function ClienteLayout({ children }: { children: React.ReactNode }) {
  return <div className="app-mobile">{children}</div>;
}
